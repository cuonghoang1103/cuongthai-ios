import Foundation

/// Boolean chịu được cả `true/false` lẫn `0/1` lẫn `"true"/"1"`.
///
/// Backend có ba trường trả về SỐ thay vì boolean vì một lỗi thứ tự toán tử
/// trong `social.service.ts:1074-1076`:
///
///     isLiked: currentUserId ? (post.likes)?.length ?? 0 > 0 : false
///
/// JavaScript đọc `?? 0 > 0` thành `?? (0 > 0)`, nên khi `likes` tồn tại thì
/// giá trị trả về là `length` — một con số. Web viết bằng JS không phát hiện
/// (0/1 vẫn dùng được như true/false), còn Swift thì hỏng NGAY: cả bảng tin
/// không giải mã được, và trên màn hình chỉ thấy "Không tải được".
///
/// Bọc như thế này KHÔNG phải để che lỗi backend — lỗi đó nên sửa (thêm cặp
/// ngoặc). Nhưng một trường lệch kiểu KHÔNG được phép làm sập cả màn hình.
@propertyWrapper
struct BoolDeTinh: Codable, Hashable {
    var wrappedValue: Bool

    init(wrappedValue: Bool) { self.wrappedValue = wrappedValue }

    init(from decoder: Decoder) throws {
        let o = try decoder.singleValueContainer()
        if let b = try? o.decode(Bool.self) { wrappedValue = b }
        else if let i = try? o.decode(Int.self) { wrappedValue = i != 0 }
        else if let d = try? o.decode(Double.self) { wrappedValue = d != 0 }
        else if let c = try? o.decode(String.self) { wrappedValue = c == "true" || c == "1" }
        else { wrappedValue = false }
    }

    func encode(to encoder: Encoder) throws {
        var o = encoder.singleValueContainer()
        try o.encode(wrappedValue)
    }
}

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
    @BoolDeTinh var isLiked: Bool
    @BoolDeTinh var isSaved: Bool
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
    /// Mã môn của Academy FPT (CEA201, PRF192…). `nil` với khoá tự biên soạn.
    let courseCode: String?
    let semesterName: String?
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

extension Course {
    /// Dựng từ `CourseDetail` để đưa sang trình phát. Trình phát chỉ cần
    /// `id` + `slug` (mở web cho bài quiz), phần còn lại điền tạm.
    init(from ct: CourseDetail) {
        self.init(
            id: ct.id, title: ct.title, slug: ct.slug ?? "",
            courseCode: nil, semesterName: nil,
            shortDescription: ct.description, thumbnailUrl: ct.thumbnailUrl,
            instructor: ct.instructor, price: 0, discountPrice: nil, isFree: true,
            level: "", totalStudents: 0, avgRating: nil, totalLessons: nil,
            totalDurationSeconds: nil, isEnrolled: ct.isEnrolled,
        )
    }
}

struct CourseDetail: Codable, Identifiable {
    let id: Int
    let title: String
    /// Cần cho nút "Mở trên website" ở bài kiểm tra.
    let slug: String?
    let description: String?
    let thumbnailUrl: String?
    let instructor: User?
    let sections: [CourseSection]?
    let reviews: [CourseReview]?
    let isEnrolled: Bool
    let progress: Double?

    // ── Những trường API VẪN LUÔN TRẢ mà app chưa từng dùng ────────
    // Trước đây màn chi tiết chỉ lấy title + description, nên phần giới thiệu
    // là một khối chữ 10 dòng đổ thẳng ra màn hình, không cấp bậc, không nhịp
    // nghỉ — trong khi máy chủ đã gửi sẵn cấp độ, thời lượng, số bài, danh
    // mục, "bạn sẽ học được gì", "yêu cầu đầu vào".
    let level: String?
    let language: String?
    let categoryName: String?
    let totalLessons: Int?
    let totalDurationSeconds: Int?
    let totalStudents: Int?
    let avgRating: Double?
    let totalReviews: Int?
    let isFree: Bool?
    let accessType: String?
    let whatYouLearn: String?
    let requirements: String?
    let documentsNote: String?

    var nhanCapDo: String? {
        switch level {
        case "BEGINNER": return "Cơ bản"
        case "INTERMEDIATE": return "Trung cấp"
        case "ADVANCED": return "Nâng cao"
        default: return level
        }
    }

    /// "5 giờ 09 phút" — thời lượng cả khoá, đọc được bằng tiếng người.
    var nhanThoiLuong: String? {
        guard let giay = totalDurationSeconds, giay > 0 else { return nil }
        let gio = giay / 3600, phut = (giay % 3600) / 60
        if gio > 0 { return phut > 0 ? "\(gio) giờ \(phut) phút" : "\(gio) giờ" }
        return "\(phut) phút"
    }

    /// Tách "ý này; ý kia; ý nữa" thành từng gạch đầu dòng.
    /// Backend gộp hết vào MỘT chuỗi, ngăn bằng `;` (whatYouLearn) hoặc `•`
    /// (documentsNote) — không tách thì lại thành khối chữ như cũ.
    static func tachY(_ chu: String?) -> [String] {
        guard let chu, !chu.isEmpty else { return [] }
        let dau: Character = chu.contains("•") ? "•" : ";"
        return chu.split(separator: dau)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Chương trình học
//
// `GET /courses/:id/curriculum` trả `{ success, data: [chương] }` — MẢNG chương
// ở tầng gốc, mỗi chương ôm mảng bài. Đo thật trên khoá PostgreSQL: 11 chương,
// 54 bài (44 VIDEO + 10 QUIZ), tất cả `videoPlatform: EMBED`.
struct CourseSection: Codable, Identifiable, Hashable {
    let id: Int
    let courseId: Int?
    let title: String
    let description: String?
    let sortOrder: Int?
    let isLocked: Bool?
    let lessons: [CourseLesson]?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (l: CourseSection, r: CourseSection) -> Bool { l.id == r.id }
}

struct CourseLesson: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let slug: String?
    let description: String?
    /// VIDEO | QUIZ | (có thể thêm loại khác về sau)
    let lessonType: String?
    let videoDurationSeconds: Int?
    let thumbnailUrl: String?
    let isFreePreview: Bool?
    let sortOrder: Int?
    let videoUrl: String?
    /// EMBED (YouTube) | DIRECT (file trên R2, qua URL ký ngắn hạn)
    let videoPlatform: String?
    let videoTracks: [VideoTrack]?
    /// Luồng mở sẵn khi vào bài: "YT" | "VI" | "EN"
    let defaultVideoTrack: String?
    let sourceCodeUrl: String?
    let teachingNotes: String?
    /// KHÔNG có trong `/curriculum` — chỉ có ở `/courses/:id/lessons/:id`.
    let content: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (l: CourseLesson, r: CourseLesson) -> Bool { l.id == r.id }

    var laQuiz: Bool { lessonType == "QUIZ" }

    /// "4:19:34" cho bài dài, "12:05" cho bài ngắn.
    ///
    /// Bản đầu chia mọi thứ ra phút:giây, nên một bài 15.574 giây (hơn 4 tiếng)
    /// hiện thành "259:34" — đúng về số học, vô nghĩa với người đọc.
    var thoiLuong: String? {
        guard let giay = videoDurationSeconds, giay > 0 else { return nil }
        let gio = giay / 3600
        let phut = (giay % 3600) / 60
        let du = giay % 60
        if gio > 0 {
            return "\(gio):\(String(format: "%02d:%02d", phut, du))"
        }
        return "\(phut):\(String(format: "%02d", du))"
    }
}

/// Một bài có thể mang tới ba bản thu song song: tiếng Việt của giảng viên,
/// bản tiếng Anh, và một bài giảng YouTube được tuyển chọn.
struct VideoTrack: Codable, Hashable {
    /// "VI" | "EN" | "YT"
    let track: String
    let url: String?
    let platform: String?
    /// Dòng ghi công người làm video gốc — PHẢI hiện khi phát bài của người
    /// khác. Đây vừa là phép lịch sự vừa là chỗ dựa nếu bị hỏi về bản quyền.
    let credit: String?

    var nhan: String {
        switch track {
        case "VI": return "Tiếng Việt"
        case "EN": return "English"
        case "YT": return "YouTube"
        default: return track
        }
    }
}

/// Tiến độ một bài — `GET /courses/:id/progress` trả mảng các mục này.
struct LessonProgress: Codable, Identifiable {
    let id: Int?
    let lessonId: Int
    let isCompleted: Bool
    let watchTimeSeconds: Int?
    let lastPositionSeconds: Int?
}

// MARK: - Tiêu đề song ngữ
//
// Backend nhét cả hai ngôn ngữ vào MỘT chuỗi, ngăn bằng `|||`:
//     "0.1 — About this course|||0.1 — Về khoá học này"
// Không tách thì người dùng đọc nguyên cả chuỗi kèm ba gạch đứng.
extension String {
    /// Nửa hợp với ngôn ngữ máy. Không có dấu `|||` thì trả nguyên chuỗi.
    var songNguTheoMay: String {
        let phan = components(separatedBy: "|||")
        guard phan.count >= 2 else { return self }
        let tiengViet = Locale.preferredLanguages.first?.hasPrefix("vi") ?? false
        // Quy ước của web: vế TRƯỚC là tiếng Anh, vế SAU là tiếng Việt.
        let chon = tiengViet ? phan[1] : phan[0]
        return chon.trimmingCharacters(in: .whitespaces)
    }

    /// Nửa còn lại, để hiện mờ bên dưới cho người muốn đối chiếu.
    var songNguVeKia: String? {
        let phan = components(separatedBy: "|||")
        guard phan.count >= 2 else { return nil }
        let tiengViet = Locale.preferredLanguages.first?.hasPrefix("vi") ?? false
        return phan[tiengViet ? 0 : 1].trimmingCharacters(in: .whitespaces)
    }
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
// CHỈ dùng cho `/users/:id/posts` — endpoint DUY NHẤT trả kiểu lồng
// `{ data: { items, nextCursor, hasMore } }`. Bảng tin `/social/posts` trả
// `{ data: [...], pagination: {...} }` và phải đi qua `requestList`.
struct FeedResponse: Codable {
    let items: [SocialPost]
    let nextCursor: Int?
    let hasMore: Bool
}

// KHÔNG dùng nữa — bình luận trả `{ data: [...], pagination }`, đi qua
// `requestList`. Giữ lại vì các model khác trong file tham chiếu kiểu này.
struct CommentsResponse: Codable {
    let items: [Comment]
    let nextCursor: Int?
    let hasMore: Bool
}

// KHÔNG dùng nữa — `/messages/threads` trả mảng trần.
struct ThreadsResponse: Codable {
    let items: [MessageThread]
    let nextCursor: Int?
    let hasMore: Bool
}

// KHÔNG dùng nữa — `/threads/:id/messages` trả mảng trần.
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
    ///
    /// ⚠️ Chú thích trong `prisma/schema.prisma` chỉ liệt kê 6 loại và ĐÃ CŨ.
    /// Đếm thật trong `notification.service.ts` (19/08/2026) có 11 loại. Thiếu
    /// loại nào thì nó rơi vào câu mặc định "có hoạt động mới" — không sai,
    /// nhưng vô nghĩa với người đọc.
    var loiNhan: String {
        switch type {
        case "NEW_REACTION": return "đã bày tỏ cảm xúc về bài viết của bạn"
        case "NEW_COMMENT": return "đã bình luận bài viết của bạn"
        case "NEW_REPLY": return "đã trả lời bình luận của bạn"
        case "NEW_MENTION": return "đã nhắc tới bạn"
        case "NEW_POST": return "vừa đăng một bài mới"
        case "NEW_MESSAGE": return "đã gửi cho bạn một tin nhắn"
        case "NEW_FOLLOW": return "đã theo dõi bạn"
        case "FRIEND_REQUEST": return "đã gửi lời mời kết bạn"
        case "FRIEND_ACCEPT": return "đã chấp nhận lời mời kết bạn"
        case "NOTE_SHARE": return "đã chia sẻ một ghi chú với bạn"
        case "NOTE_COMMENT": return "đã bình luận ghi chú của bạn"
        case "HUB_SHARE": return "đã chia sẻ một tài liệu với bạn"
        case "ADMIN_ANNOUNCEMENT": return "có thông báo mới từ ban quản trị"
        default: return "có hoạt động mới"
        }
    }

    var bieuTuong: String {
        switch type {
        case "NEW_REACTION": return "heart.fill"
        case "NEW_COMMENT", "NEW_REPLY", "NOTE_COMMENT": return "bubble.left.fill"
        case "NEW_MENTION": return "at"
        case "NEW_POST": return "doc.text.fill"
        case "NEW_MESSAGE": return "envelope.fill"
        case "NEW_FOLLOW": return "person.badge.plus"
        case "FRIEND_REQUEST", "FRIEND_ACCEPT": return "person.2.fill"
        case "NOTE_SHARE", "HUB_SHARE": return "square.and.arrow.up.fill"
        case "ADMIN_ANNOUNCEMENT": return "megaphone.fill"
        default: return "bell.fill"
        }
    }

    /// Bấm vào thì đi đâu. Đoán sai chỗ đến còn tệ hơn không đi đâu cả: mở
    /// bài viết bằng id hội thoại sẽ ra "không tìm thấy bài viết".
    enum NoiDen {
        case baiViet(Int)
        case nguoiDung(Int)
        case tinNhan
        case khongDauCa
    }

    var noiDen: NoiDen {
        switch type {
        case "NEW_MESSAGE":
            return .tinNhan
        case "NEW_FOLLOW", "FRIEND_REQUEST", "FRIEND_ACCEPT":
            // Với các loại này `entityId` KHÔNG phải id bài viết; người gửi
            // mới là thứ đáng mở.
            return sender.map { .nguoiDung($0.id) } ?? .khongDauCa
        case "NEW_REACTION", "NEW_COMMENT", "NEW_REPLY", "NEW_MENTION", "NEW_POST":
            return entityId.map { .baiViet($0) } ?? .khongDauCa
        default:
            // NOTE_*, HUB_SHARE, ADMIN_ANNOUNCEMENT: app chưa có màn tương ứng.
            return .khongDauCa
        }
    }
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


// MARK: - Academy FPT
//
// Chương trình FPT nằm TÁCH khỏi các khoá tự biên soạn: `/courses` chỉ trả 5
// khoá `academyType: "GENERAL"`, còn 50 môn FPT (`academyType: "FPT"`) chỉ lấy
// được qua học kỳ. Hai đường khác nhau, nên trong app cũng để hai nhánh riêng
// — trộn chung thì "PostgreSQL" nằm cạnh "Mathematics for Engineering", không
// ai hiểu đang xem cái gì.
struct Semester: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let code: String
    let ordinal: Int?
    let description: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (l: Semester, r: Semester) -> Bool { l.id == r.id }

    /// Số kỳ để hiện trên huy hiệu.
    ///
    /// ⚠️ KHÔNG dùng `ordinal` — nó là khoá SẮP XẾP, không phải số kỳ. Đo thật:
    /// "Kỳ 3" có ordinal=5, "Kỳ 7" có ordinal=9. Lấy ordinal làm huy hiệu thì
    /// người dùng thấy ô số "5" cạnh chữ "Kỳ 3".
    /// Số thật nằm trong `name`; không rút được thì đành dùng ordinal.
    var soKy: Int? {
        let so = name.filter(\.isNumber)
        return Int(so) ?? ordinal
    }
}

extension Course {
    /// Mã môn FPT (CEA201, PRF192…). Chỉ môn Academy mới có.
    var laMonAcademy: Bool { (courseCode?.isEmpty == false) }
}


// MARK: - Khoá học đã ghi danh
//
// `GET /courses/my` trả bản ghi GHI DANH (đã làm phẳng), KHÔNG phải `Course`:
// có sẵn phần trăm tiến độ, bài học dở dang gần nhất và số hiệu chứng chỉ —
// tính sẵn ở máy chủ nên app không phải cộng lại từ danh sách bài.
struct Enrollment: Codable, Identifiable, Hashable {
    let id: Int
    let courseId: Int
    let courseTitle: String
    let courseSlug: String
    let courseThumbnail: String?
    /// Mã môn Academy (CEA201…), `nil` với khoá tự biên soạn.
    let courseCode: String?
    let semesterName: String?
    let enrolledAt: String?
    /// ACTIVE | IN_PROGRESS | COMPLETED
    let status: String?
    let progressPercent: Int?
    let lastLessonId: Int?
    let lastLessonTitle: String?
    let lastAccessedAt: String?
    let certificateNumber: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (l: Enrollment, r: Enrollment) -> Bool { l.id == r.id }

    var daXong: Bool { (progressPercent ?? 0) >= 100 }

    var nhanTrangThai: String {
        if daXong { return "Hoàn thành" }
        if (progressPercent ?? 0) > 0 { return "Đang học" }
        return "Chưa bắt đầu"
    }
}

// MARK: - Loạt bài nhiều kỳ (100 Ngày Java / Database / Tiếng Anh)

/// Mục lục một loạt bài, trả về từ `GET /social/series/:slug`.
///
/// `items` CHỈ chứa những kỳ đã đăng — Database mới ra 30/100 thì `items` có 30
/// phần tử chứ không phải 100 phần tử rỗng. Lưới ngày dựng từ `total`, rồi tra
/// `items` xem ngày nào đã có bài.
struct PostSeries: Codable, Identifiable {
    let slug: String
    let label: String
    let total: Int
    let items: [Ky]

    var id: String { slug }

    struct Ky: Codable, Identifiable {
        let day: Int
        let postId: Int
        let title: String
        var id: Int { day }
    }

    /// Tra nhanh ngày → kỳ. Lưới 100 ô mà dò tuyến tính thì thành 100×N phép so.
    var theoNgay: [Int: Ky] {
        Dictionary(items.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var soDaDang: Int { items.count }
    var tiLe: Double { total > 0 ? Double(items.count) / Double(total) : 0 }
}

/// Ba loạt bài khoá cứng ở backend (`POST_SERIES` trong `social.service.ts`).
/// Giữ ở đây phần TRÌNH BÀY thôi — màu, biểu tượng, mô tả; còn tên và số kỳ thì
/// lấy từ API để không lệch với máy chủ.
struct LoatBai: Identifiable {
    let slug: String
    let tenNgan: String
    let moTa: String
    let bieuTuong: String
    let mau: [UInt32]

    var id: String { slug }

    static let tatCa: [LoatBai] = [
        LoatBai(slug: "100-ngay-java", tenNgan: "100 Ngày Java",
                moTa: "Từ cú pháp đầu tiên tới lập trình hướng đối tượng",
                bieuTuong: "cup.and.saucer.fill", mau: [0xF89820, 0xE76F00]),
        LoatBai(slug: "100-ngay-database", tenNgan: "100 Ngày Database",
                moTa: "SQL, thiết kế bảng, tối ưu truy vấn",
                bieuTuong: "cylinder.split.1x2.fill", mau: [0x3B82F6, 0x1D4ED8]),
        LoatBai(slug: "100-ngay-tieng-anh", tenNgan: "100 Ngày Tiếng Anh",
                moTa: "Từ vựng, ngữ pháp và giao tiếp cho dân IT",
                bieuTuong: "character.book.closed.fill", mau: [0x10B981, 0x047857]),
    ]
}
