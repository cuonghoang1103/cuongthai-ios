import Foundation

// MARK: - CTWAPI — AI Agents (work.agents.routes.ts:78-133, work.agentsUi.routes.ts:29)

extension CTWAPI {
    static func dsAgent(wsId: Int) -> APIEndpoint { get("/workspaces/\(wsId)/agents") }
    static func agent(wsId: Int, id: Int) -> APIEndpoint { get("/workspaces/\(wsId)/agents/\(id)") }
    static func agentLease(wsId: Int, id: Int) -> APIEndpoint { get("/workspaces/\(wsId)/agents/\(id)/leases") }
    static func chipAgent(pid: Int) -> APIEndpoint { get("/projects/\(pid)/agent-leases") }
    /// Tạm dừng / chạy lại — chủ agent hoặc OWNER/ADMIN không gian (`canManage`).
    /// KHÔNG có `retire` trên điện thoại: không đảo được, để ở web.
    static func dungAgent(wsId: Int, id: Int, dung: Bool) -> APIEndpoint {
        goi("/workspaces/\(wsId)/agents/\(id)/\(dung ? "pause" : "resume")", "POST", [:])
    }
}
