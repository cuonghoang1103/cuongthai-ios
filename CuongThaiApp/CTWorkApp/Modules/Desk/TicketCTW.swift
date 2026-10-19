import SwiftUI

// MARK: - Service desk — CHI TIẾT ticket
//
// Ba nguồn: `GET …/issues/:n/desk` (SLA, trường yêu cầu, CSAT, sự kiện), `GET …/issues/:n`
// (trạng thái, người làm, `version` để đổi trạng thái an toàn) và bình luận thẻ (hội thoại).
// Trả lời khách = bình luận PUBLIC; ghi chú nội bộ = INTERNAL. Thẻ CHƯA chia sẻ với khách
// mà gửi PUBLIC ⇒ máy chủ trả `WORK_ISSUE_NOT_SHARED` — hỏi người dùng trước khi chia sẻ.

@MainActor
final class TicketVM: ObservableObject {
    let pid: Int
    let so: Int
    @Published var desk: CTWDeskChiTiet?
    @Published var the: CTWIssueDetail?
    @Published var binhLuan: [CTWComment]?
    @Published var loi: String?
    @Published var dangLam = false

    init(pid: Int, so: Int) { self.pid = pid; self.so = so }

    var lamDuoc: Bool { desk?.canWork == true }

    func tai() async {
        do {
            async let a: CTWDeskChiTiet = APIClient.shared.request(CTWAPI.deskTicket(pid: pid, so: so))
            async let b: CTWIssueDetail = APIClient.shared.request(CTWAPI.dvThe(pid: pid, so: so))
            async let c: [CTWComment] = APIClient.shared.request(CTWAPI.dvBinhLuan(pid: pid, so: so))
            let (x, y, z) = try await (a, b, c)
            desk = x; the = y; binhLuan = z
            loi = nil
        } catch { loi = DichVuLoi.cau(error) }
    }

    private func lam(_ viec: () async throws -> Void) async {
        dangLam = true
        defer { dangLam = false }
        do { try await viec(); CTWRung.thanhCong() } catch {
            loi = CTW.laXungDot(error) ? "Someone else just changed this ticket. Pull to refresh and try again." : DichVuLoi.cau(error)
            CTWRung.loi()
        }
    }

    func doiTrangThai(_ s: CTWStatus) async {
        await lam {
            let t: CTWIssueDetail = try await APIClient.shared.request(CTWAPI.dvChuyen(pid: pid, so: so, trangThai: s.id, phienBan: the?.version))
            the = t
            desk = try await APIClient.shared.request(CTWAPI.deskTicket(pid: pid, so: so))
        }
    }

    func giao(_ id: Int?) async {
        await lam { the = try await APIClient.shared.request(CTWAPI.dvGiao(pid: pid, so: so, nguoi: id, phienBan: the?.version)) }
    }

    func suaDesk(_ khoa: String, _ gt: String) async {
        await lam { desk = try await APIClient.shared.request(CTWAPI.deskSua(pid: pid, so: so, than: [khoa: gt])) }
    }

    func doiCho() async {
        let cho = !(desk?.ticket?.waiting ?? false)
        await lam {
            try await APIClient.shared.send(CTWAPI.deskCho(pid: pid, so: so, cho: cho))
            desk = try await APIClient.shared.request(CTWAPI.deskTicket(pid: pid, so: so))
        }
    }

    enum KetQuaGui { case xong, chuaChiaSe, loi }

    func gui(_ chu: String, congKhai: Bool?) async -> KetQuaGui {
        do {
            let c: CTWComment = try await APIClient.shared.request(CTWAPI.dvGuiBinhLuan(pid: pid, so: so, chu: chu, congKhai: congKhai))
            binhLuan = (binhLuan ?? []) + [c]
            if congKhai == true { desk = try? await APIClient.shared.request(CTWAPI.deskTicket(pid: pid, so: so)) }
            return .xong
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "WORK_ISSUE_NOT_SHARED" { return .chuaChiaSe }
            loi = DichVuLoi.cau(error)
            return .loi
        }
    }

    func chiaSeRoiGui(_ chu: String) async -> Bool {
        do {
            try await APIClient.shared.send(CTWAPI.dvChiaSeKhach(pid: pid, so: so))
            return await gui(chu, congKhai: true) == .xong
        } catch { loi = DichVuLoi.cau(error); return false }
    }
}

struct TicketCTW: View {
    let pid: Int
    let so: Int
    @StateObject private var vm: TicketVM
    @EnvironmentObject private var app: AppState
    @State private var tamPhu: TamPhu?
    @State private var congKhai = true
    @State private var choChiaSe: String?

    private enum TamPhu: String, Identifiable { case giao; var id: String { rawValue } }

    init(pid: Int, so: Int) {
        self.pid = pid; self.so = so
        _vm = StateObject(wrappedValue: TicketVM(pid: pid, so: so))
    }

    private var cfg: CTWProjectConfig? { app.cauHinhDuAn }
    private var ticket: CTWDeskTicket? { vm.desk?.ticket }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let l = vm.loi { CTWErrorBanner(text: l) { vm.loi = nil } }
                if let t = vm.the {
                    dau(t)
                    if vm.desk?.enabled == false || (vm.desk != nil && ticket == nil) {
                        CTWOTrong(bieuTuong: "ticket", tieuDe: "Not a service request",
                                  moTa: "This issue isn't tracked by the service desk.")
                    }
                    if let k = ticket {
                        sla(k)
                        if vm.lamDuoc { hanhDong(t, k) }
                        chiTiet(k)
                    }
                    hoiThoai
                    if let ev = ticket?.events, !ev.isEmpty { suKien(ev) }
                    NavigationLink(value: CTWRoute.the(pid: pid, so: so)) {
                        Label("Open full issue", systemImage: "arrow.up.right.square")
                            .font(.ctw(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                } else if vm.loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: false).padding(.horizontal, -Spacing.md)
                }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.the.map { "\(cfg?.key ?? "#")-\($0.number)" } ?? "Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) { if vm.dangLam { ProgressView().padding(8) } }
        .refreshable { await vm.tai() }
        .task { if vm.the == nil { await vm.tai() } }
        .sheet(item: $tamPhu) { _ in
            CTWChonNguoiView(ds: (cfg?.dsThanhVien ?? []).filter(\.giaoDuoc), toi: app.currentUser?.id,
                             chon: Binding(get: { Set([vm.the?.assigneeId ?? 0]) },
                                           set: { s in let id = s.first ?? 0; Task { await vm.giao(id == 0 ? nil : id) } }))
        }
        .confirmationDialog("This ticket isn't shared with the client yet",
                            isPresented: Binding(get: { choChiaSe != nil }, set: { if !$0 { choChiaSe = nil } }),
                            titleVisibility: .visible) {
            Button("Share with client & send") {
                guard let c = choChiaSe else { return }
                Task { if await vm.chiaSeRoiGui(c) { CTWRung.thanhCong() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A public reply is visible to the client. Sharing also shows them the ticket's title, status and public replies.")
        }
    }

    // MARK: Khối

    private func dau(_ t: CTWIssueDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let k = ticket {
                    CTWNhanNho(chu: k.requestTypeName ?? CTWMauTrangThai.nhan(k.requestType), bieuTuong: CTWDesk.bieuTuongLoai(k.requestType), mau: AppColors.primary)
                    if let p = k.priority { CTWNhanNho(chu: p, mau: CTWDesk.mauUuTien(p)) }
                    if k.waiting == true { CTWNhanNho(chu: "Waiting on customer", bieuTuong: "pause.fill") }
                }
                Spacer(minLength: 0)
                CTWStatusChip(status: cfg?.trangThai(t.statusId))
            }
            Text(t.title).font(.ctw(size: 21, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let d = t.descriptionJson, !(d.chuTron.isEmpty) {
                CTWTipTapView(doc: d, coChu: 15)
                    .padding(12).ctwThe(12)
                    .ctwMenuBaoCaoChan(khoa: "ticket-\(pid)-\(t.number)", noiDung: d.chuTron,
                                       nguCanh: "\(cfg?.key ?? "") ticket #\(t.number)", tacGia: t.reporter,
                                       laCuaToi: t.reporter?.id == app.currentUser?.id)
            }
        }
    }

    private func sla(_ k: CTWDeskTicket) -> some View {
        HStack(spacing: 10) {
            theSla("First response", k.firstResponse, phu: k.firstResponseAt.flatMap(DichVuLoi.luc).map { "Responded \($0)" })
            theSla("Resolution", k.resolution, phu: nil)
        }
    }

    private func theSla(_ ten: String, _ s: CTWSla?, phu: String?) -> some View {
        let m = CTWDesk.mauSla(s)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(m).frame(width: 8, height: 8)
                Text(ten).font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
            }
            Text(CTWDesk.nhanSla(s)).font(.ctw(size: 19, weight: .bold)).foregroundColor(m)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(phu ?? (s?.dueAt.flatMap(DichVuLoi.luc).map { "Due \($0)" } ?? (s?.stopped == true ? "Stopped" : "No due time")))
                .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(m.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(m.opacity(0.25), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }

    private func hanhDong(_ t: CTWIssueDetail, _ k: CTWDeskTicket) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let c = cfg {
                    Menu {
                        ForEach(c.trangThaiDich(loai: t.typeId, tu: t.statusId)) { s in
                            Button { Task { await vm.doiTrangThai(s) } } label: {
                                if s.id == t.statusId { Label(s.name, systemImage: "checkmark") } else { Text(s.name) }
                            }
                        }
                    } label: { nut("arrow.triangle.2.circlepath", "Status") }
                }
                Button { tamPhu = .giao } label: { nut("person.crop.circle", t.assignee?.ten ?? "Assign") }
                Menu {
                    ForEach(CTWDesk.uuTien, id: \.self) { p in
                        Button { Task { await vm.suaDesk("priority", p) } } label: {
                            if p == k.priority { Label(p, systemImage: "checkmark") } else { Text(p) }
                        }
                    }
                } label: { nut("flag", k.priority ?? "Priority") }
                Menu {
                    Section("Impact") {
                        ForEach(CTWDesk.mucDo, id: \.self) { m in
                            Button(CTWMauTrangThai.nhan(m) + (m == k.impact ? " ✓" : "")) { Task { await vm.suaDesk("impact", m) } }
                        }
                    }
                    Section("Urgency") {
                        ForEach(CTWDesk.mucDo, id: \.self) { m in
                            Button(CTWMauTrangThai.nhan(m) + (m == k.urgency ? " ✓" : "")) { Task { await vm.suaDesk("urgency", m) } }
                        }
                    }
                } label: { nut("gauge.with.dots.needle.50percent", "Impact") }
                Button { Task { await vm.doiCho() } } label: {
                    nut(k.waiting == true ? "play.circle" : "pause.circle", k.waiting == true ? "Resume SLA" : "Waiting on customer")
                }
            }
            .padding(.vertical, 2)
        }
        .disabled(vm.dangLam)
    }

    private func nut(_ icon: String, _ chu: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.ctw(size: 13, weight: .semibold))
            Text(chu).font(.ctw(size: 13, weight: .semibold)).lineLimit(1).fixedSize()
        }
        .foregroundColor(AppColors.primary)
        .padding(.horizontal, 12).frame(minHeight: 40)
        .background(Capsule().fill(AppColors.primary.opacity(0.10)))
    }

    private func chiTiet(_ k: CTWDeskTicket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("info.circle", "Details")
            CTWKhoiTruong {
                CTWHangTruong(nhan: "Requester", bieuTuong: "person") {
                    HStack(spacing: 6) {
                        CTWAvatar(user: k.requester, size: 20)
                        Text(k.requester?.ten ?? "—")
                        if k.requester?.laAgent == true { CTWNhanAI() }
                    }
                }
                Divider()
                CTWHangTruong("Assignee", vm.the?.assignee?.ten ?? "Unassigned", bieuTuong: "person.badge.clock")
                Divider()
                CTWHangTruong("Impact · Urgency", "\(CTWMauTrangThai.nhan(k.impact)) · \(CTWMauTrangThai.nhan(k.urgency))", bieuTuong: "gauge")
                Divider()
                CTWHangTruong("Channel", k.channel == "PORTAL" ? "Client portal" : "Staff", bieuTuong: "arrow.down.message")
                ForEach(Array((k.fields ?? []).enumerated()), id: \.offset) { _, f in
                    Divider()
                    CTWHangTruong(f.label ?? f.key ?? "Field", f.value?.hienThi, bieuTuong: "text.alignleft")
                }
                if let p = k.problem {
                    Divider()
                    CTWHangTruong("Problem", "PRB-\(p.number ?? 0) \(p.title ?? "")", bieuTuong: "ant")
                }
                if let c = k.changeRequest {
                    Divider()
                    CTWHangTruong("Change request", "CR-\(c.number ?? 0) \(c.title ?? "")", bieuTuong: "arrow.triangle.2.circlepath")
                }
                if let cs = k.csat, cs.rating != nil || cs.requestedAt != nil {
                    Divider()
                    CTWHangTruong(nhan: "Satisfaction", bieuTuong: "star") {
                        if let r = cs.rating {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { i in
                                    Image(systemName: i <= r ? "star.fill" : "star").foregroundColor(AppColors.warning).font(.ctw(size: 12))
                                }
                            }
                            .accessibilityLabel("\(r) of 5 stars")
                        } else { Text("Waiting for rating") }
                    }
                }
            }
            if let c = k.csat?.comment, !c.isEmpty {
                Text("“\(c)”").font(.ctw(size: 14)).italic().foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var hoiThoai: some View {
        VStack(alignment: .leading, spacing: 10) {
            CTWSectionHeader("bubble.left.and.bubble.right", "Conversation", count: vm.binhLuan.map { "\($0.count)" })
            if let ds = vm.binhLuan {
                if ds.isEmpty {
                    Text("No replies yet.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                }
                ForEach(ds) { c in
                    let noiBo = (c.visibility ?? "INTERNAL") != "PUBLIC"
                    DongBinhLuanTheCTW(pid: pid, so: so, c: c, nhanPhu: noiBo ? "Internal" : "Public", noiBo: noiBo)
                }
            }
            if cfg?.coTheBinhLuan ?? true {
                VStack(alignment: .leading, spacing: 8) {
                    if vm.lamDuoc {
                        Picker("Reply type", selection: $congKhai) {
                            Text("Reply to client").tag(true)
                            Text("Internal note").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    CTWHopSoan(goiY: vm.lamDuoc && !congKhai ? "Add an internal note…" : "Reply to the client…",
                               nutGui: congKhai ? "Send reply" : "Add note") { chu in
                        let kq = await vm.gui(chu, congKhai: vm.lamDuoc ? congKhai : nil)
                        if kq == .chuaChiaSe { choChiaSe = chu }
                        return kq == .xong
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func suKien(_ ev: [CTWDeskTicket.SuKien]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("clock.arrow.circlepath", "SLA timeline")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ev) { e in
                    let (ten, icon) = CTWDesk.nhanSuKien(e.kind)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon).font(.ctw(size: 13)).foregroundColor(AppColors.primary).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ten + (e.value.map { " · \($0)" } ?? "")).font(.ctw(size: 13, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                            Text([e.actor, DichVuLoi.luc(e.at), e.note].compactMap { $0 }.joined(separator: " · "))
                                .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8)
                    if e.id != ev.last?.id { Divider().padding(.leading, 30) }
                }
            }
            .padding(.horizontal, 12)
            .ctwThe(12)
        }
    }
}
