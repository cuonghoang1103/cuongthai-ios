import SwiftUI

// MARK: - Model phê duyệt (`services/work/approvals.service.ts` present(), `gateEvidence.ts`)
// Luật: mọi trường `var` + optional, ngày là chuỗi ISO (CLAUDE.md C3/C4).

struct CTWDuyetBuoc: Codable, Hashable, Identifiable {
    var id: Int
    var approverId: Int?
    var position: Int?
    /// PENDING | APPROVED | REJECTED | SKIPPED
    var decision: String?
    var comment: String?
    var decidedAt: String?
    var contentHash: String?
    var approver: CTWUser?
}

struct CTWDuyetTheRef: Codable, Hashable { var id: Int?; var number: Int; var title: String?; var clientVisible: Bool? }
struct CTWDuyetGiaiDoanRef: Codable, Hashable { var id: Int; var n: Int?; var slug: String?; var name: String?; var status: String? }
struct CTWDuyetTrangRef: Codable, Hashable { var id: Int?; var number: Int; var title: String?; var status: String?; var visibility: String? }
struct CTWDuyetCrRef: Codable, Hashable { var id: Int?; var number: Int; var title: String?; var status: String?; var clientVisible: Bool? }
struct CTWDuyetDuAnRef: Codable, Hashable { var id: Int; var key: String?; var name: String?; var workspaceSlug: String? }

struct CTWTrangThaiNhom: Codable, Hashable { var name: String?; var category: String? }

/// Bằng chứng của cổng giai đoạn (STAGE_GATE) — `gateEvidence.ts`.
struct CTWDuyetBangChung: Codable, Hashable {
    struct TieuChi: Codable, Hashable { var number: Int?; var key: String?; var title: String?; var done: Bool?; var text: String? }
    struct The: Codable, Hashable { var number: Int; var key: String?; var title: String?; var done: Bool?; var status: CTWTrangThaiNhom?; var type: String?; var pinned: Bool? }
    struct Trang: Codable, Hashable { var number: Int; var title: String?; var status: String?; var visibility: String? }
    struct Tep: Codable, Hashable, Identifiable { var id: Int; var fileName: String?; var mime: String?; var size: Int?; var deliverable: Bool?; var issueKey: String?; var clientVisible: Bool? }
    var criteria: TieuChi?
    var issues: [The]?
    var issueTotal: Int?
    var issueDone: Int?
    var pages: [Trang]?
    var files: [Tep]?
    var openAtRequest: Int?
    var openReason: String?
}

struct CTWDuyet: Codable, Hashable, Identifiable {
    var id: Int
    var projectId: Int?
    /// ISSUE | STAGE_GATE | DOC | CR | UAT
    var targetType: String?
    var title: String?
    var description: String?
    /// SEQUENTIAL | PARALLEL
    var mode: String?
    /// PENDING | APPROVED | REJECTED | CANCELLED
    var status: String?
    var dueAt: String?
    var contentHash: String?
    var decidedAt: String?
    var createdAt: String?
    var updatedAt: String?
    var clientNote: String?
    var createdBy: CTWUser?
    var issue: CTWDuyetTheRef?
    var stage: CTWDuyetGiaiDoanRef?
    var page: CTWDuyetTrangRef?
    var changeRequest: CTWDuyetCrRef?
    var steps: [CTWDuyetBuoc]?
    var issueKey: String?
    var currentHash: String?
    var signedHash: String?
    var contentChanged: Bool?
    var changedSinceRequest: Bool?
    var myStepId: Int?
    var canDecide: Bool?
    var canCancel: Bool?
    var waitingOn: [Int]?
    var evidence: CTWDuyetBangChung?
    /// Chỉ có ở `GET /me/approvals` (danh sách xuyên dự án).
    var project: CTWDuyetDuAnRef?

    // MARK: Hiển thị

    var dsBuoc: [CTWDuyetBuoc] { (steps ?? []).sorted { ($0.position ?? 0, $0.id) < ($1.position ?? 0, $1.id) } }
    var soDaDuyet: Int { dsBuoc.filter { $0.decision == "APPROVED" }.count }
    var dangCho: Bool { status == "PENDING" }
    var quaHan: Bool { dangCho && GovNgay.daQua(dueAt) }
    var tuanTu: Bool { mode != "PARALLEL" }

    /// Nhãn đối tượng: "NW-12", "CR-5", "Gate 2 · Analysis", "Doc 7".
    var nhanDoiTuong: String {
        switch targetType {
        case "CR": return changeRequest.map { "CR-\($0.number)" } ?? "Change request"
        case "STAGE_GATE": return stage.map { "Gate \($0.n.map(String.init) ?? "") · \($0.name ?? "Stage")" } ?? "Stage gate"
        case "DOC": return page.map { "Doc \($0.number)" } ?? "Document"
        case "UAT": return "UAT sign-off"
        default: return issueKey ?? issue.map { "#\($0.number)" } ?? "Issue"
        }
    }

    var bieuTuong: String { CTWDuyet.bieuTuong(targetType) }

    static func bieuTuong(_ t: String?) -> String {
        switch t {
        case "CR": return "arrow.triangle.branch"
        case "STAGE_GATE": return "flag.checkered"
        case "DOC": return "doc.text.fill"
        case "UAT": return "person.badge.shield.checkmark"
        default: return "checklist"
        }
    }

    /// Người đang phải ký (để hiện "Their turn" khi máy chủ không gửi `waitingOn`).
    /// Tuần tự: bước PENDING có `position` nhỏ nhất; song song: mọi bước PENDING.
    var dangChoAi: Set<Int> {
        if let w = waitingOn { return Set(w) }
        guard dangCho else { return [] }
        let cho = dsBuoc.filter { $0.decision == "PENDING" || $0.decision == nil }
        if tuanTu { return Set(cho.prefix(1).compactMap(\.approverId)) }
        return Set(cho.compactMap(\.approverId))
    }

    /// "8…4" — dấu băm rút gọn để người duyệt đối chiếu đúng phiên bản đã ký.
    static func bamNgan(_ h: String?) -> String? {
        guard let h, h.count >= 9 else { return h }
        return "\(h.prefix(8))…\(h.suffix(4))"
    }
}

/// Tuyến mở chi tiết phê duyệt — mô-đun khác (Docs, Stages, Change requests) đẩy được.
struct RouteDuyetCTW: Hashable {
    var pid: Int
    var id: Int
}
