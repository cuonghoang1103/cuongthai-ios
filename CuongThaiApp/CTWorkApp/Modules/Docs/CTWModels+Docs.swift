import Foundation

// MARK: - CT Work — model mô-đun Docs (`services/work/pages.service.ts`)
// Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).

// MARK: Tài liệu (Docs)

struct CTWPageSummary: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int
    var parentId: Int?
    var title: String
    /// DRAFT | IN_REVIEW | APPROVED | ARCHIVED
    var status: String?
    var visibility: String?
    var position: Double?
    var updatedAt: String?
    var aiAssisted: Bool?
    var owner: CTWUser?
}

struct CTWPagesList: Codable {
    var pages: [CTWPageSummary]?
    var canEdit: Bool?
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

struct CTWPageDetail: Codable {
    struct Ref: Codable, Hashable, Identifiable { var id: Int; var number: Int; var title: String }
    var id: Int
    var number: Int
    var title: String
    var status: String?
    var updatedAt: String?
    var aiAssisted: Bool?
    var owner: CTWUser?
    var lastEditedBy: CTWUser?
    var ancestors: [Ref]?
    var children: [Ref]?
}

// MARK: Nhãn trạng thái tài liệu

enum CTWDocStatus {
    static func ten(_ s: String?) -> String {
        switch s {
        case "IN_REVIEW": return "In review"
        case "APPROVED": return "Approved"
        case "ARCHIVED": return "Archived"
        default: return "Draft"
        }
    }
}

