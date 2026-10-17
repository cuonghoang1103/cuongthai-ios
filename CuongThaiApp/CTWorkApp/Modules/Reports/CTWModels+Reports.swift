import Foundation

// MARK: - Model mô-đun Reports (+ dùng lại ở Dashboards)
//
// Đối chiếu backend:
//   · velocity / epics            `services/work/reports.service.ts:79-129`
//   · time                        `services/work/planning.service.ts:476-516`
//   · cfd / throughput / cycle    `services/work/flowReports.service.ts` + `flowMetrics.ts`
//   · kpis / load-by-person       `flowReports.service.ts:206-280`
//   · stats / created-resolved    `services/work/search.service.ts:136-214`
//   · insights                    `services/work/ai.service.ts:976-1037`
//   · agents ("People vs Agents") `services/work/agentReports.service.ts:78-212`
// Luật kho: `var` + optional, ngày `String` (C3/C4).

// MARK: Velocity

struct CTWVelocitySprint: Codable, Hashable, Identifiable {
    var id: Int
    var name: String?
    var committedPoints: Double?
    var completedPoints: Double?
    var completedAt: String?
    var rollingAverage: Double?
}

struct CTWVelocity: Codable {
    var unit: String?
    var sprints: [CTWVelocitySprint]?
    var average: Double?
}

// MARK: Epics

struct CTWEpicBaoCao: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int?
    var title: String?
    var statusId: Int?
    var dueDate: String?
    var resolved: Bool?
    var total: Int?
    var completed: Int?
    var points: Double?
    var pointsDone: Double?
    /// 0–100 theo SỐ thẻ
    var percent: Double?
}

struct CTWEpicsBaoCao: Codable {
    var unit: String?
    var epics: [CTWEpicBaoCao]?
}

// MARK: Time

struct CTWThoiGianTheVanTat: Codable, Hashable {
    var number: Int?
    var title: String?
    var minutes: Int?
}

struct CTWThoiGianNguoi: Codable, Hashable {
    var user: CTWUser?
    /// HUMAN | AGENT
    var userKind: String?
    var name: String?
    var totalMin: Int?
    var autoMin: Int?
    /// "YYYY-MM-DD" → phút
    var byDay: [String: Int]?
    var issues: [CTWThoiGianTheVanTat]?
}

struct CTWBaoCaoThoiGian: Codable {
    var from: String?
    var to: String?
    var principal: String?
    var totalMin: Int?
    var byPrincipal: [String: Int]?
    var people: [CTWThoiGianNguoi]?
}

// MARK: Flow — CFD

struct CTWCfdDai: Codable, Hashable, Identifiable {
    /// "s<statusId>"
    var key: String
    var name: String?
    var category: String?
    var color: String?
    var id: String { key }
}

/// Điểm CFD: `{day, s12: 4, s13: 2, …}` — khoá động ⇒ giải mã tay.
struct CTWCfdDiem: Codable, Hashable {
    var day: String
    var giaTri: [String: Double]

    private struct K: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(day: String, giaTri: [String: Double]) { self.day = day; self.giaTri = giaTri }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        day = (try? c.decode(String.self, forKey: K(stringValue: "day"))) ?? ""
        var g: [String: Double] = [:]
        for k in c.allKeys where k.stringValue != "day" {
            if let v = try? c.decode(Double.self, forKey: k) { g[k.stringValue] = v }
        }
        giaTri = g
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(day, forKey: K(stringValue: "day"))
        for (k, v) in giaTri { try c.encode(v, forKey: K(stringValue: k)) }
    }
}

struct CTWCfd: Codable {
    var scope: String?
    var days: Int?
    var from: String?
    var to: String?
    var bands: [CTWCfdDai]?
    var points: [CTWCfdDiem]?
}

// MARK: Flow — throughput / cycle time

struct CTWThroughputTuan: Codable, Hashable, Identifiable {
    var week: String
    var end: String?
    var count: Int?
    var points: Double?
    var id: String { week }
}

struct CTWThroughput: Codable {
    var scope: String?
    var unit: String?
    var weeks: [CTWThroughputTuan]?
    var average: Double?
    var averagePoints: Double?
}

struct CTWPhanVi: Codable, Hashable {
    var n: Int?
    var p50: Double?
    var p85: Double?
    var p95: Double?
    var mean: Double?
}

struct CTWCycleItem: Codable, Hashable {
    var issueId: Int?
    var number: Int?
    var title: String?
    var resolvedAt: String?
    var day: String?
    var cycleDays: Double?
    var leadDays: Double?
}

struct CTWCycleTime: Codable {
    var scope: String?
    var days: Int?
    var items: [CTWCycleItem]?
    var cycle: CTWPhanVi?
    var lead: CTWPhanVi?
}

// MARK: KPIs

struct CTWKpiSo: Codable, Hashable {
    var value: Double?
    var previous: Double?
}

struct CTWKpiSprint: Codable, Hashable {
    var name: String?
    /// NO_ESTIMATES | TOO_EARLY | DONE | AT_RISK | ON_TRACK
    var status: String?
    var daysLeft: Int?
    var total: Double?
    var done: Double?
    var pctDone: Double?
}

struct CTWKpis: Codable {
    var asOf: String?
    var open: CTWKpiSo?
    var overdue: CTWKpiSo?
    var blocked: CTWKpiSo?
    var sprint: CTWKpiSprint?
    var highRisks: Int?
}

// MARK: Insights (tab Overview / widget health)

struct CTWInsightThe: Codable, Hashable {
    var key: String?
    var number: Int?
    var title: String?
    var assignee: String?
    var status: String?
    var dueDate: String?
    var idleDays: Int?
}

struct CTWInsightTai: Codable, Hashable {
    var username: String?
    var points: Double?
    var issues: Int?
    var unit: String?
    var capacity: Double?
    var overloaded: Bool?
    var basis: String?
}

struct CTWSprintNhip: Codable, Hashable {
    var sprint: String?
    var committed: Double?
    var total: Double?
    var remaining: Double?
    var done: Double?
    var daysLeft: Int?
    var elapsedDays: Int?
    var neededPerDay: Double?
    var recentPerDay: Double?
    var estimated: Bool?
    var atRisk: Bool?
    var status: String?
    var summary: String?
}

struct CTWInsights: Codable {
    var overdue: [CTWInsightThe]?
    var dueSoon: [CTWInsightThe]?
    var stale: [CTWInsightThe]?
    var unassignedUrgent: [CTWInsightThe]?
    var overloaded: [CTWInsightTai]?
    var loads: [CTWInsightTai]?
    var sprintRisk: CTWSprintNhip?
    var unit: String?
}

// MARK: Phân bố (`/stats`) + created vs resolved

struct CTWNhomThongKe: Codable, Hashable, Identifiable {
    var key: String
    var label: String?
    var color: String?
    var category: String?
    var count: Int?
    var points: Double?
    var id: String { key }
}

struct CTWThongKe: Codable {
    var unit: String?
    var total: Int?
    var groups: [CTWNhomThongKe]?
}

struct CTWTaoXongNgay: Codable, Hashable, Identifiable {
    var day: String
    var created: Int?
    var resolved: Int?
    var id: String { day }
}

// MARK: Tải theo người (widget workload)

struct CTWTaiNguoi: Codable, Hashable {
    var user: CTWUser?
    var todo: Int?
    var inProgress: Int?
    var overdue: Int?
    var blocked: Int?
    var estimate: Double?
    var total: Int?
}

struct CTWTaiTheoNguoi: Codable {
    var unit: String?
    var people: [CTWTaiNguoi]?
}

// MARK: People vs Agents

struct CTWAgentNhanh: Codable, Hashable {
    var id: Int?
    var userId: Int?
    var username: String?
    var displayName: String?
    var model: String?
    var status: String?
    var owner: CTWUser?
}

struct CTWNguonChiPhi: Codable, Hashable {
    /// USD — agent TỰ KHAI (MCP `report_usage`)
    var reported: Double?
    /// USD — cổng của CT Work đo được
    var gateway: Double?
}

struct CTWToken: Codable, Hashable {
    var `in`: Int?
    var out: Int?
    var cacheRead: Int?
}

struct CTWAgentBaoCao: Codable, Hashable {
    var agent: CTWAgentNhanh?
    var issuesTouched: Int?
    var issuesResolved: Int?
    var pointsResolved: Double?
    var returnedCount: Int?
    var returnRate: Double?
    var leaseMinutes: Int?
    var worklogMinutes: Int?
    var autoWorklogMinutes: Int?
    var tokens: CTWToken?
    var costUsd: Double?
    var costSource: CTWNguonChiPhi?
    var costPerPoint: Double?
    var costPerResolved: Double?
}

struct CTWNguoiBaoCao: Codable, Hashable {
    var user: CTWUser?
    var worklogMinutes: Int?
    var hours: Double?
    /// nil khi người xem không được thấy chi phí người (cần mô-đun finance + ADMIN)
    var cost: Double?
    var issuesResolved: Int?
}

struct CTWTongAgent: Codable, Hashable {
    var issuesResolved: Int?
    var returnedCount: Int?
    var returnRate: Double?
    var pointsResolved: Double?
    var costUsd: Double?
    var costSource: CTWNguonChiPhi?
    var leaseMinutes: Int?
    var worklogMinutes: Int?
    var costPerPoint: Double?
    var costPerResolved: Double?
}

struct CTWTongNguoi: Codable, Hashable {
    var hours: Double?
    var worklogMinutes: Int?
    var cost: Double?
    var issuesResolved: Int?
}

struct CTWTongNguoiAgent: Codable, Hashable {
    var agents: CTWTongAgent?
    var humans: CTWTongNguoi?
}

struct CTWNguoiVsAgent: Codable {
    var from: String?
    var to: String?
    var sprintId: Int?
    var agents: [CTWAgentBaoCao]?
    var humans: [CTWNguoiBaoCao]?
    var totals: CTWTongNguoiAgent?
    var currency: String?
}

// MARK: Tìm kiếm JQL (`/search` — widget counter/filter)

struct CTWKetQuaJql: Codable {
    var total: Int?
    var items: [CTWIssueCard]?
    var offset: Int?
    var limit: Int?
}
