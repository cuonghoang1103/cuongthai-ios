import Foundation

// MARK: - CT Work — model mô-đun Docs (`services/work/pages.service.ts`, `kb.service.ts`)
// Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).

// MARK: Danh sách trang

struct CTWPageSummary: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    /// `id` (KHÔNG phải `number`) của trang cha.
    var parentId: Int?
    var title: String
    /// DRAFT | IN_REVIEW | APPROVED | ARCHIVED
    var status: String?
    /// INTERNAL | CLIENT
    var visibility: String?
    var position: Double?
    var updatedAt: String?
    var aiAssisted: Bool?
    var ownerId: Int?
    var owner: CTWUser?
}

struct CTWPagesList: Codable {
    var pages: [CTWPageSummary]?
    var canEdit: Bool?
    var canManage: Bool?
    var approvalsOn: Bool?
}

struct CTWPageHit: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    var title: String
    var status: String?
    var updatedAt: String?
    var snippet: String?
}

struct CTWPageMarkdown: Codable {
    var filename: String?
    var markdown: String?
}

// MARK: Một trang

struct CTWPageDetail: Codable {
    struct Ref: Codable, Hashable, Identifiable { var id: Int; var number: Int; var title: String; var status: String? }
    struct TheLienKet: Codable, Hashable, Identifiable {
        struct TrangThai: Codable, Hashable { var name: String?; var category: String? }
        struct Loai: Codable, Hashable { var key: String?; var name: String?; var icon: String?; var color: String? }
        var linkId: Int?
        var id: Int
        var number: Int
        var title: String
        var key: String?
        var resolvedAt: String?
        var status: TrangThai?
        var type: Loai?
    }
    struct DuyetTomTat: Codable, Hashable {
        var id: Int
        var status: String?
        var decidedAt: String?
        var createdAt: String?
        var contentChanged: Bool?
        var changedSinceRequest: Bool?
    }

    var id: Int
    var number: Int
    var title: String
    var status: String?
    var visibility: String?
    var updatedAt: String?
    var aiAssisted: Bool?
    var ownerId: Int?
    var owner: CTWUser?
    var lastEditedBy: CTWUser?
    /// Bộ đếm lần LƯU — khoá lạc quan của PATCH (khác `currentVersion` = số ảnh chụp lịch sử).
    var version: Int?
    var currentVersion: Int?
    var versionCount: Int?
    var contentJson: CTWNode?
    var ancestors: [Ref]?
    var children: [Ref]?
    var issues: [TheLienKet]?
    var approval: DuyetTomTat?
    var approvalsOn: Bool?
    var canEdit: Bool?
    var canManage: Bool?
    var canComment: Bool?
    var canRequestApproval: Bool?
}

/// `data` của lỗi 409 `WORK_PAGE_CONFLICT`.
struct CTWPageXungDot: Codable { var version: Int?; var by: CTWUser? }

// MARK: Phiên bản

struct CTWPageVersion: Codable, Hashable, Identifiable {
    var id: Int
    var n: Int
    /// CREATE | EDIT | RESTORE | MANUAL
    var kind: String?
    var title: String?
    var note: String?
    var createdAt: String?
    var updatedAt: String?
    var author: CTWUser?
    var chars: Int?
    var contentJson: CTWNode?
}

struct CTWPageCompare: Codable {
    struct Dong: Codable, Hashable { var op: String; var text: String }
    var lines: [Dong]?
    var added: Int?
    var removed: Int?
}

// MARK: Bình luận trang

struct CTWPageComment: Codable, Hashable, Identifiable {
    struct NeoChu: Codable, Hashable { var anchorId: String?; var quote: String?; var resolvedAt: String? }
    var id: Int
    var bodyJson: CTWNode?
    var bodyText: String?
    var createdAt: String?
    var editedAt: String?
    var authorId: Int?
    var author: CTWUser?
    var parentId: Int?
    var anchor: NeoChu?
    var canDelete: Bool?
}

// MARK: Khoá sửa · ảnh · thùng rác

struct CTWEditLock: Codable { var locked: Bool?; var since: String? }

struct CTWAnhTaiLieu: Codable { var id: Int; var url: String; var width: Int?; var height: Int? }

struct CTWTrashPages: Codable {
    struct Muc: Codable, Hashable, Identifiable {
        struct NguoiXoa: Codable, Hashable { var id: Int?; var name: String? }
        struct VeCho: Codable, Hashable { var number: Int?; var title: String? }
        var id: Int
        var number: Int
        var title: String
        var deletedAt: String?
        var childCount: Int?
        var deletedBy: NguoiXoa?
        var restoresTo: VeCho?
        var canRestore: Bool?
    }
    var canPurge: Bool?
    var items: [Muc]?
}

struct CTWTrashRestore: Codable { var restored: Int?; var number: Int?; var toTopLevel: Bool? }

// MARK: KB

struct CTWKb: Codable {
    struct DanhMuc: Codable, Hashable, Identifiable {
        var id: Int; var name: String; var description: String?; var position: Int?; var articles: Int?
    }
    struct BaiViet: Codable, Hashable, Identifiable {
        struct DM: Codable, Hashable { var id: Int?; var name: String? }
        var id: Int
        var title: String?
        var pageNumber: Int
        var category: DM?
        var excerpt: String?
        var updatedAt: String?
        /// CLIENT | INTERNAL
        var audience: String?
        var published: Bool?
        var pageStatus: String?
        var views: Int?
        var helpful: Int?
        var notHelpful: Int?
        var deflected: Int?
        var helpfulPercent: Int?
        var hiddenFromClients: Bool?
    }
    struct Tong: Codable, Hashable {
        var articles: Int?; var forClients: Int?; var views: Int?; var deflected: Int?; var helpful: Int?; var notHelpful: Int?
    }
    var canEdit: Bool?
    var categories: [DanhMuc]?
    var articles: [BaiViet]?
    var totals: Tong?
}

// MARK: Nhãn trạng thái tài liệu

enum CTWDocStatus {
    static let tatCa = ["DRAFT", "IN_REVIEW", "APPROVED", "ARCHIVED"]

    static func ten(_ s: String?) -> String {
        switch s {
        case "IN_REVIEW": return "In review"
        case "APPROVED": return "Approved"
        case "ARCHIVED": return "Archived"
        default: return "Draft"
        }
    }

    static func bieuTuong(_ s: String?) -> String {
        switch s {
        case "IN_REVIEW": return "eye"
        case "APPROVED": return "checkmark.seal"
        case "ARCHIVED": return "archivebox"
        default: return "pencil.line"
        }
    }

    /// Trạng thái chuyển tới được (luật `pages.service.ts` 381–411):
    /// - ARCHIVED chỉ về DRAFT.
    /// - Bật mô-đun Phê duyệt ⇒ IN_REVIEW/APPROVED KHÔNG đặt tay (phải xin duyệt).
    /// - Tắt ⇒ ai sửa được cũng đặt IN_REVIEW; chỉ quản lý (`canManage`) đặt APPROVED.
    static func dich(tu: String?, duyetBat: Bool, quanLy: Bool) -> [String] {
        let hien = tu ?? "DRAFT"
        if hien == "ARCHIVED" { return ["DRAFT"] }
        var out = ["DRAFT"]
        if !duyetBat {
            out.append("IN_REVIEW")
            if quanLy { out.append("APPROVED") }
        }
        out.append("ARCHIVED")
        return out.filter { $0 != hien }
    }
}
