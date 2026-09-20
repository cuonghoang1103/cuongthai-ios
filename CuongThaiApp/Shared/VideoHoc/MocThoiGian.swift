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
        /*
         * ⚠️ BỎ QUA KHỐI MÃ. Gia sư được dặn vẽ sơ đồ mermaid và hay kèm ví
         * dụ mã; một dòng `arr[1:23]` trong ví dụ Python trông y hệt một mốc
         * thời gian, và biến nó thành nút tua là sửa mã của người ta ngay
         * giữa bài giảng. Đếm hàng rào ``` và dấu nháy đơn để biết đang ở
         * trong hay ngoài. (Bản web làm y hệt — xem `mocThoiGian.ts`.)
         */
        if chu.contains("```") || chu.contains("`") {
            var trongKhoi = false
            let dong = chu.components(separatedBy: "\n").map { d -> String in
                let cat = d.trimmingCharacters(in: .whitespaces)
                if cat.hasPrefix("```") || cat.hasPrefix("~~~") { trongKhoi.toggle(); return d }
                if trongKhoi { return d }
                // Phần tử CHẴN nằm ngoài mã, LẺ nằm trong.
                return d.components(separatedBy: "`").enumerated()
                    .map { $0.offset % 2 == 1 ? $0.element : thayTrenMotDoan($0.element) }
                    .joined(separator: "`")
            }
            return dong.joined(separator: "\n")
        }
        return thayTrenMotDoan(chu)
    }

    /// Thay mốc trên một đoạn chữ ĐÃ CHẮC CHẮN nằm ngoài mã.
    private static func thayTrenMotDoan(_ chu: String) -> String {
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

    // ════════════════════════════════════════════════════════════
    // MỤC LỤC VIDEO — bóc các phần từ câu TÓM TẮT của gia sư
    // ════════════════════════════════════════════════════════════

    struct Phan: Identifiable, Hashable {
        let tu: Double
        let den: Double?
        let ten: String
        let y: String
        var id: String { "\(tu)-\(ten.prefix(16))" }
        var moc: String {
            let n = Int(tu)
            return n >= 3600
                ? String(format: "%d:%02d:%02d", n / 3600, (n % 3600) / 60, n % 60)
                : String(format: "%d:%02d", n / 60, n % 60)
        }
    }

    /// Mốc phải ở ĐẦU dòng, cho phép `-`/`*`/số thứ tự/`**` phía trước.
    ///
    /// ⚠️ Nhận mốc ở GIỮA câu thì mọi câu văn có trích dẫn `[2:19]` cũng
    /// thành một "phần", và mục lục dài gấp mấy lần nội dung thật.
    private static let mauPhan = try! NSRegularExpression(
        pattern: #"^\s*(?:[-*+]\s*)?(?:\d+[.)]\s*)?\**\s*\[(\d{1,2}:\d{2}(?::\d{2})?)(?:\s*[-–—]\s*(\d{1,2}:\d{2}(?::\d{2})?))?\]\s*(.*)$"#)

    /// Bản song sinh của `bocPhan()` trong `mocThoiGian.ts` (web) — sửa một
    /// bên thì soi lại bên kia. Đã kiểm 20 phép thử bên web.
    static func bocPhan(_ chu: String) -> [Phan] {
        var ra: [Phan] = []
        var daThay = Set<Double>()
        var trongKhoiMa = false

        for dong in chu.components(separatedBy: "\n") {
            let cat = dong.trimmingCharacters(in: .whitespaces)
            if cat.hasPrefix("```") || cat.hasPrefix("~~~") { trongKhoiMa.toggle(); continue }
            if trongKhoiMa { continue }

            let ns = dong as NSString
            guard let k = mauPhan.firstMatch(in: dong, range: NSRange(location: 0, length: ns.length)),
                  let tu = giay(ns.substring(with: k.range(at: 1))) else { continue }
            if daThay.contains(tu) { continue }   // model hay nhắc lại danh sách ở cuối

            let den = k.range(at: 2).location != NSNotFound ? giay(ns.substring(with: k.range(at: 2))) : nil
            let con = (k.range(at: 3).location != NSNotFound ? ns.substring(with: k.range(at: 3)) : "")
                .trimmingCharacters(in: .whitespaces)

            // `**Tên** — mô tả` · `Tên: mô tả` · chỉ có tên
            var ten = con, y = ""
            if let cat2 = try? NSRegularExpression(pattern: #"^\**\s*(.+?)\s*\**\s*(?:[—–]|\s-\s|:)\s*(.+)$"#),
               let m = cat2.firstMatch(in: con, range: NSRange(location: 0, length: (con as NSString).length)) {
                let nsc = con as NSString
                ten = nsc.substring(with: m.range(at: 1))
                y = nsc.substring(with: m.range(at: 2))
            }
            ten = ten.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
            y = y.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
            if ten.isEmpty && y.isEmpty { continue }

            daThay.insert(tu)
            ra.append(Phan(tu: tu, den: den, ten: ten.isEmpty ? "—" : ten, y: y))
        }
        return ra
    }
}
#endif
