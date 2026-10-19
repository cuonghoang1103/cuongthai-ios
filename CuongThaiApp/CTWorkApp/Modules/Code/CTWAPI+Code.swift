import Foundation

// MARK: - CTWAPI — Code (`api-backend/src/routes/work.code.routes.ts`, 18/10/2026)
//
// Mọi tuyến cần đăng nhập; quyền ở `code.service.ts → codeGate`: thành viên dự án xem được, vai CLIENT ⇒ 403
// `WORK_CODE_FORBIDDEN` (khách cổng còn bị chặn sớm hơn ở chốt cổng khách). Agent không xem mã nguồn.
// Mã nguồn là PROXY GitHub/GitLab có đệm: 409 `WORK_GIT_NO_REPO`, 429 `WORK_GIT_RATE_LIMIT`, 413 `WORK_GIT_TOO_LARGE`.
// Cài đặt token/kênh (PUT …/read-token, …/activity) là việc ADMIN trên web — app KHÔNG gọi.

extension CTWAPI {
    /// `{connected, providers}` — rẻ; khung dùng để ẩn/hiện mục "Code".
    static func codeTrangThai(pid: Int) -> APIEndpoint { get("/projects/\(pid)/code/status") }
    static func codeTongQuan(pid: Int) -> APIEndpoint { get("/projects/\(pid)/code/overview") }
    /// `kind`: push | branch | pr. `before` = `nextBefore` của trang trước (ISO).
    static func codeHoatDong(pid: Int, kind: String? = nil, nhanh: String? = nil, nguoi: String? = nil,
                             before: String? = nil, limit: Int = 30) -> APIEndpoint {
        var q: [String: Any] = ["limit": limit]
        if let kind { q["kind"] = kind }
        if let nhanh { q["branch"] = nhanh }
        if let nguoi { q["actor"] = nguoi }
        if let before { q["before"] = before }
        return get("/projects/\(pid)/code/activity", q)
    }
    static func codeNhanh(pid: Int) -> APIEndpoint { get("/projects/\(pid)/code/branches") }
    /// `state`: open | merged | closed | all.
    static func codePR(pid: Int, state: String) -> APIEndpoint { get("/projects/\(pid)/code/pulls", ["state": state]) }
    static func codeThe(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/code/issues/\(so)") }

    private static func nguon(_ ref: String?, _ path: String?, _ provider: String?) -> [String: Any]? {
        var q: [String: Any] = [:]
        if let ref, !ref.isEmpty { q["ref"] = ref }
        if let path, !path.isEmpty { q["path"] = path }
        if let provider { q["provider"] = provider }
        return q.isEmpty ? nil : q
    }
    static func codeRepo(pid: Int, provider: String? = nil) -> APIEndpoint {
        get("/projects/\(pid)/code/source/meta", nguon(nil, nil, provider))
    }
    static func codeRefs(pid: Int, provider: String? = nil) -> APIEndpoint {
        get("/projects/\(pid)/code/source/refs", nguon(nil, nil, provider))
    }
    static func codeCay(pid: Int, ref: String?, path: String?, provider: String? = nil) -> APIEndpoint {
        get("/projects/\(pid)/code/source/tree", nguon(ref, path, provider))
    }
    static func codeTep(pid: Int, ref: String?, path: String, provider: String? = nil) -> APIEndpoint {
        get("/projects/\(pid)/code/source/blob", nguon(ref, path, provider))
    }
    static func codeLichSu(pid: Int, ref: String?, path: String?, provider: String? = nil) -> APIEndpoint {
        get("/projects/\(pid)/code/source/commits", nguon(ref, path, provider))
    }
    static func codeCommit(pid: Int, sha: String, provider: String? = nil) -> APIEndpoint {
        get("/projects/\(pid)/code/source/commit/\(doan(sha))", nguon(nil, nil, provider))
    }
}
