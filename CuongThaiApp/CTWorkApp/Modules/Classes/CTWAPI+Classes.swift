import Foundation

// MARK: - CTWAPI — Lớp học (`work.ctw5.routes.ts`, `work.ctw9a.routes.ts`, `work.ctw9b.routes.ts`)

extension CTWAPI {
    static func dsLop() -> APIEndpoint { get("/classes") }
    static func lop(_ id: Int) -> APIEndpoint { get("/classes/\(id)") }
    static func quyenGiangDay() -> APIEndpoint { get("/teaching/access") }
    static func tongQuanGiangDay(q: String) -> APIEndpoint {
        let s = q.trimmingCharacters(in: .whitespacesAndNewlines)
        return get("/teaching/overview", s.isEmpty ? nil : ["q": String(s.prefix(100))])
    }

    // Bài tập
    static func baiTapLop(_ id: Int) -> APIEndpoint { get("/classes/\(id)/assignments") }
    static func baiTap(_ id: Int, _ aid: Int) -> APIEndpoint { get("/classes/\(id)/assignments/\(aid)") }
    static func dsBaiNop(_ id: Int, _ aid: Int) -> APIEndpoint { get("/classes/\(id)/assignments/\(aid)/submissions") }
    /// Lưu NHÁP bài nộp (chữ + liên kết). Đã nộp thì phải rút lại trước (409 `WORK_CLASSWORK_TURNED_IN`).
    static func luuBaiNop(_ id: Int, _ aid: Int, chu: String, lienKet: [CTWLienKetNop]) -> APIEndpoint {
        goi("/classes/\(id)/assignments/\(aid)/my", "PUT", [
            "text": chu.isEmpty ? (NSNull() as Any) : (chu as Any),
            "links": lienKet.map { ["url": $0.url, "label": $0.label ?? ""] },
        ])
    }
    static func xoaTepNop(_ id: Int, _ aid: Int, fid: Int) -> APIEndpoint {
        goi("/classes/\(id)/assignments/\(aid)/my/files/\(fid)", "DELETE", nil)
    }
    static func nopBai(_ id: Int, _ aid: Int) -> APIEndpoint { goi("/classes/\(id)/assignments/\(aid)/my/turn-in", "POST") }
    static func rutBai(_ id: Int, _ aid: Int) -> APIEndpoint { goi("/classes/\(id)/assignments/\(aid)/my/unsubmit", "POST") }
    static func binhLuanRieng(_ id: Int, aid: Int, chu: String) -> APIEndpoint {
        goi("/classes/\(id)/submission-comments", "POST", ["assignmentId": aid, "body": String(chu.prefix(4000))])
    }
    static func urlTepLop(_ id: Int, fid: Int) -> APIEndpoint { get("/classes/\(id)/files/\(fid)") }

    // Bảng tin
    static func bangTinLop(_ id: Int, truoc: String?) -> APIEndpoint {
        var q: [String: Any] = ["limit": 30]
        if let truoc { q["before"] = truoc }
        return get("/classes/\(id)/stream", q)
    }
    static func binhLuanBangTin(_ id: Int, post: Int, chu: String) -> APIEndpoint {
        goi("/classes/\(id)/stream/\(post)/comments", "POST", ["body": String(chu.prefix(4000))])
    }
    static func xoaBinhLuanBangTin(_ id: Int, cid: Int) -> APIEndpoint { goi("/classes/\(id)/stream-comments/\(cid)", "DELETE", nil) }
    static func anBinhLuanBangTin(_ id: Int, cid: Int, an: Bool) -> APIEndpoint {
        goi("/classes/\(id)/stream-comments/\(cid)", "PATCH", ["hidden": an])
    }
}
