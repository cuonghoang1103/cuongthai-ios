import Foundation

// MARK: - CTWAPI — thẻ, bình luận, đính kèm, backlog, tìm kiếm (`work.routes.ts`)

extension CTWAPI {
    // MARK: Thẻ

    struct BoLoc {
        var assignee: [Int] = []
        var status: [Int] = []
        var type: [Int] = []
        var label: [Int] = []
        /// `backlog` | `open` | id sprint | nil = mọi sprint.
        var sprint: String?
        var q: String = ""
        var includeDone = false
    }

    static func dsThe(pid: Int, loc: BoLoc, cursor: String? = nil, limit: Int = 200) -> APIEndpoint {
        var q: [String: Any] = ["limit": limit, "includeDone": loc.includeDone ? "true" : "false"]
        func ds(_ a: [Int]) -> String { a.map(String.init).joined(separator: ",") }
        if !loc.assignee.isEmpty { q["assignee"] = ds(loc.assignee) }
        if !loc.status.isEmpty { q["status"] = ds(loc.status) }
        if !loc.type.isEmpty { q["type"] = ds(loc.type) }
        if !loc.label.isEmpty { q["label"] = ds(loc.label) }
        if let s = loc.sprint { q["sprint"] = s }
        let t = loc.q.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { q["q"] = String(t.prefix(200)) }
        if let cursor { q["cursor"] = cursor }
        return get("/projects/\(pid)/issues", q)
    }

    static func backlog(pid: Int) -> APIEndpoint { get("/projects/\(pid)/backlog") }
    static func lichSu(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/issues/\(so)/history") }
    static func theoDoi(pid: Int, so: Int, bat: Bool) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/watch", bat ? "PUT" : "DELETE")
    }
    static func timToanCuc(q: String, limit: Int = 30) -> APIEndpoint {
        get("/search", ["q": String(q.prefix(200)), "limit": limit])
    }

    // MARK: Bình luận

    static func suaBinhLuan(pid: Int, so: Int, cid: Int, chu: String) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/comments/\(cid)", "PATCH", ["bodyJson": CTWNode.docTuChu(chu)])
    }
    static func xoaBinhLuan(pid: Int, so: Int, cid: Int) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/comments/\(cid)", "DELETE")
    }

    // MARK: Đính kèm

    static func xinDuongTaiLen(pid: Int, so: Int, ten: String, kieu: String, coByte: Int) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/attachments/presign", "POST",
          ["fileName": String(ten.prefix(255)), "contentType": String(kieu.prefix(100)), "size": coByte])
    }
    static func xongTaiLen(pid: Int, so: Int, key: String, ten: String) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/attachments/complete", "POST", ["key": key, "fileName": String(ten.prefix(255))])
    }
    static func urlDinhKem(pid: Int, aid: Int, xemTrongApp: Bool) -> APIEndpoint {
        get("/projects/\(pid)/attachments/\(aid)/url", xemTrongApp ? ["inline": "1"] : nil)
    }
    static func xoaDinhKem(pid: Int, aid: Int) -> APIEndpoint { goi("/projects/\(pid)/attachments/\(aid)", "DELETE") }
}
