import SwiftUI

// MARK: - Model Change request (`services/work/changeRequests.service.ts` :38–54, :166–210)
// Một struct cho cả hàng danh sách lẫn chi tiết — trường chỉ có ở chi tiết để optional.

struct CTWCrLienKet: Codable, Hashable, Identifiable {
    struct The: Codable, Hashable { var number: Int; var key: String?; var title: String?; var done: Bool?; var status: CTWTrangThaiNhom? }
    struct GiaiDoan: Codable, Hashable { var id: Int; var n: Int?; var name: String?; var status: String? }
    struct PhienBan: Codable, Hashable { var id: Int; var name: String?; var status: String?; var releaseDate: String? }
    var id: Int
    /// AFFECTED | IMPLEMENTS
    var role: String?
    var createdAt: String?
    var issue: The?
    var stage: GiaiDoan?
    var version: PhienBan?
}

struct CTWCrRuiRo: Codable, Hashable { var number: Int; var type: String?; var title: String?; var status: String?; var probability: Int?; var impact: Int? }
struct CTWCrGoiY: Codable, Hashable { var title: String?; var description: String?; var typeKey: String? }

struct CTWCr: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    var key: String?
    var title: String
    /// DRAFT | SUBMITTED | UNDER_REVIEW | APPROVED | REJECTED | IMPLEMENTED
    var status: String?
    /// LOW | MEDIUM | HIGH
    var urgency: String?
    var scheduleDays: Int?
    var costAmount: Double?
    var costCurrency: String?
    var clientVisible: Bool?
    var submittedAt: String?
    var decidedAt: String?
    var implementedAt: String?
    var createdAt: String?
    var updatedAt: String?
    var owner: CTWUser?
    var requester: CTWUser?
    var pendingApprovalId: Int?
    var waitingDays: Int?
    // Chỉ ở chi tiết
    var descriptionJson: CTWNode?
    var reason: String?
    var impactScope: String?
    var impactRisk: String?
    var alternatives: String?
    var clientSharedAt: String?
    var version: Int?
    var createdById: Int?
    var createdBy: CTWUser?
    var sourceIssue: CTWDuyetTheRef?
    var links: [CTWCrLienKet]?
    var risks: [CTWCrRuiRo]?
    var canEdit: Bool?
    var canDelete: Bool?
    var canRequestApproval: Bool?
    var portalOn: Bool?
    var approvalsOn: Bool?
    var suggestions: [CTWCrGoiY]?

    var nhanKhoa: String { key ?? "CR-\(number)" }

    /// "+5 days" / "−2 days" / nil.
    var nhanLich: String? {
        guard let d = scheduleDays, d != 0 else { return nil }
        return "\(d > 0 ? "+" : "−")\(abs(d)) day\(abs(d) == 1 ? "" : "s")"
    }

    var nhanChiPhi: String? {
        guard let c = costAmount, c != 0 else { return nil }
        return CTWCrLuat.tien(c, costCurrency)
    }
}

struct CTWCrDanhSach: Codable {
    struct TienTe: Codable, Hashable { var currency: String?; var amount: Double? }
    struct Tong: Codable, Hashable {
        var approvedCount: Int?
        var approvedDays: Int?
        var approvedCost: [TienTe]?
        var pending: Int?
        var byStatus: [String: Int]?
    }
    var items: [CTWCr]?
    var totals: Tong?
    var canEdit: Bool?
    var canRequestApproval: Bool?
    var portalOn: Bool?
}

enum CTWCrLuat {
    static let trangThai = ["DRAFT", "SUBMITTED", "UNDER_REVIEW", "APPROVED", "REJECTED", "IMPLEMENTED"]

    /// Bước chuyển TAY được phép (`governance.ts` :23–34). UNDER_REVIEW/APPROVED/
    /// REJECTED chỉ đến từ phê duyệt — đặt tay máy chủ trả 409.
    static func buocTay(tu s: String?) -> [String] {
        switch s {
        case "DRAFT": return ["SUBMITTED"]
        case "SUBMITTED": return ["DRAFT"]
        case "REJECTED": return ["DRAFT"]
        case "APPROVED": return ["IMPLEMENTED"]
        default: return []
        }
    }

    /// Xin phê duyệt chỉ từ DRAFT/SUBMITTED.
    static func xinDuyetDuoc(_ s: String?) -> Bool { s == "DRAFT" || s == "SUBMITTED" }

    static func nhanBuoc(_ den: String) -> String {
        switch den {
        case "SUBMITTED": return "Submit"
        case "DRAFT": return "Move back to draft"
        case "IMPLEMENTED": return "Mark implemented"
        default: return CTWMauTrangThai.nhan(den)
        }
    }

    static func tien(_ v: Double, _ cur: String?) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = v.rounded() == v ? 0 : 2
        f.locale = Locale(identifier: "en_US")
        return "\(f.string(from: NSNumber(value: v)) ?? "\(v)") \(cur ?? "")".trimmingCharacters(in: .whitespaces)
    }
}

/// Tuyến chi tiết Change request.
struct RouteCrCTW: Hashable {
    var pid: Int
    var so: Int
}
