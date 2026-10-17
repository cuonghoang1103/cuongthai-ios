import Foundation

// MARK: - CTWAPI — Tài chính dự án, CHỈ ĐỌC (work.s4.routes.ts:59-170)
// Không có hàm ghi nào ở đây — App Store 3.1.1: mọi thao tác tiền bạc ở web.

extension CTWAPI {
    static func caiDatTaiChinh(pid: Int) -> APIEndpoint { get("/projects/\(pid)/finance/settings") }
    /// Cần `manageFinance` (ADMIN dự án) — người khác nhận 403 WORK_FINANCE_FORBIDDEN.
    static func tongQuanTaiChinh(pid: Int) -> APIEndpoint { get("/projects/\(pid)/finance/summary") }
    static func mocThanhToan(pid: Int) -> APIEndpoint { get("/projects/\(pid)/finance/payments") }
    static func chiPhi(pid: Int) -> APIEndpoint { get("/projects/\(pid)/finance/expenses") }
    static func bangCong(pid: Int) -> APIEndpoint { get("/projects/\(pid)/finance/timesheets") }
}
