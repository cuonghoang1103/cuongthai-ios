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
    /// Phần cấu hình lõi không khai (phiên bản, component, trường tuỳ chỉnh, đơn vị ước lượng) — cùng phản hồi.
    @Published var cauHinhThem: CTWCauHinhThem?
    @Published var the: CTWIssueDetail?
    /// Phần thẻ lõi không khai + mô tả THÔ (để ghi lại không mất định dạng) — cùng phản hồi.
    @Published var them: CTWIssueThem?
    @Published var binhLuan: [CTWComment] = []
    @Published var lichSu: [CTWHistory]?
    @Published var nhatKyGio: [CTWWorklogThe]?
    @Published var loi: String?
    @Published var dangGui = false
    @Published var dangTaiLen = false
    /// Thẻ đã bị xoá / chuyển đi ⇒ màn tự đóng.
    @Published var daRoi = false
    /// Lần lưu gần nhất hỏng vì 409 (có người sửa chen) — thẻ đã được nạp lại.
    var vuaXungDot = false

    init(pid: Int, so: Int) { self.pid = pid; self.so = so }

    func tai() async {
        do {
            async let c = APIClient.shared.requestRaw(.workDuAn(pid: pid))
            async let t = APIClient.shared.requestRaw(.workThe(pid: pid, so: so))
            let (dc, dt) = try await (c, t)
            cauHinh = try CTWAPI.giaiMa(CTWProjectConfig.self, dc)
            cauHinhThem = try? CTWAPI.giaiMa(CTWCauHinhThem.self, dc)
            try nhanThe(dt)
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
        await taiBinhLuan()
    }

    /// Đọc MỘT phản hồi thẻ bằng hai model.
    private func nhanThe(_ d: Data) throws {
        the = try CTWAPI.giaiMa(CTWIssueDetail.self, d)
        them = try? CTWAPI.giaiMa(CTWIssueThem.self, d)
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

    func taiNhatKyGio() async {
        do {
            nhatKyGio = try await APIClient.shared.request(CTWAPI.nhatKyGio(pid: pid, so: so))
        } catch {
            if nhatKyGio == nil { nhatKyGio = [] }
            loi = CTW.loi(error)
        }
    }

    func napLaiThe() async {
        if let d = try? await APIClient.shared.requestRaw(.workThe(pid: pid, so: so)) { try? nhanThe(d) }
    }

    /// PATCH một nhóm trường. `null` gửi bằng `NSNull()`. Trả `true` khi lưu được.
    @discardableResult
    func sua(_ truong: [String: Any]) async -> Bool {
        guard let t = the else { return false }
        var than = truong
        if let v = them?.version ?? t.version { than["version"] = v }
        dangGui = true
        defer { dangGui = false }
        vuaXungDot = false
        do {
            try nhanThe(try await APIClient.shared.requestRaw(CTWAPI.suaThe(pid: pid, so: so, than)))
            loi = nil
            lichSu = nil
            return true
        } catch {
            loi = CTW.loi(error)
            vuaXungDot = CTW.laXungDot(error)
            if vuaXungDot { await napLaiThe() }
            CTWRung.loi()
            return false
        }
    }

    /// Tick/bỏ tick ô việc thứ `chiSo` trong mô tả — sửa JSON THÔ (giữ mọi định dạng khác), kèm `version`.
    func doiViec(_ chiSo: Int) async {
        guard let goc = them?.descriptionJson, let moi = CTWMoTaThe.doiViec(goc, chiSo: chiSo) else { return }
        // Lạc quan: đổi ngay trên màn, hỏng thì `sua` nạp lại.
        let cu = them?.descriptionJson
        them?.descriptionJson = moi
        the?.descriptionJson = moi.nut
        CTWRung.chon()
        if !(await sua(["descriptionJson": moi.any])) && them?.descriptionJson == moi {
            them?.descriptionJson = cu
            the?.descriptionJson = cu?.nut
        }
    }

    /// Lưu mô tả từ markdown. Trả `nil` khi xong; khác ⇒ câu lỗi (bản nháp giữ nguyên ở màn soạn).
    func luuMoTa(_ md: String) async -> String? {
        let t = md.trimmingCharacters(in: .whitespacesAndNewlines)
        let gt: Any = t.isEmpty ? NSNull() : CTWMoTaThe.doc(t).any
        if await sua(["descriptionJson": gt]) { CTWRung.thanhCong(); return nil }
        if vuaXungDot {
            loi = nil
            return String(localized: "Someone else changed this issue while you were editing. Your text is kept — tap Save again to replace their version, or Cancel to keep theirs.")
        }
        return loi ?? String(localized: "Couldn't save. Please try again.")
    }

    /// Thao tác thẻ con/liên kết… xong ⇒ nạp lại thẻ (lấy `children`/`links` mới).
    func goi(_ e: APIEndpoint, thanhCong: Bool = true) async -> Bool {
        dangGui = true
        defer { dangGui = false }
        do {
            try await APIClient.shared.send(e)
            await napLaiThe()
            lichSu = nil
            loi = nil
            if thanhCong { CTWRung.thanhCong() }
            return true
        } catch {
            loi = CTW.loi(error)
            CTWRung.loi()
            return false
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
/// cái cuối chạy). Tấm phủ của từng khối (trường, mô tả, liên kết…) gắn ở view con của khối đó.
private enum TamPhuThe: Identifiable {
    case suaBinhLuan(CTWComment)
    case mayAnh
    /// "Details…" của Sub-tasks — hộp tạo thẻ đầy đủ, thẻ cha điền sẵn.
    case taoTheCon
    /// Hộp tạo thẻ (chỉ cửa xem thử DEBUG `the:taothe`).
    case taoThe
    case chiaSe
    case chuyenDuAn
    var id: String {
        switch self {
        case .suaBinhLuan(let c): return "sua-\(c.id)"
        case .mayAnh: return "mayanh"
        case .taoTheCon: return "taocon"
        case .taoThe: return "tao"
        case .chiaSe: return "chiase"
        case .chuyenDuAn: return "chuyen"
        }
    }
}

/// Một mục của tab Activity (bình luận · lịch sử · nhật ký giờ, xếp theo thời gian như web).
private enum MucHoatDong: Identifiable {
    case binhLuan(CTWComment)
    case lichSu(CTWHistory)
    case gio(CTWWorklogThe)
    var id: String {
        switch self {
        case .binhLuan(let c): return "c\(c.id)"
        case .lichSu(let h): return "h\(h.id)"
        case .gio(let w): return "w\(w.id)"
        }
    }
    var luc: String {
        switch self {
        case .binhLuan(let c): return c.createdAt ?? ""
        case .lichSu(let h): return h.createdAt ?? ""
        case .gio(let w): return w.createdAt ?? w.startedAt ?? ""
        }
    }
}

struct CTWIssueView: View {
    @StateObject private var vm: CTWIssueVM
    @ObservedObject private var kiemDuyet = ModerationStore.shared
    @ObservedObject private var an = AnNoiDungCTW.shared
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var moURL
    @Environment(\.dismiss) private var dong

    @State private var dangSuaTieuDe = false
    @State private var tieuDeNhap = ""
    @State private var binhLuanNhap = ""
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
    @State private var khoiHoatDong: KhoiHoatDong = .tatCa
    @State private var hoiXoaThe = false
    /// Vừa nhân bản ⇒ số thẻ mới (hỏi "Open").
    @State private var daNhanBan: Int?
    @State private var moTheSo: Int?
    @State private var moThe = false
    @State private var daChuyen: CTWKetQuaChuyenDuAn?

    enum KhoiHoatDong: String, CaseIterable, Identifiable {
        case tatCa, binhLuan, lichSu, nhatKy, lienKet
        var id: String { rawValue }
        var ten: String {
            switch self {
            case .tatCa: return String(localized: "Activity")
            case .binhLuan: return String(localized: "Comments")
            case .lichSu: return String(localized: "History")
            case .nhatKy: return String(localized: "Work log")
            case .lienKet: return String(localized: "Links")
            }
        }
    }

    /// Gọi MỘT lần khi thẻ tải xong (app CT Work: ghi "thẻ đã xem" cho Spotlight/Share Extension).
    private let khiMo: ((CTWIssueDetail, CTWProjectConfig) -> Void)?
    /// Móc của app CT Work (ghi giờ, mở tài liệu). App chính để `nil`.
    private let moRong: CTWIssueMoRong?

    init(pid: Int, so: Int, khiMo: ((CTWIssueDetail, CTWProjectConfig) -> Void)? = nil, moRong: CTWIssueMoRong? = nil) {
        _vm = StateObject(wrappedValue: CTWIssueVM(pid: pid, so: so))
        self.khiMo = khiMo
        self.moRong = moRong
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
        .navigationTitle(vm.cauHinh.map { "\($0.key)-\(vm.so)" } ?? String(localized: "Issue"))
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
        .confirmationDialog(
            vm.cauHinh.map { String(localized: "Delete \($0.key)-\(vm.so)?") } ?? "",
            isPresented: $hoiXoaThe, titleVisibility: .visible
        ) {
            Button("Delete issue", role: .destructive) { Task { await xoaThe() } }
        } message: {
            Text("The issue and its sub-tasks move to the project's trash. Admins can restore them from the web.")
        }
        .alert(daBaoCao ?? "", isPresented: Binding(get: { daBaoCao != nil }, set: { if !$0 { daBaoCao = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .alert(daNhanBan.map { n in String(localized: "Cloned as \(vm.cauHinh?.key ?? "")-\(n)") } ?? "",
               isPresented: Binding(get: { daNhanBan != nil }, set: { if !$0 { daNhanBan = nil } })) {
            Button("Open") { moTheSo = daNhanBan; moThe = true }
            Button("OK", role: .cancel) {}
        }
        .alert(String(localized: "Moved to \(daChuyen?.key ?? "")"),
               isPresented: Binding(get: { daChuyen != nil }, set: { if !$0 { daChuyen = nil; dong() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let bo = daChuyen?.dropped, !bo.isEmpty {
                Text("Not carried over: \(bo.joined(separator: ", "))")
            }
        }
        .navigationDestination(isPresented: $moThe) {
            if let n = moTheSo { CTWIssueView(pid: vm.pid, so: n, khiMo: khiMo, moRong: moRong) }
        }
        .sheet(item: $tamPhu) { tp in tamPhuView(tp) }
        .ctwXemTep($xemNhanh)
        #if DEBUG
        .task {
            let man = ProcessInfo.processInfo.environment["CT_XEM_MAN"]?.lowercased()
            guard man == "the:taothe" || man == "the:chiase" || man == "the:chuyen" else { return }
            try? await Task.sleep(nanoseconds: 900_000_000)
            tamPhu = man == "the:taothe" ? .taoThe : (man == "the:chiase" ? .chiaSe : .chuyenDuAn)
        }
        #endif
    }

    @ViewBuilder
    private func tamPhuView(_ tp: TamPhuThe) -> some View {
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
        case .taoTheCon, .taoThe:
            if let cfg = vm.cauHinh, let t = vm.the {
                CTWCreateIssueView(cauHinh: cfg, sprintId: nil,
                                   cha: tp.id == "taocon" ? CTWCreateIssueView.TheCha(id: t.id, number: t.number, title: t.title) : nil) { _ in
                    Task { await vm.napLaiThe() }
                }
            }
        case .chiaSe:
            if let cfg = vm.cauHinh, let t = vm.the {
                CTWChiaSeKenhView(pid: cfg.id,
                                  duong: "/work/\(cfg.workspace?.slug ?? "")/\(cfg.key)/issue/\(t.number)",
                                  nhan: "\(cfg.key)-\(t.number): \(t.title)")
            }
        case .chuyenDuAn:
            if let cfg = vm.cauHinh, let t = vm.the {
                CTWChuyenDuAnView(cfg: cfg, so: t.number, version: vm.them?.version ?? t.version) { r in daChuyen = r }
            }
        }
    }

    // MARK: Menu ⋯ của thẻ

    private func menuThe(_ t: CTWIssueDetail, _ cfg: CTWProjectConfig) -> some View {
        // Như web đợt 8D: thanh đầu chỉ giữ trạng thái + theo dõi; thao tác phụ vào "…".
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
            if cfg.role != "CLIENT" {
                Button { tamPhu = .chiaSe } label: { Label("Share to channel", systemImage: "bubble.left.and.text.bubble.right") }
            }
            if cfg.coTheTao || t.canDelete == true { Divider() }
            if cfg.coTheTao {
                Button { Task { await nhanBan() } } label: { Label("Clone", systemImage: "plus.square.on.square") }
            }
            if t.canDelete == true {
                Button { tamPhu = .chuyenDuAn } label: { Label("Move to another project", systemImage: "arrow.left.arrow.right") }
                Button(role: .destructive) { hoiXoaThe = true } label: { Label("Delete issue", systemImage: "trash") }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("More actions")
    }

    private func nhanBan() async {
        do {
            let moi: CTWIssueDetail = try await APIClient.shared.request(CTWAPI.nhanBanThe(pid: vm.pid, so: vm.so))
            CTWRung.thanhCong()
            await vm.napLaiThe()
            vm.lichSu = nil
            daNhanBan = moi.number
        } catch {
            vm.loi = CTW.loi(error)
        }
    }

    private func xoaThe() async {
        do {
            try await APIClient.shared.send(CTWAPI.xoaThe(pid: vm.pid, so: vm.so))
            CTWRung.thanhCong()
            dong()
        } catch {
            vm.loi = CTW.loi(error)
        }
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
                CTWIssueTruongView(vm: vm, t: t, cfg: cfg, moRong: moRong)
                CTWIssueMoTaView(vm: vm, coTheSua: cfg.coTheSua)
                CTWIssueTheConView(vm: vm, t: t, cfg: cfg) { tamPhu = .taoTheCon }.id("theCon")
                dinhKem(t, cfg)
                thanhTab(t)
                    .padding(.top, 4)
                    .id("hoatDong")
                switch khoiHoatDong {
                case .tatCa: khoiTatCa(cfg)
                case .binhLuan: khoiBinhLuan(cfg)
                case .lichSu: khoiLichSu(cfg)
                case .nhatKy: CTWIssueNhatKyGioView(vm: vm, cfg: cfg)
                case .lienKet:
                    VStack(alignment: .leading, spacing: 18) {
                        CTWIssueLienKetView(vm: vm, t: t, cfg: cfg)
                        CTWIssueLienKetKhacView(vm: vm, cfg: cfg, moRong: moRong)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await vm.tai()
            vm.lichSu = nil
            vm.nhatKyGio = nil
        }
        .overlay(alignment: .top) {
            if vm.dangGui { ProgressView().padding(8) }
        }
        // Tab cần dữ liệu chưa có (hoặc vừa bị xoá sau một lần sửa) ⇒ tải.
        .task(id: "\(khoiHoatDong.rawValue)-\(vm.lichSu == nil)-\(vm.nhatKyGio == nil)") {
            if [.tatCa, .lichSu].contains(khoiHoatDong), vm.lichSu == nil { await vm.taiLichSu() }
            if khoiHoatDong == .tatCa, vm.nhatKyGio == nil { await vm.taiNhatKyGio() }
        }
        #if DEBUG
        // Cửa xem màn (`CT_XEM_MAN`) của app CT Work: cuộn thẳng tới khối cần chụp.
        .task {
            let man = ProcessInfo.processInfo.environment["CT_XEM_MAN"]?.lowercased() ?? ""
            let dich: [String: (KhoiHoatDong?, String)] = [
                "binhluan": (.binhLuan, "hoatDong"), "lichsu": (.lichSu, "hoatDong"),
                "the:lienket": (.lienKet, "hoatDong"), "the:nhatky": (.nhatKy, "hoatDong"),
                "the:thecon": (nil, "theCon"), "the:ghigio": (nil, "ghiGio"), "the:tuychinh": (nil, "tuyChinh"),
            ]
            guard let (k, id) = dich[man] else { return }
            if let k { khoiHoatDong = k }
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation { cuon.scrollTo(id, anchor: .top) }
        }
        #endif
        }
    }

    /// Thanh tab kiểu web (gạch chân) — cuộn ngang được khi chữ dài (tiếng Việt).
    private func thanhTab(_ t: CTWIssueDetail) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(KhoiHoatDong.allCases) { k in
                    let chon = k == khoiHoatDong
                    Button { khoiHoatDong = k } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Text(verbatim: k.ten)
                                if k == .lienKet, let n = t.links?.count, n > 0 {
                                    Text(verbatim: "\(n)").foregroundColor(AppColors.textTertiary)
                                }
                            }
                            .font(.ctw(size: 14, weight: chon ? .semibold : .medium))
                            .foregroundColor(chon ? AppColors.textPrimary : AppColors.textTertiary)
                            .fixedSize()
                            Rectangle().fill(chon ? AppColors.primary : Color.clear).frame(height: 2)
                        }
                        .padding(.horizontal, 8)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(chon ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: Activity (tất cả, theo thời gian)

    private func khoiTatCa(_ cfg: CTWProjectConfig) -> some View {
        let bl: [MucHoatDong] = binhLuanHien.map { .binhLuan($0) }
        let ls: [MucHoatDong] = (vm.lichSu ?? []).map { .lichSu($0) }
        let gio: [MucHoatDong] = (vm.nhatKyGio ?? []).map { .gio($0) }
        let ds = (bl + ls + gio).sorted { $0.luc < $1.luc }
        return VStack(alignment: .leading, spacing: 10) {
            if vm.lichSu == nil {
                ProgressView().frame(maxWidth: .infinity)
            } else if ds.isEmpty {
                Text("No activity yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
            }
            ForEach(ds) { m in
                switch m {
                case .binhLuan(let c): hangBinhLuan(c, cfg)
                case .lichSu(let h): hangLichSu(h, cfg).padding(.horizontal, 12).ctwThe(12)
                case .gio(let w): CTWHangNhatKyGio(w: w).padding(.horizontal, 12).ctwThe(12)
                }
            }
            oSoanBinhLuan(cfg)
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

    // MARK: Trạng thái (đầu thẻ)

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

    // MARK: Đính kèm

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

    // MARK: Lịch sử

    private func khoiLichSu(_ cfg: CTWProjectConfig) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let ds = vm.lichSu {
                if ds.isEmpty {
                    Text("No history yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(ds) { h in
                        hangLichSu(h, cfg)
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

    private func hangLichSu(_ h: CTWHistory, _ cfg: CTWProjectConfig) -> some View {
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
    }

    private func tenNguoiLam(_ h: CTWHistory) -> String {
        switch h.actorKind {
        case "AUTOMATION": return String(localized: "Automation")
        case "SYSTEM": return "CT Work"
        default: return h.actor?.ten ?? String(localized: "Someone")
        }
    }

    // MARK: Bình luận

    /// Ẩn: bình luận của người đã chặn + bình luận mình đã báo cáo
    /// (Guideline 1.2 — chặn/báo cáo phải có tác dụng ngay).
    private var binhLuanHien: [CTWComment] {
        vm.binhLuan.filter { c in
            if an.binhLuanAn.contains(c.id) { return false }
            guard let a = c.author?.id else { return true }
            return !kiemDuyet.blockedUserIds.contains(a)
        }
    }

    private func khoiBinhLuan(_ cfg: CTWProjectConfig) -> some View {
        let ds = binhLuanHien
        return VStack(alignment: .leading, spacing: 10) {
            CTWSectionHeader("bubble.left.and.bubble.right", String(localized: "Comments"), count: "\(ds.count)")
            if ds.isEmpty {
                Text("No comments yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
            }
            ForEach(ds) { c in hangBinhLuan(c, cfg) }
            oSoanBinhLuan(cfg)
        }
    }

    @ViewBuilder
    private func oSoanBinhLuan(_ cfg: CTWProjectConfig) -> some View {
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
