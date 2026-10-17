import Foundation

// MARK: - Model mô-đun Dashboards (+ Report builder chỉ xem)
//
// Đối chiếu backend:
//   · dashboards     `services/work/search.service.ts:216-292` (Widget :227-238)
//   · widgets-7c     `services/work/widgets7c.service.ts:52-67` (my-time)
//   · timer          `services/work/timer.service.ts:42-53` (`GET /me/timer` → `{timer}`)
//   · report builder `services/work/reportBuilder.service.ts:49-85, 295-365` + `reportBuilderExport.ts:21-44`
// Luật kho: `var` + optional, ngày `String` (C3/C4).

struct CTWWidgetDb: Codable, Hashable, Identifiable {
    var id: String
    /// filter | my_issues | overdue | counter | pie | bar | created_resolved | burndown | health | text | top_risks
    /// | kpis | cfd | throughput | cycle_time | aging_wip | velocity | release_burnup | workload | test_pass_rate
    /// | defects_by_severity | license_expiring | my_timer | okr
    var kind: String
    var title: String?
    var query: String?
    var groupBy: String?
    var sprintId: Int?
    var versionId: Int?
    var days: Int?
    var text: String?
    /// half | full
    var size: String?
}

struct CTWDashboardDb: Codable, Hashable, Identifiable {
    var id: Int
    var name: String?
    var shared: Bool?
    var ownerId: Int?
    var widgets: [CTWWidgetDb]?
    var updatedAt: String?
}

/// `GET /me/timer` → `{timer}` — chỉ các trường widget cần (mô-đun Time có model đầy đủ riêng).
struct CTWDongHoWidgetDb: Codable, Hashable {
    var issueKey: String?
    var issueTitle: String?
    var issueNumber: Int?
    var projectId: Int?
    var running: Bool?
    var elapsedSec: Int?
    var serverNow: String?
}

struct CTWDongHoGoiDb: Codable {
    var timer: CTWDongHoWidgetDb?
}

struct CTWGioCuaToiDb: Codable {
    var todayMinutes: Int?
    var weekMinutes: Int?
}

// MARK: Report builder (chỉ xem)

struct CTWMauBaoCaoDb: Codable, Hashable, Identifiable {
    var ref: String
    var key: String?
    var builtin: Bool?
    var name: String?
    var description: String?
    var updatedAt: String?
    var id: String { ref }
}

struct CTWDsMauBaoCaoDb: Codable {
    var language: String?
    var builtins: [CTWMauBaoCaoDb]?
    var templates: [CTWMauBaoCaoDb]?
    var canEdit: Bool?
    var canManage: Bool?
}

/// Mục trong khối `kpis` (`{key,label,value,hint}`) hoặc `risks` (`{key,title,level,score,owner,mitigation}`).
struct CTWMucKhoiBaoCaoDb: Codable, Hashable {
    var key: String?
    var label: String?
    var value: String?
    var hint: String?
    var title: String?
    var level: String?
    var score: Double?
    var owner: String?
    var mitigation: String?
}

/// Một khối của báo cáo đã dựng. Hình dạng đổi theo `type` ⇒ gộp mọi trường thành optional.
struct CTWKhoiBaoCaoDb: Codable, Hashable, Identifiable {
    var id: String
    /// heading | text | pageBreak | kpis | chart | issues | risks | ai | error
    var type: String
    var text: String?
    var level: Int?
    var title: String?
    var items: [CTWMucKhoiBaoCaoDb]?
    /// SVG do máy chủ dựng (khối chart)
    var svg: String?
    var columns: [String]?
    var colKeys: [String]?
    var rows: [[String]]?
    var total: Int?
    var note: String?
    var generatedAt: String?
    var message: String?
}

struct CTWKyBaoCaoDb: Codable, Hashable {
    var from: String?
    var to: String?
    var kind: String?
}

struct CTWBaoCaoDungDb: Codable {
    var title: String?
    var subtitle: String?
    var lang: String?
    var period: CTWKyBaoCaoDb?
    var accent: String?
    var generatedAt: String?
    var blocks: [CTWKhoiBaoCaoDb]?
}
