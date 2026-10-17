import Foundation

// MARK: - CTWAPI — phê duyệt (`work.routes.ts` :1758–1789, `approvals.service.ts`)

extension CTWAPI {
    /// Xuyên dự án: chỉ những bước ĐANG tới lượt mình.
    static func duyetChoToi() -> APIEndpoint { get("/me/approvals") }

    static func dsDuyet(pid: Int, trangThai: String?) -> APIEndpoint {
        var q: [String: Any] = ["limit": 200]
        if let trangThai { q["status"] = trangThai }
        return get("/projects/\(pid)/approvals", q)
    }

    static func duyet(pid: Int, id: Int) -> APIEndpoint { get("/projects/\(pid)/approvals/\(id)") }

    /// `decision`: APPROVE | REJECT. Từ chối BẮT BUỘC có lý do (`WORK_REJECT_REASON`).
    static func quyetDinhDuyet(pid: Int, id: Int, dongY: Bool, yKien: String?) -> APIEndpoint {
        let y = yKien?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return goi("/projects/\(pid)/approvals/\(id)/decide", "POST",
                   ["decision": dongY ? "APPROVE" : "REJECT", "comment": govNull(y.isEmpty ? nil : String(y.prefix(5000)))])
    }

    static func huyDuyet(pid: Int, id: Int, lyDo: String?) -> APIEndpoint {
        let l = lyDo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return goi("/projects/\(pid)/approvals/\(id)/cancel", "POST", ["reason": govNull(l.isEmpty ? nil : String(l.prefix(1000)))])
    }
}
