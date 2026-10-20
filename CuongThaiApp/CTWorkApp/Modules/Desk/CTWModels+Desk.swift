import SwiftUI

// MARK: - CT Work — model Service desk (`services/work/serviceDesk.service.ts`, `slaRules.ts`;
// kiểu chuẩn ở `frontend/src/lib/work-s5a-api.ts`). Ticket = một THẺ + hàng `WorkDeskTicket`:
// hội thoại là bình luận thẻ, trạng thái/người làm đổi qua route thẻ.
// Luật: `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).

/// Một đích SLA (phản hồi đầu / giải quyết).
struct CTWSla: Codable, Hashable {
    var goalMin: Int?
    var calendar: String?
    var elapsedMin: Double?
    /// Âm = đã quá hạn.
    var remainingMin: Double?
    /// ON_TRACK | AT_RISK | BREACHED | MET
    var status: String?
    var stopped: Bool?
    var paused: Bool?
    var dueAt: String?
    var atRiskAt: String?
    var breachedAt: String?
    var stoppedAt: String?
    /// "2h left" | "35m over" | "Paused" | "Met" | "Breached"
    var label: String?
}

struct CTWDeskTrangThai: Codable, Hashable { var id: Int?; var name: String?; var category: String?; var color: String? }
struct CTWDeskNhom: Codable, Hashable, Identifiable { var id: Int; var key: String?; var name: String?; var color: String? }

struct CTWDeskMuc: Codable, Hashable, Identifiable {
    var number: Int
    var key: String?
    var title: String
    var requestType: String?
    var requestTypeName: String?
    /// P1 | P2 | P3 | P4
    var priority: String?
    var waiting: Bool?
    var paused: Bool?
    /// PORTAL | STAFF
    var channel: String?
    var shared: Bool?
    var status: CTWDeskTrangThai?
    var team: CTWDeskNhom?
    var assignee: CTWUser?
    var requester: CTWUser?
    var createdAt: String?
    var updatedAt: String?
    var resolvedAt: String?
    var firstResponse: CTWSla?
    var resolution: CTWSla?
    var problemId: Int?
    var csat: Int?
    var id: Int { number }
}

struct CTWDeskHang: Codable {
    var view: String?
    var counts: [String: Int]?
    var canWork: Bool?
    var now: String?
    var teams: [CTWDeskNhom]?
    var items: [CTWDeskMuc]?
    var truncated: Bool?
}

struct CTWDeskTicket: Codable {
    struct Truong: Codable, Hashable { var key: String?; var label: String?; var value: CTWGiaTri? }
    struct ThamChieu: Codable, Hashable { var number: Int?; var title: String?; var status: String? }
    struct Csat: Codable, Hashable { var requestedAt: String?; var rating: Int?; var comment: String?; var at: String? }
    struct SuKien: Codable, Hashable, Identifiable {
        var id: Int
        /// START | PAUSE | RESUME | FIRST_RESPONSE | RESOLVE | REOPEN | PRIORITY
        var kind: String?
        var at: String?
        var value: String?
        var note: String?
        var actor: String?
    }
    var requestType: String?
    var requestTypeName: String?
    var impact: String?
    var urgency: String?
    var priority: String?
    var channel: String?
    var requester: CTWUser?
    var fields: [Truong]?
    var waiting: Bool?
    var waitingSince: String?
    var firstResponseAt: String?
    var firstResponseBy: String?
    var paused: Bool?
    var firstResponse: CTWSla?
    var resolution: CTWSla?
    var problem: ThamChieu?
    var changeRequest: ThamChieu?
    var csat: Csat?
    var events: [SuKien]?
    var createdAt: String?
}

struct CTWDeskChiTiet: Codable {
    struct LoaiYeuCau: Codable, Hashable { var key: String?; var name: String?; var enabled: Bool? }
    var enabled: Bool?
    var canWork: Bool?
    var requestTypes: [LoaiYeuCau]?
    var ticket: CTWDeskTicket?
}

// MARK: Nhãn

enum CTWDesk {
    /// Bộ xem của hàng chờ — thứ tự chip trên màn.
    static var cheDo: [(ma: String, nhan: String, bieuTuong: String)] { [
        ("open", String(localized: "Open"), "tray.full"),
        ("unassigned", String(localized: "Unassigned"), "person.crop.circle.badge.questionmark"),
        ("mine", String(localized: "Mine"), "person.fill"),
        ("at_risk", String(localized: "At risk"), "exclamationmark.triangle"),
        ("breached", String(localized: "Breached"), "flame"),
        ("waiting", String(localized: "Waiting"), "pause.circle"),
        ("resolved", String(localized: "Resolved"), "checkmark.circle"),
    ] }

    static let mucDo = ["HIGH", "MEDIUM", "LOW"]
    static let uuTien = ["P1", "P2", "P3", "P4"]

    static func mauUuTien(_ p: String?) -> Color {
        switch p {
        case "P1": return AppColors.error
        case "P2": return Color(hex: 0xEA580C)
        case "P3": return AppColors.info
        default: return AppColors.textSecondary
        }
    }

    /// Màu SLA: đã dừng (đạt) xanh, tạm dừng xám, có nguy cơ vàng, vỡ đỏ.
    static func mauSla(_ s: CTWSla?) -> Color {
        guard let s else { return AppColors.textTertiary }
        if s.paused == true && s.status != "BREACHED" { return AppColors.textSecondary }
        switch s.status {
        case "MET": return AppColors.success
        case "BREACHED": return AppColors.error
        case "AT_RISK": return AppColors.warning
        default: return AppColors.info
        }
    }

    static func nhanSla(_ s: CTWSla?) -> String {
        guard let s else { return "—" }
        if let l = s.label, !l.isEmpty { return l }
        if s.paused == true { return String(localized: "Paused") }
        return CTWMauTrangThai.nhan(s.status)
    }

    static func bieuTuongLoai(_ k: String?) -> String {
        switch k {
        case "INCIDENT": return "exclamationmark.octagon"
        case "SERVICE_REQUEST": return "wrench.and.screwdriver"
        case "QUESTION": return "questionmark.bubble"
        case "CHANGE": return "arrow.triangle.2.circlepath"
        default: return "ticket"
        }
    }

    static func nhanSuKien(_ k: String?) -> (String, String) {
        switch k {
        case "START": return (String(localized: "Ticket opened"), "play.circle")
        case "PAUSE": return (String(localized: "Waiting on customer"), "pause.circle")
        case "RESUME": return (String(localized: "Resumed"), "play.circle")
        case "FIRST_RESPONSE": return (String(localized: "First response"), "arrowshape.turn.up.left")
        case "RESOLVE": return (String(localized: "Resolved"), "checkmark.circle")
        case "REOPEN": return (String(localized: "Reopened"), "arrow.uturn.backward.circle")
        case "PRIORITY": return (String(localized: "Priority changed"), "flag")
        default: return (CTWMauTrangThai.nhan(k), "circle")
        }
    }
}
