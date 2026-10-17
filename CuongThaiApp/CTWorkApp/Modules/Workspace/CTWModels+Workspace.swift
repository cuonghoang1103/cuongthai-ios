import Foundation

// MARK: - Model cấp KHÔNG GIAN (đối chiếu `portfolio.service.ts:86-452`, `teams.service.ts:27-262`,
// `agentReports.service.ts:209-286`). Route chỉ nhận id SỐ của không gian.

// MARK: Portfolio

struct CTWMocDuAn: Codable, Hashable, Identifiable {
    var id: Int
    var name: String?
    /// "YYYY-MM-DD"
    var date: String?
    /// Âm = trễ
    var daysUntil: Int?
    var total: Int?
    var done: Int?
    var projectId: Int?
    var projectKey: String?
    var projectName: String?
    var url: String?
}

struct CTWDuAnPortfolio: Codable, Hashable, Identifiable {
    struct Dem: Codable, Hashable { var open: Int?; var overdue: Int?; var done14: Int? }
    struct NhipSprint: Codable, Hashable {
        var name: String?
        /// NO_ESTIMATES | TOO_EARLY | DONE | AT_RISK | ON_TRACK
        var status: String?
        var summary: String?
        var daysLeft: Int?
        var remaining: Double?
        var total: Double?
        var done: Double?
        var neededPerDay: Double?
        var recentPerDay: Double?
        var unit: String?
    }
    struct GiaiDoan: Codable, Hashable {
        struct HienTai: Codable, Hashable { var n: Int?; var name: String?; var status: String? }
        var current: HienTai?
        var done: Int?
        var total: Int?
        var percent: Double?
    }
    struct Duyet: Codable, Hashable { var pending: Int?; var oldestDays: Int? }
    struct PhuThuoc: Codable, Hashable { var blockedBy: Int?; var blocking: Int? }
    struct SucKhoe: Codable, Hashable {
        struct LyDo: Codable, Hashable { var level: String?; var code: String?; var text: String? }
        /// RED | AMBER | GREEN
        var rag: String?
        var reasons: [LyDo]?
    }
    var id: Int
    var key: String?
    var name: String?
    var type: String?
    var role: String?
    var archivedAt: String?
    var color: String?
    var iconEmoji: String?
    var kind: String?
    var lead: CTWUser?
    var url: String?
    var counts: Dem?
    var sprint: NhipSprint?
    var stage: GiaiDoan?
    var approvals: Duyet?
    var nextMilestone: CTWMocDuAn?
    var dependencies: PhuThuoc?
    var health: SucKhoe?
}

struct CTWPhiaChan: Codable, Hashable {
    var hidden: Bool?
    var projectKey: String?
    var key: String?
    var number: Int?
    var title: String?
    var dueDate: String?
}

struct CTWPortfolio: Codable {
    struct Chan: Codable, Hashable, Identifiable { var id: Int; var since: String?; var blocker: CTWPhiaChan?; var blocked: CTWPhiaChan? }
    var today: String?
    var projects: [CTWDuAnPortfolio]?
    var milestones: [CTWMocDuAn]?
    var blockers: [Chan]?
    var canSeeWorkload: Bool?
    var workloadScope: String?
}

// MARK: Workload

struct CTWTaiTuan: Codable, Hashable {
    var start: String
    var end: String?
    var workingDays: Int?
    var capacity: Double?
    var hours: Double?
    var pct: Double?
    var overloaded: Bool?
    /// none | low | ok | high | over
    var level: String?
}

struct CTWNguoiTai: Codable, Hashable, Identifiable {
    struct Viec: Codable, Hashable, Identifiable {
        struct DuAn: Codable, Hashable { var id: Int?; var key: String?; var name: String? }
        var id: Int
        var key: String?
        var number: Int?
        var title: String?
        var project: DuAn?
        var due: String?
        var overdue: Bool?
        var hours: Double?
        var url: String?
    }
    var user: CTWUser
    var teamIds: [Int]?
    var hoursPerDay: Double?
    var weeks: [CTWTaiTuan]?
    var totalHours: Double?
    var totalCapacity: Double?
    var pct: Double?
    var overloaded: Bool?
    var level: String?
    var unestimated: Int?
    var issues: [Viec]?
    var id: Int { user.id }
}

struct CTWWorkload: Codable {
    struct Tuan: Codable, Hashable { var start: String; var end: String? }
    struct DoiChon: Codable, Hashable, Identifiable { var id: Int; var key: String?; var name: String?; var color: String? }
    var from: String?
    var to: String?
    var weeks: [Tuan]?
    /// ALL | TEAMS | SELF
    var scope: String?
    var hoursPerPoint: Double?
    var teamOptions: [DoiChon]?
    var people: [CTWNguoiTai]?
    var truncated: Bool?
}

// MARK: Teams

struct CTWDoi: Codable, Hashable, Identifiable {
    var id: Int
    var key: String?
    var name: String?
    var color: String?
    var description: String?
    var archivedAt: String?
    /// PublicUser + `teamRole` (LEAD | MEMBER)
    var members: [ThanhVien]?
    var leadIds: [Int]?
    var openIssues: Int?

    struct ThanhVien: Codable, Hashable, Identifiable {
        var id: Int
        var username: String?
        var fullName: String?
        var displayName: String?
        var avatarUrl: String?
        var kind: String?
        var teamRole: String?
        var nguoi: CTWUser { CTWUser(id: id, username: username, fullName: fullName, displayName: displayName, avatarUrl: avatarUrl, kind: kind) }
    }
}

struct CTWHangDoi: Codable {
    struct The: Codable, Hashable, Identifiable {
        var id: Int
        var number: Int?
        var title: String?
        var priority: Int?
        var dueDate: String?
        var projectId: Int?
        var projectKey: String?
        var key: String?
        var assignee: CTWUser?
        var resolvedAt: String?
    }
    var team: CTWDoi?
    var isLead: Bool?
    var total: Int?
    var items: [The]?
}

// MARK: AI agents (People vs Agents cấp không gian)

struct CTWAgentDashboard: Codable {
    struct Tuan: Codable, Hashable {
        var weekStart: String
        var humanResolved: Int?
        var agentResolved: Int?
        var agentReturned: Int?
        var agentCostUsd: Double?
        var humanHours: Double?
    }
    struct NguonChiPhi: Codable, Hashable { var reported: Double?; var gateway: Double? }
    struct Agent: Codable, Hashable, Identifiable {
        struct Ho: Codable, Hashable {
            var id: Int
            var userId: Int?
            var username: String?
            var displayName: String?
            var model: String?
            var status: String?
            var owner: CTWUser?
            var lastSeenAt: String?
        }
        var agent: Ho
        var issuesResolved: Int?
        var pointsResolved: Double?
        var returnedCount: Int?
        var returnRate: Double?
        var costUsd: Double?
        var costSource: NguonChiPhi?
        var costPerPoint: Double?
        var leaseMinutes: Int?
        var activeLeases: Int?
        var id: Int { agent.id }
        /// Người dùng-agent để dựng avatar có ✦ + nhãn AI.
        var nguoi: CTWUser { CTWUser(id: agent.userId ?? agent.id, username: agent.username, fullName: agent.displayName, kind: "AGENT") }
    }
    struct Tong: Codable, Hashable {
        var humanResolved: Int?
        var agentResolved: Int?
        var agentReturned: Int?
        var agentReturnRate: Double?
        var agentCostUsd: Double?
        var humanHours: Double?
        var costSource: NguonChiPhi?
    }
    var days: Int?
    var from: String?
    var to: String?
    /// ALL | OWN
    var scope: String?
    var weeks: [Tuan]?
    var agents: [Agent]?
    var totals: Tong?
}

/// Phép tính thuần cho Workspace (kiểm thử được).
enum WorkspaceTinh {
    static func tenMuc(_ level: String?) -> String {
        switch level {
        case "over": return "Overloaded"
        case "high": return "High"
        case "ok": return "Healthy"
        case "low": return "Light"
        default: return "No capacity"
        }
    }
    static func tenRag(_ r: String?) -> String {
        switch r {
        case "RED": return "Off track"
        case "AMBER": return "Needs attention"
        default: return "On track"
        }
    }
    static func bieuTuongRag(_ r: String?) -> String {
        switch r {
        case "RED": return "xmark.octagon.fill"
        case "AMBER": return "exclamationmark.triangle.fill"
        default: return "checkmark.circle.fill"
        }
    }
    /// Phần trăm chi phí agent tự khai (0…1) — để ghi rõ "self-reported" khi đa số là số tự khai.
    static func tiLeTuKhai(_ n: CTWAgentDashboard.NguonChiPhi?) -> Double {
        let r = n?.reported ?? 0, g = n?.gateway ?? 0
        return r + g > 0 ? r / (r + g) : 0
    }
}
