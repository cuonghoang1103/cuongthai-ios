import Foundation

// MARK: - CT Work — MÔ TẢ THẺ: TipTap JSON ⇄ Markdown (thuần, có kiểm thử `SuaTheCTWTests`)
//
// Máy chủ chỉ nhận `descriptionJson` (TipTap) ở PATCH thẻ — tuyến REST KHÔNG có
// `descriptionMarkdown` (chỉ công cụ MCP có). Nên app tự đổi hai chiều, ĐÚNG bộ nút
// mà trình soạn của web sinh ra (`RichEditor.tsx`, `docMarkdown.ts` ở máy chủ):
//   khối: paragraph · heading · bulletList/orderedList/listItem · taskList/taskItem ·
//         codeBlock · blockquote · horizontalRule · image · hardBreak
//   dấu:  bold · italic · strike · code · link
// Mô tả chứa thứ ngoài bộ đó (nhắc tên @, bảng, màu chữ, chú thích…) ⇒ KHÔNG cho sửa
// chữ trên máy (sửa sẽ làm mất chúng) — nói rõ lý do; ô việc vẫn tick được vì tick
// sửa thẳng JSON thô (`doiViec`), không đi qua markdown.

enum CTWMoTaThe {
    static let nutGiuDuoc: Set<String> = [
        "doc", "paragraph", "heading", "text", "bulletList", "orderedList", "listItem", "taskList", "taskItem",
        "codeBlock", "blockquote", "horizontalRule", "image", "hardBreak",
    ]
    static let dauGiuDuoc: Set<String> = ["bold", "italic", "strike", "code", "link"]

    // MARK: Kiểm tra sửa được

    /// `nil` = sửa trên máy an toàn; ngược lại là câu giải thích cho người dùng.
    static func lyDoKhongSua(_ doc: CTWJSON?) -> String? {
        guard let doc, !doc.laNull else { return nil }
        var lyDo: String?
        func di(_ n: CTWJSON) {
            guard lyDo == nil else { return }
            let kieu = n["type"]?.chuoi ?? ""
            if kieu == "mention" { lyDo = String(localized: "This description @mentions people. Editing it here would turn mentions into plain text."); return }
            if kieu == "table" { lyDo = String(localized: "This description has a table, which the mobile editor can't keep yet."); return }
            if !nutGiuDuoc.contains(kieu) { lyDo = String(localized: "This description contains content the mobile editor can't keep yet (\(kieu))."); return }
            for d in n["marks"]?.mang ?? [] {
                let t = d["type"]?.chuoi ?? ""
                if !dauGiuDuoc.contains(t) { lyDo = String(localized: "This description uses text formatting the mobile editor can't keep (\(t))."); return }
            }
            for c in n["content"]?.mang ?? [] { di(c) }
        }
        di(doc)
        return lyDo
    }

    static func trong(_ doc: CTWJSON?) -> Bool {
        guard let doc, !doc.laNull else { return true }
        var coChu = false
        func di(_ n: CTWJSON) {
            if coChu { return }
            if let t = n["text"]?.chuoi, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { coChu = true; return }
            if let k = n["type"]?.chuoi, ["image", "horizontalRule", "mention", "table", "taskItem"].contains(k) { coChu = true; return }
            n["content"]?.mang?.forEach(di)
        }
        di(doc)
        return !coChu
    }

    // MARK: Ô việc (checklist)

    /// Số ô việc tick được — cùng thứ tự với khối `.viec` cấp ngoài cùng của `CTWTipTap.khoi`
    /// (duyệt trước-sau, BỎ QUA trong blockquote và bảng vì ở đó không tick được).
    static func soViec(_ doc: CTWJSON?) -> Int {
        var n = 0
        func di(_ x: CTWJSON) {
            let k = x["type"]?.chuoi
            if k == "blockquote" || k == "table" { return }
            if k == "taskItem" { n += 1 }
            x["content"]?.mang?.forEach(di)
        }
        if let doc { di(doc) }
        return n
    }

    /// Đảo `checked` của ô việc thứ `chiSo` (0-based). Giữ nguyên MỌI thứ khác của tài liệu.
    static func doiViec(_ doc: CTWJSON, chiSo: Int) -> CTWJSON? {
        var dem = 0
        var daDoi = false
        func di(_ x: CTWJSON) -> CTWJSON {
            guard case .doiTuong(var o) = x else { return x }
            let k = o["type"]?.chuoi
            if k == "blockquote" || k == "table" { return x }
            if k == "taskItem" {
                if dem == chiSo {
                    var a = o["attrs"]?.doiTuong ?? [:]
                    a["checked"] = .bool(!(a["checked"]?.bool ?? false))
                    o["attrs"] = .doiTuong(a)
                    daDoi = true
                }
                dem += 1
            }
            if let con = o["content"]?.mang { o["content"] = .mang(con.map(di)) }
            return .doiTuong(o)
        }
        let kq = di(doc)
        return daDoi ? kq : nil
    }

    // MARK: TipTap → Markdown

    static func markdown(_ doc: CTWJSON?) -> String {
        guard let doc, !doc.laNull else { return "" }
        return khoi(doc["content"]?.mang ?? []).joined(separator: "\n\n")
    }

    private static func khoi(_ ds: [CTWJSON]) -> [String] { ds.compactMap(mdKhoi) }

    private static func mdKhoi(_ n: CTWJSON) -> String? {
        let k = n["type"]?.chuoi ?? ""
        let con = n["content"]?.mang ?? []
        switch k {
        case "paragraph": return dongChu(con)
        case "heading":
            let cap = max(1, min(6, Int(n["attrs"]?["level"]?.so ?? 2)))
            return String(repeating: "#", count: cap) + " " + dongChu(con)
        case "bulletList", "orderedList", "taskList":
            let batDau = Int(n["attrs"]?["start"]?.so ?? 1)
            return con.enumerated().map { i, muc in
                let dau: String
                if muc["type"]?.chuoi == "taskItem" || k == "taskList" {
                    dau = (muc["attrs"]?["checked"]?.bool ?? false) ? "- [x] " : "- [ ] "
                } else if k == "orderedList" {
                    dau = "\(batDau + i). "
                } else {
                    dau = "- "
                }
                let trongMuc = muc["content"]?.mang ?? []
                let dauTien = trongMuc.first?["type"]?.chuoi == "paragraph" ? dongChu(trongMuc.first?["content"]?.mang ?? []) : ""
                let conLai = trongMuc.first?["type"]?.chuoi == "paragraph" ? Array(trongMuc.dropFirst()) : trongMuc
                let thut = String(repeating: " ", count: k == "orderedList" ? dau.count : 2)
                var s = dau + dauTien
                for c in conLai {
                    guard let m = mdKhoi(c) else { continue }
                    s += "\n" + m.components(separatedBy: "\n").map { $0.isEmpty ? $0 : thut + $0 }.joined(separator: "\n")
                }
                return s
            }.joined(separator: "\n")
        case "codeBlock":
            let ngonNgu = n["attrs"]?["language"]?.chuoi ?? ""
            let chu = con.compactMap { $0["text"]?.chuoi }.joined()
            return "```\(ngonNgu)\n\(chu)\n```"
        case "blockquote":
            return khoi(con).joined(separator: "\n\n").components(separatedBy: "\n").map { $0.isEmpty ? ">" : "> " + $0 }.joined(separator: "\n")
        case "horizontalRule": return "---"
        case "image":
            let src = n["attrs"]?["src"]?.chuoi ?? ""
            let alt = n["attrs"]?["alt"]?.chuoi ?? ""
            return src.isEmpty ? nil : "![\(alt)](\(src))"
        default:
            let s = khoi(con).joined(separator: "\n\n")
            return s.isEmpty ? nil : s
        }
    }

    /// Chuỗi dấu của một nút chữ, xếp theo thứ tự bọc cố định (ngoài → trong).
    private static func dongChu(_ ds: [CTWJSON]) -> String {
        var out = ""
        for x in ds {
            switch x["type"]?.chuoi {
            case "hardBreak": out += "\\\n"
            case "text":
                let t = x["text"]?.chuoi ?? ""
                let dau = (x["marks"]?.mang ?? []).compactMap { $0["type"]?.chuoi }
                let href = (x["marks"]?.mang ?? []).first { $0["type"]?.chuoi == "link" }?["attrs"]?["href"]?.chuoi
                var s: String
                if dau.contains("code") {
                    s = "`" + t + "`"
                } else {
                    // Khoảng trắng đầu/cuối nằm NGOÀI dấu (`** a**` không còn là đậm trong markdown).
                    let dauTrang = String(t.prefix { $0 == " " })
                    let cuoiTrang = String(t.reversed().prefix { $0 == " " })
                    let loi = t.trimmingCharacters(in: .whitespaces)
                    var g = thoat(loi)
                    if !loi.isEmpty {
                        if dau.contains("strike") { g = "~~" + g + "~~" }
                        if dau.contains("italic") { g = "_" + g + "_" }
                        if dau.contains("bold") { g = "**" + g + "**" }
                    }
                    s = loi.isEmpty ? t : dauTrang + g + cuoiTrang
                }
                if let href { s = "[" + s + "](" + href + ")" }
                out += s
            default:
                out += dongChu(x["content"]?.mang ?? [])
            }
        }
        return out
    }

    /// Thoát ký tự có nghĩa trong markdown của chữ thường. CỐ Ý không thoát `_` và `[`:
    /// `user_id` / "[draft]" vẫn đọc ra đúng chữ nhờ luật biên từ của bộ đọc (đỡ rác `\_` khi sửa).
    private static func thoat(_ s: String) -> String {
        var o = ""
        for c in s {
            if c == "\\" || c == "*" || c == "`" { o.append("\\") }
            o.append(c)
        }
        // "~~" mới là gạch ngang — một dấu ~ giữ nguyên.
        return o.replacingOccurrences(of: "~~", with: "\\~\\~")
    }

    // MARK: Markdown → TipTap

    static func doc(_ md: String) -> CTWJSON {
        let dong = md.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var i = 0
        let khoi = docKhoi(dong, &i)
        return .doiTuong(["type": .chuoi("doc"), "content": .mang(khoi.isEmpty ? [.doiTuong(["type": .chuoi("paragraph")])] : khoi)])
    }

    private static func nut(_ type: String, attrs: [String: CTWJSON]? = nil, content: [CTWJSON]? = nil) -> CTWJSON {
        var o: [String: CTWJSON] = ["type": .chuoi(type)]
        if let attrs { o["attrs"] = .doiTuong(attrs) }
        if let content, !content.isEmpty { o["content"] = .mang(content) }
        return .doiTuong(o)
    }

    private struct DongMuc {
        var thut: Int
        var kieu: String     // bulletList | orderedList | taskList
        var so: Int
        var tick: Bool
        var chu: String
    }

    private static func docMuc(_ s: String) -> DongMuc? {
        let thut = s.prefix { $0 == " " }.count
        let r = s.dropFirst(thut)
        var conLai: Substring
        var kieu = "bulletList"
        var so = 1
        if let c = r.first, "-*+".contains(c), r.dropFirst().first == " " {
            conLai = r.dropFirst(2)
        } else {
            let soChu = r.prefix { $0.isNumber }
            guard !soChu.isEmpty, soChu.count <= 9 else { return nil }
            let sau = r.dropFirst(soChu.count)
            guard let d = sau.first, d == "." || d == ")", sau.dropFirst().first == " " else { return nil }
            kieu = "orderedList"; so = Int(soChu) ?? 1
            conLai = sau.dropFirst(2)
        }
        var tick = false
        if kieu == "bulletList", conLai.count >= 3, conLai.hasPrefix("["),
           let x = conLai.dropFirst().first, " xX".contains(x), conLai.dropFirst(2).first == "]",
           conLai.count == 3 || conLai.dropFirst(3).first == " " {
            kieu = "taskList"; tick = x != " "
            conLai = conLai.dropFirst(3)
            if conLai.first == " " { conLai = conLai.dropFirst() }
        }
        return DongMuc(thut: thut, kieu: kieu, so: so, tick: tick, chu: String(conLai))
    }

    private static func laKe(_ t: String) -> Bool {
        let g = t.replacingOccurrences(of: " ", with: "")
        guard g.count >= 3, let c = g.first, "-*_".contains(c) else { return false }
        return g.allSatisfy { $0 == c }
    }

    private static func docKhoi(_ dong: [String], _ i: inout Int) -> [CTWJSON] {
        var out: [CTWJSON] = []
        var doan: [String] = []
        func xaDoan() {
            guard !doan.isEmpty else { return }
            var con: [CTWJSON] = []
            for (j, d) in doan.enumerated() {
                var t = d
                let ngat = t.hasSuffix("\\") && j < doan.count - 1
                if ngat { t.removeLast() }
                con += chuNoi(t)
                if ngat { con.append(nut("hardBreak")) }
                else if j < doan.count - 1 { out.append(nut("paragraph", content: con)); con = [] }
            }
            out.append(nut("paragraph", content: con))
            doan = []
        }
        while i < dong.count {
            let d = dong[i]
            let t = d.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { xaDoan(); i += 1; continue }
            // Dòng trước kết thúc bằng "\" ⇒ dòng này là phần tiếp của cùng đoạn (hardBreak).
            if let truoc = doan.last, truoc.hasSuffix("\\") { doan.append(t); i += 1; continue }
            if t.hasPrefix("```") {
                xaDoan()
                let ngonNgu = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var ma: [String] = []
                i += 1
                while i < dong.count, !dong[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") { ma.append(dong[i]); i += 1 }
                i += 1
                let chu = ma.joined(separator: "\n")
                out.append(nut("codeBlock", attrs: ["language": ngonNgu.isEmpty ? .null : .chuoi(ngonNgu)],
                               content: chu.isEmpty ? nil : [.doiTuong(["type": .chuoi("text"), "text": .chuoi(chu)])]))
                continue
            }
            if laKe(t) { xaDoan(); out.append(nut("horizontalRule")); i += 1; continue }
            if t.hasPrefix("#") {
                let cap = t.prefix { $0 == "#" }.count
                if cap <= 6, t.dropFirst(cap).first == " " {
                    xaDoan()
                    out.append(nut("heading", attrs: ["level": .so(Double(cap))],
                                   content: chuNoi(String(t.dropFirst(cap + 1)).trimmingCharacters(in: .whitespaces))))
                    i += 1; continue
                }
            }
            if t.hasPrefix(">") {
                xaDoan()
                var trich: [String] = []
                while i < dong.count {
                    let x = dong[i].trimmingCharacters(in: .whitespaces)
                    guard x.hasPrefix(">") else { break }
                    var y = String(x.dropFirst())
                    if y.hasPrefix(" ") { y.removeFirst() }
                    trich.append(y); i += 1
                }
                var j = 0
                out.append(nut("blockquote", content: docKhoi(trich, &j)))
                continue
            }
            if t.hasPrefix("!["), t.hasSuffix(")"), let giua = t.range(of: "]("), !t.contains("\n") {
                xaDoan()
                let alt = String(t[t.index(t.startIndex, offsetBy: 2)..<giua.lowerBound])
                let src = String(t[giua.upperBound..<t.index(before: t.endIndex)])
                out.append(nut("image", attrs: ["src": .chuoi(src), "alt": alt.isEmpty ? .null : .chuoi(alt)]))
                i += 1; continue
            }
            if docMuc(d) != nil {
                xaDoan()
                out.append(contentsOf: docDanhSach(dong, &i))
                continue
            }
            doan.append(t)
            i += 1
        }
        xaDoan()
        return out
    }

    /// Một chuỗi dòng danh sách liên tiếp ⇒ một/nhiều danh sách (đổi kiểu cùng cấp ⇒ danh sách mới), lồng theo thụt lề.
    private static func docDanhSach(_ dong: [String], _ i: inout Int) -> [CTWJSON] {
        guard let dau = docMuc(dong[i]) else { return [] }
        return danhSach(dong, &i, thut: dau.thut)
    }

    private static func danhSach(_ dong: [String], _ i: inout Int, thut: Int) -> [CTWJSON] {
        var out: [CTWJSON] = []
        var kieu: String?
        var batDau = 1
        var muc: [CTWJSON] = []
        func xa() {
            guard let k = kieu, !muc.isEmpty else { return }
            out.append(nut(k, attrs: k == "orderedList" ? ["start": .so(Double(batDau))] : nil, content: muc))
            muc = []
        }
        while i < dong.count {
            guard let m = docMuc(dong[i]), m.thut >= thut else { break }
            if m.thut > thut {
                // Danh sách con của mục vừa rồi.
                let con = danhSach(dong, &i, thut: m.thut)
                if case .doiTuong(var o)? = muc.last {
                    o["content"] = .mang((o["content"]?.mang ?? []) + con)
                    muc[muc.count - 1] = .doiTuong(o)
                } else {
                    muc += con
                }
                continue
            }
            if m.kieu != kieu { xa(); kieu = m.kieu; batDau = m.so }
            let doan = nut("paragraph", content: chuNoi(m.chu.trimmingCharacters(in: .whitespaces)))
            if m.kieu == "taskList" {
                muc.append(nut("taskItem", attrs: ["checked": .bool(m.tick)], content: [doan]))
            } else {
                muc.append(nut("listItem", content: [doan]))
            }
            i += 1
        }
        xa()
        return out
    }

    // MARK: Chữ trong dòng → nút text có dấu

    static func chuNoi(_ s: String) -> [CTWJSON] {
        var out: [CTWJSON] = []
        docNoi(Array(s), dau: [], href: nil, ra: &out)
        // Gộp nút text liền nhau cùng dấu.
        var gop: [CTWJSON] = []
        for n in out {
            if case .doiTuong(var cuoi)? = gop.last, cuoi["type"]?.chuoi == "text", n["type"]?.chuoi == "text",
               cuoi["marks"] == n["marks"], let a = cuoi["text"]?.chuoi, let b = n["text"]?.chuoi {
                cuoi["text"] = .chuoi(a + b)
                gop[gop.count - 1] = .doiTuong(cuoi)
            } else {
                gop.append(n)
            }
        }
        return gop
    }

    private static func chu(_ t: String, dau: [String], href: String?) -> CTWJSON {
        var o: [String: CTWJSON] = ["type": .chuoi("text"), "text": .chuoi(t)]
        var ds: [CTWJSON] = dau.map { .doiTuong(["type": .chuoi($0)]) }
        if let href { ds.append(.doiTuong(["type": .chuoi("link"), "attrs": .doiTuong(["href": .chuoi(href)])])) }
        if !ds.isEmpty { o["marks"] = .mang(ds) }
        return .doiTuong(o)
    }

    private static func laDauCau(_ c: Character?) -> Bool {
        guard let c else { return true }
        return c.isWhitespace || c.isPunctuation || c.isSymbol
    }

    /// Tìm dấu đóng `ky` từ vị trí `tu` (bỏ qua ký tự đã thoát).
    private static func timDong(_ a: [Character], _ ky: [Character], tu: Int, bienTu: Bool) -> Int? {
        var j = tu
        while j + ky.count <= a.count {
            if a[j] == "\\" { j += 2; continue }
            if Array(a[j..<j + ky.count]) == ky, j > tu {
                let truoc = a[j - 1]
                let sau: Character? = j + ky.count < a.count ? a[j + ky.count] : nil
                if !truoc.isWhitespace && (!bienTu || laDauCau(sau)) { return j }
            }
            j += 1
        }
        return nil
    }

    private static func docNoi(_ a: [Character], dau: [String], href: String?, ra out: inout [CTWJSON]) {
        var dem = ""
        func xa() { if !dem.isEmpty { out.append(chu(dem, dau: dau, href: href)); dem = "" } }
        var i = 0
        while i < a.count {
            let c = a[i]
            let sau: Character? = i + 1 < a.count ? a[i + 1] : nil
            if c == "\\", let s = sau, s.isPunctuation || s.isSymbol { dem.append(s); i += 2; continue }
            if c == "`", let j = a[(i + 1)...].firstIndex(of: "`") {
                xa()
                out.append(chu(String(a[(i + 1)..<j]), dau: dau + ["code"], href: href))
                i = j + 1; continue
            }
            if c == "*", sau == "*", let j = timDong(a, ["*", "*"], tu: i + 2, bienTu: false),
               i + 2 < a.count, !a[i + 2].isWhitespace {
                xa(); docNoi(Array(a[(i + 2)..<j]), dau: dau + ["bold"], href: href, ra: &out); i = j + 2; continue
            }
            if c == "~", sau == "~", let j = timDong(a, ["~", "~"], tu: i + 2, bienTu: false),
               i + 2 < a.count, !a[i + 2].isWhitespace {
                xa(); docNoi(Array(a[(i + 2)..<j]), dau: dau + ["strike"], href: href, ra: &out); i = j + 2; continue
            }
            if c == "_" || c == "*", sau != c, let s = sau, !s.isWhitespace, laDauCau(i > 0 ? a[i - 1] : nil),
               let j = timDong(a, [c], tu: i + 1, bienTu: true) {
                xa(); docNoi(Array(a[(i + 1)..<j]), dau: dau + ["italic"], href: href, ra: &out); i = j + 1; continue
            }
            if c == "[", href == nil, let dong = timNgoacLink(a, tu: i) {
                xa()
                docNoi(Array(a[(i + 1)..<dong.chuHet]), dau: dau, href: dong.href, ra: &out)
                i = dong.ketThuc; continue
            }
            dem.append(c)
            i += 1
        }
        xa()
    }

    /// `[chữ](href)` bắt đầu ở `tu` ⇒ (vị trí `]`, href, vị trí sau `)`).
    private static func timNgoacLink(_ a: [Character], tu: Int) -> (chuHet: Int, href: String, ketThuc: Int)? {
        var sau = 0
        var j = tu + 1
        while j < a.count {
            if a[j] == "\\" { j += 2; continue }
            if a[j] == "[" { sau += 1 }
            if a[j] == "]" {
                if sau == 0 { break }
                sau -= 1
            }
            j += 1
        }
        guard j < a.count, j + 1 < a.count, a[j + 1] == "(", let dong = a[(j + 2)...].firstIndex(of: ")") else { return nil }
        let href = String(a[(j + 2)..<dong]).trimmingCharacters(in: .whitespaces)
        guard !href.isEmpty, !href.contains(" ") else { return nil }
        return (j, href, dong + 1)
    }
}
