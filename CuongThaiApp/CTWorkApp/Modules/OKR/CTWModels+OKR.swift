import Foundation

// MARK: - Model OKR (đối chiếu `services/work/okr.service.ts:341-470`, `agileRules.ts:15-27`)
// Cây mục tiêu chỉ có `parent` (objective dự án → objective không gian cùng chu kỳ) ⇒ app tự dựng con.

struct CTWOkrChuKy: Codable, Hashable, Identifiable {
    var id: Int
    var name: String?
    var startDate: String?
    var endDate: String?
    /// ACTIVE | CLOSED
    var status: String?
}

struct CTWOkrCheckin: Codable, Hashable, Identifiable {
    var id: Int
    var weekStart: String?
    var value: Double?
    var progress: Double?
    var confidence: Double?
    var note: String?
    var at: String?
    var user: CTWUser?
}

struct CTWOkrKR: Codable, Hashable, Identifiable {
    struct TomTatLienKet: Codable, Hashable { var done: Double?; var total: Double?; var unit: String? }
    var id: Int
    var title: String?
    /// PERCENT | NUMBER | BOOLEAN
    var metric: String?
    var unit: String?
    var startValue: Double?
    var targetValue: Double?
    var currentValue: Double?
    /// MANUAL | ISSUES | POINTS
    var source: String?
    var owner: CTWUser?
    var position: Int?
    /// 0…1
    var progress: Double?
    var score: Double?
    var suggestedScore: Double?
    var linkSummary: TomTatLienKet?
    /// 0–10, lần check-in gần nhất
    var confidence: Double?
    var canCheckin: Bool?
    var checkins: [CTWOkrCheckin]?

    var tuDong: Bool { (source ?? "MANUAL") != "MANUAL" }
}

struct CTWOkrMucTieu: Codable, Hashable, Identifiable {
    struct DuAnRef: Codable, Hashable { var key: String?; var name: String? }
    struct ChaRef: Codable, Hashable { var id: Int; var title: String? }
    var id: Int
    var cycleId: Int?
    var projectId: Int?
    var project: DuAnRef?
    var parent: ChaRef?
    var title: String?
    var description: String?
    var owner: CTWUser?
    var position: Int?
    /// 0…1
    var progress: Double?
    /// 0…1 — phần đã trôi của chu kỳ
    var expected: Double?
    /// NOT_STARTED | ON_TRACK | AT_RISK | OFF_TRACK | DONE | SCORED
    var status: String?
    var confidence: Double?
    var score: Double?
    var scoreBand: String?
    var scoreNote: String?
    var canEdit: Bool?
    var keyResults: [CTWOkrKR]?
}

struct CTWOkrBang: Codable {
    struct Tuan: Codable, Hashable { var week: String; var actual: Double?; var expected: Double?; var confidence: Double? }
    var objectives: Int?
    var keyResults: Int?
    var statusCounts: [String: Int]?
    /// 0–100
    var avgProgress: Double?
    var avgScore: Double?
    var avgConfidence: Double?
    var weeks: [Tuan]?
}

struct CTWOkrView: Codable {
    /// workspace | project
    var scope: String?
    var workspaceId: Int?
    var projectId: Int?
    var cycles: [CTWOkrChuKy]?
    var cycle: CTWOkrChuKy?
    var canEdit: Bool?
    var objectives: [CTWOkrMucTieu]?
    var dashboard: CTWOkrBang?
}

struct CTWOkrCheckinKQ: Codable { var ok: Bool?; var value: Double?; var progress: Double?; var weekStart: String? }

/// Phép tính thuần cho OKR (kiểm thử được).
enum OkrTinh {
    /// Tiến độ KR `(hiện tại − đầu)/(đích − đầu)` kẹp 0…1; BOOLEAN = 1 khi ≥ 1 (`agileRules.ts:24-27`).
    static func tienDo(metric: String?, dau: Double, dich: Double, hienTai: Double) -> Double {
        if metric == "BOOLEAN" { return hienTai >= 1 ? 1 : 0 }
        guard dich != dau else { return hienTai >= dich ? 1 : 0 }
        return min(max((hienTai - dau) / (dich - dau), 0), 1)
    }

    /// Cây: gốc = objective không có cha trong danh sách; con = objective có `parent.id` trỏ tới gốc.
    static func cay(_ ds: [CTWOkrMucTieu]) -> [(goc: CTWOkrMucTieu, con: [CTWOkrMucTieu])] {
        let ids = Set(ds.map(\.id))
        let goc = ds.filter { $0.parent.map { !ids.contains($0.id) } ?? true }
            .sorted { ($0.position ?? 0, $0.id) < ($1.position ?? 0, $1.id) }
        return goc.map { g in
            (g, ds.filter { $0.parent?.id == g.id }.sorted { ($0.position ?? 0, $0.id) < ($1.position ?? 0, $1.id) })
        }
    }

    static func tenTrangThai(_ s: String?) -> String {
        switch s {
        case "ON_TRACK": return "On track"
        case "AT_RISK": return "At risk"
        case "OFF_TRACK": return "Off track"
        case "DONE": return "Done"
        case "SCORED": return "Scored"
        default: return "Not started"
        }
    }

    static func bieuTuong(_ s: String?) -> String {
        switch s {
        case "ON_TRACK": return "checkmark.circle.fill"
        case "AT_RISK": return "exclamationmark.triangle.fill"
        case "OFF_TRACK": return "xmark.octagon.fill"
        case "DONE", "SCORED": return "flag.checkered"
        default: return "circle.dashed"
        }
    }

    /// "12 / 20 %" · "Yes/No".
    static func giaTri(_ k: CTWOkrKR) -> String {
        if k.metric == "BOOLEAN" { return (k.currentValue ?? 0) >= 1 ? "Done" : "Not yet" }
        let u = k.unit.map { $0 == "%" ? "%" : " \($0)" } ?? ""
        return "\(CTWSo.gon(k.currentValue ?? 0)) / \(CTWSo.gon(k.targetValue ?? 0))\(u)"
    }
}
