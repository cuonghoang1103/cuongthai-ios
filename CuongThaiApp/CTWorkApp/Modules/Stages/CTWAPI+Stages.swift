import Foundation

// MARK: - CTWAPI — Stages (`work.routes.ts:1718-1754`). App chỉ ĐỌC; kích hoạt/xin duyệt cổng để web.

extension CTWAPI {
    static func dsGiaiDoan(pid: Int) -> APIEndpoint { get("/projects/\(pid)/stages") }
}
