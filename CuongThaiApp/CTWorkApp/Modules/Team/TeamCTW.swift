import SwiftUI

// MARK: - Team — thành viên dự án, khối lượng việc, nhóm của không gian, mời bằng link
//
// Danh sách thành viên đọc từ `AppState.cauHinhDuAn.members` (cấu hình dự án đã
// nạp sẵn — đừng gọi lại `GET /projects/:pid`). Khối lượng việc từng người từ
// `/team-overview` (khách cổng bị 403 ⇒ chỉ ẩn khối đó, không báo lỗi cả màn).
// Đổi vai trò/xoá: chỉ khi `permissions.manageMembers`, luôn hỏi lại trước.

@MainActor
final class TeamVM: ObservableObject {
    let pid: Int
    @Published var tongQuan: CTWTongQuanNhom?
    @Published var nhom: [CTWNhomKhongGian]?
    @Published var loi: String?
    @Published var dangLam = false

    init(pid: Int) { self.pid = pid }

    func tai(wsId: Int?, khach: Bool) async {
        // Hai lời gọi độc lập — hỏng cái nào thì chỉ ẩn khối đó.
        async let a: CTWTongQuanNhom? = khach ? nil : try? APIClient.shared.request(CTWAPI.tongQuanNhom(pid: pid))
        async let b: [CTWNhomKhongGian]? = wsId == nil ? nil : try? APIClient.shared.request(CTWAPI.nhomKhongGian(wsId: wsId!))
        let (x, y) = await (a, b)
        tongQuan = x
        nhom = y
    }

    func doiVaiTro(_ u: CTWUser, _ r: CTWVaiTroDuAn, app: AppState) async {
        dangLam = true
        defer { dangLam = false }
        do {
            try await APIClient.shared.send(CTWAPI.doiVaiTro(pid: pid, uid: u.id, vaiTro: r.rawValue))
            CTWRung.thanhCong()
            await app.napCauHinhDuAn()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }

    func xoa(_ u: CTWUser, app: AppState) async {
        dangLam = true
        defer { dangLam = false }
        do {
            try await APIClient.shared.send(CTWAPI.xoaThanhVien(pid: pid, uid: u.id))
            CTWRung.thanhCong()
            await app.napCauHinhDuAn()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}

struct TeamCTW: View {
    let nguCanh: CTWNguCanh
    @StateObject private var vm: TeamVM
    @EnvironmentObject private var app: AppState
    @State private var tamPhu: TamPhu?
    @State private var hoiDoi: (nguoi: CTWUser, vaiTro: CTWVaiTroDuAn)?
    @State private var hoiXoa: CTWUser?

    private enum TamPhu: String, Identifiable { case moi; var id: String { rawValue } }

    init(nguCanh: CTWNguCanh) {
        self.nguCanh = nguCanh
        _vm = StateObject(wrappedValue: TeamVM(pid: nguCanh.pid))
    }

    private var cfg: CTWProjectConfig? { app.cauHinhDuAn }
    private var quanLy: Bool { cfg?.coQuyen("manageMembers") == true }
    private var khach: Bool { cfg?.role == "CLIENT" }
    /// Mời bằng link: OWNER/ADMIN của không gian (máy chủ kiểm lại).
    private var moiDuoc: Bool { ["OWNER", "ADMIN"].contains(cfg?.workspaceRole ?? "") && cfg?.workspace?.id != nil }

    private var thanhVien: [CTWUser] {
        let thuTu = ["ADMIN": 0, "MEMBER": 1, "TEACHER": 2, "VIEWER": 3, "CLIENT": 4]
        return (cfg?.members ?? []).sorted {
            (thuTu[$0.role ?? ""] ?? 9, $0.laAgent ? 1 : 0, $0.ten.lowercased()) < (thuTu[$1.role ?? ""] ?? 9, $1.laAgent ? 1 : 0, $1.ten.lowercased())
        }
    }

    var body: some View {
        List {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if let t = vm.tongQuan?.totals {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                        CTWODem(so: "\(t.members ?? thanhVien.count)", nhan: "Members", bieuTuong: "person.2.fill")
                        CTWODem(so: "\(t.inProgress ?? 0)", nhan: "In progress", bieuTuong: "play.circle.fill", mau: AppColors.info)
                        CTWODem(so: "\(t.overdue ?? 0)", nhan: "Overdue", bieuTuong: "clock.badge.exclamationmark.fill",
                                mau: (t.overdue ?? 0) > 0 ? AppColors.error : AppColors.textSecondary)
                        CTWODem(so: "\(t.reviews ?? 0)", nhan: "Waiting for review", bieuTuong: "eye.fill", mau: AppColors.warning)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            Section {
                ForEach(thanhVien) { u in hang(u) }
            } header: {
                Text("Members · \(thanhVien.count)")
            } footer: {
                if quanLy { Text("Touch and hold a member to change their role or remove them from the project.") }
            }
            if let ds = vm.nhom, !ds.isEmpty {
                Section("Workspace teams") {
                    ForEach(ds.filter { $0.archivedAt == nil }) { n in hangNhom(n) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if cfg == nil { CTWKhungTai(soHang: 6) } }
        .navigationTitle("Team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if moiDuoc {
                ToolbarItem(placement: .primaryAction) {
                    Button { tamPhu = .moi } label: { Label("Invite", systemImage: "person.badge.plus") }
                }
            }
        }
        .refreshable {
            await app.napCauHinhDuAn()
            await vm.tai(wsId: cfg?.workspace?.id, khach: khach)
        }
        .task { if vm.tongQuan == nil && vm.nhom == nil { await vm.tai(wsId: cfg?.workspace?.id, khach: khach) } }
        .sheet(item: $tamPhu) { _ in
            if let ws = cfg?.workspace?.id {
                MoiBangLinkCTW(wsId: ws, pid: nguCanh.pid, tenDuAn: nguCanh.tenDuAn,
                               laAdminDuAn: quanLy)
            }
        }
        .confirmationDialog(
            hoiDoi.map { "Change \($0.nguoi.ten)'s role to \($0.vaiTro.ten)?" } ?? "",
            isPresented: Binding(get: { hoiDoi != nil }, set: { if !$0 { hoiDoi = nil } }),
            titleVisibility: .visible
        ) {
            Button("Change role") {
                guard let h = hoiDoi else { return }
                Task { await vm.doiVaiTro(h.nguoi, h.vaiTro, app: app) }
            }
        } message: {
            Text(hoiDoi?.vaiTro.moTa ?? "")
        }
        .confirmationDialog(
            "Remove \(hoiXoa?.ten ?? "this member") from the project?",
            isPresented: Binding(get: { hoiXoa != nil }, set: { if !$0 { hoiXoa = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                guard let u = hoiXoa else { return }
                Task { await vm.xoa(u, app: app) }
            }
        } message: {
            Text("They keep their workspace membership. Issues stay assigned to them until you reassign them.")
        }
        #if DEBUG
        .onAppear { if XemThuCTW.conCua("team") == "invite" { tamPhu = .moi } }
        #endif
    }

    private func nguoiTongQuan(_ u: CTWUser) -> CTWTongQuanNhom.Nguoi? {
        vm.tongQuan?.people?.first { $0.user?.id == u.id }
    }

    @ViewBuilder
    private func hang(_ u: CTWUser) -> some View {
        let laToi = u.id == app.currentUser?.id
        HStack(spacing: 12) {
            CTWAvatar(user: u, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(u.ten).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    if laToi { Text("You").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary) }
                    if u.laAgent { CTWNhanAI() }
                }
                if let p = nguoiTongQuan(u) {
                    Text(khoiLuong(p)).font(.ctw(size: 12)).foregroundColor((p.overdue ?? 0) > 0 ? AppColors.error : AppColors.textSecondary)
                        .lineLimit(1)
                } else if let un = u.username {
                    Text("@\(un)").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            CTWNhanNho(chu: CTWVaiTroDuAn(rawValue: u.role ?? "")?.ten ?? (u.role ?? "—"),
                       mau: u.role == "ADMIN" ? AppColors.primary : AppColors.textSecondary)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .contextMenu {
            if quanLy && !laToi {
                Menu {
                    ForEach(CTWVaiTroDuAn.choPhep(choAgent: u.laAgent)) { r in
                        Button { hoiDoi = (u, r) } label: {
                            if r.rawValue == u.role { Label(r.ten, systemImage: "checkmark") } else { Text(r.ten) }
                        }
                        .disabled(r.rawValue == u.role)
                    }
                } label: { Label("Change role", systemImage: "person.badge.key") }
                Button(role: .destructive) { hoiXoa = u } label: { Label("Remove from project", systemImage: "person.badge.minus") }
            }
            if let un = u.username {
                Button { CTW.chepVaoBoNho("@\(un)") } label: { Label("Copy @\(un)", systemImage: "doc.on.doc") }
            }
        }
    }

    private func khoiLuong(_ p: CTWTongQuanNhom.Nguoi) -> String {
        var s: [String] = []
        if let n = p.inProgress, n > 0 { s.append("\(n) in progress") }
        if let n = p.todo, n > 0 { s.append("\(n) to do") }
        if let n = p.overdue, n > 0 { s.append("\(n) overdue") }
        if let n = p.reviews, n > 0 { s.append("\(n) in review") }
        return s.isEmpty ? "No open issues" : s.joined(separator: " · ")
    }

    private func hangNhom(_ n: CTWNhomKhongGian) -> some View {
        let ds = n.members ?? []
        return HStack(spacing: 12) {
            Text(n.key ?? String(n.name.prefix(2)).uppercased())
                .font(.ctw(size: 12, weight: .heavy).monospaced())
                .foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(CTW.mau(n.color, macDinh: AppColors.primary)))
            VStack(alignment: .leading, spacing: 3) {
                Text(n.name).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                let lead = ds.filter { $0.teamRole == "LEAD" || (n.leadIds ?? []).contains($0.id) }.map { $0.nguoi.ten }
                Text([ "\(ds.count) member\(ds.count == 1 ? "" : "s")",
                       lead.isEmpty ? nil : "Lead: \(lead.joined(separator: ", "))",
                       (n.openIssues ?? 0) > 0 ? "\(n.openIssues!) open" : nil ].compactMap { $0 }.joined(separator: " · "))
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            HStack(spacing: -8) {
                ForEach(ds.prefix(4)) { m in
                    CTWAvatar(user: m.nguoi, size: 24).overlay(Circle().strokeBorder(AppColors.backgroundCard, lineWidth: 1.5))
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Mời bằng link

struct MoiBangLinkCTW: View {
    let wsId: Int
    let pid: Int
    let tenDuAn: String
    let laAdminDuAn: Bool
    @Environment(\.dismiss) private var dong
    @State private var vaiTro: CTWVaiTroKhongGian = .MEMBER
    @State private var kemDuAn = true
    @State private var vaiTroDuAn: CTWVaiTroDuAn = .MEMBER
    @State private var soLan = 30
    @State private var soNgay = 7
    @State private var dangTao = false
    @State private var loi: String?
    @State private var ketQua: CTWLinkMoi?

    var body: some View {
        NavigationStack {
            Form {
                if let k = ketQua {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Invite link created", systemImage: "checkmark.circle.fill")
                                .font(.ctw(size: 16, weight: .semibold)).foregroundColor(AppColors.success)
                            Text(k.url).font(.ctw(size: 13, design: .monospaced)).foregroundColor(AppColors.textPrimary)
                                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 10) {
                                if let u = URL(string: k.url) {
                                    ShareLink(item: u) { Label("Share", systemImage: "square.and.arrow.up") }
                                        .buttonStyle(.borderedProminent)
                                }
                                Button { CTW.chepVaoBoNho(k.url); CTWRung.thanhCong() } label: { Label("Copy", systemImage: "doc.on.doc") }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    } footer: {
                        Text("Save or share it now — for security CT Work shows this link only once. "
                             + "Works for \(k.maxUses ?? soLan) people\(CTW.ngayNgan(k.expiresAt).map { ", until \($0)" } ?? "").")
                    }
                } else {
                    Section {
                        Picker("Workspace role", selection: $vaiTro) {
                            ForEach(CTWVaiTroKhongGian.allCases) { Text($0.ten).tag($0) }
                        }
                    } footer: {
                        Text("Guests only see the projects they are added to.")
                    }
                    if laAdminDuAn {
                        Section {
                            Toggle("Also add to \(tenDuAn)", isOn: $kemDuAn)
                            if kemDuAn {
                                Picker("Project role", selection: $vaiTroDuAn) {
                                    ForEach(CTWVaiTroDuAn.allCases) { Text($0.ten).tag($0) }
                                }
                            }
                        } footer: {
                            if kemDuAn { Text(vaiTroDuAn.moTa) }
                        }
                    }
                    Section("Limits") {
                        Stepper("Up to \(soLan) people", value: $soLan, in: 1...200, step: soLan < 10 ? 1 : 5)
                        Stepper("Expires in \(soNgay) day\(soNgay == 1 ? "" : "s")", value: $soNgay, in: 1...30)
                    }
                    if let loi {
                        Section { Text(loi).foregroundColor(AppColors.error).font(.ctw(size: 14)) }
                    }
                }
            }
            .navigationTitle("Invite by link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(ketQua == nil ? "Cancel" : "Done") { dong() } }
                if ketQua == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { Task { await tao() } } label: {
                            if dangTao { ProgressView() } else { Text("Create link").bold() }
                        }
                        .disabled(dangTao)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func tao() async {
        dangTao = true
        defer { dangTao = false }
        do {
            let co = laAdminDuAn && kemDuAn
            ketQua = try await APIClient.shared.request(CTWAPI.taoLinkMoi(
                wsId: wsId, vaiTro: vaiTro.rawValue, pid: co ? pid : nil,
                vaiTroDuAn: co ? vaiTroDuAn.rawValue : nil, soLan: soLan, soNgay: soNgay))
            loi = nil
            CTWRung.thanhCong()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}
