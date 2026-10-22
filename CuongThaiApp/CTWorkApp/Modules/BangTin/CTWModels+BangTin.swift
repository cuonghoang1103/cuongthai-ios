import Foundation

// MARK: - Bảng tin (Team Feed) — model theo hợp đồng `api-backend/docs/ctw-feed-hop-dong-api.md` (21/10/2026)
//
// Luật model của kho (CLAUDE.md C3/C4): mọi trường `var` + optional, ngày là `String` ISO (đọc bằng `Date.tuChuoiISO`).
// Người = `CTWUser` (PUBLIC_USER: id, username, fullName, displayName, avatarUrl, kind) — có sẵn nhãn agent/chữ cái.

/// Sáu cảm xúc — CÙNG MỘT BỘ với web (hợp đồng §0 "Cảm xúc"). Thứ tự case = thứ tự trên bảng chọn.
enum CamXucBangTin: String, CaseIterable, Codable, Identifiable, Hashable {
    case like, love, haha, wow, sad, celebrate
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .like: return "👍"
        case .love: return "❤️"
        case .haha: return "😂"
        case .wow: return "😮"
        case .sad: return "😢"
        case .celebrate: return "🎉"
        }
    }

    /// Nhãn theo ngôn ngữ app (vi: Thích · Yêu thích · Haha · Wow · Buồn · Chúc mừng).
    var ten: String {
        switch self {
        case .like: return String(localized: "Like")
        case .love: return String(localized: "Love")
        case .haha: return String(localized: "Haha")
        case .wow: return String(localized: "Wow")
        case .sad: return String(localized: "Sad")
        case .celebrate: return String(localized: "Celebrate")
        }
    }
}

struct CTWFeedWorkspace: Codable, Hashable {
    var id: Int
    var slug: String?
    var name: String?
    var logoUrl: String?
}

struct CTWFeedProject: Codable, Hashable {
    var id: Int
    var key: String?
    var name: String?
}

/// FeedAttachment — ảnh / video / tệp. `url`, `thumbUrl`, `posterUrl` là URL ký sẵn sống 10 phút (`urlExpiresAt`).
struct CTWFeedAttachment: Codable, Hashable, Identifiable {
    var id: Int
    /// IMAGE | VIDEO | FILE
    var kind: String?
    /// PENDING | READY
    var status: String?
    var fileName: String?
    var mime: String?
    var size: Int?
    var width: Int?
    var height: Int?
    var durationMs: Int?
    var alt: String?
    var position: Int?
    var url: String?
    var thumbUrl: String?
    var posterUrl: String?
    var urlExpiresAt: String?

    var laAnh: Bool { kind == "IMAGE" }
    var laVideo: Bool { kind == "VIDEO" }
    var laTep: Bool { !laAnh && !laVideo }
    var sanSang: Bool { status == nil || status == "READY" }

    /// Tỉ lệ rộng/cao (nil khi máy chủ chưa đo).
    var tiLe: Double? {
        guard let w = width, let h = height, w > 0, h > 0 else { return nil }
        return Double(w) / Double(h)
    }

    /// URL ký đã hết hạn chưa (chừa 20 s cho chắc).
    func hetHan(bayGio: Date = Date()) -> Bool {
        guard let s = urlExpiresAt, let d = Date.tuChuoiISO(s) else { return false }
        return d.timeIntervalSince(bayGio) < 20
    }
}

/// FeedRef — thẻ xem trước của link CT Work trong bài (thẻ / test / tài liệu / cuộc họp), dựng theo quyền NGƯỜI XEM.
struct CTWFeedRef: Codable, Hashable {
    struct TrangThai: Codable, Hashable { var name: String?; var category: String? }
    struct Loai: Codable, Hashable { var key: String?; var name: String?; var color: String? }
    struct Nguoi: Codable, Hashable { var id: Int?; var name: String?; var avatarUrl: String? }
    /// issue | test | doc | meeting
    var t: String?
    var key: String?
    var n: Int?
    var url: String?
    var title: String?
    var status: TrangThai?
    var type: Loai?
    var assignee: Nguoi?
    var project: String?
    var when: String?
}

/// FeedLinkPreview — thẻ link web ngoài (OpenGraph tải ở máy chủ lúc đăng/sửa).
struct CTWFeedLinkPreview: Codable, Hashable {
    var url: String?
    var domain: String?
    var title: String?
    var description: String?
    var siteName: String?
    var imageUrl: String?
}

struct CTWFeedPoll: Codable, Hashable {
    struct LuaChon: Codable, Hashable, Identifiable { var id: String; var text: String?; var votes: Int? }
    var options: [LuaChon]?
    var multi: Bool?
    var closesAt: String?
    var closed: Bool?
    var totalVotes: Int?
    var voters: Int?
    var myVotes: [String]?
}

struct CTWFeedDemCamXuc: Codable, Hashable {
    var kind: String
    var count: Int?
}

struct CTWFeedNhac: Codable, Hashable {
    var id: Int
    var username: String?
    var name: String?
}

/// `can` của bài/bình luận — máy chủ tính theo NGƯỜI XEM (app chỉ ẩn/hiện nút, máy chủ vẫn là nơi phán).
struct CTWFeedQuyen: Codable, Hashable {
    var edit: Bool?
    var delete: Bool?
    var pin: Bool?
    var moderate: Bool?
    var comment: Bool?
    var react: Bool?
    var report: Bool?
    var reply: Bool?
}

struct CTWFeedComment: Codable, Hashable, Identifiable {
    var id: Int
    var postId: Int?
    var parentId: Int?
    var author: CTWUser?
    var body: String?
    var mentions: [CTWFeedNhac]?
    var reactionCount: Int?
    var reactions: [CTWFeedDemCamXuc]?
    var myReaction: String?
    var replyCount: Int?
    var replies: [CTWFeedComment]?
    var hidden: Bool?
    var hiddenForMe: Bool?
    var authorBlocked: Bool?
    var reportedByMe: Bool?
    var editedAt: String?
    var createdAt: String?
    var can: CTWFeedQuyen?
}

struct CTWFeedPost: Codable, Hashable, Identifiable {
    var id: Int
    var workspace: CTWFeedWorkspace?
    var project: CTWFeedProject?
    var author: CTWUser?
    var authorRole: String?
    var body: String?
    var mentions: [CTWFeedNhac]?
    var hashtags: [String]?
    var attachments: [CTWFeedAttachment]?
    var linkPreview: CTWFeedLinkPreview?
    var refs: [CTWFeedRef]?
    var poll: CTWFeedPoll?
    var reactionCount: Int?
    var reactions: [CTWFeedDemCamXuc]?
    var myReaction: String?
    var commentCount: Int?
    var comments: [CTWFeedComment]?
    var commentsOff: Bool?
    var pinned: Bool?
    var pinnedAt: String?
    var saved: Bool?
    /// Chính mình đã "Ẩn bài này" (chỉ gặp khi mở thẳng bài — bảng tin đã lọc). Hợp đồng 7166814b.
    var hiddenForMe: Bool?
    var hidden: Bool?
    var editedAt: String?
    var createdAt: String?
    var url: String?
    var can: CTWFeedQuyen?

    // MARK: Chỉ ở máy (không có ở máy chủ) — bài đang đăng (chèn lạc quan)
    /// `clientKey` của bài tạm; nil với bài thật.
    var khoaTam: String?
    /// Bài tạm đăng hỏng (hiện nút Thử lại / Bỏ).
    var dangHong: Bool?

    enum CodingKeys: String, CodingKey {
        case id, workspace, project, author, authorRole, body, mentions, hashtags, attachments, linkPreview, refs, poll
        case reactionCount, reactions, myReaction, commentCount, comments, commentsOff, pinned, pinnedAt, saved, hiddenForMe, hidden
        case editedAt, createdAt, url, can
    }

    var laTam: Bool { khoaTam != nil }
    var anhVaVideo: [CTWFeedAttachment] {
        (attachments ?? []).filter { $0.laAnh || $0.laVideo }.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }
    var tep: [CTWFeedAttachment] { (attachments ?? []).filter(\.laTep) }
    var camXucCuaToi: CamXucBangTin? { myReaction.flatMap(CamXucBangTin.init(rawValue:)) }
}

/// `GET /feed` ⇒ `{ posts, pinned, nextCursor }`.
struct CTWFeedTrang: Codable, Hashable {
    var posts: [CTWFeedPost]?
    var pinned: [CTWFeedPost]?
    var nextCursor: String?
}

/// `GET /feed/scopes`.
struct CTWFeedPhamVi: Codable, Hashable {
    struct DuAn: Codable, Hashable, Identifiable {
        var id: Int
        var key: String?
        var name: String?
        var role: String?
        var canPost: Bool?
        var canModerate: Bool?
        var follow: String?
    }
    struct KhongGian: Codable, Hashable, Identifiable {
        var workspace: CTWFeedWorkspace
        var role: String?
        var canPost: Bool?
        var canModerate: Bool?
        var follow: String?
        var projects: [DuAn]?
        var id: Int { workspace.id }
    }
    var scopes: [KhongGian]?
    var openReports: Int?
}

/// Kết quả thả/bỏ cảm xúc (bài hoặc bình luận).
struct CTWFeedKetQuaCamXuc: Codable, Hashable {
    var reactionCount: Int?
    var reactions: [CTWFeedDemCamXuc]?
    var myReaction: String?
}

/// `GET /feed/posts/:id/reactions`.
struct CTWFeedNguoiThaCamXuc: Codable, Hashable {
    struct Muc: Codable, Hashable { var user: CTWUser?; var kind: String?; var createdAt: String? }
    var items: [Muc]?
    var reactions: [CTWFeedDemCamXuc]?
    var nextCursor: String?
}

/// `GET /feed/posts/:id/comments`.
struct CTWFeedTrangBinhLuan: Codable, Hashable {
    var comments: [CTWFeedComment]?
    var nextCursor: String?
}

/// `POST /feed/uploads/presign`.
struct CTWFeedXinTaiLen: Codable {
    var attachment: CTWFeedAttachment
    var uploadUrl: String
    var method: String?
    var headers: [String: String]?
    var expiresAt: String?
}

/// `GET /feed/attachments/:id/url` · `GET /feed/new-count`.
struct CTWFeedURL: Codable { var url: String?; var expiresAt: String? }
struct CTWFeedDemMoi: Codable { var count: Int? }
struct CTWFeedLuu: Codable { var saved: Bool? }
struct CTWFeedAn: Codable { var hidden: Bool? }
struct CTWFeedDaBaoCao: Codable { var reported: Bool?; var duplicate: Bool? }
struct CTWFeedTheoDoi: Codable { var workspaceId: Int?; var projectId: Int?; var level: String? }
struct CTWFeedNguoiNhac: Codable { var users: [CTWUser]? }

/// `GET /feed/reports` (quản trị).
struct CTWFeedBaoCao: Codable, Hashable, Identifiable {
    struct Dich: Codable, Hashable {
        var type: String?
        var postId: Int?
        var commentId: Int?
        var excerpt: String?
        var author: CTWUser?
        var hidden: Bool?
        var deleted: Bool?
    }
    var id: Int
    var status: String?
    var reason: String?
    var detail: String?
    var createdAt: String?
    var reporter: CTWUser?
    var reportCount: Int?
    var target: Dich?
    var workspace: CTWFeedWorkspace?
    var project: CTWFeedProject?
    var resolvedBy: CTWUser?
    var resolvedAt: String?
    var action: String?
    var url: String?
}

struct CTWFeedTrangBaoCao: Codable, Hashable {
    var reports: [CTWFeedBaoCao]?
    var nextCursor: String?
    var openCount: Int?
}

/// Lý do báo cáo của bảng tin (hợp đồng §0): spam | harassment | hate | sexual | violence | other.
enum LyDoBaoCaoBangTin: String, CaseIterable, Identifiable {
    case spam, harassment, hate, sexual, violence, other
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .spam: return String(localized: "Spam or advertising")
        case .harassment: return String(localized: "Harassment or bullying")
        case .hate: return String(localized: "Hate speech")
        case .sexual: return String(localized: "Sexual content")
        case .violence: return String(localized: "Violence or dangerous content")
        case .other: return String(localized: "Something else")
        }
    }
}

/// Mức theo dõi một phạm vi (`PUT /feed/follow`).
enum MucTheoDoiBangTin: String, CaseIterable, Identifiable {
    case all = "ALL", mentions = "MENTIONS", off = "OFF"
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .all: return String(localized: "All new posts")
        case .mentions: return String(localized: "Only mentions")
        case .off: return String(localized: "Off")
        }
    }
}
