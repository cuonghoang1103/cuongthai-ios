import Foundation
import Combine
import SwiftUI

// MARK: - Kho chung của Bảng tin
//
// MỘT nơi giữ:
//   · máy chủ CÓ bảng tin không (`hoTro`) — app 1.1 phải chạy với máy chủ CŨ: `GET /feed/scopes` trả 404/405/501 ⇒ ẩn
//     MỌI lối vào (phân đoạn My Work, mô-đun dự án, ⌘K, cài đặt thông báo). Nhớ lần đo cuối qua lần mở app;
//   · phạm vi người dùng đọc/đăng được (`/feed/scopes`) — cho bộ lọc, bộ chọn nơi đăng, cài đặt theo dõi;
//   · việc ĐĂNG bài (chạy ngoài ô soạn: ô soạn đóng ngay khi bấm Đăng, bài tạm hiện ở đầu mọi bảng tin khớp phạm vi);
//   · tín hiệu đồng bộ giữa các màn (bài đổi ở màn bình luận ⇒ thẻ trong danh sách cập nhật);
//   · đích chờ mở (thông báo đẩy / đường dẫn sâu ⇒ My Work đẩy màn bài).

/// Màn con của Bảng tin (đăng ký ở `MoDunBangTin.dichDen` ⇒ ngăn xếp nào có `ctwDichDen()` cũng đẩy được).
enum RouteBangTinCTW: Hashable {
    case bai(id: Int, binhLuan: Int?)
    case khongGian(ws: Int, ten: String)
    case hashtag(String, LocBangTin)
    case kiemDuyet
}

/// Một nơi đăng được (bộ chọn "Đăng ở đâu").
struct NoiDangBangTin: Hashable, Identifiable, Codable {
    var ws: CTWFeedWorkspace
    var duAn: CTWFeedProject?
    var id: String { duAn.map { "p\($0.id)" } ?? "w\(ws.id)" }
    var ten: String { duAn?.name ?? ws.name ?? "" }
    var tenDayDu: String {
        if let p = duAn { return "\(ws.name ?? "") › \(p.name ?? p.key ?? "")" }
        return ws.name ?? ""
    }
}

/// Sự kiện đăng bài (ô soạn ⇒ mọi bảng tin đang mở).
enum SuKienDangBaiCTW {
    case batDau(CTWFeedPost)
    case xong(khoa: String, bai: CTWFeedPost)
    case hong(khoa: String, loi: String)
    /// Bộ lọc nội dung từ chối (422 CONTENT_BLOCKED, build 7): bài tạm hiện câu lỗi TẠI CHỖ + nút "Sửa" (mở lại ô soạn
    /// với bản nháp đã giữ) thay cho "Thử lại" — gửi lại y nguyên thì máy chủ vẫn chặn.
    case biChan(khoa: String, loi: String)
    case bo(khoa: String)
}

@MainActor
final class KhoBangTinCTW: ObservableObject {
    static let shared = KhoBangTinCTW()

    /// nil = chưa biết · true = máy chủ có bảng tin · false = máy chủ cũ (ẩn mọi lối vào).
    @Published private(set) var hoTro: Bool?
    @Published private(set) var phamVi: CTWFeedPhamVi?
    /// Đích chờ My Work đẩy (thông báo đẩy, đường dẫn sâu, "Bảng tin không gian" ở bảng chọn dự án).
    @Published var canMo: RouteBangTinCTW?
    /// Yêu cầu mở ô soạn từ nơi khác (⌘K "Đăng bài") — bảng tin đang hiện mở rồi xoá.
    @Published var moSoan: NoiDangBangTin?
    @Published var yeuCauSoan = false

    /// Bài vừa đổi ở một màn (bình luận, chi tiết) ⇒ màn khác thay tại chỗ.
    let baiDoi = PassthroughSubject<CTWFeedPost, Never>()
    /// Bài biến mất cho người xem (xoá, ẩn, báo cáo, gỡ).
    let baiMat = PassthroughSubject<Int, Never>()
    let dangBai = PassthroughSubject<SuKienDangBaiCTW, Never>()
    /// Ẩn/báo cáo ngay ở máy (máy chủ lọc ở lần tải sau).
    @Published private(set) var daAn: Set<Int> = []

    private let khoaHoTro = "ctw.bangTin.hoTro"
    private let khoaPhamVi = "ctw.bangTin.phamVi"
    /// Bài đang đăng: khoá ⇒ thân yêu cầu (Thử lại gửi lại CÙNG `clientKey` ⇒ máy chủ không tạo bài thứ hai).
    private var dangCho: [String: [String: Any]] = [:]
    /// Bản nháp của từng bài đang đăng — bị bộ lọc chặn ⇒ ghi lại thành nháp (`NhapBaiCTW`) để "Sửa" mở đúng nội dung đó.
    private var nhapCho: [String: NhapBaiCTW] = [:]

    private init() {
        if UserDefaults.standard.object(forKey: khoaHoTro) != nil { hoTro = UserDefaults.standard.bool(forKey: khoaHoTro) }
        if let d = UserDefaults.standard.data(forKey: khoaPhamVi) { phamVi = try? JSONDecoder().decode(CTWFeedPhamVi.self, from: d) }
    }

    /// Hiện lối vào Bảng tin: máy chủ có + người dùng đọc được ít nhất một phạm vi (khách cổng / CLIENT ⇒ không có phạm vi nào).
    var hien: Bool { hoTro == true && !(phamVi?.scopes ?? []).isEmpty }

    /// Mọi nơi người dùng ĐĂNG được (không gian trước, rồi dự án của nó).
    var noiDang: [NoiDangBangTin] {
        (phamVi?.scopes ?? []).flatMap { s -> [NoiDangBangTin] in
            var ds: [NoiDangBangTin] = []
            if s.canPost == true { ds.append(NoiDangBangTin(ws: s.workspace)) }
            for p in s.projects ?? [] where p.canPost == true {
                ds.append(NoiDangBangTin(ws: s.workspace, duAn: CTWFeedProject(id: p.id, key: p.key, name: p.name)))
            }
            return ds
        }
    }

    var coTheDang: Bool { hien && !noiDang.isEmpty }

    func khongGian(_ id: Int?) -> CTWFeedPhamVi.KhongGian? { phamVi?.scopes?.first { $0.workspace.id == id } }
    func khongGian(slug: String) -> CTWFeedPhamVi.KhongGian? { phamVi?.scopes?.first { $0.workspace.slug == slug } }
    func duAn(_ pid: Int) -> (ws: CTWFeedPhamVi.KhongGian, p: CTWFeedPhamVi.DuAn)? {
        for s in phamVi?.scopes ?? [] { if let p = s.projects?.first(where: { $0.id == pid }) { return (s, p) } }
        return nil
    }

    /// Quản trị được phạm vi này không (hiện nút kiểm duyệt).
    var quanTriDuoc: Bool {
        (phamVi?.scopes ?? []).contains { $0.canModerate == true || ($0.projects ?? []).contains { $0.canModerate == true } }
    }

    // MARK: Đo máy chủ có bảng tin không

    /// `GET /feed/scopes` tự dựng (cần MÃ HTTP — `APIClient` bỏ mã trên đường lỗi). 404/405/501 ⇒ máy chủ chưa có tuyến
    /// (máy chủ cũ trả `Route GET … not found`) ⇒ ẩn bảng tin. Lỗi mạng / 5xx ⇒ giữ kết luận cũ.
    func kiemHoTro() async {
        guard AppState.shared.isAuthenticated,
              let url = URL(string: APIClient.diaChiGoc + "/api/v1/work/feed/scopes") else { return }
        var r = URLRequest(url: url)
        r.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = StorageManager.shared.getAuthToken() { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        guard let (d, res) = try? await URLSession.shared.data(for: r), let http = res as? HTTPURLResponse else { return }
        apKetQuaDo(maHTTP: http.statusCode, du: d)
    }

    /// Tách riêng để kiểm thử (không mạng).
    func apKetQuaDo(maHTTP: Int, du: Data) {
        switch maHTTP {
        case 200..<300:
            guard let g = try? JSONDecoder().decode(APIResponse<CTWFeedPhamVi>.self, from: du), g.success, let pv = g.data else { return }
            datHoTro(true)
            datPhamVi(pv)
        case 404, 405, 501:
            datHoTro(false)
        case 403:
            // Agent / không được dùng bảng tin ⇒ coi như không có phạm vi nào (ẩn), máy chủ vẫn CÓ tuyến.
            datHoTro(true)
            datPhamVi(CTWFeedPhamVi(scopes: [], openReports: 0))
        default:
            break
        }
    }

    func taiPhamVi() async {
        do {
            let pv: CTWFeedPhamVi = try await APIClient.shared.request(CTWAPI.bangTinPhamVi())
            datHoTro(true)
            datPhamVi(pv)
        } catch {
            if hoTro == nil { await kiemHoTro() }
        }
    }

    private func datHoTro(_ b: Bool) {
        if hoTro != b {
            hoTro = b
            // Mô-đun dự án đọc `hien` trong `CTWModule.hien` ⇒ khung dựng lại theo AppState.
            AppState.shared.objectWillChange.send()
        }
        UserDefaults.standard.set(b, forKey: khoaHoTro)
    }

    func datPhamVi(_ pv: CTWFeedPhamVi) {
        phamVi = pv
        if let d = try? JSONEncoder().encode(pv) { UserDefaults.standard.set(d, forKey: khoaPhamVi) }
    }

    /// Đổi mức theo dõi tại chỗ (sau `PUT /feed/follow`).
    func datTheoDoi(ws: Int, pid: Int?, muc: String) {
        guard var pv = phamVi, var ds = pv.scopes, let i = ds.firstIndex(where: { $0.workspace.id == ws }) else { return }
        if let pid {
            if var ps = ds[i].projects, let j = ps.firstIndex(where: { $0.id == pid }) { ps[j].follow = muc; ds[i].projects = ps }
        } else { ds[i].follow = muc }
        pv.scopes = ds
        datPhamVi(pv)
    }

    // MARK: Ẩn tại máy

    func an(_ id: Int) {
        daAn.insert(id)
        baiMat.send(id)
    }

    // MARK: Đăng bài (lạc quan)

    /// Bấm Đăng: chèn bài tạm vào mọi bảng tin khớp phạm vi, gửi `POST /feed/posts` (kèm `clientKey`), thay bằng bài thật.
    func dang(than: [String: Any], tam: CTWFeedPost, nhap: NhapBaiCTW? = nil) {
        guard let khoa = tam.khoaTam else { return }
        var t = than
        t["clientKey"] = khoa
        dangCho[khoa] = t
        nhapCho[khoa] = nhap
        dangBai.send(.batDau(tam))
        Task { await gui(khoa) }
    }

    func thuLai(_ khoa: String) {
        guard dangCho[khoa] != nil else { return }
        Task { await gui(khoa) }
    }

    func boBaiTam(_ khoa: String) {
        dangCho[khoa] = nil
        nhapCho[khoa] = nil
        dangBai.send(.bo(khoa: khoa))
    }

    /// "Sửa" trên bài bị bộ lọc chặn: bỏ bài tạm, mở lại ô soạn — ô soạn đọc nháp đã ghi lúc bị chặn (chữ, ảnh/tệp đã
    /// tải, bình chọn, nơi đăng).
    func suaBaiBiChan(_ khoa: String, noi: NoiDangBangTin?) {
        let n = NhapBaiCTW.doc()
        boBaiTam(khoa)
        moSoan = n?.noi ?? noi
        yeuCauSoan = true
    }

    private func gui(_ khoa: String) async {
        guard let t = dangCho[khoa] else { return }
        do {
            let p: CTWFeedPost = try await APIClient.shared.request(CTWAPI.baiMoi(t))
            dangCho[khoa] = nil
            nhapCho[khoa] = nil
            CTWRung.thanhCong()
            dangBai.send(.xong(khoa: khoa, bai: p))
        } catch where CTWLoiDich.laNoiDungBiChan(error) {
            // Giữ bản nháp (ô soạn đã đóng khi bấm Đăng) — người dùng sửa lại từ nút "Sửa" trên bài tạm.
            CTWRung.loi()
            if let n = nhapCho[khoa] { NhapBaiCTW.ghi(n) }
            dangCho[khoa] = nil
            dangBai.send(.biChan(khoa: khoa, loi: BangTinLoi.chu(error)))
        } catch {
            CTWRung.loi()
            dangBai.send(.hong(khoa: khoa, loi: BangTinLoi.chu(error)))
        }
    }

    // MARK: Điều hướng

    /// Mở một bài (thông báo đẩy / đường dẫn sâu / Inbox): My Work đẩy màn bài.
    func moBai(_ d: DichBangTin) {
        AppState.shared.muc = .viecCuaToi
        canMo = .bai(id: d.post, binhLuan: d.comment)
    }

    /// Bảng tin không gian (bảng chọn dự án): My Work đẩy màn bảng tin của không gian đó.
    func moKhongGian(_ ws: CTWFeedWorkspace) {
        AppState.shared.muc = .viecCuaToi
        canMo = .khongGian(ws: ws.id, ten: ws.name ?? "")
    }

    func xoaHet() {
        phamVi = nil
        canMo = nil
        daAn = []
        dangCho = [:]
        nhapCho = [:]
        UserDefaults.standard.removeObject(forKey: khoaPhamVi)
        NhapBaiCTW.xoa()
    }
}

// MARK: - Câu lỗi riêng của bảng tin (máy chủ chỉ nói tiếng Anh — dịch theo MÃ ở client, như `CTW.loi`)

enum BangTinLoi {
    static func chu(_ e: Error) -> String {
        if case APIError.coMa(let ma, _) = e, let c = bang[ma] { return c() }
        return CTW.loi(e)
    }

    private static let bang: [String: () -> String] = [
        "WORK_EMPTY": { String(localized: "Write something or add a photo first.") },
        "WORK_TOO_LONG": { String(localized: "That's too long — posts are up to 10,000 characters, comments 4,000.") },
        "WORK_FEED_TOO_MANY_FILES": { String(localized: "A post can have up to 10 photos or videos and 5 files.") },
        "WORK_FILE_TOO_LARGE": { String(localized: "This file is too large.") },
        "WORK_FILE_EMPTY": { String(localized: "This file is empty.") },
        "WORK_FILE_TYPE": { String(localized: "This file type isn't supported.") },
        "WORK_UPLOAD_MISSING": { String(localized: "The upload didn't finish. Please try again.") },
        "WORK_FEED_BAD_ATTACHMENT": { String(localized: "One of the attachments is no longer available. Remove it and add it again.") },
        "WORK_FEED_POLL": { String(localized: "A poll needs 2–6 options of up to 120 characters.") },
        "WORK_FEED_POLL_CLOSED": { String(localized: "This poll is closed.") },
        "WORK_FEED_PIN_LIMIT": { String(localized: "You can pin up to 5 posts here. Unpin one first.") },
        "WORK_RATE": { String(localized: "You're posting too fast. Wait a moment and try again.") },
        "WORK_REPORT_SELF": { String(localized: "You can't report your own post.") },
        "WORK_URL_BLOCKED": { String(localized: "This link can't be previewed.") },
        "WORK_FEED_FORBIDDEN": { String(localized: "You don't have permission to do that here.") },
        "WORK_AGENT_FORBIDDEN": { String(localized: "AI agents can't use the team feed.") },
        "NOT_FOUND": { String(localized: "This post is no longer available.") },
    ]
}

// MARK: - Bản nháp ô soạn (giữ khi lỡ tay đóng)

struct NhapBaiCTW: Codable, Equatable {
    var chu: String = ""
    var noi: NoiDangBangTin?
    var dinhKem: [CTWFeedAttachment] = []
    var luaChon: [String] = []
    var nhieuLuaChon = false

    var trong: Bool { chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && dinhKem.isEmpty && luaChon.allSatisfy { $0.isEmpty } }

    @MainActor private static var khoa: String { "ctw.bangTin.nhap.\(AppState.shared.currentUser?.id ?? 0)" }

    @MainActor static func doc() -> NhapBaiCTW? {
        guard let d = UserDefaults.standard.data(forKey: khoa) else { return nil }
        return try? JSONDecoder().decode(NhapBaiCTW.self, from: d)
    }

    @MainActor static func ghi(_ n: NhapBaiCTW?) {
        guard let n, !n.trong, let d = try? JSONEncoder().encode(n) else { UserDefaults.standard.removeObject(forKey: khoa); return }
        UserDefaults.standard.set(d, forKey: khoa)
    }

    @MainActor static func xoa() {
        for k in UserDefaults.standard.dictionaryRepresentation().keys where k.hasPrefix("ctw.bangTin.nhap.") {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }
}
