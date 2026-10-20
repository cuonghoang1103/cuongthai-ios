import Foundation

// MARK: - Locale HIỂN THỊ của phần CT Work (ngày giờ, số) — 20/10/2026
//
// Tệp này nằm trong `Shared/CTWork` nên CẢ app chính lẫn app CT Work biên dịch.
// · App CT Work: `NgonNguCTW` (CTWorkShared/NgonNguCTW.swift) đặt `CTWDinhDang.locale` lúc mở + mỗi lần đổi ngôn ngữ.
// · App chính: không ai đặt ⇒ giữ `en_US` như trước (phần CT Work trong app chính vẫn là chữ tiếng Anh).
//
// ⚠️ CHỈ để HIỂN THỊ. Đọc/ghi ngày của máy chủ vẫn dùng `en_US_POSIX` + `yyyy-MM-dd`/ISO 8601 (đổi locale ở đó
// là đọc sai ngày trên máy để lịch Phật lịch/12 giờ).

enum CTWDinhDang {
    /// Locale hiển thị. `en_US` hoặc `vi_VN`.
    static var locale = Locale(identifier: "en_US")

    static var laTiengViet: Bool { locale.identifier.hasPrefix("vi") }

    /// DateFormatter hiển thị theo MẪU (template) — mỗi ngôn ngữ tự sắp thứ tự:
    /// "MMMd" ⇒ "Oct 5" / "5 thg 10"; "yMMMd" ⇒ "Oct 5, 2026" / "5 thg 10, 2026"; "EEEEMMMd" ⇒ "Monday, Oct 5" / "Thứ Hai, 5 thg 10".
    static func mau(_ template: String, muiGio: TimeZone? = nil) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = Calendar(identifier: .gregorian)
        if let muiGio { f.timeZone = muiGio }
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }

    /// Giờ:phút 24 giờ ("14:05") — dùng chung cho mọi ngôn ngữ của app.
    static func gio(_ d: Date, muiGio: TimeZone? = nil) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        if let muiGio { f.timeZone = muiGio }
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    /// "2 hours ago" / "2 giờ trước", "in 3 days" / "sau 3 ngày".
    static func tuongDoi(_ d: Date, so voi: Date = Date(), kieu: RelativeDateTimeFormatter.UnitsStyle = .full) -> String {
        let r = RelativeDateTimeFormatter()
        r.locale = locale
        r.unitsStyle = kieu
        return r.localizedString(for: d, relativeTo: voi)
    }

    /// Số có phân cách hàng nghìn theo ngôn ngữ ("1,250" / "1.250").
    static func so(_ n: Int) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
}
