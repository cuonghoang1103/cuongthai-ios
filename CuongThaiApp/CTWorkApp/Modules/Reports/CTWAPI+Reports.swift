import Foundation

// MARK: - CTWAPI — Báo cáo (`work.routes.ts:859-874, 1090, 1200-1211, 1320`, `work.uxb.routes.ts`,
//         `work.agents.routes.ts:195`). Mọi route chỉ cần `project.view`; khách cổng bị chặn 403.

extension CTWAPI {
    static func velocity(pid: Int) -> APIEndpoint { get("/projects/\(pid)/reports/velocity") }
    static func epicsBaoCao(pid: Int) -> APIEndpoint { get("/projects/\(pid)/reports/epics") }
    static func kpis(pid: Int) -> APIEndpoint { get("/projects/\(pid)/reports/kpis") }
    static func insights(pid: Int) -> APIEndpoint { get("/projects/\(pid)/insights") }
    static func cfd(pid: Int, ngay: Int) -> APIEndpoint { get("/projects/\(pid)/reports/cfd", ["days": min(max(ngay, 7), 180)]) }
    static func throughput(pid: Int, tuan: Int = 12) -> APIEndpoint { get("/projects/\(pid)/reports/throughput", ["weeks": min(max(tuan, 4), 52)]) }
    static func cycleTime(pid: Int, ngay: Int = 90) -> APIEndpoint { get("/projects/\(pid)/reports/cycle-time", ["days": min(max(ngay, 14), 365)]) }
    static func taiTheoNguoi(pid: Int) -> APIEndpoint { get("/projects/\(pid)/reports/load-by-person") }

    /// `groupBy`: status | statusCategory | assignee | type | priority | label | sprint | component
    static func thongKe(pid: Int, nhomTheo: String, jql: String = "") -> APIEndpoint {
        get("/projects/\(pid)/stats", ["groupBy": nhomTheo, "jql": String(jql.prefix(4000))])
    }
    static func taoVsXong(pid: Int, ngay: Int, jql: String = "") -> APIEndpoint {
        get("/projects/\(pid)/stats/created-resolved", ["days": min(max(ngay, 7), 90), "jql": String(jql.prefix(4000))])
    }
    static func timJql(pid: Int, jql: String, limit: Int = 10) -> APIEndpoint {
        get("/projects/\(pid)/search", ["jql": String(jql.prefix(4000)), "limit": min(max(limit, 1), 500)])
    }

    /// `from`/`to` "YYYY-MM-DD" (tối đa 92 ngày). `principal`: HUMAN | AGENT | ALL.
    static func baoCaoThoiGian(pid: Int, tu: String, den: String, nguoi: Int? = nil, principal: String = "ALL") -> APIEndpoint {
        var q: [String: Any] = ["from": tu, "to": den, "principal": principal]
        if let nguoi { q["userId"] = nguoi }
        return get("/projects/\(pid)/reports/time", q)
    }

    /// People vs Agents — mặc định 30 ngày gần nhất, tối đa 92.
    static func nguoiVsAgent(pid: Int, tu: String?, den: String?, sprint: Int? = nil) -> APIEndpoint {
        var q: [String: Any] = [:]
        if let tu { q["from"] = tu }
        if let den { q["to"] = den }
        if let sprint { q["sprintId"] = sprint }
        return get("/projects/\(pid)/reports/agents", q.isEmpty ? nil : q)
    }
}
