import SwiftUI

// MARK: - Thành viên — mọi người cùng không gian CT Work, kiểu "Mọi người" của Messenger
//
// Đang hoạt động lên đầu (hàng avatar cuộn ngang + danh sách), ô tìm ở trên, chạm ⇒ hồ sơ (Nhắn tin · thẻ được giao ·
// Chặn · Báo cáo). Dữ liệu: `GET /work/me/people` (đã áp luật riêng tư ở máy chủ) + socket `presence:update`.
// Tự làm mới 30 s một lần khi màn đang hiện (socket không phát trạng thái của đồng nghiệp chưa từng nhắn tin).

struct DanhSachThanhVienCTW: View {
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @EnvironmentObject private var nganXep: NganXepCTW
    @ObservedObject private var kd = ModerationStore.shared
    @State private var tim = ""
    @State private var hoSo: CTWThanhVien?
    @State private var bayGio = Date()

    var body: some View {
        let ds = kho.danhBaDaSap(tim: tim, bayGio: bayGio)
        let dangHD = ds.filter { kho.moc($0.id, bayGio: bayGio) == .dangHoatDong }
        List {
            if !kho.toiHienTrangThai {
                Section {
                    Label("Your active status is off, so you can't see when others are active either.", systemImage: "eye.slash")
                        .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            }
            if tim.isEmpty, !dangHD.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(dangHD) { n in
                                Button { hoSo = n } label: {
                                    VStack(spacing: 5) {
                                        AvatarHoatDongCTW(user: n.nguoi, size: 54, moc: .dangHoatDong)
                                        Text(verbatim: TenNguoi.tenNgan(n.ten))
                                            .font(.ctw(size: 12)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                                            .fixedSize()
                                    }
                                    .frame(minWidth: 60)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } header: { Text("Active now") }
            }
            Section {
                ForEach(ds) { n in
                    Button { hoSo = n } label: { HangThanhVienCTW(n: n, moc: kho.moc(n.id, bayGio: bayGio)) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("member.\(n.id)")
                }
            } header: {
                Text(ds.count == 1 ? String(localized: "1 member") : String(localized: "\(ds.count) members"))
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if !kho.daTaiDanhBa && kho.danhBa.isEmpty {
                CTWKhungTai()
            } else if let l = kho.loiDanhBa, kho.danhBa.isEmpty {
                CTWOLoi(loi: l) { Task { await kho.taiDanhBa() } }
            } else if kho.danhBa.isEmpty {
                CTWOTrong(bieuTuong: "person.2", tieuDe: String(localized: "No teammates yet"),
                          moTa: String(localized: "People who share a workspace with you appear here."))
            } else if ds.isEmpty {
                CTWOTrong(bieuTuong: "magnifyingglass", tieuDe: String(localized: "No matches"), moTa: String(localized: "Try another name."))
            }
        }
        .searchable(text: $tim, prompt: "Search members")
        .navigationTitle("Members")
        .refreshable { await kho.taiDanhBa() }
        .task {
            // Làm mới định kỳ khi màn đang hiện (Task tự huỷ khi rời màn).
            while !Task.isCancelled {
                await kho.taiDanhBa()
                bayGio = Date()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        #if DEBUG
        .task(id: kho.danhBa.count) {
            if XemThuCTW.conCua("thanh-vien") == "hoso", hoSo == nil, let n = kho.danhBa.first { hoSo = n }
        }
        #endif
        // Hồ sơ cần mở từ màn Tìm mọi thứ (gõ tên người) ⇒ về gốc ngăn xếp rồi mở tấm phủ hồ sơ; xoá cờ ở CUỐI (mục 6).
        .task(id: kho.hoSoCanMo) {
            guard let id = kho.hoSoCanMo else { return }
            defer { kho.hoSoCanMo = nil }
            nganXep.veDau()
            if kho.thanhVien(id) == nil { await kho.taiDanhBa() }
            try? await Task.sleep(for: .milliseconds(150))
            if let n = kho.thanhVien(id) { hoSo = n }
        }
        .sheet(item: $hoSo) { n in
            NavigationStack { HoSoThanhVienCTW(userId: n.id, laTamPhu: true) }
                .presentationDetents([.medium, .large])
        }
    }
}

struct HangThanhVienCTW: View {
    let n: CTWThanhVien
    let moc: TrangThaiHoatDongCTW.Moc

    var body: some View {
        HStack(spacing: 12) {
            AvatarHoatDongCTW(user: n.nguoi, size: 44, moc: moc)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(n.ten).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    if n.laAgent { CTWNhanAI() }
                    if n.blocked == true {
                        Text("Blocked").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.error)
                    }
                }
                let chu = TrangThaiHoatDongCTW.chu(moc)
                if !chu.isEmpty {
                    Text(chu).font(.ctw(size: 12, weight: moc == .dangHoatDong ? .semibold : .regular))
                        .foregroundColor(moc == .dangHoatDong ? AppColors.success : AppColors.textSecondary)
                }
                if !n.dongPhu.isEmpty {
                    Text(n.dongPhu).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Hồ sơ thành viên

struct HoSoThanhVienCTW: View {
    let userId: Int
    var laTamPhu = false
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @ObservedObject private var kd = ModerationStore.shared
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dong
    @State private var the: [CTWIssueCard]?
    @State private var dangMo = false
    @State private var loi: String?
    @State private var hoiChan = false
    @State private var baoCao = false

    private var n: CTWThanhVien? { kho.thanhVien(userId) }
    private var daChan: Bool { kd.blockedUserIds.contains(userId) }

    var body: some View {
        List {
            if let n {
                Section {
                    VStack(spacing: 10) {
                        AvatarHoatDongCTW(user: n.nguoi, size: 84, moc: kho.moc(userId))
                        HStack(spacing: 6) {
                            Text(n.ten).font(.ctw(size: 21, weight: .bold)).foregroundColor(AppColors.textPrimary)
                            if n.laAgent { CTWNhanAI() }
                        }
                        if let u = n.username { Text("@\(u)").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary) }
                        let chu = TrangThaiHoatDongCTW.chu(kho.moc(userId))
                        if !chu.isEmpty {
                            Text(chu).font(.ctw(size: 13, weight: .medium))
                                .foregroundColor(kho.moc(userId) == .dangHoatDong ? AppColors.success : AppColors.textSecondary)
                        }
                        if !n.laAgent {
                            Button { Task { await nhanTin() } } label: {
                                Label(daChan ? "Unblock to message" : "Message", systemImage: "bubble.left.fill")
                                    .font(.ctw(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(dangMo || daChan)
                            .accessibilityIdentifier("member.message")
                            .padding(.top, 4)
                        }
                        if let loi { CTWErrorBanner(text: loi) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                Section("Workspaces") {
                    ForEach(n.workspaces ?? [], id: \.id) { w in
                        CTWHangTruong(nhan: w.name ?? "—") { Text(CTWThanhVien.tenVai(w.role ?? "")).foregroundColor(AppColors.textSecondary) }
                    }
                }
                if let p = n.projects, !p.isEmpty {
                    Section("Projects in common") {
                        ForEach(p, id: \.id) { d in
                            CTWHangTruong(nhan: "\(d.key ?? "") · \(d.name ?? "")") { Text(CTWThanhVien.tenVai(d.role ?? "")).foregroundColor(AppColors.textSecondary) }
                        }
                    }
                }
                Section {
                    if let the {
                        if the.isEmpty {
                            Text("No open issues assigned to them in your current project.").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                        }
                        ForEach(the.prefix(10)) { t in
                            Button { moThe(t.number) } label: {
                                HStack(spacing: 8) {
                                    Text("\(app.luaChon?.maDuAn ?? "")-\(t.number)").font(.ctw(size: 12, weight: .semibold).monospaced())
                                        .foregroundColor(AppColors.textSecondary)
                                    Text(t.title).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                                }
                                .frame(minHeight: 36)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        ProgressView()
                    }
                } header: {
                    Text(app.luaChon.map { String(localized: "Assigned issues · \($0.maDuAn)") } ?? String(localized: "Assigned issues"))
                }
                if !n.laAgent {
                    Section {
                        if daChan {
                            Button { Task { try? await kd.unblock(userId: userId); await kho.taiDanhBa() } } label: {
                                Label("Unblock", systemImage: "hand.raised.slash")
                            }
                        } else {
                            Button(role: .destructive) { hoiChan = true } label: { Label("Block", systemImage: "hand.raised") }
                        }
                        Button(role: .destructive) { baoCao = true } label: { Label("Report", systemImage: "exclamationmark.bubble") }
                    } footer: {
                        Text("Blocked people can't message you and you won't see their messages or active status.")
                    }
                }
            } else {
                CTWOTrong(bieuTuong: "person.crop.circle.badge.questionmark", tieuDe: String(localized: "Member not found"), moTa: "")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(n?.ten ?? String(localized: "Member"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if laTamPhu { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
        }
        .task { await taiThe() }
        .confirmationDialog("Block \(n?.ten ?? "")?", isPresented: $hoiChan, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task { try? await kd.block(userId: userId, reason: nil); await kho.taiDanhBa(); CTWRung.thanhCong() }
            }
        } message: { Text("They won't be able to message you. You can unblock them in Account › Blocked users.") }
        .sheet(isPresented: $baoCao) {
            BaoCaoNguoiCTW(ten: n?.ten ?? "", userId: userId, threadId: kho.hoiThoai.first { $0.peer?.id == userId }?.id)
        }
    }

    /// Thẻ đang mở được giao cho người này trong dự án đang chọn — rẻ: MỘT lời gọi JQL như màn List.
    private func taiThe() async {
        guard let l = app.luaChon, let u = n?.username else { the = []; return }
        let jql = "assignee = \"\(u)\" AND statusCategory != Done ORDER BY updated DESC"
        if let r: CTWKetQuaJql = try? await APIClient.shared.request(CTWAPI.timTheoJql(pid: l.pid, jql: jql, limit: 10)) {
            the = r.items ?? []
        } else { the = [] }
    }

    /// Mở thẻ như deep link (tab My Work) — tấm phủ này không có ngăn xếp của khung.
    private func moThe(_ so: Int) {
        guard let l = app.luaChon else { return }
        if laTamPhu { dong() }
        app.muc = .viecCuaToi
        app.ctWorkDich = CTWDich(slug: l.slug, maDuAn: l.maDuAn, so: so)
    }

    private func nhanTin() async {
        dangMo = true; loi = nil
        defer { dangMo = false }
        do {
            let t = try await kho.moVoi(userId)
            if laTamPhu { dong() }
            try? await Task.sleep(for: .milliseconds(laTamPhu ? 350 : 0))
            kho.moHoiThoai(t.id)
        } catch { loi = CTW.loi(error) }
    }
}

// MARK: - Báo cáo người dùng / hội thoại (App Store 1.2)

struct BaoCaoNguoiCTW: View {
    let ten: String
    let userId: Int
    var threadId: Int?
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @Environment(\.dismiss) private var dong
    @State private var loai = "harassment"
    @State private var chiTiet = ""
    @State private var dangGui = false
    @State private var loi: String?
    @State private var chanLuon = false

    private var cacLoai: [(String, String)] { [
        ("spam", String(localized: "Spam or advertising")),
        ("harassment", String(localized: "Harassment or bullying")),
        ("hate", String(localized: "Hate speech")),
        ("impersonation", String(localized: "Pretending to be someone else")),
        ("other", String(localized: "Something else")),
    ] }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reason", selection: $loai) { ForEach(cacLoai, id: \.0) { Text($0.1).tag($0.0) } }
                        .pickerStyle(.inline).labelsHidden()
                } header: { Text("Why are you reporting \(ten)?") }
                Section("Details (optional)") {
                    TextField("What happened?", text: $chiTiet, axis: .vertical).lineLimit(3...6)
                }
                Section {
                    Toggle("Also block \(ten)", isOn: $chanLuon)
                } footer: {
                    Text("Reports go to the CT Work moderation team, who review them within 24 hours. The person isn't told who reported them.")
                }
                if let loi { Section { CTWErrorBanner(text: loi) } }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await gui() } }.disabled(dangGui)
                }
            }
        }
    }

    private func gui() async {
        dangGui = true; loi = nil
        defer { dangGui = false }
        let nhan = cacLoai.first { $0.0 == loai }?.1 ?? loai
        let lyDo = chiTiet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nhan : "\(nhan): \(chiTiet)"
        do {
            if let threadId {
                try await APIClient.shared.send(TinNhanAPI.baoCao(threadId: threadId, lyDo: lyDo, loai: loai))
            } else {
                // Chưa có hội thoại ⇒ đường báo cáo chung (hàng chờ kiểm duyệt của quản trị).
                try await ModerationStore.shared.baoCaoNoiDung(nhan: "Người dùng", noiDung: "@\(ten) (id \(userId))",
                                                                 ngucanh: "CT Work › Thành viên", lyDo: .harassment, chiTiet: lyDo)
            }
            if chanLuon { try? await ModerationStore.shared.block(userId: userId, reason: loai); await kho.taiDanhBa() }
            CTWRung.thanhCong()
            dong()
        } catch { loi = CTW.loi(error) }
    }
}
