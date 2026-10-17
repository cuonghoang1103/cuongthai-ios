import Foundation

// MARK: - CT Work — model Nguồn lực/liên kết dự án (`resources.service.ts:48-196`)
// Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).
// Các trường "nội bộ" (createdById…canEdit, `broken`) CHỈ có khi người xem thuộc nhóm —
// khách cổng nhận bản rút gọn ⇒ tất cả optional.

struct CTWNhomNguonLuc: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var icon: String?
    var color: String?
    var rank: Double?
    var isDefault: Bool?
    var count: Int?
}

struct CTWNguonLuc: Codable, Hashable, Identifiable {
    struct GitHub: Codable, Hashable {
        var fullName: String?
        var stars: Int?
        var lastCommitAt: String?
        var description: String?
        var language: String?
    }
    var id: Int
    var groupId: Int?
    var groupName: String?
    var title: String?
    var url: String
    var description: String?
    var tags: [String]?
    var kind: String?
    var faviconUrl: String?
    var pinned: Bool?
    var visibility: String?
    var rank: Double?
    var github: GitHub?
    var createdByName: String?
    var lastOpenedAt: String?
    var openCount: Int?
    /// OK | BROKEN | UNKNOWN
    var linkStatus: String?
    var updatedAt: String?

    var tenHien: String {
        if let t = title, !t.trimmingCharacters(in: .whitespaces).isEmpty { return t }
        return URL(string: url)?.host ?? url
    }
}

struct CTWDsNguonLuc: Codable {
    struct DemThe: Codable, Hashable { var tag: String; var count: Int? }
    var groups: [CTWNhomNguonLuc]?
    var ungrouped: Int?
    var total: Int?
    var canEdit: Bool?
    var broken: Int?
    var tags: [DemThe]?
    var items: [CTWNguonLuc]?
}

struct CTWMoNguonLuc: Codable { var id: Int?; var url: String? }

enum CTWNguonLucHienThi {
    /// SF Symbol theo `kind` (resourceRules.ts:83-87) — không tải favicon bên thứ ba
    /// mỗi lần cuộn, và biểu tượng hệ thống tự đổi theo chế độ tối.
    static func bieuTuong(_ k: String?) -> String {
        switch k {
        case "github", "gitlab", "bitbucket": return "chevron.left.forwardslash.chevron.right"
        case "figma", "canva", "miro": return "paintpalette"
        case "gdrive", "onedrive", "dropbox", "sharepoint": return "externaldrive"
        case "gdoc", "gsheet", "gslide", "notion", "confluence": return "doc.richtext"
        case "youtube", "vimeo", "loom": return "play.rectangle"
        case "slack", "discord", "teams", "zalo": return "bubble.left.and.bubble.right"
        case "jira", "trello", "linear": return "checklist"
        case "vercel", "netlify", "render", "railway", "heroku": return "server.rack"
        case "swagger", "postman", "api": return "point.3.connected.trianglepath.dotted"
        default: return "link"
        }
    }
}
