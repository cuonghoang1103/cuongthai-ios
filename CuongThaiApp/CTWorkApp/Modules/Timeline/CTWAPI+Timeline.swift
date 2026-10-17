import Foundation

// MARK: - CTWAPI — Timeline (`work.routes.ts:1276-1282`, `work.uxc.routes.ts:46-60`)

extension CTWAPI {
    static func dongThoiGian(pid: Int) -> APIEndpoint { get("/projects/\(pid)/timeline") }
    static func mocThoiGian(pid: Int) -> APIEndpoint { get("/projects/\(pid)/timeline/markers") }
    /// Đổi lịch một thẻ — `version` là khoá lạc quan (409 nếu cũ). Cả hai khoá ngày bắt buộc (null được).
    static func datLichThe(pid: Int, so: Int, batDau: String?, han: String?, version: Int?) -> APIEndpoint {
        var t: [String: Any] = ["startDate": batDau ?? NSNull(), "dueDate": han ?? NSNull()]
        if let version { t["version"] = version }
        return goi("/projects/\(pid)/issues/\(so)/schedule", "PUT", t)
    }
}
