import SwiftUI

// ════════════════════════════════════════════════════════════════
// ĐỔI HTML SANG CHỮ CÓ ĐỊNH DẠNG
//
// Nội dung ngữ pháp và bài đọc do máy chủ trả về dạng HTML. Đo thật cả ba
// ngôn ngữ, TOÀN BỘ nội dung chỉ dùng ĐÚNG BỐN thẻ:
//   <p> ×302 · <strong> ×10 · <li> ×4 · <ul> ×2
//
// Vì thế không kéo thư viện, cũng không dùng `NSAttributedString(data:
// options: .html)` — cái đó phải chạy trên luồng chính, chậm thấy rõ khi
// cuộn danh sách, và nó lôi cả WebKit vào chỉ để in đậm mười chỗ.
// ════════════════════════════════════════════════════════════════

enum ChuHTML {
    /// Trả về các ĐOẠN, mỗi đoạn là chữ đã dựng sẵn định dạng.
    static func doan(_ html: String) -> [AttributedString] {
        guard !html.isEmpty else { return [] }
        var s = html

        // Danh sách: mỗi <li> thành một đoạn có dấu đầu dòng.
        s = s.replacingOccurrences(of: "<li>", with: "<p>•\u{00A0}")
        s = s.replacingOccurrences(of: "</li>", with: "</p>")
        for t in ["<ul>", "</ul>", "<ol>", "</ol>"] {
            s = s.replacingOccurrences(of: t, with: "")
        }
        s = s.replacingOccurrences(of: "<br>", with: "</p><p>")
        s = s.replacingOccurrences(of: "<br/>", with: "</p><p>")
        s = s.replacingOccurrences(of: "<br />", with: "</p><p>")

        let tho = s.components(separatedBy: "</p>")
        return tho.compactMap { khoi -> AttributedString? in
            let d = khoi.replacingOccurrences(of: "<p>", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !d.isEmpty else { return nil }
            return dungDoan(d)
        }
    }

    /// Gộp thành MỘT chuỗi, ngăn bằng dòng trống. Dùng cho chỗ chỉ cần một
    /// khối chữ (ví dụ ô xem trước).
    static func gop(_ html: String) -> AttributedString {
        var ra = AttributedString()
        for (i, d) in doan(html).enumerated() {
            if i > 0 { ra += AttributedString("\n\n") }
            ra += d
        }
        return ra
    }

    private static func dungDoan(_ chu: String) -> AttributedString {
        var ra = AttributedString()
        var con = chu

        while let mo = con.range(of: "<strong>") {
            let truoc = String(con[con.startIndex..<mo.lowerBound])
            if !truoc.isEmpty { ra += AttributedString(goThe(truoc)) }
            let sau = con[mo.upperBound...]
            if let dong = sau.range(of: "</strong>") {
                var dam = AttributedString(goThe(String(sau[sau.startIndex..<dong.lowerBound])))
                dam.font = .system(size: 15, weight: .semibold)
                ra += dam
                con = String(sau[dong.upperBound...])
            } else {
                // Thẻ mở không có thẻ đóng — lấy nốt phần còn lại chứ không
                // vứt đi. Nội dung do người nhập tay nên chuyện này xảy ra.
                ra += AttributedString(goThe(String(sau)))
                con = ""
            }
        }
        if !con.isEmpty { ra += AttributedString(goThe(con)) }
        return ra
    }

    /// Bỏ mọi thẻ còn sót và giải mã thực thể HTML.
    ///
    /// ⚠️ `&amp;` phải giải mã CUỐI CÙNG. Làm trước thì "&amp;lt;" biến thành
    /// "&lt;" rồi thành "<" — tức là chữ người ta cố ý viết ra lại thành thẻ.
    private static func goThe(_ s: String) -> String {
        var r = s.replacingOccurrences(of: "<[^>]+>", with: "",
                                       options: .regularExpression)
        for (a, b) in [("&nbsp;", "\u{00A0}"), ("&lt;", "<"), ("&gt;", ">"),
                       ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            r = r.replacingOccurrences(of: a, with: b)
        }
        return r
    }
}

/// Khối chữ HTML dựng sẵn.
struct ChuHTMLView: View {
    let html: String
    var co: CGFloat = 15
    var mau: Color = AppColors.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(ChuHTML.doan(html).enumerated()), id: \.offset) { _, d in
                Text(d)
                    .font(.system(size: co))
                    .foregroundColor(mau)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
