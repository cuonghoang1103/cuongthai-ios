import Foundation

// MARK: - JQL phía app — gợi ý khi gõ, bọc nháy, ORDER BY (21/10/2026)
//
// Port `frontend/src/components/work/search/jql.ts` (suggest/quote) + `search/columns.tsx` (jqlOrder/withOrder).
// Danh sách trường/hàm phải khớp backend `src/services/work/jql.ts` — đổi bên kia thì đổi ở đây (và ở web).
// ⛔ Giá trị gợi ý là TÊN GỐC (trạng thái "To Do", loại "Story"…) — JQL tìm theo tên gốc, không theo bản dịch.
// Gợi ý (nhãn trường) là cú pháp JQL ⇒ không dịch; chỉ phần mô tả (`goiY`) là chữ cho người đọc.

enum CTWJql {
    struct GoiY: Hashable, Identifiable {
        var nhan: String
        var chen: String
        /// Mô tả ngắn (đã dịch) — nil nếu không có.
        var moTa: String?
        var id: String { nhan + "|" + chen }
    }

    /// Dữ liệu dự án để gợi ý giá trị.
    struct NguCanh {
        var trangThai: [String] = []
        var loai: [String] = []
        var nhan: [String] = []
        var sprint: [String] = []
        /// (username, tên hiển thị, là agent)
        var nguoi: [(String, String?, Bool)] = []
        var maDuAn: [String] = []

        init() {}
        init(cfg: CTWProjectConfig) {
            var thay = Set<String>()
            trangThai = cfg.tatCaTrangThai.map(\.name).filter { thay.insert($0).inserted }
            loai = cfg.dsLoai.map(\.name)
            nhan = (cfg.labels ?? []).map(\.name)
            sprint = (cfg.sprints ?? []).map(\.name)
            nguoi = cfg.dsThanhVien.compactMap { u in u.username.map { ($0, u.displayName ?? u.fullName, u.laAgent) } }
            maDuAn = [cfg.key]
        }
    }

    static let truong: [String] = [
        "project", "status", "statusCategory", "assignee", "reporter", "type", "priority", "labels", "component", "sprint",
        "parent", "points", "summary", "description", "text", "comment", "key", "created", "updated", "due", "resolved",
        "watcher", "fixVersion", "flagged", "assigneeKind",
    ]

    /// Trường sắp xếp được (`ORDERABLE` của web).
    static let sapXepDuoc = ["key", "rank", "priority", "created", "updated", "due", "resolved", "points", "summary", "status", "assignee"]

    static func moTaTruong(_ t: String) -> String? {
        switch t {
        case "project": return String(localized: "Project key")
        case "status": return String(localized: "Status name")
        case "statusCategory": return String(localized: "To Do · In Progress · Done")
        case "assignee": return String(localized: "Username, currentUser() or EMPTY")
        case "reporter", "watcher": return String(localized: "Username or currentUser()")
        case "type": return String(localized: "Issue type")
        case "priority": return String(localized: "Highest … Lowest")
        case "labels": return String(localized: "Label name")
        case "component": return String(localized: "Component name")
        case "sprint": return String(localized: "Sprint name or openSprints()")
        case "parent": return String(localized: "Parent issue key")
        case "points": return String(localized: "Story points")
        case "summary": return String(localized: "Title contains (~)")
        case "description": return String(localized: "Description contains (~)")
        case "text": return String(localized: "Title, description or comments")
        case "comment": return String(localized: "Comment contains (~)")
        case "key": return String(localized: "Issue key")
        case "created", "updated", "due", "resolved": return String(localized: "Date: 2026-09-01, -7d, startOfWeek()")
        case "fixVersion": return String(localized: "Release")
        case "flagged": return String(localized: "true / false")
        case "assigneeKind": return String(localized: "AGENT or HUMAN")
        default: return nil
        }
    }

    /// Tên có khoảng trắng/ký tự lạ ⇒ bọc nháy (cùng regex với web).
    static func boc(_ v: String) -> String {
        let hopLe = v.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) || "_-.:/@".unicodeScalars.contains($0) }
        if hopLe && !v.isEmpty { return v }
        return "\"" + v.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    // MARK: ORDER BY

    static func thuTu(_ jql: String) -> (goc: String, truong: String?, giam: Bool) {
        guard let re = try? NSRegularExpression(pattern: #"\s*\bORDER\s+BY\s+("?)([\w.]+)\1(?:\s+(ASC|DESC))?[\s\S]*$"#, options: [.caseInsensitive]),
              let m = re.firstMatch(in: jql, range: NSRange(jql.startIndex..., in: jql)),
              let r = Range(m.range, in: jql), let rt = Range(m.range(at: 2), in: jql) else {
            return (jql.trimmingCharacters(in: .whitespaces), nil, false)
        }
        let huong = Range(m.range(at: 3), in: jql).map { jql[$0].uppercased() } ?? "ASC"
        return (String(jql[..<r.lowerBound]).trimmingCharacters(in: .whitespaces), jql[rt].lowercased(), huong == "DESC")
    }

    static func voiThuTu(_ jql: String, truong: String, giam: Bool) -> String {
        let g = thuTu(jql).goc
        return (g.isEmpty ? "" : g + " ") + "ORDER BY \(truong) \(giam ? "DESC" : "ASC")"
    }

    // MARK: Gợi ý khi gõ

    private enum Loai { case tu, chuoi, toanTu, moNgoac, dongNgoac, phay }
    private struct Tok { var loai: Loai; var giaTri: String }

    private static let kyTuTu = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: "_-.:/+@"))

    private static func tach(_ src: String) -> [Tok] {
        var out: [Tok] = []
        let c = Array(src)
        var i = 0
        while i < c.count {
            let ch = c[i]
            if ch.isWhitespace { i += 1; continue }
            if ch == "\"" || ch == "'" {
                var j = i + 1
                var s = ""
                while j < c.count && c[j] != ch { if c[j] == "\\" && j + 1 < c.count { j += 1 }; s.append(c[j]); j += 1 }
                out.append(Tok(loai: .chuoi, giaTri: s)); i = min(j + 1, c.count); continue
            }
            let hai = i + 1 < c.count ? String([ch, c[i + 1]]) : ""
            if ["!~", "!=", ">=", "<="].contains(hai) { out.append(Tok(loai: .toanTu, giaTri: hai)); i += 2; continue }
            if "=><~".contains(ch) { out.append(Tok(loai: .toanTu, giaTri: String(ch))); i += 1; continue }
            if ch == "(" { out.append(Tok(loai: .moNgoac, giaTri: "(")); i += 1; continue }
            if ch == ")" { out.append(Tok(loai: .dongNgoac, giaTri: ")")); i += 1; continue }
            if ch == "," { out.append(Tok(loai: .phay, giaTri: ",")); i += 1; continue }
            var j = i
            var w = ""
            while j < c.count, c[j].unicodeScalars.allSatisfy({ kyTuTu.contains($0) }) { w.append(c[j]); j += 1 }
            if w.isEmpty { break }
            out.append(Tok(loai: .tu, giaTri: w)); i = j
        }
        return out
    }

    static func giaTri(truong: String, _ nc: NguCanh) -> [GoiY] {
        func lit(_ xs: [String]) -> [GoiY] {
            var thay = Set<String>()
            return xs.filter { thay.insert($0).inserted }.map { GoiY(nhan: $0, chen: boc($0)) }
        }
        let ham = String(localized: "function")
        func fn(_ xs: [String]) -> [GoiY] { xs.map { GoiY(nhan: $0, chen: $0, moTa: ham) } }
        switch truong.lowercased() {
        case "project": return lit(nc.maDuAn)
        case "status": return lit(nc.trangThai)
        case "statuscategory", "category": return lit(["To Do", "In Progress", "Done"])
        case "type", "issuetype": return lit(nc.loai)
        case "priority": return lit(["Highest", "High", "Medium", "Low", "Lowest"])
        case "assignee", "reporter", "watcher", "watchers":
            let f = truong.lowercased()
            var ds = fn(["currentUser()"] + (f == "assignee" || f == "reporter" ? ["agents()", "people()"] : []))
            if f == "assignee" { ds.append(GoiY(nhan: "EMPTY", chen: "EMPTY")) }
            ds += nc.nguoi.map { u, ten, agent in GoiY(nhan: u, chen: boc(u), moTa: agent ? String(localized: "AI agent · \(ten ?? u)") : ten) }
            return ds
        case "assigneekind": return lit(["AGENT", "HUMAN"]) + [GoiY(nhan: "EMPTY", chen: "EMPTY")]
        case "labels", "label": return lit(nc.nhan)
        case "sprint": return fn(["openSprints()", "closedSprints()", "futureSprints()"]) + lit(nc.sprint)
        case "fixversion", "fixversions", "version", "release": return fn(["unreleasedVersions()", "releasedVersions()"]) + [GoiY(nhan: "EMPTY", chen: "EMPTY")]
        case "flagged", "flag", "blocked": return lit(["true", "false"])
        case "created", "updated", "due", "duedate", "resolved":
            return lit(["-1d", "-7d", "-30d"]) + fn(["now()", "startOfDay()", "startOfWeek()", "startOfMonth()", "endOfWeek()", "endOfMonth()"])
        default: return []
        }
    }

    /// Gợi ý cho vị trí con trỏ (`caret` = số ký tự). `tu` = vị trí bắt đầu từ đang gõ (thay đoạn [tu, caret) bằng `chen`).
    static func goiY(_ text: String, caret: Int, _ nc: NguCanh) -> (tu: Int, ds: [GoiY]) {
        let c = Array(text)
        let k = max(0, min(caret, c.count))
        let truoc = String(c[..<k])
        // Đang trong chuỗi nháy ⇒ không gợi ý.
        if truoc.filter({ $0 == "\"" }).count % 2 == 1 { return (k, []) }
        var dau = k
        while dau > 0, c[dau - 1].unicodeScalars.allSatisfy({ kyTuTu.contains($0) }) { dau -= 1 }
        let dangGo = String(c[dau..<k])
        let toks = tach(String(c[..<dau]))
        let cuoi = toks.last
        let keCuoi = toks.count >= 2 ? toks[toks.count - 2] : nil
        func la(_ t: Tok?, _ kw: String...) -> Bool { t?.loai == .tu && kw.contains(t!.giaTri.uppercased()) }

        let tatCaTruong: [GoiY] = truong.map { GoiY(nhan: $0, chen: $0, moTa: moTaTruong($0)) }
            + [GoiY(nhan: "ORDER BY", chen: "ORDER BY", moTa: String(localized: "Sort results")),
               GoiY(nhan: "NOT", chen: "NOT", moTa: String(localized: "Negate"))]

        var ds: [GoiY] = []
        var dauTruong = cuoi == nil || la(cuoi, "AND", "OR", "NOT") || cuoi?.loai == .moNgoac
        if cuoi?.loai == .moNgoac && la(keCuoi, "IN") { dauTruong = false }
        let coBy = toks.contains { la($0, "BY") }

        if la(cuoi, "ORDER") {
            ds = [GoiY(nhan: "BY", chen: "BY")]
        } else if la(cuoi, "BY") || (cuoi?.loai == .phay && coBy) {
            ds = sapXepDuoc.map { GoiY(nhan: $0, chen: $0) }
        } else if coBy, cuoi?.loai == .tu, !la(cuoi, "ASC", "DESC") {
            ds = [GoiY(nhan: "ASC", chen: "ASC"), GoiY(nhan: "DESC", chen: "DESC")]
        } else if dauTruong {
            ds = tatCaTruong
        } else if la(cuoi, "IS") {
            ds = [GoiY(nhan: "EMPTY", chen: "EMPTY"), GoiY(nhan: "NOT EMPTY", chen: "NOT EMPTY")]
        } else if let cuoi, cuoi.loai == .toanTu || (cuoi.loai == .moNgoac && la(keCuoi, "IN")) || cuoi.loai == .phay {
            var i = toks.count - 1
            if cuoi.loai != .toanTu {
                while i >= 0 && !la(toks[i], "IN") { i -= 1 }
                i -= 1
                if i >= 0 && la(toks[i], "NOT") { i -= 1 }
            } else { i -= 1 }
            if i >= 0, toks[i].loai == .tu || toks[i].loai == .chuoi { ds = giaTri(truong: toks[i].giaTri, nc) }
        } else if let cuoi, cuoi.loai == .tu || cuoi.loai == .chuoi, keCuoi == nil || la(keCuoi, "AND", "OR", "NOT") || keCuoi?.loai == .moNgoac {
            ds = ["=", "!=", "IN", "NOT IN", "~", "IS EMPTY", "IS NOT EMPTY", ">=", "<=", ">", "<", "!~"].map { GoiY(nhan: $0, chen: $0) }
        } else if let cuoi, cuoi.loai == .tu || cuoi.loai == .chuoi || cuoi.loai == .dongNgoac {
            ds = ["AND", "OR", "ORDER BY"].map { GoiY(nhan: $0, chen: $0) }
        }

        let p = dangGo.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        if !p.isEmpty {
            ds = ds.filter { $0.nhan.lowercased().contains(p) }
                .sorted { ($0.nhan.lowercased().hasPrefix(p) ? 0 : 1) < ($1.nhan.lowercased().hasPrefix(p) ? 0 : 1) }
            if ds.count == 1 && ds[0].nhan.lowercased() == p { ds = [] }
        }
        return (dau, Array(ds.prefix(10)))
    }

    /// Chấp nhận một gợi ý: thay đoạn [tu, caret) rồi thêm khoảng trắng nếu sau đó chưa có. Trả (chuỗi mới, con trỏ mới).
    static func chapNhan(_ g: GoiY, text: String, tu: Int, caret: Int) -> (String, Int) {
        let c = Array(text)
        let k = max(0, min(caret, c.count))
        let sau = String(c[k...])
        let canCach = !sau.hasPrefix(" ")
        let moi = String(c[..<tu]) + g.chen + (canCach ? " " : "") + sau
        return (moi, tu + g.chen.count + 1)
    }
}
