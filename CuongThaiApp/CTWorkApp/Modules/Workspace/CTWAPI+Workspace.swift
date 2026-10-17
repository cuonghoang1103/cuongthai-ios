import Foundation

// MARK: - CTWAPI — cấp không gian (`work.portfolio.routes.ts:41-55`, `work.routes.ts:1675-1715`,
// `work.agents.routes.ts:99`). `ws` là id SỐ (slug ⇒ 400) — lấy bằng `AppState.idKhongGian()`.

extension CTWAPI {
    static func portfolio(ws: Int) -> APIEndpoint { get("/workspaces/\(ws)/portfolio") }
    static func workload(ws: Int, tu: String?, doi: Int?) -> APIEndpoint {
        var q: [String: Any] = [:]
        if let tu { q["from"] = tu }
        if let doi { q["teamId"] = doi }
        return get("/workspaces/\(ws)/workload", q.isEmpty ? nil : q)
    }
    static func dsDoi(ws: Int) -> APIEndpoint { get("/workspaces/\(ws)/teams") }
    static func hangDoi(ws: Int, doi: Int) -> APIEndpoint { get("/workspaces/\(ws)/teams/\(doi)/queue", ["limit": 100]) }
    static func agentDashboard(ws: Int, ngay: Int) -> APIEndpoint { get("/workspaces/\(ws)/agents/dashboard", ["days": ngay]) }
}
