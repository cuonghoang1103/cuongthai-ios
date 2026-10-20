import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

// MARK: - CT Work — Chi tiết thẻ
//
// Sửa trường nào thì PATCH đúng trường đó kèm `version` — máy chủ trả 409 khi
// có người sửa chen giữa; lúc đó nạp lại và báo, không ghi đè.
// Đổi trạng thái đi qua `/move` (quyền `issue.transition`), còn lại qua PATCH
// (quyền `issue.edit`). Người xem/giảng viên/khách hàng chỉ đọc.
//
// 17/10/2026 (app CT Work riêng): mô tả dựng định dạng thật (TipTap), đính kèm
// (xem + tải lên từ Máy ảnh/Ảnh/Tệp), lịch sử hoạt động, sửa/xoá bình luận của
// mình, nhãn "AI agent", theo dõi thẻ.

@MainActor
final class CTWIssueVM: ObservableObject {
    let pid: Int
    let so: Int
    @Published var cauHinh: CTWProjectConfig?
    @Published var the: CTWIssueDetail?
    @Published var binhLuan: [CTWComment] = []
    @Published var lichSu: [CTWHistory]?
    @Published var loi: String?
    @Published var dangGui = false
    @Published var dangTaiLen = false

    init(pid: Int, so: Int) { self.pid = pid; self.so = so }

    func tai() async {
        do {
            async let c: CTWProjectConfig = APIClient.shared.request(.workDuAn(pid: pid))
            async let t: CTWIssueDetail = APIClient.shared.request(.workThe(pid: pid, so: so))
            let (cc, tt) = try await (c, t)
            cauHinh = cc
            the = tt
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
        await taiBinhLuan()
    }

    func taiBinhLuan() async {
        do {
            binhLuan = try await APIClient.shared.request(.workDsBinhLuan(pid: pid, so: so))
        } catch {
            if loi == nil { loi = CTW.loi(error) }
        }
    }

    func taiLichSu() async {
        do {
            lichSu = try await APIClient.shared.request(CTWAPI.lichSu(pid: pid, so: so))
        } catch {
            loi = CTW.loi(error)
        }
    }

    private func napLaiThe() async {
        if let moi: CTWIssueDetail = try? await APIClient.shared.request(.workThe(pid: pid, so: so)) { the = moi }
    }

    /// PATCH một nhóm trường. `null` gửi bằng `NSNull()`.
    func sua(_ truong: [String: Any]) async {
        guard let t = the else { return }
        var than = truong
        if let v = t.version { than["version"] = v }
        dangGui = true
        defer { dangGui = false }
        do {
            the = try await APIClient.shared.request(.workSuaThe(pid: pid, so: so, than: than))
            loi = nil
            lichSu = nil
        } catch {
            loi = CTW.loi(error)
            if CTW.laXungDot(error) { await napLaiThe() }
        }
    }

    func chuyenTrangThai(_ statusId: Int) async {
        guard let t = the, t.statusId != statusId else { return }
        var than: [String: Any] = ["statusId": statusId]
        if let v = t.version { than["version"] = v }
        dangGui = true
        defer { dangGui = false }
        do {
            try await APIClient.shared.send(.workChuyenThe(pid: pid, so: so, than: than))
            the = try await APIClient.shared.request(.workThe(pid: pid, so: so))
            loi = nil
            lichSu = nil
            CTWRung.thanhCong()
        } catch {
            loi = CTW.loi(error)
            CTWRung.loi()
            if CTW.laXungDot(error) { await napLaiThe() }
        }
    }

    func guiBinhLuan(_ chu: String) async -> Bool {
        let s = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        dangGui = true
        defer { dangGui = false }
        do {
            let c: CTWComment = try await APIClient.shared.request(
                .workThemBinhLuan(pid: pid, so: so, than: ["bodyJson": CTWNode.docTuChu(s)]))
            binhLuan.append(c)
            loi = nil
            CTWRung.thanhCong()
            return true
        } catch {
            loi = CTW.loi(error)
            return false
        }
    }

    func suaBinhLuan(_ c: CTWComment, chu: String) async -> Bool {
        let s = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        dangGui = true
        defer { dangGui = false }
        do {
            let moi: CTWComment = try await APIClient.shared.request(CTWAPI.suaBinhLuan(pid: pid, so: so, cid: c.id, chu: s))
            if let i = binhLuan.firstIndex(where: { $0.id == c.id }) {
                var m = moi
                m.attachments = binhLuan[i].attachments
                binhLuan[i] = m
            }
            loi = nil
            return true
        } catch {
            loi = CTW.loi(error)
            return false
        }
    }

    func xoaBinhLuan(_ c: CTWComment) async {
        dangGui = true
        defer { dangGui = false }
        do {
            try await APIClient.shared.send(CTWAPI.xoaBinhLuan(pid: pid, so: so, cid: c.id))
            binhLuan.removeAll { $0.id == c.id }
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
    }

    func taiLen(du: Data, ten: String, kieu: String? = nil) async {
        dangTaiLen = true
        defer { dangTaiLen = false }
        do {
            let a = try await CTWTaiLen.taiLen(pid: pid, so: so, du: du, ten: ten, kieu: kieu)
            the?.attachments = (the?.attachments ?? []) + [a]
            loi = nil
            CTWRung.thanhCong()
            lichSu = nil
        } catch {
            loi = CTW.loi(error)
        }
    }

    func xoaDinhKem(_ a: CTWAttachment) async {
        do {
            try await APIClient.shared.send(CTWAPI.xoaDinhKem(pid: pid, aid: a.id))
            the?.attachments?.removeAll { $0.id == a.id }
        } catch {
            loi = CTW.loi(error)
        }
    }

    /// Tải tệp về thư mục tạm để Xem nhanh (QuickLook) — url ký sẵn sống 10 phút.
    func taiVeDeXem(_ a: CTWAttachment) async -> URL? {
        do {
            let r: CTWUrl = try await APIClient.shared.request(CTWAPI.urlDinhKem(pid: pid, aid: a.id, xemTrongApp: true))
            guard let u = URL(string: r.url) else { return nil }
            return try await CTWXemTep.taiVe(url: u, ten: a.fileName ?? "file", khoa: "\(a.id)")
        } catch {
            loi = CTW.loi(error)
            return nil
        }
    }

    func doiTheoDoi() async {
        guard let t = the else { return }
        let bat = t.isWatching != true
        do {
            try await APIClient.shared.send(CTWAPI.theoDoi(pid: pid, so: so, bat: bat))
            the?.isWatching = bat
            the?.watcherCount = max(0, (t.watcherCount ?? 0) + (bat ? 1 : -1))
        } catch {
            loi = CTW.loi(error)
        }
    }
}

/// Một tấm phủ duy nhất cho màn (bẫy C5: hai `.sheet` trên một view thì chỉ
/// cái cuối chạy).
private enum TamPhuThe: Identifiable {
    case suaBinhLuan(CTWComment)
    case mayAnh
    var id: String {
        switch self {
        case .suaBinhLuan(let c): return "sua-\(c.id)"
        case .mayAnh: return "mayanh"
        }
    }
}

struct CTWIssueView: View {
    @StateObject private var vm: CTWIssueVM
    @ObservedObject private var kiemDuyet = ModerationStore.shared
    @ObservedObject private var an = AnNoiDungCTW.shared
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var moURL

    @State private var dangSuaTieuDe = false
    @State private var tieuDeNhap = ""
    @State private var binhLuanNhap = ""
    @State private var chonNgay = false
    @State private var ngayNhap = Date()
    @State private var hoiChan: CTWUser?
    /// Bình luận đang chờ chọn lý do báo cáo.
    @State private var baoCao: CTWComment?
    @State private var hoiXoa: CTWComment?
    @State private var daBaoCao: String?
    @State private var tamPhu: TamPhuThe?
    @State private var chonAnh: [PhotosPickerItem] = []
    @State private var moChonAnh = false
    @State private var moChonTep = false
    @State private var xemNhanh: URL?
    @State private var khoiHoatDong: KhoiHoatDong = .binhLuan

    enum KhoiHoatDong: String, CaseIterable, Identifiable {
        case binhLuan = "Comments", lichSu = "History"
        var id: String { rawValue }
        var ten: String { self == .binhLuan ? String(localized: "Comments") : String(localized: "History") }
    }

    /// Gọi MỘT lần khi thẻ tải xong (app CT Work: ghi "thẻ đã xem" cho Spotlight/Share Extension).
    private let khiMo: ((CTWIssueDetail, CTWProjectConfig) -> Void)?

    init(pid: Int, so: Int, khiMo: ((CTWIssueDetail, CTWProjectConfig) -> Void)? = nil) {
        _vm = StateObject(wrappedValue: CTWIssueVM(pid: pid, so: so))
        self.khiMo = khiMo
    }

    var body: some View {
        Group {
            if let t = vm.the, let cfg = vm.cauHinh {
                noiDung(t, cfg)
            } else if let loi = vm.loi {
                VStack(spacing: Spacing.md) {
                    CTWErrorBanner(text: loi)
                    Button("Try again") { Task { await vm.tai() } }.buttonStyle(.bordered)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.cauHinh.map { "\($0.key)-\(vm.so)" } ?? "Issue")
        .ctwTieuDeNho()
        .toolbar {
            if let t = vm.the, let cfg = vm.cauHinh {
                ToolbarItem(placement: .primaryAction) { menuThe(t, cfg) }
            }
        }
        .task { if vm.the == nil { await vm.tai() } }
        .onChange(of: vm.the != nil && vm.cauHinh != nil) { _, xong in
            if xong, let t = vm.the, let c = vm.cauHinh { khiMo?(t, c) }
        }
        .confirmationDialog(
            "Block \(hoiChan?.ten ?? "this user")?",
            isPresented: Binding(get: { hoiChan != nil }, set: { if !$0 { hoiChan = nil } }),
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                guard let u = hoiChan else { return }
                Task {
                    do { try await kiemDuyet.block(userId: u.id) } catch { vm.loi = CTW.loi(error) }
                }
            }
        } message: {
            Text("You won't see their comments or messages anywhere in the app.")
        }
        .confirmationDialog(
            "Report this comment",
            isPresented: Binding(get: { baoCao != nil }, set: { if !$0 { baoCao = nil } }),
            titleVisibility: .visible
        ) {
            ForEach(ctwLyDoBaoCao, id: \.ma) { l in
                Button(l.nhan, role: .destructive) {
                    guard let c = baoCao, let pid = vm.cauHinh?.id else { return }
                    let cid = c.id
                    let so = vm.so
                    Task {
                        do {
                            let r: CTWBaoCaoKetQua = try await APIClient.shared.request(
                                .workBaoCaoBinhLuan(pid: pid, so: so, cid: cid, lyDo: l.ma))
                            an.anBinhLuan(cid)
                            daBaoCao = r.duplicate == true
                                ? String(localized: "You already reported this comment.")
                                : String(localized: "Thanks — project admins have been notified. The comment is hidden for you.")
                        } catch { vm.loi = CTW.loi(error) }
                    }
                }
            }
        } message: {
            Text("Project admins will review it and remove it if it breaks the rules.")
        }
        .confirmationDialog(
            "Delete this comment?",
            isPresented: Binding(get: { hoiXoa != nil }, set: { if !$0 { hoiXoa = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let c = hoiXoa else { return }
                Task { await vm.xoaBinhLuan(c) }
            }
        }
        .alert(daBaoCao ?? "", isPresented: Binding(get: { daBaoCao != nil }, set: { if !$0 { daBaoCao = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .sheet(item: $tamPhu) { tp in
            switch tp {
            case .suaBinhLuan(let c):
                CTWSuaBinhLuanView(chuBanDau: c.bodyJson?.chuTron ?? "") { chu in
                    await vm.suaBinhLuan(c, chu: chu)
                }
            case .mayAnh:
                #if os(iOS)
                MayAnh { du in
                    Task { await vm.taiLen(du: du, ten: String(localized: "Photo \(CTW.tenTepTheoGio()).jpg"), kieu: "image/jpeg") }
                }
                .ignoresSafeArea()
                #else
                EmptyView()
                #endif
            }
        }
        .ctwXemTep($xemNhanh)
    }

    // MARK: Menu ⋯ của thẻ

    private func menuThe(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        // Như web đợt 8D: thanh đầu chỉ giữ trạng thái + theo dõi; thao tác phụ (sửa tiêu đề, chép, chia sẻ, web) vào "…".
        Menu {
            if cfg.coTheSua {
                Button {
                    tieuDeNhap = t.title
                    dangSuaTieuDe = true
                } label: { Label("Edit title", systemImage: "pencil") }
                Divider()
            }
            Button {
                CTW.chepVaoBoNho("\(cfg.key)-\(t.number)")
            } label: { Label("Copy key", systemImage: "number") }
            if let u = CTW.urlWeb(cfg: cfg, so: t.number) {
                ShareLink(item: u) { Label("Share link", systemImage: "square.and.arrow.up") }
                Button { moURL(u) } label: { Label("Open on the web", systemImage: "safari") }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("More actions")
    }

    // MARK: Nội dung

    private func noiDung(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        ScrollViewReader { cuon in
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi = vm.loi {
                    CTWErrorBanner(text: loi) { vm.loi = nil }
                }
                dau(t, cfg)
                truong(t, cfg)
                moTa(t)
                dinhKem(t, cfg)
                if let con = t.children, !con.isEmpty { theCon(con, cfg) }
                if let lk = t.links, !lk.isEmpty { lienKet(lk, cfg) }
                Picker("Activity", selection: $khoiHoatDong) {
                    ForEach(KhoiHoatDong.allCases) { Text($0.ten).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)
                .id("hoatDong")
                switch khoiHoatDong {
                case .binhLuan: khoiBinhLuan(cfg)
                case .lichSu: khoiLichSu(cfg)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await vm.tai(); if khoiHoatDong == .lichSu { await vm.taiLichSu() } }
        .disabled(vm.dangGui)
        .overlay(alignment: .top) {
            if vm.dangGui { ProgressView().padding(8) }
        }
        .onChange(of: khoiHoatDong) { _, moi in
            if moi == .lichSu && vm.lichSu == nil { Task { await vm.taiLichSu() } }
        }
        #if DEBUG
        // Cửa xem màn (`CT_XEM_MAN`) của app CT Work: cuộn thẳng tới bình luận/lịch sử để chụp.
        .task {
            let man = ProcessInfo.processInfo.environment["CT_XEM_MAN"]?.lowercased()
            guard man == "binhluan" || man == "lichsu" else { return }
            if man == "lichsu" { khoiHoatDong = .lichSu }
            try? await Task.sleep(nanoseconds: 600_000_000)
            cuon.scrollTo("hoatDong", anchor: .top)
        }
        #endif
        }
    }

    private func dau(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let p = t.parent {
                    NavigationLink(value: CTWRoute.the(pid: vm.pid, so: p.number)) {
                        HStack(spacing: 4) {
                            CTWTypeIcon(type: p.typeId.flatMap(cfg.loai), size: 11)
                            Text("\(cfg.key)-\(p.number)").font(.ctw(size: 12, weight: .medium).monospaced())
                        }
                    }
                    Text("/").foregroundColor(AppColors.textTertiary)
                }
                CTWTypeIcon(type: cfg.loai(t.typeId), size: 13)
                Text("\(cfg.key)-\(t.number)")
                    .font(.ctw(size: 13, weight: .semibold).monospaced())
                    .foregroundColor(AppColors.textSecondary)
                    .textSelection(.enabled)
                Text(cfg.loai(t.typeId)?.name ?? "")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                Spacer(minLength: 0)
                if t.flaggedAt != nil {
                    Label("Flagged", systemImage: "flag.fill")
                        .font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.error)
                }
            }

            if dangSuaTieuDe {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Title", text: $tieuDeNhap, axis: .vertical)
                        .font(.ctw(size: 20, weight: .semibold))
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancel") { dangSuaTieuDe = false }
                        Spacer()
                        Button("Save") {
                            let moi = tieuDeNhap.trimmingCharacters(in: .whitespacesAndNewlines)
                            dangSuaTieuDe = false
                            guard !moi.isEmpty, moi != t.title else { return }
                            Task { await vm.sua(["title": String(moi.prefix(255))]) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(tieuDeNhap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            } else {
                Text(t.title)
                    .font(.ctw(size: 21, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Trạng thái (đổi ngay tại đầu thẻ, như web) · theo dõi (số người).
            HStack(spacing: 8) {
                menuTrangThai(t, cfg)
                Spacer(minLength: 0)
                Button { Task { await vm.doiTheoDoi() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: t.isWatching == true ? "eye.fill" : "eye")
                        if let n = t.watcherCount, n > 0 { Text("\(n)").monospacedDigit() }
                    }
                    .font(.ctw(size: 13, weight: .medium))
                    .foregroundColor(t.isWatching == true ? AppColors.primary : AppColors.textSecondary)
                    .padding(.horizontal, 10).frame(minHeight: 32)
                    .background(Capsule().fill(t.isWatching == true ? AppColors.primary.opacity(0.10) : AppColors.backgroundTertiary))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.isWatching == true ? Text("Stop watching") : Text("Watch"))
                .accessibilityValue(Text("\(t.watcherCount ?? 0) watchers"))
            }
            .padding(.top, 2)
        }
    }

    // MARK: Trường

    private func truong(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        VStack(spacing: 0) {
            hangTruong("Assignee") { menuNguoi(t, cfg) }
            Divider()
            hangTruong("Priority") { menuUuTien(t, cfg) }
            Divider()
            hangTruong("Due date") { oNgay(t, cfg) }
            Divider()
            hangTruong("Reporter") {
                HStack(spacing: 6) {
                    CTWAvatar(user: t.reporter, size: 22)
                    Text(t.reporter?.ten ?? "—").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                    if t.reporter?.laAgent == true { CTWNhanAI() }
                }
            }
            if let sid = t.sprintId, let s = (cfg.sprints ?? []).first(where: { $0.id == sid }) {
                Divider()
                hangTruong("Sprint") {
                    Text(s.name).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                }
            }
            if let sp = t.storyPoints {
                Divider()
                hangTruong("Story points") {
                    Text(sp == sp.rounded() ? String(Int(sp)) : String(format: "%.1f", sp))
                        .font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                }
            }
            if let nhan = t.labelIds, !nhan.isEmpty {
                Divider()
                hangTruong("Labels") {
                    Text((cfg.labels ?? []).filter { nhan.contains($0.id) }.map(\.name).joined(separator: ", "))
                        .font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
            }
            Divider()
            hangTruong("Updated") {
                Text(CTW.thoiDiem(t.updatedAt)).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .ctwThe(14)
    }

    private func hangTruong<V: View>(_ ten: LocalizedStringKey, @ViewBuilder _ gt: () -> V) -> some View {
        HStack(spacing: 12) {
            Text(ten).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                .frame(width: 96, alignment: .leading)
            Spacer(minLength: 0)
            gt()
        }
        .frame(minHeight: 46)
    }

    @ViewBuilder
    private func menuTrangThai(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        let hienTai = cfg.trangThai(t.statusId)
        if cfg.coTheChuyen {
            let dich = cfg.trangThaiDich(loai: t.typeId, tu: t.statusId)
            Menu {
                ForEach(dich) { s in
                    Button {
                        Task { await vm.chuyenTrangThai(s.id) }
                    } label: {
                        if s.id == t.statusId { Label(s.name, systemImage: "checkmark") } else { Text(s.name) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    CTWStatusChip(status: hienTai)
                    Image(systemName: "chevron.down").font(.ctw(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Status: \(hienTai?.name ?? "")")
        } else {
            CTWStatusChip(status: hienTai)
        }
    }

    @ViewBuilder
    private func menuNguoi(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        let nhan = HStack(spacing: 6) {
            CTWAvatar(user: t.assignee, size: 22)
            Text(t.assignee?.ten ?? String(localized: "Unassigned"))
                .font(.ctw(size: 14))
                .foregroundColor(t.assignee == nil ? AppColors.textSecondary : AppColors.textPrimary)
                .lineLimit(1)
            if t.assignee?.laAgent == true { CTWNhanAI() }
        }
        if cfg.coTheSua {
            Menu {
                if let toi = appState.currentUser?.id, cfg.nguoiGiaoDuoc.contains(where: { $0.id == toi }),
                   t.assigneeId != toi {
                    Button { Task { await vm.sua(["assigneeId": toi]) } } label: {
                        Label("Assign to me", systemImage: "person.fill.checkmark")
                    }
                }
                Button { Task { await vm.sua(["assigneeId": NSNull()]) } } label: {
                    if t.assigneeId == nil { Label("Unassigned", systemImage: "checkmark") } else { Text("Unassigned") }
                }
                Divider()
                ForEach(cfg.nguoiGiaoDuoc) { u in
                    Button { Task { await vm.sua(["assigneeId": u.id]) } } label: {
                        let ten = u.laAgent ? String(localized: "\(u.ten) · AI agent") : u.ten
                        if u.id == t.assigneeId { Label(ten, systemImage: "checkmark") }
                        else if u.laAgent { Label(ten, systemImage: "sparkles") }
                        else { Text(ten) }
                    }
                }
            } label: { nhan }
        } else {
            nhan
        }
    }

    @ViewBuilder
    private func menuUuTien(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        let p = CTW.uuTien(t.priority)
        let nhan = HStack(spacing: 6) {
            CTWPriorityIcon(priority: t.priority)
            Text(p.ten).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
        }
        if cfg.coTheSua {
            Menu {
                ForEach(CTW.doUuTien, id: \.so) { m in
                    Button { Task { await vm.sua(["priority": m.so]) } } label: {
                        Label(m.ten, systemImage: m.so == p.so ? "checkmark" : m.bieuTuong)
                    }
                }
            } label: { nhan }
        } else {
            nhan
        }
    }

    @ViewBuilder
    private func oNgay(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        let chu = CTWKieuWeb.ngay(t.dueDate)
        let tre = t.resolvedAt == nil && CTW.quaHan(t.dueDate)
        if cfg.coTheSua {
            if chonNgay {
                HStack(spacing: 8) {
                    DatePicker("", selection: $ngayNhap, displayedComponents: .date)
                        .labelsHidden()
                    Button("Save") {
                        chonNgay = false
                        Task { await vm.sua(["dueDate": CTW.chuoiNgay(ngayNhap)]) }
                    }
                    .buttonStyle(.borderedProminent)
                    Button { chonNgay = false } label: { Image(systemName: "xmark").frame(width: 32, height: 32) }
                        .accessibilityLabel("Cancel")
                }
            } else {
                Menu {
                    Button { batChonNgay(t) } label: { Label(chu == nil ? "Set due date" : "Change due date", systemImage: "calendar") }
                    if chu != nil {
                        Button(role: .destructive) { Task { await vm.sua(["dueDate": NSNull()]) } } label: {
                            Label("Remove due date", systemImage: "calendar.badge.minus")
                        }
                    }
                } label: {
                    Text(chu ?? String(localized: "None"))
                        .font(.ctw(size: 14, weight: tre ? .semibold : .regular))
                        .foregroundColor(chu == nil ? AppColors.textSecondary : (tre ? AppColors.error : AppColors.textPrimary))
                }
            }
        } else {
            Text(chu ?? String(localized: "None"))
                .font(.ctw(size: 14))
                .foregroundColor(tre ? AppColors.error : AppColors.textPrimary)
        }
    }

    private func batChonNgay(_ t: CTWIssueDetail) {
        // Ngày lưu dạng YYYY-MM-DD không múi giờ — dựng lại theo lịch MÁY
        // để DatePicker không lệch một ngày ở UTC+7.
        if let d = CTW.ngay(t.dueDate) {
            let p = d.split(separator: "-").compactMap { Int($0) }
            if p.count == 3, let n = Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) {
                ngayNhap = n
            }
        } else {
            ngayNhap = Date()
        }
        chonNgay = true
    }

    // MARK: Mô tả, đính kèm, thẻ con, liên kết

    private func moTa(_ t: CTWIssueDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("text.alignleft", String(localized: "Description"))
            Group {
                let khoi = CTWTipTap.khoi(t.descriptionJson)
                if khoi.isEmpty {
                    Text("No description.")
                        .font(.ctw(size: 14)).foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    CTWKhoiView(khoi: khoi, coChu: 14.5)
                }
            }
            .padding(14)
            .ctwThe(12)
        }
    }

    private func dinhKem(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        let ds = t.attachments ?? []
        let duocThem = cfg.permissions?.attach == true
        let laAdmin = cfg.role == "ADMIN"
        let them: AnyView? = duocThem ? AnyView(
            Menu {
                #if os(iOS)
                if MayAnh.coMayAnh {
                    Button { tamPhu = .mayAnh } label: { Label("Take Photo", systemImage: "camera") }
                }
                #endif
                Button { moChonAnh = true } label: { Label("Photo Library", systemImage: "photo.on.rectangle") }
                Button { moChonTep = true } label: { Label("Choose File", systemImage: "folder") }
            } label: {
                if vm.dangTaiLen {
                    ProgressView()
                } else {
                    Image(systemName: "plus.circle.fill").font(.ctw(size: 20)).frame(width: 44, height: 32)
                }
            }
            .disabled(vm.dangTaiLen)
            .accessibilityLabel("Add attachment")
        ) : nil
        return VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("paperclip", String(localized: "Attachments"), count: ds.isEmpty ? nil : "\(ds.count)", trailing: them)
                // Bộ chọn tệp gắn ở ĐÂY, bộ chọn ảnh gắn ở khối ngoài, tấm phủ
                // `.sheet` gắn ở gốc màn — ba trình bày ba chỗ (bẫy C5).
                .fileImporter(isPresented: $moChonTep, allowedContentTypes: [.item], allowsMultipleSelection: false) { kq in
                    guard case .success(let ds) = kq, let u = ds.first else { return }
                    Task {
                        let mo = u.startAccessingSecurityScopedResource()
                        defer { if mo { u.stopAccessingSecurityScopedResource() } }
                        guard let du = try? Data(contentsOf: u) else { vm.loi = String(localized: "Couldn't read that file."); return }
                        await vm.taiLen(du: du, ten: u.lastPathComponent)
                    }
                }
            if ds.isEmpty {
                Text(duocThem ? "No files yet. Tap + to add a photo or file." : "No files.")
                    .font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(ds) { a in
                        Button {
                            Task { if let u = await vm.taiVeDeXem(a) { xemNhanh = u } }
                        } label: {
                            HStack(spacing: 11) {
                                Image(systemName: a.bieuTuong)
                                    .font(.ctw(size: 16, weight: .medium)).foregroundColor(AppColors.primary)
                                    .frame(width: 36, height: 36)
                                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.fileName ?? String(localized: "File")).font(.ctw(size: 14, weight: .medium))
                                        .foregroundColor(AppColors.textPrimary).lineLimit(1)
                                    Text([a.coChu, a.uploader?.ten, CTW.thoiDiem(a.createdAt)]
                                        .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "eye").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if laAdmin || a.uploader?.id == appState.currentUser?.id {
                                Button(role: .destructive) { Task { await vm.xoaDinhKem(a) } } label: {
                                    Label("Delete file", systemImage: "trash")
                                }
                            }
                        }
                        if a.id != ds.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 14)
                .ctwThe(12)
            }
        }
        .photosPicker(isPresented: $moChonAnh, selection: $chonAnh, maxSelectionCount: 5, matching: .images)
        .onChange(of: chonAnh) { _, ds in
            guard !ds.isEmpty else { return }
            chonAnh = []
            Task {
                for (i, item) in ds.enumerated() {
                    guard let du = try? await item.loadTransferable(type: Data.self) else { continue }
                    let loai = item.supportedContentTypes.first
                    let duoi = loai?.preferredFilenameExtension ?? "jpg"
                    let kieu = loai?.preferredMIMEType ?? "image/jpeg"
                    await vm.taiLen(du: du, ten: String(localized: "Image \(CTW.tenTepTheoGio())\(ds.count > 1 ? "-\(i + 1)" : "").\(duoi)"), kieu: kieu)
                }
            }
        }
    }

    private func theCon(_ con: [CTWIssueRef], _ cfg: CTWProjectConfig) -> some View {
        let xong = con.filter { $0.statusId.flatMap(cfg.trangThai)?.category == "DONE" }.count
        return VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("checklist", String(localized: "Sub-tasks"), count: "\(xong)/\(con.count)")
            VStack(spacing: 0) {
                ForEach(con) { c in
                    NavigationLink(value: CTWRoute.the(pid: vm.pid, so: c.number)) {
                        HStack(spacing: 8) {
                            CTWTypeIcon(type: c.typeId.flatMap(cfg.loai), size: 12)
                            Text("\(cfg.key)-\(c.number)").font(.ctw(size: 12, weight: .medium).monospaced())
                                .foregroundColor(AppColors.textSecondary)
                            Text(c.title).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            CTWStatusChip(status: c.statusId.flatMap(cfg.trangThai))
                            if c.assigneeId != nil { CTWAvatar(user: cfg.thanhVien(c.assigneeId), size: 20) }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if c.id != con.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 14)
            .ctwThe(12)
        }
    }

    private func lienKet(_ lk: [CTWIssueLink], _ cfg: CTWProjectConfig) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("link", String(localized: "Linked issues"))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lk) { l in
                    let hang = HStack(spacing: 8) {
                        Text(tenLienKet(l)).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                            .frame(width: 100, alignment: .leading)
                        Text(l.issue?.key ?? "").font(.ctw(size: 12, weight: .medium).monospaced())
                            .foregroundColor(AppColors.textSecondary)
                        Text(l.issue?.title ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                    // Thẻ cùng dự án (mã khớp) thì mở được ngay trong app.
                    if let i = l.issue, (i.key ?? "").hasPrefix(cfg.key + "-") {
                        NavigationLink(value: CTWRoute.the(pid: vm.pid, so: i.number)) { hang }.buttonStyle(.plain)
                    } else {
                        hang
                    }
                    if l.id != lk.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 14)
            .ctwThe(12)
        }
    }

    private func tenLienKet(_ l: CTWIssueLink) -> String {
        let ra = l.direction != "inward"
        switch l.type {
        case "BLOCKS": return ra ? String(localized: "blocks") : String(localized: "is blocked by")
        case "DUPLICATES": return ra ? String(localized: "duplicates") : String(localized: "is duplicated by")
        case "CLONES": return ra ? String(localized: "clones") : String(localized: "is cloned by")
        case "TESTS": return ra ? String(localized: "tests") : String(localized: "is tested by")
        default: return String(localized: "relates to")
        }
    }

    // MARK: Lịch sử

    private func khoiLichSu(_ cfg: CTWProjectConfig) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let ds = vm.lichSu {
                if ds.isEmpty {
                    Text("No history yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(ds) { h in
                        HStack(alignment: .top, spacing: 10) {
                            if h.actorKind == "AUTOMATION" || h.actorKind == "SYSTEM" {
                                Image(systemName: "gearshape.fill").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                                    .frame(width: 24, height: 24).background(Circle().fill(AppColors.backgroundTertiary))
                            } else {
                                CTWAvatar(user: h.actor, size: 24)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 5) {
                                    Text(tenNguoiLam(h)).font(.ctw(size: 13, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                    if h.actor?.laAgent == true || h.actorKind == "AGENT" { CTWNhanAI() }
                                    else if h.actorKind == "AI" { CTWNhanAI(chu: "AI") }
                                }
                                Text(CTWLichSu.moTa(h, cfg: cfg))
                                    .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(CTW.thoiDiem(h.createdAt)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 9)
                        if h.id != ds.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 14)
                .ctwThe(12)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
        }
    }

    private func tenNguoiLam(_ h: CTWHistory) -> String {
        switch h.actorKind {
        case "AUTOMATION": return String(localized: "Automation")
        case "SYSTEM": return "CT Work"
        default: return h.actor?.ten ?? String(localized: "Someone")
        }
    }

    // MARK: Bình luận

    private func khoiBinhLuan(_ cfg: CTWProjectConfig) -> some View {
        // Ẩn: bình luận của người đã chặn + bình luận mình đã báo cáo
        // (Guideline 1.2 — chặn/báo cáo phải có tác dụng ngay).
        let ds = vm.binhLuan.filter { c in
            if an.binhLuanAn.contains(c.id) { return false }
            guard let a = c.author?.id else { return true }
            return !kiemDuyet.blockedUserIds.contains(a)
        }
        return VStack(alignment: .leading, spacing: 10) {
            CTWSectionHeader("bubble.left.and.bubble.right", String(localized: "Comments"), count: "\(ds.count)")
            if ds.isEmpty {
                Text("No comments yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
            }
            ForEach(ds) { c in hangBinhLuan(c, cfg) }

            if cfg.coTheBinhLuan {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Add a comment…", text: $binhLuanNhap, axis: .vertical)
                        .lineLimit(1...6)
                        .textFieldStyle(.roundedBorder)
                    let trong = binhLuanNhap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button {
                        let s = binhLuanNhap
                        Task { if await vm.guiBinhLuan(s) { binhLuanNhap = "" } }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.ctw(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(trong ? AppColors.textTertiary : AppColors.primary))
                    }
                    .buttonStyle(.plain)
                    .disabled(trong || vm.dangGui)
                    .accessibilityLabel("Send comment")
                }
                .padding(.top, 4)
                Text("Comments are visible to project members. Be respectful — you can report or block anyone.")
                    .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
            } else {
                Text("You can view this issue but not comment on it.")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
            }
        }
    }

    private func hangBinhLuan(_ c: CTWComment, _ cfg: CTWProjectConfig) -> some View {
        let laCuaToi = c.author?.id != nil && c.author?.id == appState.currentUser?.id
        let laAdmin = cfg.role == "ADMIN"
        return HStack(alignment: .top, spacing: 10) {
            CTWAvatar(user: c.author, size: 28)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(c.author?.ten ?? String(localized: "Someone"))
                        .font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    if c.author?.laAgent == true { CTWNhanAI() }
                    else if c.isAi == true { CTWNhanAI(chu: String(localized: "AI-drafted")) }
                    Text(CTW.thoiDiem(c.createdAt)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                    if c.editedAt != nil {
                        Text("(edited)").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                }
                CTWTipTapView(doc: c.bodyJson, coChu: 14)
                if let ds = c.attachments, !ds.isEmpty {
                    ForEach(ds) { a in
                        Label(a.fileName ?? String(localized: "File"), systemImage: a.bieuTuong)
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .ctwThe(12)
        .contextMenu {
            Button { CTW.chepVaoBoNho(c.bodyJson?.chuTron ?? "") } label: { Label("Copy text", systemImage: "doc.on.doc") }
            if laCuaToi && cfg.coTheBinhLuan {
                Button { tamPhu = .suaBinhLuan(c) } label: { Label("Edit", systemImage: "pencil") }
            }
            if laCuaToi || laAdmin {
                Button(role: .destructive) { hoiXoa = c } label: { Label("Delete", systemImage: "trash") }
            }
            if !laCuaToi {
                Button(role: .destructive) { baoCao = c } label: {
                    Label("Report comment", systemImage: "flag")
                }
            }
            if let a = c.author, !laCuaToi {
                Button(role: .destructive) { hoiChan = a } label: {
                    Label("Block \(a.ten)", systemImage: "hand.raised")
                }
            }
        }
    }
}

// MARK: - Sửa bình luận

struct CTWSuaBinhLuanView: View {
    let chuBanDau: String
    let luu: (String) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var chu = ""
    @State private var dangLuu = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Comment", text: $chu, axis: .vertical).lineLimit(3...14)
            }
            .navigationTitle("Edit comment")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangLuu { ProgressView() } else {
                        Button("Save") {
                            Task {
                                dangLuu = true
                                if await luu(chu) { dong() }
                                dangLuu = false
                            }
                        }
                        .disabled(chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onAppear { if chu.isEmpty { chu = chuBanDau } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Lịch sử: câu mô tả

enum CTWLichSu {
    static func moTa(_ h: CTWHistory, cfg: CTWProjectConfig) -> String {
        let tu = h.fromValue, den = h.toValue
        func ten(_ s: String?, _ ra: (Int) -> String?) -> String {
            guard let s, let n = Int(s) else { return s ?? String(localized: "none") }
            return ra(n) ?? "#\(n)"
        }
        switch h.field {
        case "created": return String(localized: "created the issue")
        case "title": return String(localized: "changed the title to “\(den ?? "")”")
        case "description": return String(localized: "updated the description")
        case "statusId":
            return String(localized: "moved from \(ten(tu) { cfg.trangThai($0)?.name }) to \(ten(den) { cfg.trangThai($0)?.name })")
        case "assigneeId":
            if den == nil { return String(localized: "unassigned the issue") }
            return String(localized: "assigned to \(ten(den) { cfg.thanhVien($0)?.ten })")
        case "priority":
            return String(localized: "changed priority to \(den.flatMap(Int.init).map { CTW.uuTien($0).ten } ?? String(localized: "none"))")
        case "dueDate": return den == nil ? String(localized: "removed the due date") : String(localized: "set the due date to \(CTW.ngayNgan(den) ?? den ?? "")")
        case "startDate": return den == nil ? String(localized: "removed the start date") : String(localized: "set the start date to \(CTW.ngayNgan(den) ?? den ?? "")")
        case "storyPoints": return String(localized: "set story points to \(den ?? String(localized: "none"))")
        case "sprintId":
            return den == nil ? String(localized: "moved to the backlog")
                : String(localized: "moved to sprint \(ten(den) { id in (cfg.sprints ?? []).first { $0.id == id }?.name })")
        case "parentId": return den == nil ? String(localized: "removed the parent") : String(localized: "changed the parent issue")
        case "labels": return String(localized: "set labels: \(den?.isEmpty == false ? den! : String(localized: "none"))")
        case "components": return String(localized: "set components: \(den?.isEmpty == false ? den! : String(localized: "none"))")
        case "attachment": return den != nil ? String(localized: "attached \(den!)") : String(localized: "removed \(tu ?? String(localized: "a file"))")
        case "flagged": return den == "true" ? String(localized: "flagged the issue") : String(localized: "removed the flag")
        case "agentReview": return String(localized: "sent the issue to review")
        default:
            let f = (h.field ?? "a field").replacingOccurrences(of: "Id", with: "")
            return String(localized: "changed \(f)")
        }
    }
}

// MARK: - Báo cáo bình luận (App Store 1.2)

struct CTWBaoCaoKetQua: Decodable {
    var reported: Bool?
    var duplicate: Bool?
}

/// Lý do báo cáo — khớp COMMENT_REPORT_REASONS ở backend.
/// Computed (không phải `let`): nhãn dịch theo ngôn ngữ app lúc hiện, đổi ngôn ngữ là đổi theo.
var ctwLyDoBaoCao: [(ma: String, nhan: String)] { [
    ("spam", String(localized: "Spam or advertising")),
    ("harassment", String(localized: "Harassment or bullying")),
    ("hate", String(localized: "Hate speech")),
    ("sexual", String(localized: "Sexual content")),
    ("violence", String(localized: "Violence or threats")),
    ("other", String(localized: "Something else")),
] }
