import Foundation

// MARK: - Model chấm công (đối chiếu `services/work/timer.service.ts`, `planning.service.ts`,
// `timeActivity.service.ts`, `finance.service.ts`). Mọi trường `var` + optional, ngày là String (C3/C4).

/// Đồng hồ đang chạy — `view()` ở `timer.service.ts:42-53`. MỖI người MỘT đồng hồ (lưu ở máy chủ).
struct CTWDongHoChay: Codable, Hashable {
    var id: Int?
    var projectId: Int?
    var issueNumber: Int?
    var issueKey: String?
    var issueTitle: String?
    var projectKey: String?
    var projectName: String?
    var workspaceSlug: String?
    var url: String?
    var startedAt: String?
    var running: Bool?
    var runningSince: String?
    /// Giây đã chạy TÍNH ĐẾN `serverNow`.
    var elapsedSec: Int?
    var activity: String?
    var note: String?
    var remindAfterMin: Int?
    var overdue: Bool?
    var serverNow: String?

    var dangChay: Bool { running == true }
}

/// `GET /me/timer`, `PATCH /me/timer`, `pause`, `resume`, `GET issue timer`.
struct CTWDongHoGoi: Codable {
    var timer: CTWDongHoChay?
    var switched: CTWKetQuaDung?
    var onThisIssue: Bool?
}

/// `POST /me/timer/stop` — dưới 30 giây ⇒ `minutes = 0`, `worklog = nil` (không ghi gì).
struct CTWKetQuaDung: Codable, Hashable {
    struct Ghi: Codable, Hashable { var id: Int?; var minutes: Int? }
    var stopped: Bool?
    var issueKey: String?
    var elapsedSec: Int?
    var minutes: Int?
    var capped: Bool?
    var worklog: Ghi?
}

/// Một lần ghi giờ — `planning.service.ts:403-406`.
struct CTWWorklog: Codable, Hashable, Identifiable {
    var id: Int
    var minutes: Int?
    var startedAt: String?
    var note: String?
    /// MANUAL | AGENT_AUTO
    var source: String?
    var createdAt: String?
    var userId: Int?
    var user: CTWUser?
    var activity: String?
    var workProduct: String?
}

/// `GET /issues/:num/worklog-defaults`.
struct CTWWorklogMacDinh: Codable {
    var activity: String?
    var workProduct: String?
    var activities: [String]?
    var products: [String]?
}

/// `GET /projects/:pid/reports/time` — `planning.service.ts:476-517`.
struct CTWBaoCaoGio: Codable {
    struct The: Codable, Hashable { var number: Int?; var title: String?; var minutes: Int? }
    struct Nguoi: Codable, Hashable {
        var user: CTWUser?
        var userKind: String?
        var name: String?
        var totalMin: Int?
        var autoMin: Int?
        /// "YYYY-MM-DD" → phút
        var byDay: [String: Int]?
        var issues: [The]?
    }
    var from: String?
    var to: String?
    var principal: String?
    var totalMin: Int?
    var people: [Nguoi]?
}

/// `GET /projects/:pid/finance/timesheet?week=` — CHỈ phần app dùng (trạng thái tuần).
/// Module finance tắt / không có quyền ⇒ 403, app bỏ qua im lặng.
struct CTWBangGioTuan: Codable {
    struct Phieu: Codable, Hashable {
        var id: Int?
        /// SUBMITTED | APPROVED | RETURNED | REOPENED
        var status: String?
        var totalMinutes: Int?
        var returnReason: String?
        var submittedAt: String?
        var decidedAt: String?
    }
    var weekStart: String?
    var weekEnd: String?
    var totalMin: Int?
    var timesheet: Phieu?
    var locked: Bool?
}
