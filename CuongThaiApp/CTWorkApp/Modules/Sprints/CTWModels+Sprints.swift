import Foundation

// MARK: - Model mô-đun Sprints
//
// Đối chiếu backend `services/work/sprints.service.ts` (SPRINT_SELECT :52-55, report :188-199)
// và `services/work/reports.service.ts` (burndown :48-76, sprint :96-102).
// Luật kho: mọi trường `var` + optional, ngày là `String` (CLAUDE.md C3/C4).

/// Sprint ĐẦY ĐỦ (`GET /sprints`, PATCH/start trả về). `CTWSprint` lõi thiếu các trường điểm.
struct CTWSprintDu: Codable, Hashable, Identifiable {
    var id: Int
    var name: String?
    var goal: String?
    /// PLANNED | ACTIVE | CLOSED
    var state: String?
    var startAt: String?
    var endAt: String?
    var completedAt: String?
    var committedPoints: Double?
    var completedPoints: Double?
    var position: Int?

    var ten: String { name ?? String(localized: "Sprint \(id)") }
    var dangChay: Bool { state == "ACTIVE" }
    var daDong: Bool { state == "CLOSED" }
    var chuaBatDau: Bool { state == "PLANNED" || state == nil }
}

struct CTWSprintReportItem: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int?
    var title: String?
    var points: Double?
}

/// Báo cáo sprint (khi hoàn tất, hoặc tính sống khi chưa đóng).
struct CTWSprintReport: Codable, Hashable {
    var completed: [CTWSprintReportItem]?
    var incomplete: [CTWSprintReportItem]?
    /// SỐ thẻ thêm vào sau khi bắt đầu.
    var added: [Int]?
    /// SỐ thẻ bị rút ra sau khi bắt đầu.
    var removed: [Int]?
    var committedPoints: Double?
    var completedPoints: Double?
    /// POINTS | HOURS
    var unit: String?
}

/// `POST /sprints/:sid/complete` → `{report, movedTo}`.
struct CTWSprintCompleteKetQua: Codable {
    var report: CTWSprintReport?
    var movedTo: Int?
}

/// Sprint trong báo cáo burndown/sprint report (có thêm `report` thô — bỏ qua, vì hình dạng
/// khác nhau theo trạng thái: ACTIVE `{committedIssueIds}`, CLOSED = SprintReport).
struct CTWSprintBaoCao: Codable, Hashable {
    var id: Int
    var name: String?
    var goal: String?
    var state: String?
    var startAt: String?
    var endAt: String?
    var completedAt: String?
    var committedPoints: Double?
    var completedPoints: Double?
}

struct CTWBurndownDiem: Codable, Hashable {
    /// "YYYY-MM-DD" giờ VN
    var day: String
    /// nil = ngày tương lai
    var remaining: Double?
    var total: Double?
    var done: Double?
    var ideal: Double?
}

/// `GET /reports/burndown?sprintId=`
struct CTWBurndown: Codable {
    var sprint: CTWSprintBaoCao?
    /// POINTS | HOURS
    var unit: String?
    var points: [CTWBurndownDiem]?
}

/// `GET /reports/sprint?sprintId=`
struct CTWBaoCaoSprint: Codable {
    var sprint: CTWSprintBaoCao?
    var report: CTWSprintReport?
}

extension CTWSprintReport {
    var soXong: Int { completed?.count ?? 0 }
    var soChuaXong: Int { incomplete?.count ?? 0 }
}

/// Đơn vị ước lượng: "pts" / "h".
enum DonViSprintCTW {
    static func ten(_ unit: String?) -> String { unit == "HOURS" ? String(localized: "h") : String(localized: "pts") }
    static func tenDai(_ unit: String?) -> String { unit == "HOURS" ? String(localized: "hours") : String(localized: "points") }
    static func so(_ v: Double?, _ unit: String?) -> String {
        guard let v else { return "—" }
        return "\(CTWSo.gon(v)) \(ten(unit))"
    }
}
