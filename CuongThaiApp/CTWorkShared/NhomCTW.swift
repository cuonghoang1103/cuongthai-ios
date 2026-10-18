import Foundation
import Security

// MARK: - Vùng CHUNG của app CT Work với widget + Share Extension (mảng D, 18/10/2026)
//
// Ba target cùng biên dịch tệp này: `CTWorkApp`, `CTWorkWidget`, `CTWorkShare`. Nó CHỈ `import
// Foundation` + `Security` — không kéo `Shared/Network`, Kingfisher, Socket.IO… vào extension (extension
// chỉ được vài chục MB; lôi thư viện app vào là bị hệ thống giết câm — bài học TienWidget/ChiaSeVideo).
//
// · App Group `group.com.cuongthai.ctwork` — phải TRÙNG KHÍT với `com.security.application-groups` của cả
//   ba target trong `project.yml` (XcodeGen sinh lại tệp .entitlements; KHÔNG sửa tay tệp đó).
//   App GHI ảnh chụp (JSON), widget/extension chỉ ĐỌC. Widget KHÔNG gọi mạng, không cầm token.
// · Keychain chia sẻ `<TEAM>.com.cuongthai.ctwork.shared` — CHỈ Share Extension đọc (nó phải gọi API để tạo
//   thẻ/bình luận). App chép token vào đây mỗi lần ra tiền cảnh / đăng nhập; đăng xuất ⇒ xoá.
//   Tiền tố đội đọc từ Info.plist `CTWNhomKeychain` (= `$(AppIdentifierPrefix)com.cuongthai.ctwork.shared`).

enum NhomCTW {
    static let appGroup = "group.com.cuongthai.ctwork"

    static var thuMuc: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    static func ghi<T: Encodable>(_ v: T, ten: String) {
        guard let u = thuMuc?.appendingPathComponent(ten) else { return }
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        if let d = try? e.encode(v) { try? d.write(to: u, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }

    static func doc<T: Decodable>(_ t: T.Type, ten: String) -> T? {
        guard let u = thuMuc?.appendingPathComponent(ten), let d = try? Data(contentsOf: u) else { return nil }
        let dc = JSONDecoder()
        dc.dateDecodingStrategy = .iso8601
        return try? dc.decode(t, from: d)
    }

    static func xoa(ten: String) {
        guard let u = thuMuc?.appendingPathComponent(ten) else { return }
        try? FileManager.default.removeItem(at: u)
    }

    static func xoaHet() {
        for t in [AnhViecHomNayCTW.tep, AnhDongHoCTW.tep, AnhDuAnCTW.tep, TheGanDayCTW.tep] { xoa(ten: t) }
        TokenNhomCTW.xoa()
    }
}

// MARK: - Ảnh chụp: việc hôm nay (widget "My work today" + Siri "What's on my plate")

struct AnhViecHomNayCTW: Codable, Equatable {
    static let tep = "viec-hom-nay.json"

    struct Viec: Codable, Equatable, Identifiable, Hashable {
        /// "due" | "meeting" | "sprint" | "release" | "stage" | "overdue"
        var loai: String
        var id: String
        var tieuDe: String
        /// "NW-12" hoặc "M-3"
        var ma: String?
        var duAn: String?
        /// Họp: giờ bắt đầu (ISO). Khác: nil.
        var gio: Date?
        var quaHan: Bool
        /// Đường mở trong app (`ctwork://…` hoặc `/work/...`).
        var duongDan: String?
    }

    /// Ngày (YMD giờ VN) mà ảnh chụp này nói về.
    var ngay: String
    var capNhat: Date
    var viec: [Viec]
    /// Đăng xuất ⇒ widget hiện "Sign in", không hiện dữ liệu của người trước.
    var daDangNhap: Bool

    static func doc() -> AnhViecHomNayCTW? { NhomCTW.doc(AnhViecHomNayCTW.self, ten: tep) }
    func ghi() { NhomCTW.ghi(self, ten: Self.tep) }
}

// MARK: - Ảnh chụp: đồng hồ bấm giờ (widget + nguồn cho Live Activity)

struct AnhDongHoCTW: Codable, Equatable {
    static let tep = "dong-ho.json"
    var issueKey: String
    var issueTitle: String
    var projectKey: String
    var running: Bool
    /// Mốc ĐÃ LÙI theo số giây chạy trước (đếm tiếp bằng `Text(timerInterval:)`). nil khi tạm dừng.
    var runningSince: Date?
    var elapsedSec: Int
    var duongDan: String?
    var capNhat: Date

    static func doc() -> AnhDongHoCTW? { NhomCTW.doc(AnhDongHoCTW.self, ten: tep) }
}

// MARK: - Ảnh chụp: dự án gần đây (Share Extension chọn nơi tạo thẻ)

struct AnhDuAnCTW: Codable, Equatable {
    static let tep = "du-an.json"
    struct DuAn: Codable, Equatable, Identifiable, Hashable {
        var id: Int
        var ma: String
        var ten: String
        var slug: String
        var tenKhongGian: String?
    }
    var duAn: [DuAn]
    /// Dự án đang chọn trong app (mặc định của Share Extension).
    var macDinh: Int?

    static func doc() -> AnhDuAnCTW? { NhomCTW.doc(AnhDuAnCTW.self, ten: tep) }
}

// MARK: - Thẻ đã xem gần đây (Spotlight + Share Extension "bình luận vào thẻ" + Siri chọn thẻ)

struct TheGanDayCTW: Codable, Equatable, Identifiable, Hashable {
    static let tep = "the-gan-day.json"
    static let toiDa = 30

    var pid: Int
    var slug: String
    var maDuAn: String
    var so: Int
    var tieuDe: String
    var xemLuc: Date

    var id: String { "\(maDuAn)-\(so)" }
    var ma: String { "\(maDuAn)-\(so)" }
    var duongDan: String { "/work/\(slug)/\(maDuAn)/issue/\(so)" }

    static func ds() -> [TheGanDayCTW] { NhomCTW.doc([TheGanDayCTW].self, ten: tep) ?? [] }

    /// Thêm lên đầu, bỏ bản trùng, giữ tối đa `toiDa`. Trả danh sách mới.
    @discardableResult
    static func them(_ t: TheGanDayCTW) -> [TheGanDayCTW] {
        var ds = ds().filter { $0.id != t.id }
        ds.insert(t, at: 0)
        if ds.count > toiDa { ds = Array(ds.prefix(toiDa)) }
        NhomCTW.ghi(ds, ten: tep)
        return ds
    }
}

// MARK: - Token trong Keychain chia sẻ (chỉ Share Extension đọc)

enum TokenNhomCTW {
    private static let dichVu = "com.cuongthai.ctwork.shared"
    private static let tai = "token"

    /// `<TEAM>.com.cuongthai.ctwork.shared` từ Info.plist; thiếu ⇒ nil (bản dựng không ký: bỏ qua im lặng).
    static var nhom: String? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "CTWNhomKeychain") as? String,
              !s.isEmpty, !s.hasPrefix("$(") else { return nil }
        return s
    }

    private static func truyVan() -> [String: Any]? {
        guard let nhom else { return nil }
        return [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: dichVu,
                kSecAttrAccount as String: tai,
                kSecAttrAccessGroup as String: nhom]
    }

    static func luu(_ token: String?) {
        guard var q = truyVan() else { return }
        guard let token, !token.isEmpty, let d = token.data(using: .utf8) else { xoa(); return }
        let thuocTinh: [String: Any] = [kSecValueData as String: d,
                                        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        if SecItemUpdate(q as CFDictionary, thuocTinh as CFDictionary) == errSecSuccess { return }
        q.merge(thuocTinh) { $1 }
        SecItemAdd(q as CFDictionary, nil)
    }

    static func doc() -> String? {
        guard var q = truyVan() else { return nil }
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var kq: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &kq) == errSecSuccess, let d = kq as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func xoa() {
        guard let q = truyVan() else { return }
        SecItemDelete(q as CFDictionary)
    }
}

// MARK: - Ngày theo giờ VN (máy chủ CT Work cắt ngày theo Asia/Ho_Chi_Minh)

enum NgayNhomCTW {
    static let mui = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
    static func ymd(_ d: Date = Date()) -> String {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = mui
        let p = c.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", p.year ?? 1970, p.month ?? 1, p.day ?? 1)
    }
}
