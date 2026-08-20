import Foundation

// ════════════════════════════════════════════════════════════════
// ProseMirror (contentJson) → Markdown
//
// Chiều ngược của `MarkdownSangTiptap`, để mở ghi chú CŨ ra sửa. Không có nó
// thì mở một ghi chú có sẵn rồi lưu là xoá sạch định dạng của nó.
//
// Node KHÔNG nhận ra (bảng, ảnh, trang cơ sở dữ liệu…) được giữ nguyên bằng
// một dòng giữ chỗ thay vì bỏ đi lặng lẽ — người dùng thấy được là ở đó có thứ
// app này chưa sửa được, và biết mà mở trên web.
// ════════════════════════════════════════════════════════════════

enum TiptapSangMarkdown {

    static func chuyen(_ doc: [String: Any]?) -> String {
        guard let doc, let con = doc["content"] as? [[String: Any]] else { return "" }
        return con.map(khoi).joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Nhận `[String: AnyCodable]` từ model rồi bóc về `[String: Any]`.
    static func chuyen(anyCodable: [String: AnyCodable]?) -> String {
        guard let anyCodable else { return "" }
        var tho: [String: Any] = [:]
        for (k, v) in anyCodable { tho[k] = boc(v.value) }
        return chuyen(tho)
    }

    private static func boc(_ v: Any) -> Any {
        if let a = v as? AnyCodable { return boc(a.value) }
        if let m = v as? [String: AnyCodable] { return m.mapValues { boc($0.value) } }
        if let m = v as? [String: Any] { return m.mapValues { boc($0) } }
        if let ds = v as? [AnyCodable] { return ds.map { boc($0.value) } }
        if let ds = v as? [Any] { return ds.map { boc($0) } }
        return v
    }

    private static func khoi(_ n: [String: Any]) -> String {
        let loai = n["type"] as? String ?? ""
        let con = n["content"] as? [[String: Any]] ?? []

        switch loai {
        case "heading":
            let muc = (n["attrs"] as? [String: Any])?["level"] as? Int ?? 1
            return String(repeating: "#", count: max(1, min(muc, 6))) + " " + chuTrongDong(con)
        case "paragraph":
            return chuTrongDong(con)
        case "bulletList":
            return con.map { "- " + chuTrongDong(khoiCon($0)) }.joined(separator: "\n")
        case "orderedList":
            return con.enumerated()
                .map { "\($0.offset + 1). " + chuTrongDong(khoiCon($0.element)) }
                .joined(separator: "\n")
        case "blockquote":
            return con.map(khoi).joined(separator: "\n")
                .components(separatedBy: "\n").map { "> " + $0 }.joined(separator: "\n")
        case "codeBlock":
            let ngonNgu = (n["attrs"] as? [String: Any])?["language"] as? String ?? ""
            return "```\(ngonNgu)\n\(chuThuan(con))\n```"
        case "horizontalRule":
            return "---"
        case "text":
            return chuTrongDong([n])
        default:
            // Giữ chỗ thay vì vứt: xem chú thích đầu file.
            return "> ⟦\(loai) — mở trên web để sửa phần này⟧"
        }
    }

    /// `listItem` bọc một `paragraph` bên trong; lấy ruột của nó.
    private static func khoiCon(_ n: [String: Any]) -> [[String: Any]] {
        let con = n["content"] as? [[String: Any]] ?? []
        if con.count == 1, let trong = con[0]["content"] as? [[String: Any]] { return trong }
        return con
    }

    private static func chuThuan(_ con: [[String: Any]]) -> String {
        con.compactMap { $0["text"] as? String }.joined()
    }

    private static func chuTrongDong(_ con: [[String: Any]]) -> String {
        con.map { n -> String in
            guard n["type"] as? String == "text" else { return khoi(n) }
            var t = n["text"] as? String ?? ""
            // Bọc từ TRONG ra NGOÀI: `**` phải nằm ngoài `*`, không thì
            // "***chữ***" bị đọc thành đậm-rỗng cộng chữ.
            for m in (n["marks"] as? [[String: Any]] ?? []) {
                switch m["type"] as? String {
                case "code":   t = "`\(t)`"
                case "italic": t = "*\(t)*"
                case "bold":   t = "**\(t)**"
                case "strike": t = "~~\(t)~~"
                case "link":
                    let href = (m["attrs"] as? [String: Any])?["href"] as? String ?? ""
                    t = "[\(t)](\(href))"
                default: break
                }
            }
            return t
        }.joined()
    }
}
