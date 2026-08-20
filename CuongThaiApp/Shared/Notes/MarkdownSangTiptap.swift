import Foundation

// ════════════════════════════════════════════════════════════════
// MARKDOWN → ProseMirror (contentJson) + HTML
//
// ⚠️ GHI VÀO NOTES PHẢI ĐẶT `contentJson`, KHÔNG chỉ `contentHtml`.
// Trình soạn của web nạp `note.contentJson`, nên nếu chỉ ghi HTML thì API trả
// 200, tìm kiếm thấy, mà người dùng mở ghi chú ra thấy **TRẮNG TINH**. Ghi CẢ
// HAI: JSON cho trình soạn, HTML cho tìm kiếm và bản xem chia sẻ.
//
// ⚠️ Chỉ được dùng node mà trình soạn thật sự bật: heading 1-3, paragraph,
// bulletList/orderedList/listItem, blockquote, codeBlock, horizontalRule; mark
// bold/italic/strike/code/link. Một `type` lạ bị ProseMirror **vứt lặng lẽ**;
// một node text **RỖNG** làm nó **NÉM** và cả ghi chú không mở được nữa.
//
// Cổng theo `desktop/src/main/agent/markdownTiptap.ts`.
// ════════════════════════════════════════════════════════════════

enum MarkdownSangTiptap {

    static func chuyen(_ md: String) -> (json: [String: Any], html: String) {
        let khoi = phanTich(md)
        let json: [String: Any] = [
            "type": "doc",
            // Tài liệu RỖNG không hợp lệ — phải có ít nhất một đoạn.
            "content": khoi.isEmpty ? [["type": "paragraph"]] : khoi.map(\.json),
        ]
        return (json, khoi.map(\.html).joined())
    }

    // MARK: Khối

    private struct Khoi { let json: [String: Any]; let html: String }

    private static func phanTich(_ md: String) -> [Khoi] {
        var ra: [Khoi] = []
        let dong = md.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var i = 0

        while i < dong.count {
            let d = dong[i]
            let cat = d.trimmingCharacters(in: .whitespaces)

            if cat.isEmpty { i += 1; continue }

            // ``` khối mã ```
            if cat.hasPrefix("```") {
                let ngonNgu = String(cat.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var than: [String] = []
                i += 1
                while i < dong.count, !dong[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    than.append(dong[i]); i += 1
                }
                if i < dong.count { i += 1 }
                let chu = than.joined(separator: "\n")
                var node: [String: Any] = ["type": "codeBlock"]
                if !ngonNgu.isEmpty { node["attrs"] = ["language": ngonNgu] }
                // Khối mã RỖNG thì bỏ hẳn `content` — node text rỗng làm
                // ProseMirror ném.
                if !chu.isEmpty { node["content"] = [["type": "text", "text": chu]] }
                ra.append(Khoi(json: node, html: "<pre><code>\(thoat(chu))</code></pre>"))
                continue
            }

            // --- đường kẻ ngang
            if cat.range(of: #"^(-{3,}|\*{3,}|_{3,})$"#, options: .regularExpression) != nil {
                ra.append(Khoi(json: ["type": "horizontalRule"], html: "<hr>"))
                i += 1; continue
            }

            // # tiêu đề (chỉ 1-3, trình soạn không bật mức sâu hơn)
            if let m = khop(cat, #"^(#{1,6})\s+(.*)$"#) {
                let muc = min(m[1].count, 3)
                let chu = m[2]
                ra.append(Khoi(json: ["type": "heading", "attrs": ["level": muc],
                                      "content": chuVoiDinhDang(chu).map(\.json)],
                               html: "<h\(muc)>\(chuVoiDinhDang(chu).map(\.html).joined())</h\(muc)>"))
                i += 1; continue
            }

            // > trích dẫn
            if cat.hasPrefix(">") {
                var than: [String] = []
                while i < dong.count, dong[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    than.append(dong[i].trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: #"^>\s?"#, with: "", options: .regularExpression))
                    i += 1
                }
                let doanCon = than.map { doan($0) }
                ra.append(Khoi(json: ["type": "blockquote", "content": doanCon.map(\.json)],
                               html: "<blockquote>\(doanCon.map(\.html).joined())</blockquote>"))
                continue
            }

            // - danh sách  /  1. danh sách đánh số
            if let loai = kieuDanhSach(cat) {
                var muc: [Khoi] = []
                while i < dong.count {
                    let c = dong[i].trimmingCharacters(in: .whitespaces)
                    guard let l2 = kieuDanhSach(c), l2 == loai,
                          let m = khop(c, loai == .cham ? #"^[-*+]\s+(.*)$"# : #"^\d+[.)]\s+(.*)$"#)
                    else { break }
                    let d2 = doan(m[1])
                    muc.append(Khoi(json: ["type": "listItem", "content": [d2.json]],
                                    html: "<li>\(d2.html)</li>"))
                    i += 1
                }
                let ten = loai == .cham ? "bulletList" : "orderedList"
                let the = loai == .cham ? "ul" : "ol"
                ra.append(Khoi(json: ["type": ten, "content": muc.map(\.json)],
                               html: "<\(the)>\(muc.map(\.html).joined())</\(the)>"))
                continue
            }

            // Đoạn thường — gộp các dòng liền nhau
            var than: [String] = []
            while i < dong.count {
                let c = dong[i].trimmingCharacters(in: .whitespaces)
                if c.isEmpty || c.hasPrefix("```") || c.hasPrefix(">") || c.hasPrefix("#")
                    || kieuDanhSach(c) != nil { break }
                than.append(c); i += 1
            }
            ra.append(doan(than.joined(separator: " ")))
        }
        return ra
    }

    private enum KieuDS { case cham, so }

    private static func kieuDanhSach(_ d: String) -> KieuDS? {
        if d.range(of: #"^[-*+]\s+"#, options: .regularExpression) != nil { return .cham }
        if d.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) != nil { return .so }
        return nil
    }

    private static func doan(_ chu: String) -> Khoi {
        let con = chuVoiDinhDang(chu)
        // Đoạn rỗng thì KHÔNG kèm `content` — mảng chứa node text rỗng là thứ
        // làm ProseMirror ném.
        if con.isEmpty { return Khoi(json: ["type": "paragraph"], html: "<p></p>") }
        return Khoi(json: ["type": "paragraph", "content": con.map(\.json)],
                    html: "<p>\(con.map(\.html).joined())</p>")
    }

    // MARK: Chữ trong dòng

    private struct Manh { let json: [String: Any]; let html: String }

    private static let mauDinhDang =
        #"(\*\*(.+?)\*\*)|(\*(.+?)\*)|(`(.+?)`)|(~~(.+?)~~)|(\[(.+?)\]\((.+?)\))"#

    private static func chuVoiDinhDang(_ dong: String) -> [Manh] {
        guard !dong.isEmpty else { return [] }
        var ra: [Manh] = []
        let ns = dong as NSString
        guard let re = try? NSRegularExpression(pattern: mauDinhDang) else {
            return [Manh(json: ["type": "text", "text": dong], html: thoat(dong))]
        }
        var cuoi = 0
        for m in re.matches(in: dong, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > cuoi {
                let t = ns.substring(with: NSRange(location: cuoi, length: m.range.location - cuoi))
                if !t.isEmpty { ra.append(Manh(json: ["type": "text", "text": t], html: thoat(t))) }
            }
            func nhom(_ i: Int) -> String? {
                guard m.range(at: i).location != NSNotFound else { return nil }
                return ns.substring(with: m.range(at: i))
            }
            if let t = nhom(2) {
                ra.append(Manh(json: ["type": "text", "text": t, "marks": [["type": "bold"]]],
                               html: "<strong>\(thoat(t))</strong>"))
            } else if let t = nhom(4) {
                ra.append(Manh(json: ["type": "text", "text": t, "marks": [["type": "italic"]]],
                               html: "<em>\(thoat(t))</em>"))
            } else if let t = nhom(6) {
                ra.append(Manh(json: ["type": "text", "text": t, "marks": [["type": "code"]]],
                               html: "<code>\(thoat(t))</code>"))
            } else if let t = nhom(8) {
                ra.append(Manh(json: ["type": "text", "text": t, "marks": [["type": "strike"]]],
                               html: "<s>\(thoat(t))</s>"))
            } else if let t = nhom(10), let u = nhom(11) {
                ra.append(Manh(json: ["type": "text", "text": t,
                                      "marks": [["type": "link", "attrs": ["href": u]]]],
                               html: "<a href=\"\(thoat(u))\">\(thoat(t))</a>"))
            }
            cuoi = m.range.location + m.range.length
        }
        if cuoi < ns.length {
            let t = ns.substring(from: cuoi)
            if !t.isEmpty { ra.append(Manh(json: ["type": "text", "text": t], html: thoat(t))) }
        }
        return ra
    }

    private static func khop(_ chu: String, _ mau: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: mau),
              let m = re.firstMatch(in: chu, range: NSRange(location: 0, length: (chu as NSString).length))
        else { return nil }
        let ns = chu as NSString
        return (0..<m.numberOfRanges).map {
            m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0))
        }
    }

    private static func thoat(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
