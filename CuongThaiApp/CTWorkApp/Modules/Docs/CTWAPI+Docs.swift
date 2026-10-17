import Foundation

// MARK: - CTWAPI — tài liệu dự án (`work.routes.ts` /pages, `pages.service.ts`,
// `work.ctwk3b.routes.ts` collab, `work.docs3a.routes.ts` ảnh, `work.s5c.routes.ts` thùng rác,
// `work.ctw7b.routes.ts` KB). Trang đánh số theo `number` của dự án, KHÔNG theo `id`.

extension CTWAPI {
    // MARK: Đọc

    static func dsTrang(pid: Int) -> APIEndpoint { get("/projects/\(pid)/pages") }
    static func trang(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/pages/\(so)") }
    static func trangMarkdown(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/pages/\(so)/markdown") }
    static func timTrang(pid: Int, q: String) -> APIEndpoint {
        get("/projects/\(pid)/pages/search", ["q": String(q.prefix(200)), "limit": 30])
    }

    // MARK: Ghi
    //
    // Thân `.strict()` ở máy chủ: thêm trường lạ là 400 ⇒ chỉ gửi đúng các khoá dưới.
    // Nội dung gửi dạng `markdown` (máy chủ tự đổi sang TipTap bằng `markdownToTiptap`
    // — cùng bộ đổi của nút Import trên web), không tự dựng TipTap ở máy.

    static func taoTrang(pid: Int, tieuDe: String, trangCha: Int?, markdown: String?) -> APIEndpoint {
        var t: [String: Any] = ["title": tieuDe]
        if let trangCha { t["parentNumber"] = trangCha }
        if let markdown, !markdown.isEmpty { t["markdown"] = markdown }
        return goi("/projects/\(pid)/pages", "POST", t)
    }

    /// PATCH có `version` ⇒ máy chủ chỉ ghi khi phiên bản khớp (409 `WORK_PAGE_CONFLICT` nếu lệch).
    static func suaTrang(pid: Int, so: Int, phienBan: Int?, tieuDe: String? = nil, markdown: String? = nil,
                         trangThai: String? = nil) -> APIEndpoint {
        var t: [String: Any] = [:]
        if let phienBan { t["version"] = phienBan }
        if let tieuDe { t["title"] = tieuDe }
        if let markdown { t["markdown"] = markdown }
        if let trangThai { t["status"] = trangThai }
        return goi("/projects/\(pid)/pages/\(so)", "PATCH", t)
    }

    static func chuyenTrang(pid: Int, so: Int, trangCha: Int?) -> APIEndpoint {
        goi("/projects/\(pid)/pages/\(so)/move", "POST", ["parentNumber": trangCha.map { $0 as Any } ?? NSNull(), "index": 0])
    }
    static func xoaTrang(pid: Int, so: Int) -> APIEndpoint { goi("/projects/\(pid)/pages/\(so)", "DELETE", nil) }

    /// Ghi trạng thái Yjs đang sống xuống CSDL (được phép cả khi đang khoá sửa) —
    /// gọi TRƯỚC khi so phiên bản, để "phiên bản trong CSDL" là phiên bản thật.
    static func xaCollab(pid: Int, so: Int) -> APIEndpoint { goi("/projects/\(pid)/pages/\(so)/collab/flush", "POST") }

    // MARK: Khoá sửa cá nhân (theo người + dự án)

    static func khoaSua(pid: Int) -> APIEndpoint { get("/projects/\(pid)/edit-lock") }
    static func moKhoaSua(pid: Int) -> APIEndpoint { goi("/projects/\(pid)/edit-lock", "PUT", ["locked": false]) }

    // MARK: Phiên bản

    static func phienBanTrang(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/pages/\(so)/versions") }
    static func motPhienBan(pid: Int, so: Int, n: Int) -> APIEndpoint { get("/projects/\(pid)/pages/\(so)/versions/\(n)") }
    static func soPhienBan(pid: Int, so: Int, tu: Int) -> APIEndpoint {
        get("/projects/\(pid)/pages/\(so)/versions/compare", ["from": tu, "to": "current"])
    }
    static func khoiPhucPhienBan(pid: Int, so: Int, n: Int) -> APIEndpoint {
        goi("/projects/\(pid)/pages/\(so)/versions/\(n)/restore", "POST")
    }

    // MARK: Bình luận trang

    static func binhLuanTrang(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/pages/\(so)/comments") }
    static func guiBinhLuanTrang(pid: Int, so: Int, chu: String) -> APIEndpoint {
        goi("/projects/\(pid)/pages/\(so)/comments", "POST", ["bodyJson": CTWNode.docTuChu(chu)])
    }
    static func xoaBinhLuanTrang(pid: Int, so: Int, cid: Int) -> APIEndpoint {
        goi("/projects/\(pid)/pages/\(so)/comments/\(cid)", "DELETE", nil)
    }

    // MARK: Thẻ liên kết với trang

    static func ganTheVaoTrang(pid: Int, so: Int, the: Int) -> APIEndpoint {
        goi("/projects/\(pid)/pages/\(so)/issues", "POST", ["issueNumber": the])
    }
    static func goTheKhoiTrang(pid: Int, so: Int, the: Int) -> APIEndpoint {
        goi("/projects/\(pid)/pages/\(so)/issues/\(the)", "DELETE", nil)
    }

    // MARK: Phê duyệt trang

    static func xinDuyetTrang(pid: Int, so: Int, nguoiDuyet: [Int], tuanTu: Bool) -> APIEndpoint {
        goi("/projects/\(pid)/pages/\(so)/request-approval", "POST",
            ["approverIds": nguoiDuyet, "mode": tuanTu ? "SEQUENTIAL" : "PARALLEL"])
    }

    // MARK: Thùng rác

    static func thungRacTrang(pid: Int) -> APIEndpoint { get("/projects/\(pid)/trash/pages") }
    static func khoiPhucTrang(pid: Int, so: Int) -> APIEndpoint { goi("/projects/\(pid)/trash/pages/\(so)/restore", "POST") }

    // MARK: Kho kiến thức (KB) — bài = một trang Docs + siêu dữ liệu

    static func kb(pid: Int) -> APIEndpoint { get("/projects/\(pid)/kb") }
}
