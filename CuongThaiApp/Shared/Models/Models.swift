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
struct SocialPost: Codable, Identifiable, Equatable {
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

// MARK: - Notification
struct AppNotification: Codable, Identifiable {
    let id: Int
    let type: String
    let title: String
    let body: String?
    let data: NotificationData?
    let isRead: Bool
    let createdAt: String
}

struct NotificationData: Codable {
    let postId: Int?
    let userId: Int?
    let threadId: Int?
    let commentId: Int?
}

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
