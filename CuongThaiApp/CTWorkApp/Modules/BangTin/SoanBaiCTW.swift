import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Ô soạn bài (toàn màn trên iPhone, form sheet trên iPad)
//
// · Nơi đăng: không gian hoặc dự án có `canPost` (`/feed/scopes`). Tệp đã tải thuộc MỘT không gian ⇒ khi đã có tệp,
//   chỉ đổi được sang nơi cùng không gian.
// · Ảnh: PhotosPicker (≤ 10 ảnh+video), máy ảnh; NÉN trước khi gửi (cạnh dài ≤ 2048 px, JPEG 0,82 — HEIC đổi JPEG
//   như hợp đồng yêu cầu) ⇒ đường A. Video ≤ 200 MB ⇒ đường B (URL ký) + ảnh bìa khung đầu. Tệp ≤ 100 MB (≤ 5).
//   Mỗi tệp tải NGAY khi chọn, có % + huỷ; nút Đăng chỉ bật khi mọi tệp đã xong.
// · @nhắc gợi ý từ `/feed/mentionable`; gắn thẻ CT Work (chèn link ⇒ máy chủ dựng thẻ xem trước); bình chọn 2–6 lựa chọn.
// · Lỡ tay đóng ⇒ giữ NHÁP (chữ, nơi đăng, tệp đã tải) — mở lại là khôi phục.
// · Đăng: đóng ngay, bài tạm hiện đầu bảng tin (KhoBangTinCTW.dang — `clientKey` chống đăng trùng khi mạng chập chờn).

enum AnhBangTin {
    static let canhToiDa: CGFloat = 2048

    /// Kích thước sau khi thu (giữ tỉ lệ, không phóng ảnh nhỏ lên).
    static func kichThuoc(rong: CGFloat, cao: CGFloat, toiDa: CGFloat = canhToiDa) -> CGSize {
        let dai = max(rong, cao)
        guard dai > toiDa, dai > 0 else { return CGSize(width: rong, height: cao) }
        let k = toiDa / dai
        return CGSize(width: (rong * k).rounded(), height: (cao * k).rounded())
    }

    /// HEIC/PNG/… ⇒ JPEG đã thu nhỏ. nil nếu không đọc được ảnh.
    static func nen(_ du: Data) -> (Data, CGSize)? {
        guard let u = UIImage(data: du) else { return nil }
        let s = kichThuoc(rong: u.size.width * u.scale, cao: u.size.height * u.scale)
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        let anh = UIGraphicsImageRenderer(size: s, format: f).image { _ in u.draw(in: CGRect(origin: .zero, size: s)) }
        guard let j = anh.jpegData(compressionQuality: 0.82) else { return nil }
        return (j, s)
    }
}

/// Video chọn từ thư viện — chép ra thư mục tạm (PhotosPicker trao tệp sống ngắn).
struct PhimChonCTW: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { m in SentTransferredFile(m.url) } importing: { r in
            let duoi = r.file.pathExtension.isEmpty ? "mov" : r.file.pathExtension
            let dich = FileManager.default.temporaryDirectory.appendingPathComponent("ctwfeed-\(UUID().uuidString).\(duoi)")
            try FileManager.default.copyItem(at: r.file, to: dich)
            return PhimChonCTW(url: dich)
        }
    }
}

/// Một tệp trong ô soạn: đang tải (có %) · xong (bản nháp máy chủ) · hỏng.
struct MucDinhKemCTW: Identifiable {
    enum Loai { case anh, video, tep }
    let id = UUID()
    var loai: Loai
    var ten: String
    var xemTruoc: UIImage?
    var tienDo: Double?
    var loi: String?
    var tep: CTWFeedAttachment?
    var xong: Bool { tep != nil }
}

@MainActor
final class SoanBaiVM: ObservableObject {
    @Published var chu = ""
    @Published var noi: NoiDangBangTin?
    @Published private(set) var dinhKem: [MucDinhKemCTW] = []
    @Published var coBinhChon = false
    @Published var luaChon: [String] = ["", ""]
    @Published var nhieuLuaChon = false
    @Published var tatBinhLuan = false
    @Published private(set) var goiY: [CTWUser] = []
    @Published var loi: String?
    @Published private(set) var xemTruoc: CTWFeedLinkPreview?
    @Published private(set) var daKhoiPhuc = false
    @Published var theGan: [CTWSearchItem] = []

    /// Bài đang sửa (nil = bài mới).
    let suaBai: CTWFeedPost?
    @Published private(set) var tepCu: [CTWFeedAttachment] = []
    private var boTepCu: [Int] = []
    private var tacVu: [UUID: Task<Void, Never>] = [:]
    private var timNhacTask: Task<Void, Never>?
    private var linkTask: Task<Void, Never>?
    private var linkDaXem: String?
    private var daDang = false

    init(noi: NoiDangBangTin?, sua: CTWFeedPost? = nil) {
        suaBai = sua
        if let p = sua {
            chu = p.body ?? ""
            tepCu = p.attachments ?? []
            tatBinhLuan = p.commentsOff ?? false
            if let w = p.workspace { self.noi = NoiDangBangTin(ws: w, duAn: p.project) }
        } else if let n = NhapBaiCTW.doc(), !n.trong {
            chu = n.chu
            self.noi = n.noi ?? noi
            dinhKem = n.dinhKem.map { MucDinhKemCTW(loai: $0.laVideo ? .video : $0.laAnh ? .anh : .tep, ten: $0.fileName ?? "", tep: $0) }
            if !n.luaChon.isEmpty { coBinhChon = true; luaChon = n.luaChon; nhieuLuaChon = n.nhieuLuaChon }
            daKhoiPhuc = true
        } else {
            self.noi = noi
        }
    }

    // MARK: Trạng thái

    var soAnhVideo: Int { dinhKem.filter { $0.loai != .tep }.count + tepCu.filter { !$0.laTep }.count }
    var soTep: Int { dinhKem.filter { $0.loai == .tep }.count + tepCu.filter(\.laTep).count }
    var conChoAnh: Int { max(0, 10 - soAnhVideo) }
    var dangTaiLen: Bool { dinhKem.contains { !$0.xong && $0.loi == nil } }
    var luaChonHopLe: [String] { luaChon.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    var binhChonHopLe: Bool { coBinhChon && (2...6).contains(luaChonHopLe.count) && luaChonHopLe.allSatisfy { $0.count <= 120 } }
    var coNoiDung: Bool {
        !chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dinhKem.contains(where: \.xong) || !tepCu.isEmpty
            || binhChonHopLe || !theGan.isEmpty
    }
    /// Nút Đăng bật khi: có nơi đăng, có nội dung, không tệp nào đang tải/hỏng, bình chọn (nếu bật) hợp lệ, chữ ≤ 10 000.
    var dangDuoc: Bool {
        noi != nil && coNoiDung && !dangTaiLen && !dinhKem.contains { $0.loi != nil } && (!coBinhChon || binhChonHopLe)
            && chu.count <= 10_000 && !daDang
    }
    var coThayDoi: Bool { suaBai == nil ? !nhap.trong || !theGan.isEmpty : chu != (suaBai?.body ?? "") || !dinhKem.isEmpty || !boTepCu.isEmpty }

    var nhap: NhapBaiCTW {
        NhapBaiCTW(chu: chu, noi: noi, dinhKem: dinhKem.compactMap(\.tep), luaChon: coBinhChon ? luaChon : [], nhieuLuaChon: nhieuLuaChon)
    }

    func boNhap() {
        NhapBaiCTW.ghi(nil)
        for d in dinhKem { if let t = d.tep { Task { _ = try? await APIClient.shared.send(CTWAPI.xoaNhapTep(t.id)) } } }
        dinhKem = []; chu = ""; luaChon = ["", ""]; coBinhChon = false; theGan = []; daKhoiPhuc = false
    }

    /// Đóng ô soạn mà chưa đăng ⇒ giữ nháp (bài mới).
    func khiDong() {
        guard suaBai == nil, !daDang else { return }
        for (_, t) in tacVu { t.cancel() }
        NhapBaiCTW.ghi(nhap)
    }

    // MARK: Thêm tệp

    func themAnh(_ items: [PhotosPickerItem]) {
        guard let ws = noi?.ws.id else { return }
        for it in items.prefix(conChoAnh) {
            let laVideo = it.supportedContentTypes.contains { $0.conforms(to: .movie) }
            let m = MucDinhKemCTW(loai: laVideo ? .video : .anh, ten: laVideo ? "video.mov" : "photo.jpg", tienDo: 0)
            let id = m.id
            dinhKem.append(m)
            tacVu[id] = Task { [weak self] in
                guard let self else { return }
                do {
                    if laVideo {
                        guard let phim = try await it.loadTransferable(type: PhimChonCTW.self) else { throw TaiLenBangTin.Loi.khongDocDuoc }
                        try await taiVideo(id: id, ws: ws, url: phim.url)
                    } else {
                        guard let d = try await it.loadTransferable(type: Data.self) else { throw TaiLenBangTin.Loi.khongDocDuoc }
                        try await taiAnh(id: id, ws: ws, du: d)
                    }
                } catch { sua(id) { $0.loi = Task.isCancelled ? nil : BangTinLoi.chu(error) } }
            }
        }
    }

    func themAnhChup(_ d: Data) {
        guard let ws = noi?.ws.id, conChoAnh > 0 else { return }
        let m = MucDinhKemCTW(loai: .anh, ten: "camera.jpg", tienDo: 0)
        dinhKem.append(m)
        tacVu[m.id] = Task { [weak self] in
            do { try await self?.taiAnh(id: m.id, ws: ws, du: d) } catch { self?.sua(m.id) { $0.loi = BangTinLoi.chu(error) } }
        }
    }

    func themTep(_ urls: [URL]) {
        guard let ws = noi?.ws.id else { return }
        for u in urls.prefix(max(0, 5 - soTep)) {
            let co = u.startAccessingSecurityScopedResource()
            defer { if co { u.stopAccessingSecurityScopedResource() } }
            let ten = u.lastPathComponent
            let tam = FileManager.default.temporaryDirectory.appendingPathComponent("ctwfeed-\(UUID().uuidString)-\(ten)")
            guard (try? FileManager.default.copyItem(at: u, to: tam)) != nil else { loi = TaiLenBangTin.Loi.khongDocDuoc.localizedDescription; continue }
            let m = MucDinhKemCTW(loai: .tep, ten: ten, tienDo: 0)
            dinhKem.append(m)
            tacVu[m.id] = Task { [weak self] in
                guard let self else { return }
                do {
                    let co = (try? FileManager.default.attributesOfItem(atPath: tam.path)[.size] as? Int) ?? 0
                    guard co <= TaiLenBangTin.tranTep else { throw TaiLenBangTin.Loi.quaLon(100) }
                    let mime = TaiLenBangTin.mime(cho: ten)
                    let id = m.id
                    let bao = baoTienDo(id)
                    let a: CTWFeedAttachment
                    if co <= TaiLenBangTin.tranQuaMayChu, let d = try? Data(contentsOf: tam) {
                        a = try await TaiLenBangTin.quaMayChu(ws: ws, du: d, ten: ten, mime: mime, tienDo: bao)
                    } else {
                        a = try await TaiLenBangTin.quaUrlKy(ws: ws, tepCucBo: tam, ten: ten, mime: mime, kind: "FILE", coByte: co, tienDo: bao)
                    }
                    try Task.checkCancellation()
                    sua(id) { $0.tep = a; $0.tienDo = nil }
                } catch { sua(m.id) { $0.loi = Task.isCancelled ? nil : BangTinLoi.chu(error) } }
                try? FileManager.default.removeItem(at: tam)
            }
        }
    }

    private func taiAnh(id: UUID, ws: Int, du: Data) async throws {
        guard let (j, _) = AnhBangTin.nen(du) else { throw TaiLenBangTin.Loi.khongDocDuoc }
        guard j.count <= TaiLenBangTin.tranAnh else { throw TaiLenBangTin.Loi.quaLon(20) }
        sua(id) { $0.xemTruoc = UIImage(data: j) }
        let a = try await TaiLenBangTin.quaMayChu(ws: ws, du: j, ten: "photo-\(Int(Date().timeIntervalSince1970)).jpg", mime: "image/jpeg",
                                                         tienDo: baoTienDo(id))
        try Task.checkCancellation()
        sua(id) { $0.tep = a; $0.tienDo = nil }
    }

    private func taiVideo(id: UUID, ws: Int, url: URL) async throws {
        defer { try? FileManager.default.removeItem(at: url) }
        let co = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        guard co <= TaiLenBangTin.tranVideo else { throw TaiLenBangTin.Loi.quaLon(200) }
        let asset = AVURLAsset(url: url)
        var rong: Int?, cao: Int?, ms: Int?
        if let t = try? await asset.loadTracks(withMediaType: .video).first,
           let (s, tf) = try? await t.load(.naturalSize, .preferredTransform) {
            let r = s.applying(tf)
            rong = Int(abs(r.width)); cao = Int(abs(r.height))
        }
        if let d = try? await asset.load(.duration) { ms = Int(CMTimeGetSeconds(d) * 1000) }
        var bia: Data?
        let g = AVAssetImageGenerator(asset: asset)
        g.appliesPreferredTrackTransform = true
        g.maximumSize = CGSize(width: 1280, height: 1280)
        if let (cg, _) = try? await g.image(at: CMTime(seconds: 0.1, preferredTimescale: 600)) {
            let u = UIImage(cgImage: cg)
            sua(id) { $0.xemTruoc = u }
            bia = u.jpegData(compressionQuality: 0.8)
        }
        let duoi = url.pathExtension.lowercased()
        let mime = duoi == "mp4" ? "video/mp4" : duoi == "webm" ? "video/webm" : "video/quicktime"
        var a = try await TaiLenBangTin.quaUrlKy(ws: ws, tepCucBo: url, ten: "video.\(duoi.isEmpty ? "mov" : duoi)", mime: mime, kind: "VIDEO",
                                                 coByte: co, rong: rong, cao: cao, thoiLuongMs: ms, tienDo: baoTienDo(id))
        try Task.checkCancellation()
        if let bia, let b = try? await TaiLenBangTin.anhBia(a.id, jpeg: bia) { a = b }
        sua(id) { $0.tep = a; $0.tienDo = nil }
    }

    /// Tiến độ từ luồng mạng (không phải luồng chính) ⇒ đẩy về MainActor.
    private func baoTienDo(_ id: UUID) -> @Sendable (Double) -> Void {
        { [weak self] p in Task { @MainActor in self?.sua(id) { $0.tienDo = p } } }
    }

    private func sua(_ id: UUID, _ f: (inout MucDinhKemCTW) -> Void) {
        if let i = dinhKem.firstIndex(where: { $0.id == id }) { f(&dinhKem[i]) }
    }

    /// Bỏ một tệp: đang tải ⇒ huỷ; đã thành nháp ⇒ `DELETE /feed/uploads/:id`.
    func bo(_ m: MucDinhKemCTW) {
        tacVu[m.id]?.cancel()
        tacVu[m.id] = nil
        dinhKem.removeAll { $0.id == m.id }
        if let t = m.tep { Task { _ = try? await APIClient.shared.send(CTWAPI.xoaNhapTep(t.id)) } }
    }

    func boTepCu(_ a: CTWFeedAttachment) {
        tepCu.removeAll { $0.id == a.id }
        boTepCu.append(a.id)
    }

    #if DEBUG
    /// Màn thử (`CT_XEM_FEED_MO=soan`) — đặt sẵn tệp đính kèm mẫu.
    func datMau(_ ds: [MucDinhKemCTW]) { dinhKem = ds }
    #endif

    func thuLai(_ m: MucDinhKemCTW) {
        // Tệp hỏng không còn byte gốc ⇒ bỏ để người dùng chọn lại.
        bo(m)
    }

    // MARK: Nơi đăng

    /// Đổi nơi đăng: đã có tệp ⇒ chỉ trong CÙNG không gian (tệp nháp thuộc không gian đã tải).
    func doiNoi(_ n: NoiDangBangTin) -> Bool {
        if !dinhKem.isEmpty, let cu = noi, cu.ws.id != n.ws.id { return false }
        noi = n
        return true
    }

    // MARK: @nhắc + xem trước link

    func khiDoiChu() {
        timNhacTask?.cancel()
        if let q = NhacDangGo.dangGo(chu), let ws = noi?.ws.id {
            let pid = noi?.duAn?.id
            timNhacTask = Task {
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else { return }
                let r: CTWFeedNguoiNhac? = try? await APIClient.shared.request(CTWAPI.bangTinNguoiNhac(ws: ws, pid: pid, q: q))
                guard !Task.isCancelled else { return }
                goiY = (r?.users ?? []).filter { $0.id != AppState.shared.currentUser?.id && !$0.laAgent }
            }
        } else { goiY = [] }
        // Link web ngoài đầu tiên ⇒ xem trước (máy chủ tải OpenGraph).
        let link = ChuBangTin.manh(chu, nhac: []).compactMap { m -> URL? in
            if case .url(let u) = m.1, !TrinhDuyetCuongThaiCTW.laCuaCuongThai(u) { return u }
            return nil
        }.first
        guard link?.absoluteString != linkDaXem else { return }
        linkTask?.cancel()
        linkDaXem = link?.absoluteString
        guard let link else { xemTruoc = nil; return }
        linkTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            let r: CTWFeedLinkPreview? = try? await APIClient.shared.request(CTWAPI.xemTruocLink(link.absoluteString))
            guard !Task.isCancelled else { return }
            xemTruoc = r
        }
    }

    func chonNhac(_ u: CTWUser) {
        chu = NhacDangGo.chen(chu, username: u.username ?? "")
        goiY = []
    }

    // MARK: Đăng / Lưu

    /// Bài mới: trả `true` ⇒ đóng ô soạn (bài tạm đã chèn). Bài sửa: chờ máy chủ.
    func dang(toi: CTWUser?) async -> Bool {
        guard dangDuoc, let n = noi else { return false }
        var noiDung = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        let lienKet = theGan.compactMap { t -> String? in
            guard let slug = t.workspace?.slug, let ma = t.project?.key else { return nil }
            return "/work/\(slug)/\(ma)/issue/\(t.number)"
        }
        if !lienKet.isEmpty { noiDung += (noiDung.isEmpty ? "" : "\n\n") + lienKet.joined(separator: "\n") }
        let ids = dinhKem.compactMap(\.tep?.id)

        if let p = suaBai {
            var than: [String: Any] = ["body": noiDung, "commentsOff": tatBinhLuan]
            if !ids.isEmpty { than["attachmentIds"] = ids }
            if !boTepCu.isEmpty { than["removeAttachmentIds"] = boTepCu }
            do {
                let moi: CTWFeedPost = try await APIClient.shared.request(CTWAPI.suaBai(p.id, than))
                KhoBangTinCTW.shared.baiDoi.send(moi)
                daDang = true
                CTWRung.thanhCong()
                return true
            } catch {
                loi = BangTinLoi.chu(error)
                CTWRung.loi()
                return false
            }
        }

        var than: [String: Any] = ["workspaceId": n.ws.id, "projectId": n.duAn.map { $0.id as Any } ?? NSNull()]
        if !noiDung.isEmpty { than["body"] = noiDung }
        if !ids.isEmpty { than["attachmentIds"] = ids }
        if binhChonHopLe { than["poll"] = ["options": luaChonHopLe, "multi": nhieuLuaChon] }
        if tatBinhLuan { than["commentsOff"] = true }
        let khoa = TrangBangTin.khoaMoi()
        var tam = TrangBangTin.baiTam(khoa: khoa, toi: toi, chu: noiDung, ws: n.ws, duAn: n.duAn, dinhKem: dinhKem.compactMap(\.tep))
        if binhChonHopLe {
            tam.poll = CTWFeedPoll(options: luaChonHopLe.enumerated().map { .init(id: "\($0.offset)", text: $0.element, votes: 0) },
                                   multi: nhieuLuaChon, closed: false, totalVotes: 0, voters: 0, myVotes: [])
        }
        daDang = true
        KhoBangTinCTW.shared.dang(than: than, tam: tam)
        NhapBaiCTW.ghi(nil)
        return true
    }
}

// MARK: - Màn soạn

struct SoanBaiCTW: View {
    @StateObject private var vm: SoanBaiVM
    @ObservedObject private var kho = KhoBangTinCTW.shared
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dong
    @State private var anhChon: [PhotosPickerItem] = []
    @State private var tamPhu: TamPhu?
    @State private var moThuVien = false
    @State private var moTep = false
    @State private var moMayAnh = false
    @State private var hoiDong = false
    @State private var dangDang = false
    @FocusState private var goChu: Bool

    enum TamPhu: String, Identifiable { case noi, the; var id: String { rawValue } }

    init(noi: NoiDangBangTin?, sua: CTWFeedPost? = nil) {
        _vm = StateObject(wrappedValue: SoanBaiVM(noi: noi, sua: sua))
    }

    private var toi: CTWUser? { app.currentUser?.nguoiBangTin }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if vm.daKhoiPhuc { bangNhap }
                    dau
                    oChu
                    if !vm.goiY.isEmpty && NhacDangGo.dangGo(vm.chu) != nil { goiYNhac }
                    if let l = vm.xemTruoc, vm.dinhKem.isEmpty { TheLinkCTW(l: l) { _ in }.allowsHitTesting(false) }
                    if !vm.theGan.isEmpty { theDaGan }
                    if vm.coBinhChon { oBinhChon }
                    if !vm.tepCu.isEmpty || !vm.dinhKem.isEmpty { luoiDinhKem }
                    if let loi = vm.loi { CTWErrorBanner(text: loi) { vm.loi = nil } }
                    Toggle(isOn: $vm.tatBinhLuan) { Label("Turn off comments", systemImage: "bubble.left.and.exclamationmark.bubble.right") }
                        .font(.ctw(size: 14)).tint(AppColors.primary)
                        .padding(.top, 6)
                }
                .padding(16)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { thanhCongCu }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(vm.suaBai == nil ? "Create post" : "Edit post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if vm.coThayDoi && vm.suaBai == nil { hoiDong = true } else { dong() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await dang() } } label: {
                        if dangDang { ProgressView() } else { Text(vm.suaBai == nil ? "Post" : "Save").fontWeight(.semibold) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.dangDuoc || dangDang)
                    .accessibilityIdentifier("feed.composer.post")
                }
            }
            .confirmationDialog("Keep this post as a draft?", isPresented: $hoiDong, titleVisibility: .visible) {
                Button("Save draft") { dong() }
                Button("Discard post", role: .destructive) { vm.boNhap(); dong() }
                Button("Keep writing", role: .cancel) {}
            }
        }
        .photosPicker(isPresented: $moThuVien, selection: $anhChon, maxSelectionCount: max(1, vm.conChoAnh),
                      matching: .any(of: [.images, .videos]), preferredItemEncoding: .compatible)
        .onChange(of: anhChon) { _, ds in
            guard !ds.isEmpty else { return }
            vm.themAnh(ds)
            anhChon = []
        }
        .fileImporter(isPresented: $moTep, allowedContentTypes: [.item], allowsMultipleSelection: true) { r in
            if case .success(let urls) = r { vm.themTep(urls) }
        }
        .fullScreenCover(isPresented: $moMayAnh) { MayAnh { vm.themAnhChup($0) }.ignoresSafeArea() }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .noi: ChonNoiDangCTW(chon: vm.noi, coTep: !vm.dinhKem.isEmpty) { n in _ = vm.doiNoi(n) }
            case .the: ChonTheGanCTW(slug: vm.noi?.ws.slug) { it in if !vm.theGan.contains(where: { $0.id == it.id }) { vm.theGan.append(it) } }
            }
        }
        .onChange(of: vm.chu) { _, _ in vm.khiDoiChu() }
        .onDisappear { vm.khiDong() }
        .onAppear {
            if vm.noi == nil { vm.noi = kho.noiDang.first { $0.duAn?.id == app.luaChon?.pid } ?? kho.noiDang.first }
            #if DEBUG
            XemThuBangTin.mauSoan(vm)
            #endif
            var tuGo = true
            #if DEBUG
            tuGo = XemThuBangTin.mo != "soan"   // ảnh chụp ô soạn: không bật bàn phím (thấy đủ ảnh đính kèm)
            #endif
            if tuGo { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { goChu = true } }
        }
        .interactiveDismissDisabled(dangDang)
    }

    private func dang() async {
        dangDang = true
        defer { dangDang = false }
        goChu = false
        if await vm.dang(toi: toi) { dong() }
    }

    // MARK: Phần

    private var bangNhap: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.badge.clock").foregroundColor(AppColors.primary)
            Text("Draft restored").font(.ctw(size: 13, weight: .semibold))
            Spacer()
            Button("Discard") { vm.boNhap() }.font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.error)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.primary.opacity(0.08)))
    }

    private var dau: some View {
        HStack(spacing: 10) {
            CTWAvatar(user: toi, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(toi?.ten ?? "").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Button { if vm.suaBai == nil { tamPhu = .noi } } label: {
                    HStack(spacing: 5) {
                        Image(systemName: vm.noi?.duAn == nil ? "building.2.fill" : "folder.fill").font(.ctw(size: 11, weight: .semibold))
                        Text(vm.noi?.tenDayDu ?? String(localized: "Choose where to post")).font(.ctw(size: 13, weight: .semibold)).lineLimit(1)
                        if vm.suaBai == nil { Image(systemName: "chevron.down").font(.ctw(size: 10, weight: .bold)) }
                    }
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 10).frame(minHeight: 30)
                    .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Post to: \(vm.noi?.tenDayDu ?? "")"))
                .accessibilityHint(Text("Choose a workspace or project"))
                .accessibilityIdentifier("feed.composer.audience")
            }
            Spacer()
        }
    }

    private var oChu: some View {
        ZStack(alignment: .topLeading) {
            if vm.chu.isEmpty {
                Text("Share an update with your team… Type @ to mention someone.")
                    .font(.ctw(size: 17)).foregroundColor(AppColors.textTertiary)
                    .padding(.top, 8).padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $vm.chu)
                .font(.ctw(size: 17))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .focused($goChu)
                .accessibilityLabel(Text("Post text"))
                .accessibilityIdentifier("feed.composer.text")
        }
        .overlay(alignment: .bottomTrailing) {
            if vm.chu.count > 9_000 {
                Text(verbatim: "\(vm.chu.count)/10000").font(.ctw(size: 11).monospacedDigit())
                    .foregroundColor(vm.chu.count > 10_000 ? AppColors.error : AppColors.textTertiary)
            }
        }
    }

    private var goiYNhac: some View {
        VStack(spacing: 0) {
            ForEach(vm.goiY.prefix(6)) { u in
                Button { vm.chonNhac(u) } label: {
                    HStack(spacing: 10) {
                        CTWAvatar(user: u, size: 30)
                        Text(u.ten).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                        if let n = u.username { Text(verbatim: "@\(n)").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary) }
                        Spacer()
                    }
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("feed.mention.\(u.username ?? "")")
                Divider().padding(.leading, 52)
            }
        }
        .ctwThe(12)
    }

    private var theDaGan: some View {
        VStack(spacing: 6) {
            ForEach(vm.theGan) { t in
                HStack(spacing: 8) {
                    Image(systemName: CTW.bieuTuongLoai(key: t.type?.key)).font(.ctw(size: 11, weight: .bold)).foregroundColor(.white)
                        .frame(width: 22, height: 22).background(RoundedRectangle(cornerRadius: 6).fill(CTW.mau(t.type?.color, macDinh: AppColors.info)))
                    Text(verbatim: t.key ?? "").font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.primary)
                    Text(verbatim: t.title).font(.ctw(size: 14)).lineLimit(1)
                    Spacer()
                    Button { vm.theGan.removeAll { $0.id == t.id } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary).frame(width: 32, height: 32)
                    }
                    .accessibilityLabel(Text("Remove \(t.key ?? "")"))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundSecondary))
            }
        }
    }

    private var oBinhChon: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Poll", systemImage: "chart.bar.doc.horizontal").font(.ctw(size: 14, weight: .semibold))
                Spacer()
                Button { vm.coBinhChon = false } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary) }
                    .accessibilityLabel(Text("Remove poll"))
            }
            ForEach(vm.luaChon.indices, id: \.self) { i in
                HStack {
                    TextField(String(localized: "Option \(i + 1)"), text: $vm.luaChon[i])
                        .textFieldStyle(.roundedBorder)
                    if vm.luaChon.count > 2 {
                        Button { vm.luaChon.remove(at: i) } label: { Image(systemName: "minus.circle").foregroundColor(AppColors.error) }
                            .accessibilityLabel(Text("Remove option"))
                    }
                }
            }
            if vm.luaChon.count < 6 {
                Button { vm.luaChon.append("") } label: { Label("Add option", systemImage: "plus") }.font(.ctw(size: 14))
            }
            Toggle("Allow several answers", isOn: $vm.nhieuLuaChon).font(.ctw(size: 14)).tint(AppColors.primary)
        }
        .padding(12)
        .ctwThe(12)
    }

    private var luoiDinhKem: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
            ForEach(vm.tepCu) { a in
                oTep(ten: a.fileName ?? "", anh: nil, a: a, tienDo: nil, loi: nil) { vm.boTepCu(a) }
            }
            ForEach(vm.dinhKem) { m in
                oTep(ten: m.ten, anh: m.xemTruoc, a: m.tep, tienDo: m.xong ? nil : (m.tienDo ?? 0), loi: m.loi, laVideo: m.loai == .video,
                     laTep: m.loai == .tep) { vm.bo(m) }
            }
        }
    }

    private func oTep(ten: String, anh: UIImage?, a: CTWFeedAttachment?, tienDo: Double?, loi: String?, laVideo: Bool = false,
                      laTep: Bool = false, bo: @escaping () -> Void) -> some View {
        let tep = laTep || a?.laTep == true
        // Khung CỐ ĐỊNH theo ô lưới (Color.clear + overlay) — ảnh `scaledToFill` không được nới rộng ô (tràn lề, đo 22/10).
        return Color.clear.frame(maxWidth: .infinity).frame(height: 100).overlay { ZStack {
            if let anh { Image(uiImage: anh).resizable().scaledToFill() }
            else if let a, !tep { AnhTepBangTinCTW(a: a, kieu: "thumb") }
            else {
                VStack(spacing: 6) {
                    Image(systemName: tep ? (a.map(ChipTepCTW.bieuTuong) ?? "doc") : (laVideo ? "video" : "photo"))
                        .font(.ctw(size: 24)).foregroundColor(AppColors.primary)
                    if tep { Text(ten).font(.ctw(size: 11)).lineLimit(2).multilineTextAlignment(.center).padding(.horizontal, 6) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundSecondary)
            }
            if let tienDo {
                Color.black.opacity(0.35)
                ZStack {
                    Circle().stroke(.white.opacity(0.35), lineWidth: 4)
                    Circle().trim(from: 0, to: max(0.04, tienDo)).stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90)).animation(.linear(duration: 0.2), value: tienDo)
                }
                .frame(width: 34, height: 34)
                .accessibilityLabel(Text("Uploading \(Int(tienDo * 100))%"))
            }
            if loi != nil {
                Color.black.opacity(0.5)
                Image(systemName: "exclamationmark.triangle.fill").font(.ctw(size: 22)).foregroundColor(.yellow)
            }
            if laVideo || a?.laVideo == true {
                Image(systemName: "video.fill").font(.ctw(size: 11, weight: .bold)).foregroundColor(.white)
                    .padding(5).background(Circle().fill(.black.opacity(0.5)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(6)
            }
        } }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button(action: bo) {
                Image(systemName: tienDo != nil ? "xmark.circle.fill" : "xmark.circle.fill")
                    .font(.ctw(size: 20)).foregroundStyle(.white, .black.opacity(0.6))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(tienDo != nil ? Text("Cancel upload") : Text("Remove"))
        }
        .help(loi ?? "")
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(loi ?? ten))
    }

    private var thanhCongCu: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 4) {
                nut("photo.on.rectangle.angled", String(localized: "Photo or video"), id: "feed.composer.photos", tat: vm.conChoAnh == 0 || vm.noi == nil) {
                    #if DEBUG
                    // UI test: thêm thẳng ảnh mẫu, không lái bảng chọn ảnh của hệ thống (XemThuCTW+BangTin.swift).
                    if XemThuBangTin.anhMau { vm.themAnhChup(XemThuBangTin.taoAnhMau()); return }
                    #endif
                    moThuVien = true
                }
                if MayAnh.coMayAnh {
                    nut("camera", String(localized: "Camera"), tat: vm.conChoAnh == 0 || vm.noi == nil) { moMayAnh = true }
                }
                nut("paperclip", String(localized: "File"), tat: vm.soTep >= 5 || vm.noi == nil) { moTep = true }
                nut("number.square", String(localized: "Attach an issue"), tat: vm.noi == nil) { tamPhu = .the }
                if vm.suaBai == nil {
                    nut("chart.bar.doc.horizontal", String(localized: "Poll"), tat: vm.coBinhChon) { vm.coBinhChon = true }
                }
                nut("at", String(localized: "Mention"), tat: false) {
                    if !(vm.chu.last.map { $0.isWhitespace } ?? true) { vm.chu += " " }
                    vm.chu += "@"
                    goChu = true
                }
                Spacer()
                if vm.soAnhVideo > 0 {
                    Text(verbatim: "\(vm.soAnhVideo)/10").font(.ctw(size: 12).monospacedDigit()).foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
        }
        .background(AppColors.backgroundCard)
    }

    private func nut(_ icon: String, _ ten: String, id: String? = nil, tat: Bool, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Image(systemName: icon).font(.ctw(size: 19, weight: .medium))
                .foregroundColor(tat ? AppColors.textTertiary : AppColors.primary)
                .frame(width: 44, height: 44)
        }
        .disabled(tat)
        .accessibilityLabel(Text(ten))
        .accessibilityIdentifier(id ?? "feed.composer.\(icon)")
    }
}

// MARK: - Chọn nơi đăng

struct ChonNoiDangCTW: View {
    let chon: NoiDangBangTin?
    let coTep: Bool
    let xong: (NoiDangBangTin) -> Void
    @ObservedObject private var kho = KhoBangTinCTW.shared
    @Environment(\.dismiss) private var dong

    var body: some View {
        NavigationStack {
            List {
                ForEach(kho.phamVi?.scopes ?? []) { s in
                    let ds = kho.noiDang.filter { $0.ws.id == s.workspace.id }
                    if !ds.isEmpty {
                        Section {
                            ForEach(ds) { n in hang(n) }
                        } header: {
                            Text(verbatim: s.workspace.name ?? "").textCase(nil)
                        } footer: {
                            if coTep, let c = chon, c.ws.id != s.workspace.id {
                                Text("Remove the attachments to post in another workspace.")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Post to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func hang(_ n: NoiDangBangTin) -> some View {
        let khoa = coTep && chon != nil && chon?.ws.id != n.ws.id
        return Button { xong(n); dong() } label: {
            HStack(spacing: 12) {
                if let p = n.duAn {
                    CTWProjectMark(ma: p.key ?? "?", co: 34, caMa: true)
                } else {
                    Image(systemName: "building.2.fill").font(.ctw(size: 15)).foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(CTWKieuWeb.mau(n.ws.slug ?? "")))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: n.ten).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                    Text(n.duAn == nil ? String(localized: "Everyone in the workspace") : String(localized: "Members of this project"))
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if chon?.id == n.id { Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.primary) }
            }
            .contentShape(Rectangle())
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(khoa)
        .opacity(khoa ? 0.4 : 1)
        .accessibilityAddTraits(chon?.id == n.id ? .isSelected : [])
    }
}

// MARK: - Gắn thẻ CT Work

struct ChonTheGanCTW: View {
    let slug: String?
    let chon: (CTWSearchItem) -> Void
    @Environment(\.dismiss) private var dong
    @State private var q = ""
    @State private var ds: [CTWSearchItem] = []
    @State private var dangTai = false

    var body: some View {
        NavigationStack {
            List {
                if !dangTai && ds.isEmpty {
                    Text(q.count < 2 ? "Type an issue key or a few words of its title." : "No matching issues")
                        .foregroundColor(AppColors.textSecondary)
                }
                ForEach(ds) { t in
                    Button { chon(t); dong() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: CTW.bieuTuongLoai(key: t.type?.key)).font(.ctw(size: 11, weight: .bold)).foregroundColor(.white)
                                .frame(width: 22, height: 22).background(RoundedRectangle(cornerRadius: 6).fill(CTW.mau(t.type?.color, macDinh: AppColors.info)))
                            Text(verbatim: t.key ?? "").font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.primary)
                            Text(verbatim: t.title).lineLimit(2).foregroundColor(AppColors.textPrimary)
                            Spacer()
                            CTWStatusChip(ten: t.status?.name, category: t.status?.category).fixedSize()
                        }
                        .frame(minHeight: 40)
                    }
                }
                if dangTai { ProgressView().frame(maxWidth: .infinity) }
            }
            .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search issues"))
            .navigationTitle("Attach an issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } } }
            .task(id: q) {
                guard q.trimmingCharacters(in: .whitespaces).count >= 2 else { ds = []; return }
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                dangTai = true
                defer { dangTai = false }
                let r: CTWSearchResult? = try? await APIClient.shared.request(CTWAPI.timToanCuc(q: q, limit: 20))
                ds = (r?.items ?? []).filter { slug == nil || $0.workspace?.slug == nil || $0.workspace?.slug == slug }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

extension User {
    /// Người đang đăng nhập dưới dạng PUBLIC_USER (avatar/tên ở ô soạn, bài tạm).
    var nguoiBangTin: CTWUser { CTWUser(id: id, username: username, fullName: fullName, displayName: displayName, avatarUrl: avatarUrl, kind: "HUMAN") }
}
