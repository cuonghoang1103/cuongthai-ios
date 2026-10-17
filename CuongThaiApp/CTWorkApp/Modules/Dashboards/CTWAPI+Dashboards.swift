import Foundation

// MARK: - CTWAPI — Dashboards (`work.routes.ts:1222-1239`, `work.uxb.routes.ts:69`,
//         `work.ctw7c.routes.ts:181-184`, `work.ctw8b.routes.ts:62-82`)

extension CTWAPI {
    static func dsDashboard(pid: Int) -> APIEndpoint { get("/projects/\(pid)/dashboards") }
    /// Trả (hoặc tạo lần đầu) dashboard "Project overview" với bộ widget mặc định.
    static func dashboardTongQuan(pid: Int) -> APIEndpoint { goi("/projects/\(pid)/dashboards/overview", "POST") }
    static func dongHoCuaToiDb() -> APIEndpoint { get("/me/timer") }
    static func gioCuaToiDb(pid: Int) -> APIEndpoint { get("/projects/\(pid)/widgets-7c/my-time") }

    // Report builder — chỉ đội dự án (CLIENT/GUEST ⇒ 403 WORK_INTERNAL_ONLY).
    static func dsMauBaoCao(pid: Int) -> APIEndpoint { get("/projects/\(pid)/report-builder/templates") }
    static func xemTruocBaoCao(pid: Int, ref: String) -> APIEndpoint {
        goi("/projects/\(pid)/report-builder/preview", "POST", ["ref": ref])
    }
}
