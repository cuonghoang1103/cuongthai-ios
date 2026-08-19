import Foundation

// MARK: - User Model
struct User: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let email: String?
    let fullName: String?
    let displayName: String?
    let avatarUrl: String?
    let coverPhotoUrl: String?
    let bio: String?
    let isFollowing: Bool?
    let isFollowedBy: Bool?
    let followersCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let createdAt: String?

    var name: String {
        displayName ?? fullName ?? username
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Social Post
struct SocialPost: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let content: String
    let author: User
    let media: [SocialMedia]?
    let poll: SocialPoll?
    let youtubeUrl: String?
    let musicTrack: MusicTrackInfo?
    let type: String
    let visibility: String
    let likesCount: Int
    let commentsCount: Int
    let sharesCount: Int
    let savesCount: Int
    let viewsCount: Int?
    let isLiked: Bool
    let isSaved: Bool
    let myReaction: String?
    let reactionBreakdown: ReactionBreakdown?
    let createdAt: String
    let updatedAt: String

    static func == (lhs: SocialPost, rhs: SocialPost) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SocialMedia: Codable, Identifiable {
    let id: Int
    let type: String
    let url: String
    let thumbnail: String?
    let width: Int?
    let height: Int?
    let duration: Int?
    let fileSize: Int?
    let mimeType: String?
    let fileName: String?
    let alt: String?
    let sortOrder: Int?
}

struct ReactionBreakdown: Codable {
    let LIKE: Int?
    let LOVE: Int?
    let HAHA: Int?
    let SAD: Int?
    let ANGRY: Int?
}

struct SocialPoll: Codable, Identifiable {
    let id: Int
    let question: String
    let options: [PollOption]?
    let multiChoice: Bool
    let totalVotes: Int?
    let closesAt: String?
    let userVotes: [Int]?
}

struct PollOption: Codable, Identifiable {
    let id: Int
    let text: String
    let votes: Int?
    let percentage: Double?
}

struct MusicTrackInfo: Codable {
    let id: Int
    let title: String
    let artist: String
    let coverImage: String?
    let audioUrl: String?
}

// MARK: - Comment
struct Comment: Codable, Identifiable {
    let id: Int
    let content: String
    let author: User
    let likesCount: Int
    let repliesCount: Int?
    let isLiked: Bool
    let parentId: Int?
    let createdAt: String
}

// MARK: - Message
// Hashable để dùng được với `navigationDestination(item:)`. So sánh theo `id`
// như User: hai lần tải cùng một hội thoại khác nhau ở `unreadCount`/
// `lastMessage`, mà đó không phải thứ định danh hội thoại.
struct MessageThread: Codable, Identifiable, Hashable {
    let id: Int
    let type: String
    let participants: [User]?
    let lastMessage: Message?
    let unreadCount: Int
    let createdAt: String?
    let updatedAt: String?

    var displayName: String {
        participants?.first?.name ?? "Unknown"
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: MessageThread, rhs: MessageThread) -> Bool { lhs.id == rhs.id }

    var avatarUrl: String? {
        participants?.first?.avatarUrl
    }
}

struct Message: Codable, Identifiable {
    let id: Int
    let senderId: Int
    let sender: User?
    let content: String
    let type: String
    let mediaUrl: String?
    let thumbnailUrl: String?
    let createdAt: String
    let readAt: String?
}

// MARK: - Notes
struct NotesTree: Codable {
    let subjects: [NoteSubject]
    let recentNotes: [NoteSummary]?
}

struct NoteSubject: Codable, Identifiable {
    let id: Int
    let name: String
    let color: String?
    let emoji: String?
    let sortOrder: Int?
    let chapters: [NoteChapter]?
    let notesCount: Int?
}

struct NoteChapter: Codable, Identifiable {
    let id: Int
    let title: String
    let sortOrder: Int?
    let notesCount: Int?
}

struct NoteSummary: Codable, Identifiable {
    let id: Int
    let title: String
    let updatedAt: String
}

struct Note: Codable, Identifiable {
    let id: Int
    let title: String
    let contentJson: [String: AnyCodable]?
    let contentHtml: String?
    let isPinned: Bool
    let isFavorite: Bool
    let isArchived: Bool
    let tags: [String]?
    let createdAt: String
    let updatedAt: String
}

// MARK: - Course
struct Course: Codable, Identifiable {
    let id: Int
    let title: String
    let slug: String
    let shortDescription: String?
    let thumbnailUrl: String?
    let instructor: User?
    let price: Double
    let discountPrice: Double?
    let isFree: Bool
    let level: String
    let totalStudents: Int
    let avgRating: Double?
    let totalLessons: Int?
    let totalDurationSeconds: Int?
    let isEnrolled: Bool?
}

struct CourseDetail: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let thumbnailUrl: String?
    let instructor: User?
    let sections: [CourseSection]?
    let reviews: [CourseReview]?
    let isEnrolled: Bool
    let progress: Double?
}

struct CourseSection: Codable, Identifiable {
    let id: Int
    let title: String
    let sortOrder: Int?
    let lessons: [CourseLesson]?
}

struct CourseLesson: Codable, Identifiable {
    let id: Int
    let title: String
    let durationSeconds: Int?
    let isCompleted: Bool?
}

struct CourseReview: Codable, Identifiable {
    let id: Int
    let user: User?
    let rating: Int
    let content: String?
    let createdAt: String
}

// MARK: - Music
struct MusicTrack: Codable, Identifiable {
    let id: Int
    let title: String
    let artist: String
    let audioUrl: String?
    let coverImage: String?
    let durationSeconds: Int?
}

struct MusicPlaylist: Codable, Identifiable {
    let id: Int
    let name: String
    let coverImage: String?
    let tracks: [MusicTrack]?
    let tracksCount: Int?
}

// Model thông báo CŨ (title/body/data) đã gỡ: nó được viết theo phỏng đoán,
// không khớp shape thật của backend (thật ra là entityId + sender, KHÔNG có
// title/body), và không một dòng nào dùng tới. Bản đúng nằm ở cuối file, viết
// sau khi đọc `notifications.routes.ts` và `model SocialNotification`.

// MARK: - API Responses
struct FeedResponse: Codable {
    let items: [SocialPost]
    let nextCursor: Int?
    let hasMore: Bool
}

struct CommentsResponse: Codable {
    let items: [Comment]
    let nextCursor: Int?
    let hasMore: Bool
}

struct ThreadsResponse: Codable {
    let items: [MessageThread]
    let nextCursor: Int?
    let hasMore: Bool
}

struct MessagesResponse: Codable {
    let items: [Message]
    let nextCursor: Int?
    let hasMore: Bool
}

struct FileUploadResponse: Codable {
    let url: String
    let key: String?
    let size: Int?
    let thumbnail: String?
    let contentType: String?
}

struct AuthResponse: Codable {
    let token: String
    let refreshToken: String?
}

struct EmptyResponse: Codable {}

// MARK: - AnyCodable
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = string }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let array = try? container.decode([AnyCodable].self) { value = array.map { $0.value } }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues { $0.value } }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let bool as Bool: try container.encode(bool)
        case let array as [Any]: try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }
}


// MARK: - Thông báo
//
// GET /api/v1/social/notifications trả về:
//   { items, pagination: { nextCursor, hasNextPage, limit }, unreadCount }
// KHÁC hẳn dạng { items, nextCursor, hasMore } của feed/comment — đừng dùng
// lại model của feed ở đây, decode sẽ hỏng câm và danh sách hiện trống rỗng.
//
// Tên `AppNotification` chứ không phải `Notification`: `Notification` là kiểu
// có sẵn của Foundation, trùng tên là mọi chỗ dùng đều phải viết đủ tên.
struct AppNotification: Codable, Identifiable, Hashable {
    let id: Int
    /// NEW_POST | NEW_REACTION | NEW_COMMENT | NEW_REPLY | NEW_MENTION | NEW_MESSAGE
    let type: String
    /// Con trỏ đa hình — nghĩa của nó phụ thuộc `type` (thường là postId).
    let entityId: Int?
    let secondaryEntityId: Int?
    let isRead: Bool
    let createdAt: String
    let sender: User?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AppNotification, rhs: AppNotification) -> Bool { lhs.id == rhs.id }

    /// Câu mô tả dựng từ `type`, KHÔNG lấy từ `payload`: payload là JSON tự do
    /// nên hình dạng không có gì bảo đảm, còn `type` thì backend ràng bằng enum.
    var loiNhan: String {
        switch type {
        case "NEW_REACTION": return "đã bày tỏ cảm xúc về bài viết của bạn"
        case "NEW_COMMENT": return "đã bình luận bài viết của bạn"
        case "NEW_REPLY": return "đã trả lời bình luận của bạn"
        case "NEW_MENTION": return "đã nhắc tới bạn"
        case "NEW_POST": return "vừa đăng một bài mới"
        case "NEW_MESSAGE": return "đã gửi cho bạn một tin nhắn"
        default: return "có hoạt động mới"
        }
    }

    var bieuTuong: String {
        switch type {
        case "NEW_REACTION": return "heart.fill"
        case "NEW_COMMENT", "NEW_REPLY": return "bubble.left.fill"
        case "NEW_MENTION": return "at"
        case "NEW_POST": return "doc.text.fill"
        case "NEW_MESSAGE": return "envelope.fill"
        default: return "bell.fill"
        }
    }

    /// Thông báo tin nhắn dẫn vào Tin nhắn, còn lại dẫn vào bài viết.
    var laTinNhan: Bool { type == "NEW_MESSAGE" }
}

struct NotificationsPagination: Codable {
    let nextCursor: Int?
    let hasNextPage: Bool
}

struct NotificationsResponse: Codable {
    let items: [AppNotification]
    let pagination: NotificationsPagination
    /// Backend gửi kèm để chuông cập nhật badge mà không phải gọi thêm lần nữa.
    let unreadCount: Int
}

struct UnreadNotificationCount: Codable {
    let unreadCount: Int
}

/// GET /api/v1/messages/unread-count trả `{ count }` — một ĐỐI TƯỢNG, không
/// phải số trần. Trước đây AppState giải mã thẳng ra Int nên luôn ném lỗi,
/// bị `catch {}` nuốt, và badge tin nhắn vĩnh viễn bằng 0.
struct UnreadMessageCount: Codable {
    let count: Int
}
