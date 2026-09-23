import Foundation

// Nằm ở `Models/` (chỉ Foundation) vì `AppNotification` dùng nó, mà app
// Admin cũng biên dịch `Shared/Models` — đặt trong `CTWork/` là Admin hỏng.

// MARK: - Đích mở từ thông báo / đường dẫn web

/// `/work/<ws>/<KEY>/issue/<n>` → đích mở trong app.
struct CTWDich: Equatable, Hashable {
    var slug: String
    var maDuAn: String?
    var so: Int?

    /// Đọc đường dẫn web của CT Work. Bỏ query (`?comment=12`) và dấu `#`.
    static func tuDuongDan(_ s: String?) -> CTWDich? {
        guard var s, !s.isEmpty else { return nil }
        if let r = s.range(of: "://"), let sau = s[r.upperBound...].firstIndex(of: "/") {
            s = String(s[sau...])     // bỏ scheme + host nếu có
        }
        if let q = s.firstIndex(where: { $0 == "?" || $0 == "#" }) { s = String(s[..<q]) }
        let p = s.split(separator: "/").map { String($0).removingPercentEncoding ?? String($0) }
        guard p.count >= 2, p[0] == "work" else { return nil }
        let slug = p[1]
        guard !slug.isEmpty else { return nil }
        var d = CTWDich(slug: slug)
        if p.count >= 3 { d.maDuAn = p[2] }
        if p.count >= 5, p[3] == "issue", let n = Int(p[4]) { d.so = n }
        return d
    }
}
