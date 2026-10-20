import SwiftUI

// MARK: - Model RAID (`services/work/raid.service.ts` :35–58, `governance.ts`)

struct CTWRaidLienKet: Codable, Hashable, Identifiable {
    struct The: Codable, Hashable { var number: Int; var key: String?; var title: String?; var done: Bool?; var status: CTWTrangThaiNhom? }
    struct GiaiDoan: Codable, Hashable { var id: Int; var n: Int?; var name: String?; var status: String? }
    struct Cr: Codable, Hashable { var number: Int; var key: String?; var title: String?; var status: String? }
    var id: Int
    var issue: The?
    var stage: GiaiDoan?
    var changeRequest: Cr?
}

struct CTWRaidLichSu: Codable, Hashable, Identifiable {
    var id: Int
    var field: String?
    var fromValue: String?
    var toValue: String?
    var createdAt: String?
    var actor: CTWUser?
}

struct CTWRaid: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    /// RISK | ASSUMPTION | ISSUE | DEPENDENCY | QUESTION
    var type: String?
    var title: String
    var description: String?
    var category: String?
    var status: String?
    var probability: Int?
    var impact: Int?
    var clientVisible: Bool?
    /// AVOID | MITIGATE | TRANSFER | ACCEPT
    var response: String?
    var mitigation: String?
    var trigger: String?
    /// "YYYY-MM-DD"
    var reviewDate: String?
    var closedAt: String?
    var createdAt: String?
    var updatedAt: String?
    var version: Int?
    var createdById: Int?
    var owner: CTWUser?
    var key: String?
    var score: Int?
    /// HIGH | MEDIUM | LOW
    var level: String?
    var closed: Bool?
    var reviewDue: Bool?
    var linkCount: Int?
    // Chi tiết
    var createdBy: CTWUser?
    var links: [CTWRaidLienKet]?
    var history: [CTWRaidLichSu]?
    var statuses: [String]?
    var canEdit: Bool?
    var canDelete: Bool?

    var nhanKhoa: String { key ?? CTWRaidLuat.khoa(type, number) }
}

struct CTWRaidDanhSach: Codable {
    struct Dem: Codable, Hashable { var total: Int?; var open: Int? }
    struct Nguong: Codable, Hashable { var HIGH: Int?; var MEDIUM: Int? }
    var today: String?
    var items: [CTWRaid]?
    /// 5×5, `[xácSuất-1][tácĐộng-1]`, chỉ rủi ro đang mở.
    var matrix: [[Int]]?
    var counts: [String: Dem]?
    var reviewDue: Int?
    var highRisks: Int?
    var thresholds: Nguong?
    var canEdit: Bool?
}

enum CTWRaidLuat {
    static var loai: [(ma: String, ten: String, bieuTuong: String)] { [
        ("RISK", String(localized: "Risks"), "exclamationmark.triangle"),
        ("ASSUMPTION", String(localized: "Assumptions"), "lightbulb"),
        ("ISSUE", String(localized: "Issues"), "exclamationmark.bubble"),
        ("DEPENDENCY", String(localized: "Dependencies"), "point.3.connected.trianglepath.dotted"),
        ("QUESTION", String(localized: "Questions"), "questionmark.circle"),
    ] }

    static func tenLoai(_ m: String?) -> String {
        switch m {
        case "RISK": return String(localized: "Risk")
        case "ASSUMPTION": return String(localized: "Assumption")
        case "ISSUE": return String(localized: "Issue")
        case "DEPENDENCY": return String(localized: "Dependency")
        case "QUESTION": return String(localized: "Question")
        default: return String(localized: "Item")
        }
    }

    static func khoa(_ type: String?, _ so: Int) -> String {
        let t: String
        switch type {
        case "ASSUMPTION": t = "A"
        case "ISSUE": t = "I"
        case "DEPENDENCY": t = "D"
        case "QUESTION": t = "Q"
        default: t = "R"
        }
        return "\(t)-\(so)"
    }

    /// Trạng thái hợp lệ theo loại (`raidStatusesFor`) — dùng khi máy chủ chưa gửi `statuses`.
    static func trangThai(cho type: String?) -> [String] {
        switch type {
        case "ASSUMPTION": return ["UNVALIDATED", "VALIDATED", "INVALID"]
        case "QUESTION": return ["OPEN", "ANSWERED", "CANCELLED"]
        default: return ["OPEN", "MONITORING", "MITIGATED", "CLOSED"]
        }
    }

    static func macDinh(cho type: String?) -> String { trangThai(cho: type).first ?? "OPEN" }

    /// Điểm = xác suất × tác động (1–5 mỗi trục).
    static func diem(_ p: Int?, _ i: Int?) -> Int? {
        guard let p, let i, (1...5).contains(p), (1...5).contains(i) else { return nil }
        return p * i
    }

    /// ≥15 HIGH · ≥8 MEDIUM · còn lại LOW (`thresholds` của máy chủ).
    static func muc(_ diem: Int?, cao: Int = 15, vua: Int = 8) -> String? {
        guard let d = diem else { return nil }
        return d >= cao ? "HIGH" : (d >= vua ? "MEDIUM" : "LOW")
    }

    static func mauMuc(_ m: String?) -> Color {
        switch m {
        case "HIGH": return AppColors.error
        case "MEDIUM": return AppColors.warning
        case "LOW": return AppColors.success
        default: return AppColors.textTertiary
        }
    }

    static let phanUng = ["AVOID", "MITIGATE", "TRANSFER", "ACCEPT"]

    static func tenTruong(_ f: String?) -> String {
        switch f {
        case "status": return String(localized: "status")
        case "probability": return String(localized: "probability")
        case "impact": return String(localized: "impact")
        case "ownerId", "owner": return String(localized: "owner")
        case "response": return String(localized: "response")
        case "type": return String(localized: "type")
        case "title": return String(localized: "title")
        case "reviewDate": return String(localized: "review date")
        case "created": return String(localized: "created")
        default: return f ?? String(localized: "field")
        }
    }
}

struct RouteRaidCTW: Hashable {
    var pid: Int
    var so: Int
}
