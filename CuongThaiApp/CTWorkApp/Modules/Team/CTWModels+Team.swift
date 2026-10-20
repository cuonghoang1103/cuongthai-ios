import Foundation

// MARK: - CT Work — model mô-đun Team (`projects.service.ts` members, `teams.service.ts`,
// `workspaces.service.ts` invite-links, `uxc.service.ts` team-overview)
// Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).

/// Vai trò dự án (`ProjectRole`, constants.ts:10).
enum CTWVaiTroDuAn: String, CaseIterable, Identifiable {
    case ADMIN, MEMBER, VIEWER, TEACHER, CLIENT
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .ADMIN: return String(localized: "Admin")
        case .MEMBER: return String(localized: "Member")
        case .VIEWER: return String(localized: "Viewer")
        case .TEACHER: return String(localized: "Teacher")
        case .CLIENT: return String(localized: "Client")
        }
    }
    var moTa: String {
        switch self {
        case .ADMIN: return String(localized: "Full control, settings and members")
        case .MEMBER: return String(localized: "Create, edit and move issues")
        case .VIEWER: return String(localized: "Read-only")
        case .TEACHER: return String(localized: "Read, comment and approve")
        case .CLIENT: return String(localized: "Client portal access only")
        }
    }
    /// Agent chỉ được MEMBER/VIEWER (máy chủ trả `WORK_AGENT_ROLE` nếu khác).
    static func choPhep(choAgent: Bool) -> [CTWVaiTroDuAn] { choAgent ? [.MEMBER, .VIEWER] : allCases }
}

/// Vai trò không gian (`WorkspaceRole`).
enum CTWVaiTroKhongGian: String, CaseIterable, Identifiable {
    case ADMIN, MEMBER, GUEST
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .ADMIN: return String(localized: "Admin")
        case .MEMBER: return String(localized: "Member")
        case .GUEST: return String(localized: "Guest")
        }
    }
}

struct CTWNhomThanhVien: Codable, Hashable, Identifiable {
    var id: Int
    var username: String?
    var fullName: String?
    var displayName: String?
    var avatarUrl: String?
    var kind: String?
    /// LEAD | MEMBER
    var teamRole: String?

    var nguoi: CTWUser {
        CTWUser(id: id, username: username, fullName: fullName, displayName: displayName, avatarUrl: avatarUrl, role: nil, kind: kind)
    }
}

/// Một nhóm (team) của không gian — `GET /workspaces/:wsId/teams`.
struct CTWNhomKhongGian: Codable, Hashable, Identifiable {
    var id: Int
    var key: String?
    var name: String
    var color: String?
    var description: String?
    var archivedAt: String?
    var members: [CTWNhomThanhVien]?
    var leadIds: [Int]?
    var openIssues: Int?
}

/// Kết quả tạo link mời — token CHỈ trả về một lần.
struct CTWLinkMoi: Codable, Hashable {
    var id: Int?
    var expiresAt: String?
    var maxUses: Int?
    var url: String
}

// MARK: Team overview (`GET /projects/:pid/team-overview`, work-uxc-api.ts)

struct CTWTongQuanNhom: Codable {
    struct Tong: Codable, Hashable {
        var members: Int?
        var open: Int?
        var inProgress: Int?
        var overdue: Int?
        var stuck: Int?
        var reviews: Int?
        var unassigned: Int?
    }
    struct Nguoi: Codable, Hashable {
        var user: CTWUser?
        var name: String?
        var role: String?
        var todo: Int?
        var inProgress: Int?
        var overdue: Int?
        var blocked: Int?
        var total: Int?
        var stuck: Int?
        var reviews: Int?
    }
    var asOf: String?
    var totals: Tong?
    var people: [Nguoi]?
}

struct CTWDaCapNhat: Codable { var updated: Bool?; var removed: Bool? }
