import Foundation

// MARK: - CT Work — model Cổng khách (`services/work/portal.service.ts`; kiểu ở
// `frontend/src/lib/work-api.ts` 1677–1795). Khách chỉ thấy thẻ ĐÃ CHIA SẺ, bình
// luận PUBLIC, tài liệu/tệp đã chia sẻ; nhân viên ngoài phạm vi bị che thành
// "Project team". Đội dự án xem thử bằng `?as=client` (chỉ đọc).
// `var` + optional, ngày là chuỗi.

struct CTWPortalNguoiXem: Codable, Hashable {
    var clientView: Bool?
    var preview: Bool?
    var isClient: Bool?
    var canManage: Bool?
    var canInvite: Bool?
    var canRequestUat: Bool?
    var canSubmitRequest: Bool?
}

struct CTWPortalTongQuan: Codable {
    struct DuAn: Codable { var key: String?; var name: String?; var description: String?; var workspaceName: String?; var organization: String? }
    struct GiaiDoan: Codable, Hashable, Identifiable {
        var id: Int; var n: Int?; var name: String?; var status: String?; var percent: Double?; var startedAt: String?; var completedAt: String?
    }
    struct MocPhatHanh: Codable, Hashable, Identifiable {
        var id: Int; var name: String?; var status: String?; var releaseDate: String?; var releasedAt: String?; var items: Int?; var done: Int?
    }
    struct ChoKhach: Codable, Hashable, Identifiable {
        var id: Int; var title: String?; var kind: String?; var dueAt: String?; var createdAt: String?
    }
    struct Dem: Codable { var sharedOpen: Int?; var sharedDone: Int?; var requestsOpen: Int? }
    var project: DuAn?
    var viewer: CTWPortalNguoiXem?
    var stages: [GiaiDoan]?
    var overallPercent: Double?
    var milestones: [MocPhatHanh]?
    var waitingOnClient: [ChoKhach]?
    var counts: Dem?
}

struct CTWPortalYeuCau: Codable, Hashable, Identifiable {
    struct Loai: Codable, Hashable { var key: String?; var name: String?; var icon: String?; var color: String? }
    struct TrangThai: Codable, Hashable { var name: String?; var category: String?; var color: String? }
    var number: Int
    var key: String?
    var title: String
    var priority: Int?
    var type: Loai?
    var status: TrangThai?
    var stage: String?
    var fromClient: Bool?
    var mine: Bool?
    var replies: Int?
    var files: Int?
    var createdAt: String?
    var updatedAt: String?
    var resolvedAt: String?
    var id: Int { number }
}

struct CTWPortalDsYeuCau: Codable { var viewer: CTWPortalNguoiXem?; var items: [CTWPortalYeuCau]? }

struct CTWPortalYeuCauCT: Codable {
    struct GD: Codable { var n: Int?; var name: String?; var status: String? }
    struct PB: Codable { var name: String?; var releaseDate: String?; var status: String? }
    var number: Int
    var key: String?
    var title: String
    var descriptionJson: CTWNode?
    var priority: Int?
    var createdAt: String?
    var updatedAt: String?
    var resolvedAt: String?
    var dueDate: String?
    var type: CTWPortalYeuCau.Loai?
    var status: CTWPortalYeuCau.TrangThai?
    var stage: GD?
    var fixVersion: PB?
    var reporter: CTWUser?
    var fromClient: Bool?
    var attachments: [CTWAttachment]?
    var comments: [CTWComment]?
    var viewer: CTWPortalNguoiXem?
}

struct CTWPortalDuyet: Codable, Hashable, Identifiable {
    struct Buoc: Codable, Hashable, Identifiable {
        var id: Int; var position: Int?; var decision: String?; var decidedAt: String?
        var approver: CTWUser?; var isClient: Bool?; var comment: String?
    }
    struct The: Codable, Hashable { var number: Int?; var title: String?; var key: String? }
    struct Trang: Codable, Hashable { var number: Int?; var title: String? }
    var id: Int
    /// ISSUE | STAGE_GATE | DOC | UAT | CR
    var targetType: String?
    var title: String?
    var description: String?
    var mode: String?
    var status: String?
    var dueAt: String?
    var decidedAt: String?
    var createdAt: String?
    var createdBy: CTWUser?
    var issue: The?
    var page: Trang?
    var steps: [Buoc]?
    var waitingOnClient: Bool?
    var canDecide: Bool?
    var contentChanged: Bool?
    var clientNote: String?
}

struct CTWPortalDsDuyet: Codable { var viewer: CTWPortalNguoiXem?; var items: [CTWPortalDuyet]? }

struct CTWPortalTaiLieu: Codable {
    struct Trang: Codable, Hashable, Identifiable {
        var number: Int; var title: String; var status: String?; var updatedAt: String?
        var id: Int { number }
    }
    struct Tep: Codable, Hashable, Identifiable {
        struct The: Codable, Hashable { var number: Int?; var title: String?; var key: String? }
        var id: Int; var fileName: String?; var mime: String?; var size: Int?; var createdAt: String?; var issue: The?
    }
    var viewer: CTWPortalNguoiXem?
    var pages: [Trang]?
    var files: [Tep]?
}

struct CTWPortalTrang: Codable {
    var number: Int
    var title: String
    var status: String?
    var contentJson: CTWNode?
    var updatedAt: String?
    var owner: CTWUser?
}

struct CTWPortalTaoYeuCau: Codable { var number: Int?; var key: String? }

enum CTWPortal {
    static var loaiYeuCau: [(ma: String, nhan: String, bieuTuong: String)] { [
        ("BUG", String(localized: "Report a problem"), "ladybug"),
        ("CHANGE", String(localized: "Request a change"), "arrow.triangle.2.circlepath"),
        ("QUESTION", String(localized: "Ask a question"), "questionmark.bubble"),
        ("FEEDBACK", String(localized: "Share feedback"), "hand.thumbsup"),
    ] }
    static var locYeuCau: [(ma: String, nhan: String)] { [("all", String(localized: "All")), ("open", String(localized: "Open")), ("done", String(localized: "Done")), ("mine", String(localized: "Mine"))] }
}
