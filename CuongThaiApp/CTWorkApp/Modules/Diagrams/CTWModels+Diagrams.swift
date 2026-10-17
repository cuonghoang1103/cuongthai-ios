import Foundation

// MARK: - CT Work — model Sơ đồ (`diagrams.service.ts:117-180`)
// Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).

/// Người trong mô-đun sơ đồ — máy chủ trả dạng gọn `{id,name,username,isAgent}`
/// (KHÔNG phải PublicUser) ⇒ đổi sang `CTWUser` để dùng chung avatar + nhãn AI.
struct CTWNguoiSoDo: Codable, Hashable {
    var id: Int
    var name: String?
    var username: String?
    var isAgent: Bool?
    var nguoi: CTWUser {
        CTWUser(id: id, username: username, fullName: nil, displayName: name, avatarUrl: nil, role: nil, kind: isAgent == true ? "AGENT" : "HUMAN")
    }
}

struct CTWSoDo: Codable, Hashable, Identifiable {
    struct The: Codable, Hashable { var number: Int?; var key: String?; var title: String? }
    struct UC: Codable, Hashable { var number: Int?; var key: String?; var name: String? }
    struct Trang: Codable, Hashable { var number: Int?; var title: String? }
    var id: Int
    var number: Int
    var key: String?
    /// MERMAID | EXCALIDRAW | SQL
    var format: String?
    var type: String?
    var typeLabel: String?
    var title: String
    var description: String?
    var feature: String?
    /// PROPOSED | DRAFT | APPROVED
    var status: String?
    var currentVersion: Int?
    var approvedVersion: Int?
    var aiModel: String?
    var createdAt: String?
    var updatedAt: String?
    var issue: The?
    var useCase: UC?
    var page: Trang?
    var updatedBy: CTWNguoiSoDo?
    var openComments: Int?
    var pendingProposals: Int?
}

struct CTWDsSoDo: Codable {
    var canEdit: Bool?
    var canApprove: Bool?
    var canComment: Bool?
    var items: [CTWSoDo]?
}

struct CTWSoDoChiTiet: Codable {
    struct PhienBan: Codable, Hashable, Identifiable {
        var number: Int
        var note: String?
        var state: String?
        var author: CTWNguoiSoDo?
        var aiModel: String?
        var createdAt: String?
        var id: Int { number }
    }
    struct BinhLuan: Codable, Hashable, Identifiable {
        var id: Int
        var parentId: Int?
        var versionNumber: Int?
        var anchor: String?
        var body: String?
        var resolved: Bool?
        var createdAt: String?
        var author: CTWNguoiSoDo?
        var mine: Bool?
    }
    var id: Int
    var number: Int
    var key: String?
    var format: String?
    var type: String?
    var typeLabel: String?
    var title: String
    var description: String?
    var status: String?
    var currentVersion: Int?
    var approvedVersion: Int?
    var aiModel: String?
    var updatedAt: String?
    var issue: CTWSoDo.The?
    var useCase: CTWSoDo.UC?
    var page: CTWSoDo.Trang?
    var updatedBy: CTWNguoiSoDo?
    var canComment: Bool?
    var versions: [PhienBan]?
    var comments: [BinhLuan]?

    /// Bản mặc định để xem — như máy chủ: bản đã duyệt, không có thì bản mới nhất.
    var banMacDinh: Int? { approvedVersion ?? currentVersion }
}
