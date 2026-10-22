import Foundation
import ObjectiveC

// MARK: - NGÔN NGỮ của app CT Work (20/10/2026) — Tiếng Việt / English, đổi NGAY trong app
//
// Ba target cùng biên dịch tệp này: `CTWorkApp`, `CTWorkWidget`, `CTWorkShare` (chỉ `import Foundation`).
//
// · Lựa chọn (`CheDo`): theo máy (mặc định) · vi · en. App lưu ở UserDefaults chuẩn + chép ra App Group
//   (`ngon-ngu.json`, ghi bằng `NhomCTW.ghi`) để widget/extension đọc bằng tệp.
//   ⚠️ (build 7, 22/10/2026 — audit R1) Tệp này VẪN gọi `UserDefaults.standard` (`cheDo` chạy cả trong widget và Share
//   Extension) ⇒ PrivacyInfo của CẢ BA target khai `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1` (miền
//   riêng của chính target, không App Group defaults ⇒ không 1C8F.1). Thêm API "required reason" nào ở đây ⇒ khai cả ba.
// · Ngôn ngữ của MÁY đọc bằng `Locale.preferredLanguages` — KHÔNG đọc `AppleLanguages` của miền toàn cục
//   (dữ liệu hệ thống ghi; CA92.1 không cho phép — audit R2).
// · Đổi ngay không khởi động lại: `caiDatBundle()` tráo lớp của `Bundle.main` (object_setClass) sang
//   `BundleNgonNguCTW` ⇒ MỌI `String(localized:)` / `NSLocalizedString` / `Text("…")` tra trong
//   `<ma>.lproj` đang chọn. Gốc view còn gắn `.environment(\.locale, …)` + `.id(ma)` để dựng lại cả cây.
// · `AppleLanguages` cũng được ghi ⇒ phần do HỆ THỐNG vẽ (bảng chọn ảnh, nút Huỷ của UIKit, App Intents…)
//   theo ngôn ngữ đã chọn từ lần mở app sau. Chọn "theo máy" ⇒ xoá khoá đó (về danh sách của máy).
// · Người dùng đổi ngôn ngữ trong Cài đặt iOS › CT Work › Ngôn ngữ ⇒ iOS ghi `AppleLanguages` của app ⇒ lần mở
//   sau app thấy khác với lần mình ghi ⇒ nhận đó là lựa chọn mới (không đè lại).

enum NgonNguCTW {
    enum CheDo: String, Codable, CaseIterable, Identifiable {
        case theoMay = "system", vi, en
        var id: String { rawValue }
    }

    /// Hai ngôn ngữ app có. Ngôn ngữ nguồn là `en`.
    static let hoTro = ["vi", "en"]

    private static let khoaCheDo = "com.cuongthai.ctwork.ngonNgu"
    private static let khoaDaGhi = "com.cuongthai.ctwork.ngonNgu.daGhiAppleLanguages"
    static let tep = "ngon-ngu.json"

    private struct AnhNgonNgu: Codable { var cheDo: CheDo }

    /// Lựa chọn hiện tại. App: UserDefaults chuẩn; extension: tệp App Group do app ghi.
    static var cheDo: CheDo {
        if let s = UserDefaults.standard.string(forKey: khoaCheDo), let c = CheDo(rawValue: s) { return c }
        if let a = NhomCTW.doc(AnhNgonNgu.self, ten: tep) { return a.cheDo }
        return .theoMay
    }

    /// Mã ngôn ngữ đang hiệu lực: "vi" hoặc "en".
    static private(set) var ma: String = tinhMa()

    static var locale: Locale { Locale(identifier: ma == "vi" ? "vi" : "en") }

    /// Ngôn ngữ của MÁY. Chỉ dùng khi lựa chọn là "theo máy" — khi đó app đã XOÁ `AppleLanguages` riêng của mình
    /// (`ghiAppleLanguages`) nên `Locale.preferredLanguages` là danh sách của máy. (Vừa đổi vi/en ⇒ "theo máy" trong
    /// cùng phiên: hệ thống có thể còn giữ danh sách cũ tới lần mở sau — chấp nhận, đúng lại từ lần mở kế.)
    static func maTheoMay(_ ds: [String] = Locale.preferredLanguages) -> String {
        for l in ds {
            let goc = String(l.prefix(2)).lowercased()
            if hoTro.contains(goc) { return goc }
        }
        return "en"
    }

    private static func tinhMa() -> String {
        switch cheDo {
        case .vi: return "vi"
        case .en: return "en"
        case .theoMay: return maTheoMay()
        }
    }

    /// Bundle `<ma>.lproj` trong gói đang chạy (app hoặc extension). nil ⇒ tra như thường.
    static private(set) var bundle: Bundle? = timBundle(ma)

    private static func timBundle(_ ma: String) -> Bundle? {
        // Bundle.main đã bị tráo lớp — `path(forResource:)` không đi qua phần ghi đè nên vẫn đúng.
        guard let p = Bundle.main.path(forResource: ma, ofType: "lproj") else { return nil }
        return Bundle(path: p)
    }

    /// Gọi MỘT lần thật sớm (init của App / widget bundle / Share Extension).
    static func caiDatBundle() {
        if object_getClass(Bundle.main) != BundleNgonNguCTW.self {
            object_setClass(Bundle.main, BundleNgonNguCTW.self)
        }
        napLai()
    }

    /// CHỈ trong bộ nhớ, không lưu (kiểm thử: chạy mọi phép kiểm bằng tiếng Anh dù máy mô phỏng đang chọn tiếng Việt).
    static func datTrongBoNho(_ c: CheDo) {
        ma = c == .vi ? "vi" : (c == .en ? "en" : maTheoMay())
        bundle = timBundle(ma)
    }

    /// Tính lại mã + bundle (sau khi đổi lựa chọn).
    static func napLai() {
        ma = tinhMa()
        bundle = timBundle(ma)
    }

    // MARK: Chỉ APP gọi (extension chỉ đọc)

    /// Lần mở app: nếu `AppleLanguages` của app khác với lần mình ghi ⇒ người dùng đã đổi trong Cài đặt iOS.
    static func dongBoVoiCaiDatHeThong() {
        let daGhi = UserDefaults.standard.string(forKey: khoaDaGhi)
        let hienCo = (UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?["AppleLanguages"] as? [String])?.first
        guard let hienCo else {
            // Không có khoá riêng ⇒ theo máy, trừ khi người dùng đã chọn trong app (ghi lại cho chắc).
            if cheDo != .theoMay { ghiAppleLanguages() }
            return
        }
        let goc = String(hienCo.prefix(2)).lowercased()
        if goc != daGhi, hoTro.contains(goc) {
            // Đổi ở Cài đặt iOS ⇒ nhận làm lựa chọn mới.
            UserDefaults.standard.set(goc, forKey: khoaCheDo)
            UserDefaults.standard.set(goc, forKey: khoaDaGhi)
            NhomCTW.ghi(AnhNgonNgu(cheDo: CheDo(rawValue: goc) ?? .theoMay), ten: tep)
        }
        napLai()
    }

    /// Đổi lựa chọn (Account › Language). Áp ngay; phần hệ thống theo từ lần mở sau.
    static func dat(_ c: CheDo) {
        UserDefaults.standard.set(c.rawValue, forKey: khoaCheDo)
        NhomCTW.ghi(AnhNgonNgu(cheDo: c), ten: tep)
        ghiAppleLanguages()
        napLai()
    }

    private static func ghiAppleLanguages() {
        switch cheDo {
        case .theoMay:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            UserDefaults.standard.removeObject(forKey: khoaDaGhi)
        case .vi, .en:
            let m = cheDo.rawValue
            UserDefaults.standard.set([m], forKey: "AppleLanguages")
            UserDefaults.standard.set(m, forKey: khoaDaGhi)
        }
    }
}

/// `Bundle.main` được tráo sang lớp này: tra chuỗi trong `<ma>.lproj` đang chọn.
/// Bảng không có trong lproj (vd chuỗi của thư viện dùng Bundle.main) ⇒ trả về như cũ.
///
/// ⚠️ Phải chặn ĐỦ các biến thể selector (đo trên iOS 26, 20/10/2026): `String(localized:)` của swift-foundation và
/// `Text("…")` của SwiftUI KHÔNG đi qua `localizedStringForKey:value:table:` mà qua các biến thể có
/// `localization(s):` (truyền ngôn ngữ ưa thích LÚC KHỞI ĐỘNG) — chỉ ghi đè hàm cũ là đổi ngôn ngữ không có tác dụng
/// tới lần mở app sau. Ở đây mọi biến thể đều bỏ qua ngôn ngữ được truyền vào và dùng ngôn ngữ app đang chọn.
final class BundleNgonNguCTW: Bundle, @unchecked Sendable {
    /// nil ⇒ không phải bảng của app (để lớp gốc xử lý).
    private func tra(_ key: String, _ value: String?, _ tableName: String?) -> String? {
        guard let b = NgonNguCTW.bundle else { return nil }
        let bang = (tableName?.isEmpty == false ? tableName : nil) ?? "Localizable"
        // Bảng có trong lproj đang chọn ⇒ tra ở ĐÓ, thiếu khoá thì trả chính khoá (chữ tiếng Anh gốc).
        if b.path(forResource: bang, ofType: "strings") != nil || b.path(forResource: bang, ofType: "stringsdict") != nil {
            return b.localizedString(forKey: key, value: value, table: tableName)
        }
        // Ngôn ngữ NGUỒN (en): Xcode bỏ hẳn bảng trong en.lproj khi mọi chữ trùng khoá ⇒ bảng chỉ có ở vi.lproj.
        // Là bảng của app (vi.lproj có) ⇒ trả chính khoá, đừng để lớp gốc chọn tiếng Việt theo máy.
        if NgonNguCTW.ma == "en",
           path(forResource: bang, ofType: "strings", inDirectory: nil, forLocalization: "vi") != nil
            || path(forResource: bang, ofType: "stringsdict", inDirectory: nil, forLocalization: "vi") != nil {
            if let value, !value.isEmpty { return value }
            return key
        }
        return nil
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        tra(key, value, tableName) ?? super.localizedString(forKey: key, value: value, table: tableName)
    }

    @objc(localizedStringForKey:value:table:localization:)
    func ctwTra1(_ key: String, value: String?, table tableName: String?, localization: String?) -> String {
        tra(key, value, tableName) ?? super.localizedString(forKey: key, value: value, table: tableName)
    }

    // iOS 18.4+: API công khai (NS_REFINED_FOR_SWIFT ⇒ Swift thấy tên `__localizedString`). iOS 17 không có hàm
    // này trên lớp gốc ⇒ chỉ ghi đè khi có; khai `@objc` riêng cho 17 sẽ trùng selector nên để 18.4 lo.
    @available(iOS 18.4, *)
    override func __localizedString(forKey key: String, value: String?, table tableName: String?, localizations: [String]) -> String {
        tra(key, value, tableName) ?? super.__localizedString(forKey: key, value: value, table: tableName, localizations: localizations)
    }

    @objc(_localizedStringForKey:value:table:localizations:)
    func ctwTra3(_ key: String, value: String?, table tableName: String?, localizations: [String]?) -> String {
        tra(key, value, tableName) ?? super.localizedString(forKey: key, value: value, table: tableName)
    }
}
