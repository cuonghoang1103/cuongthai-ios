import Foundation
import ObjectiveC

// MARK: - NGÔN NGỮ của app CT Work (20/10/2026) — Tiếng Việt / English, đổi NGAY trong app
//
// Ba target cùng biên dịch tệp này: `CTWorkApp`, `CTWorkWidget`, `CTWorkShare` (chỉ `import Foundation`).
//
// · Lựa chọn (`CheDo`): theo máy (mặc định) · vi · en. App lưu ở UserDefaults chuẩn + chép ra App Group
//   (`ngon-ngu.json`, ghi bằng `NhomCTW.ghi` — đọc tệp KHÔNG phải API "required reason" nên widget/extension
//   không phải khai thêm UserDefaults trong PrivacyInfo).
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

    static var locale: Locale { Locale(identifier: ma == "vi" ? "vi_VN" : "en_US") }

    /// Ngôn ngữ của MÁY (danh sách toàn cục, không tính `AppleLanguages` riêng của app nếu app đã tự ghi).
    static func maTheoMay() -> String {
        // Miền TOÀN CỤC (danh sách của máy) — không đọc khoá riêng của app (app có thể đã tự ghi `["vi"]`).
        let ds = (UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String])
            ?? Locale.preferredLanguages
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
final class BundleNgonNguCTW: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let b = NgonNguCTW.bundle {
            let bang = (tableName?.isEmpty == false ? tableName : nil) ?? "Localizable"
            // Bảng có trong lproj đang chọn ⇒ tra ở ĐÓ, thiếu khoá thì trả chính khoá (chữ tiếng Anh gốc) —
            // KHÔNG rơi về `super`: bản gốc chọn ngôn ngữ theo lúc khởi động (vd máy tiếng Việt) nên sẽ lẫn.
            if b.path(forResource: bang, ofType: "strings") != nil || b.path(forResource: bang, ofType: "stringsdict") != nil {
                return b.localizedString(forKey: key, value: value, table: tableName)
            }
            // Ngôn ngữ NGUỒN (en): Xcode bỏ hẳn bảng trong en.lproj khi mọi chữ trùng khoá ⇒ bảng chỉ có ở vi.lproj.
            // Là bảng của app (vi.lproj có) ⇒ trả chính khoá, đừng để `super` chọn tiếng Việt theo máy.
            if NgonNguCTW.ma == "en",
               path(forResource: bang, ofType: "strings", inDirectory: nil, forLocalization: "vi") != nil
                || path(forResource: bang, ofType: "stringsdict", inDirectory: nil, forLocalization: "vi") != nil {
                if let value, !value.isEmpty { return value }
                return key
            }
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
