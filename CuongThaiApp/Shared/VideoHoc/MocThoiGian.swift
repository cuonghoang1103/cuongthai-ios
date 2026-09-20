#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// MỐC THỜI GIAN BẤM ĐƯỢC trong câu trả lời của AI
//
// Gia sư được dặn viết mốc dạng `[mm:ss]` hoặc `[1:26 - 2:18]`, lấy TỪ phụ
// đề. Ở đây tách chúng thành liên kết: chạm `[2:19]` là video nhảy tới
// giây 139.
//
// Đây là thứ làm "hỏi về video" khác hẳn một khung chat: câu trả lời không
// chỉ NÓI về video, nó ĐIỀU KHIỂN được video.
//
// ⚠️ Dùng `AttributedString` + sơ đồ URL riêng `tua://<giây>`, KHÔNG xếp
// `HStack` các ô. Xếp ô thì mỗi mốc thành một khối riêng và câu chữ bị ngắt
// dòng lung tung quanh nó; `AttributedString` giữ nguyên dòng chảy của chữ.
// ════════════════════════════════════════════════════════════════

enum MocThoiGian {

    static let SO_DO = "tua"

    /// `[1:26 - 2:18]` · `[12:40]` · cũng nhận `[1:02:30]`.
    private static let mau = try! NSRegularExpression(
        pattern: #"\[(\d{1,2}:\d{2}(?::\d{2})?)(?:\s*[-–—]\s*(\d{1,2}:\d{2}(?::\d{2})?))?\]"#)

    /// "2:19" → 139 · "1:02:30" → 3750.
    static func giay(_ s: String) -> Double? {
        let p = s.split(separator: ":").compactMap { Double($0) }
        switch p.count {
        case 2: return p[0] * 60 + p[1]
        case 3: return p[0] * 3600 + p[1] * 60 + p[2]
        default: return nil
        }
    }

    /// Giây lấy từ một URL `tua://139`.
    static func giayTuURL(_ u: URL) -> Double? {
        guard u.scheme == SO_DO else { return nil }
        let s = (u.host ?? "") + u.path.replacingOccurrences(of: "/", with: "")
        return Double(s)
    }

    static func coMoc(_ chu: String) -> Bool {
        mau.firstMatch(in: chu, range: NSRange(location: 0, length: (chu as NSString).length)) != nil
    }

    /// Thay mọi `[mm:ss]` bằng liên kết markdown `[mm:ss](tua://139)`.
    ///
    /// Làm ở mức CHUỖI trước khi dựng markdown, nên bộ dựng sẵn có tự lo
    /// phần còn lại — không phải viết một bộ dựng chữ thứ hai.
    static func themLienKet(_ chu: String) -> String {
        let ns = chu as NSString
        let khop = mau.matches(in: chu, range: NSRange(location: 0, length: ns.length))
        guard !khop.isEmpty else { return chu }

        var ra = ""
        var vt = 0
        for k in khop {
            if k.range.location > vt {
                ra += ns.substring(with: NSRange(location: vt, length: k.range.location - vt))
            }
            let dau = ns.substring(with: k.range(at: 1))
            let cuoi = k.range(at: 2).location != NSNotFound ? ns.substring(with: k.range(at: 2)) : nil
            let nhan = cuoi.map { "\(dau)–\($0)" } ?? dau
            if let g = giay(dau) {
                // Khoảng "1:26 - 2:18" nhảy tới ĐẦU khoảng: người học bấm để
                // XEM phần đó, nên phải bắt đầu từ chỗ nó bắt đầu.
                ra += "[\(nhan)](\(SO_DO)://\(Int(g)))"
            } else {
                ra += ns.substring(with: k.range)
            }
            vt = k.range.location + k.range.length
        }
        if vt < ns.length { ra += ns.substring(from: vt) }
        return ra
    }
}
#endif
