import Foundation

// MARK: - "AI usage" — model + API (web đợt 8B, 19/10/2026)
//
// Đối chiếu api-backend `src/routes/work.aiUsage.routes.ts` + `services/work/aiUsage.service.ts → buildReport`:
//   GET /workspaces/:wsId/ai-usage  ?from&to&userId&projectId     GET /projects/:pid/ai-usage  ?from&to&userId
// Quyền do MÁY CHỦ quyết: ADMIN dự án / OWNER-ADMIN không gian xem tất; thành viên chỉ phần của mình (`canSeeAll=false`);
// khách cổng + agent ⇒ 403. Tên model là tên CuongMini (máy chủ không bao giờ trả tên thật).
// Chi phí: chính hãng $ · CuongMini Core $ · Classic đếm LƯỢT (gói trọn) · agent $ TỰ KHAI. CuongMini là ƯỚC LƯỢNG.
// Chỉ đọc — không có nút mua/nâng cấp nào (App Store 3.1.1).

extension CTWAPI {
    static func aiUsageDuAn(pid: Int, tu: String?, den: String?, nguoi: Int?) -> APIEndpoint {
        get("/projects/\(pid)/ai-usage", locAIU(tu: tu, den: den, nguoi: nguoi, duAn: nil))
    }
    static func aiUsageKhongGian(ws: Int, tu: String?, den: String?, nguoi: Int?, duAn: Int?) -> APIEndpoint {
        get("/workspaces/\(ws)/ai-usage", locAIU(tu: tu, den: den, nguoi: nguoi, duAn: duAn))
    }
    private static func locAIU(tu: String?, den: String?, nguoi: Int?, duAn: Int?) -> [String: Any]? {
        var q: [String: Any] = [:]
        if let tu { q["from"] = tu }
        if let den { q["to"] = den }
        if let nguoi { q["userId"] = nguoi }
        if let duAn { q["projectId"] = duAn }
        return q.isEmpty ? nil : q
    }
}

struct CTWAIUBaoCao: Codable {
    struct KhoangNgay: Codable, Hashable { var from: String?; var to: String? }
    struct Tong: Codable {
        var people: Int?
        var toolCalls: Int?
        var writes: Int?
        var inputTokens: Int?
        var outputTokens: Int?
        var chinhHangUsd: Double?
        var modelapiUsd: Double?
        var ramboTurns: Double?
        var agentUsd: Double?
        var cuongMiniTurns: Double?
        var byClient: [String: Int]?
    }
    struct Nguoi: Codable, Identifiable {
        var user: CTWUser?
        var userId: Int
        /// cuongmini | mcp | agent | web | builtin
        var clients: [String]?
        var lastUsedAt: String?
        var toolCalls: Int?
        var writes: Int?
        var failed: Int?
        var inputTokens: Int?
        var outputTokens: Int?
        var chinhHangUsd: Double?
        var modelapiUsd: Double?
        var ramboTurns: Double?
        var cuongMiniTurns: Double?
        var agentUsd: Double?
        var models: [String]?
        var id: Int { userId }
    }
    struct Model: Codable, Hashable {
        var name: String?
        /// chinh_hang | modelapi | rambo | agent
        var source: String?
        /// cuongmini | web | agent
        var via: String?
        var turns: Double?
        var inputTokens: Int?
        var outputTokens: Int?
        var costUsd: Double?
    }
    struct DuAnNgan: Codable, Hashable { var id: Int?; var key: String?; var name: String? }
    struct ThayDoi: Codable, Identifiable {
        var id: Int
        var at: String?
        var user: CTWUser?
        var client: String?
        var tool: String?
        var target: String?
        var ok: Bool?
        var errorCode: String?
        var project: DuAnNgan?
    }
    struct GhiChu: Codable, Hashable { var cuongMiniEstimated: Bool?; var agentSelfReported: Bool? }

    /// project | workspace
    var scope: String?
    var canSeeAll: Bool?
    var range: KhoangNgay?
    var totals: Tong?
    var people: [Nguoi]?
    var models: [Model]?
    var writes: [ThayDoi]?
    var notes: GhiChu?
    var members: [CTWUser]?
    var projects: [DuAnNgan]?
}

enum NhanAIU {
    static func qua(_ c: String?) -> String {
        switch c {
        case "cuongmini": return "CuongMini"
        case "mcp": return String(localized: "Other AI (MCP)")
        case "web": return String(localized: "Web AI assistant")
        case "agent": return String(localized: "Agent")
        case "builtin": return String(localized: "Built-in agent")
        default: return c ?? ""
        }
    }
    static func nguon(_ s: String?) -> String {
        switch s {
        case "chinh_hang": return String(localized: "Official")
        case "modelapi": return "CuongMini Core"
        case "rambo": return String(localized: "Classic (flat plan)")
        case "agent": return String(localized: "Agent (self-reported)")
        default: return s ?? ""
        }
    }
    /// "$0.0042" / "$1.20" / "—".
    static func usd(_ n: Double?) -> String {
        guard let n, n > 0 else { return "—" }
        return n < 0.01 ? String(format: "$%.4f", n) : String(format: "$%.2f", n)
    }
    static func so(_ n: Double?) -> String {
        guard let n else { return "0" }
        return n.rounded() == n ? CTWDinhDang.so(Int(n)) : String(format: "%.1f", n)
    }
    static func luot(_ n: Double?) -> String {
        let s = so(n)
        return n == 1 ? String(localized: "1 turn") : String(localized: "\(s) turns")
    }
}
