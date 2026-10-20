#if DEBUG
import Foundation

// MARK: - Máy chủ giả: AI usage (hình dạng `aiUsage.service.ts → buildReport`)
// Màn thử: `mod:ai-usage` (dự án) · `mod:ai-usage/ws` (không gian). ⚠️ Cả tệp trong `#if DEBUG`.

enum DuLieuGiaAIUsage {
    typealias G = DuLieuGia

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        guard m == "GET", p == "/work/projects/7/ai-usage" || p == "/work/workspaces/1/ai-usage" else { return nil }
        let ws = p.hasPrefix("/work/workspaces")
        var r: [String: Any] = ["scope": ws ? "workspace" : "project", "canSeeAll": true,
                                "range": ["from": (b["from"] as? String) ?? G.ngay(-29), "to": (b["to"] as? String) ?? G.ngay(0)]]
        r["totals"] = ["people": 3, "toolCalls": ws ? 412 : 286, "writes": ws ? 57 : 41, "inputTokens": 1_284_000, "outputTokens": 96_400,
                       "chinhHangUsd": 0.84, "modelapiUsd": 0.1932, "ramboTurns": 38.5, "agentUsd": 1.27, "cuongMiniTurns": 64.0,
                       "byClient": ["cuongmini": 180, "mcp": 22, "agent": 60, "web": 24, "builtin": 0]] as [String: Any]
        r["people"] = [
            nguoi(G.toi, 1, ["cuongmini", "web"], -0.02, goi: 168, viet: 23, loi: 2, vao: 820_000, ra: 61_000, ch: 0.84, core: 0.12, classic: 30.5, agent: 0,
                  models: ["CuongMini Default", "CuongMini Solid"]),
            nguoi(G.linh, 2, ["web", "mcp"], -0.6, goi: 58, viet: 6, loi: 0, vao: 214_000, ra: 18_200, ch: 0, core: 0.0732, classic: 8, agent: 0,
                  models: ["CuongMini Solid", "AI khác (MCP)"]),
            nguoi(G.scout, 9, ["agent"], -1.2, goi: 60, viet: 12, loi: 1, vao: 250_000, ra: 17_200, ch: 0, core: 0, classic: 0, agent: 1.27,
                  models: ["claude-code"]),
        ]
        r["models"] = [
            ["name": "CuongMini Default", "source": "rambo", "via": "cuongmini", "turns": 38.5, "inputTokens": 640_000, "outputTokens": 42_000, "costUsd": 0],
            ["name": "CuongMini Code Max · Sonic", "source": "chinh_hang", "via": "cuongmini", "turns": 9, "inputTokens": 120_000, "outputTokens": 11_000, "costUsd": 0.84],
            ["name": "CuongMini Solid", "source": "modelapi", "via": "web", "turns": 24, "inputTokens": 274_000, "outputTokens": 26_200, "costUsd": 0.1932],
            ["name": "claude-code", "source": "agent", "via": "agent", "turns": 60, "inputTokens": 250_000, "outputTokens": 17_200, "costUsd": 1.27],
        ] as [[String: Any]]
        r["writes"] = [
            thay(1, G.toi, "cuongmini", "update_issue", "NW-12", ok: true, gio: 0.5),
            thay(2, G.toi, "cuongmini", "comment", "NW-17", ok: true, gio: 1.4),
            thay(3, G.scout, "agent", "transition", "NW-19", ok: true, gio: 20),
            thay(4, G.scout, "agent", "approval_request", "NW-14", ok: false, gio: 26, ma: "WORK_AGENT_FORBIDDEN"),
            thay(5, G.linh, "mcp", "create_issue", "NW-23", ok: true, gio: 30),
        ]
        r["notes"] = ["cuongMiniEstimated": true, "agentSelfReported": true]
        r["members"] = [G.toi, G.linh, G.minh, G.scout]
        if ws { r["projects"] = [["id": 7, "key": "NW", "name": "Northwind Mobile"], ["id": 8, "key": "WEB", "name": "Website"]] as [[String: Any]] }
        return r
    }

    private static func nguoi(_ u: [String: Any], _ id: Int, _ qua: [String], _ ngay: Double, goi: Int, viet: Int, loi: Int, vao: Int, ra: Int,
                              ch: Double, core: Double, classic: Double, agent: Double, models: [String]) -> [String: Any] {
        var n: [String: Any] = ["user": u, "userId": id, "clients": qua, "lastUsedAt": G.iso(ngay), "toolCalls": goi, "writes": viet, "failed": loi]
        n["inputTokens"] = vao; n["outputTokens"] = ra
        n["chinhHangUsd"] = ch; n["modelapiUsd"] = core; n["ramboTurns"] = classic; n["cuongMiniTurns"] = classic; n["agentUsd"] = agent
        n["models"] = models
        return n
    }

    private static func thay(_ id: Int, _ u: [String: Any], _ qua: String, _ tool: String, _ dich: String, ok: Bool, gio: Double, ma: String? = nil) -> [String: Any] {
        var t: [String: Any] = ["id": id, "at": G.iso(-gio / 24), "user": u, "client": qua, "tool": tool, "target": dich, "ok": ok]
        t["errorCode"] = ma.map { $0 as Any } ?? NSNull()
        t["project"] = ["key": "NW", "name": "Northwind Mobile"]
        return t
    }
}
#endif
