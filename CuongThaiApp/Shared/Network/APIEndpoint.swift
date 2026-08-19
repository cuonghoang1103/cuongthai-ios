import Foundation

// MARK: - API Endpoint
enum APIEndpoint {
    // Auth
    case login(username: String, password: String, captchaToken: String?)
    case register(username: String, email: String, password: String, fullName: String?, captchaToken: String?)
    /// Sign in with Apple / OAuth exchange — see AppleSignIn.swift.
    case oauthToken([String: Any])
    case changePassword(current: String, new: String)
    case refreshToken(String)

    // Profile
    case getProfile
    case updateProfile([String: Any])
    case getDeletionRequest
    case requestDeletion(reason: String?)
    case cancelDeletionRequest

    // Feed
    case getFeed(cursor: Int?, limit: Int, type: String?, videoCategoryId: Int?)
    case createPost([String: Any])
    case deletePost(id: Int)
    case likePost(id: Int)
    case unlikePost(id: Int)
    case reactPost(id: Int, type: String)
    case getComments(postId: Int, cursor: Int?, limit: Int)
    case createComment(postId: Int, content: String, parentId: Int?)
    case savePost(id: Int, folder: String?)
    case unsavePost(id: Int)

    // Users
    case getUserProfile(id: Int)
    case getUserPosts(id: Int, cursor: Int?, limit: Int)
    case followUser(id: Int)
    case unfollowUser(id: Int)
    case searchUsers(q: String)

    // Messaging
    case getThreads(cursor: Int?, limit: Int)
    case getMessages(threadId: Int, cursor: Int?, limit: Int)
    case sendMessage(threadId: Int, content: String, type: String)
    case markRead(threadId: Int)
    /// Mở (hoặc tạo nếu chưa có) hội thoại 1-1 với một người.
    case openThread(peerId: Int)
    /// Tắt thông báo hội thoại. `durationMinutes`: 0 = bật lại, 15/60/480/1440,
    /// nil = tắt vô thời hạn. Backend CHỈ chấp nhận đúng những giá trị đó.
    case muteThread(id: Int, durationMinutes: Int?)

    // Moderation (App Store Guideline 1.2)
    case reportPost(id: Int, reason: String, details: String?)
    case reportThread(id: Int, reason: String)
    case listBlocks
    case blockUser(id: Int, reason: String?)
    case unblockUser(id: Int)

    // Notes
    case getNotesTree
    case getNotesBySubject(id: Int)
    case createNote(subjectId: Int, chapterId: Int?, title: String?)
    case updateNote(id: Int, [String: Any])
    case deleteNote(id: Int)

    // Learning
    case getCourses(page: Int, size: Int, keyword: String?)
    case getCourseDetail(slug: String)
    case enrollCourse(id: Int)

    // Notifications
    case getUnreadNotificationCount
    case getNotifications(cursor: Int?, limit: Int)
    case getUnreadMessageCount
    /// PATCH — `nil` = đánh dấu đã đọc TẤT CẢ, hoặc truyền danh sách id.
    case markNotificationsRead(ids: [Int]?)
    /// Lấy một bài viết theo id, để bấm thông báo là mở đúng bài.
    case getPost(id: Int)

    var path: String {
        switch self {
        case .login: return "/api/v1/auth/login"
        case .register: return "/api/v1/auth/register"
        case .oauthToken: return "/api/v1/auth/oauth/token"
        case .changePassword: return "/api/v1/auth/change-password"
        case .refreshToken: return "/api/v1/auth/refresh"

        case .getProfile: return "/api/v1/profile"
        case .updateProfile: return "/api/v1/profile"
        case .getDeletionRequest: return "/api/v1/profile/deletion-request"
        case .requestDeletion: return "/api/v1/profile/deletion-request"
        case .cancelDeletionRequest: return "/api/v1/profile/deletion-request"

        case .getFeed: return "/api/v1/social/posts"
        case .createPost: return "/api/v1/social/posts"
        case .deletePost(let id): return "/api/v1/social/posts/\(id)"
        case .likePost(let id): return "/api/v1/social/posts/\(id)/like"
        case .unlikePost(let id): return "/api/v1/social/posts/\(id)/like"
        case .reactPost(let id, _): return "/api/v1/social/posts/\(id)/react"
        case .getComments(let postId, _, _): return "/api/v1/social/posts/\(postId)/comments"
        case .createComment(let postId, _, _): return "/api/v1/social/posts/\(postId)/comments"
        case .savePost(let id, _): return "/api/v1/social/posts/\(id)/save"
        case .unsavePost(let id): return "/api/v1/social/posts/\(id)/save"

        case .getUserProfile(let id): return "/api/v1/users/\(id)"
        case .getUserPosts(let id, _, _): return "/api/v1/users/\(id)/posts"
        case .followUser: return "/api/v1/users/follow"
        case .unfollowUser: return "/api/v1/users/follow"
        case .searchUsers: return "/api/v1/users/search"

        case .getThreads: return "/api/v1/messages/threads"
        case .getMessages(let threadId, _, _): return "/api/v1/messages/threads/\(threadId)/messages"
        case .sendMessage(let threadId, _, _): return "/api/v1/messages/threads/\(threadId)/messages"
        case .markRead(let threadId): return "/api/v1/messages/threads/\(threadId)/read"
        case .openThread(let peerId): return "/api/v1/messages/threads/user/\(peerId)"
        case .muteThread(let id, _): return "/api/v1/messages/threads/\(id)/mute-for"

        case .reportPost(let id, _, _): return "/api/v1/social/posts/\(id)/report"
        case .reportThread(let id, _): return "/api/v1/messages/threads/\(id)/report"
        case .listBlocks: return "/api/v1/messages/blocks"
        case .blockUser(let id, _): return "/api/v1/messages/blocks/\(id)"
        case .unblockUser(let id): return "/api/v1/messages/blocks/\(id)"

        case .getNotesTree: return "/api/v1/notes/tree"
        case .getNotesBySubject(let id): return "/api/v1/notes/subjects/\(id)"
        case .createNote: return "/api/v1/notes/notes"
        case .updateNote(let id, _): return "/api/v1/notes/notes/\(id)"
        case .deleteNote(let id): return "/api/v1/notes/notes/\(id)"

        case .getCourses: return "/api/v1/courses"
        case .getCourseDetail(let slug): return "/api/v1/courses/\(slug)"
        case .enrollCourse(let id): return "/api/v1/courses/\(id)/enroll"

        case .getUnreadNotificationCount: return "/api/v1/social/notifications/unread-count"
        case .getNotifications: return "/api/v1/social/notifications"
        case .getUnreadMessageCount: return "/api/v1/messages/unread-count"
        case .markNotificationsRead: return "/api/v1/social/notifications"
        case .getPost(let id): return "/api/v1/social/posts/\(id)"
        }
    }

    var method: String {
        switch self {
        case .login, .register, .oauthToken, .changePassword, .refreshToken,
             .createPost, .likePost, .followUser, .unfollowUser,
             .createComment, .savePost, .sendMessage, .enrollCourse,
             .createNote, .reportPost, .reportThread, .blockUser, .requestDeletion,
             .openThread, .muteThread:
            return "POST"
        case .updateProfile:
            return "PUT"
        case .updateNote, .markRead, .reactPost, .markNotificationsRead:
            return "PATCH"
        case .deletePost, .unlikePost, .unsavePost, .deleteNote,
             .unblockUser, .cancelDeletionRequest:
            return "DELETE"
        default:
            return "GET"
        }
    }

    var body: [String: Any]? {
        switch self {
        case .login(let u, let p, let c):
            var m: [String: Any] = ["username": u, "password": p]
            if let t = c { m["cf-turnstile-response"] = t }
            return m
        case .register(let u, let e, let p, let f, let c):
            var m: [String: Any] = ["username": u, "email": e, "password": p]
            if let name = f { m["fullName"] = name }
            if let t = c { m["cf-turnstile-response"] = t }
            return m
        case .oauthToken(let payload):
            return payload
        case .changePassword(let current, let new):
            // The backend validates confirmPassword === newPassword.
            return ["currentPassword": current, "newPassword": new, "confirmPassword": new]
        case .createPost(let d): return d
        case .updateProfile(let d): return d
        case .updateNote(_, let d): return d
        case .reactPost(_, let t): return ["type": t]
        // Backend `POST /users/follow` is a toggle keyed by `targetId`.
        case .followUser(let id): return ["targetId": id]
        case .unfollowUser(let id): return ["targetId": id]
        case .createComment(_, let c, let p):
            var m: [String: Any] = ["content": c]
            if let parent = p { m["parentId"] = parent }
            return m
        case .savePost(_, let f):
            return f != nil ? ["folder": f!] : nil
        case .sendMessage(_, let c, let t):
            return ["content": c, "type": t]
        case .createNote(let s, let ch, let t):
            var m: [String: Any] = ["subjectId": s]
            if let chapter = ch { m["chapterId"] = chapter }
            if let title = t { m["title"] = title }
            return m
        case .reportPost(_, let reason, let details):
            var m: [String: Any] = ["reason": reason]
            if let d = details, !d.isEmpty { m["details"] = d }
            return m
        case .reportThread(_, let reason):
            return ["reason": reason]
        case .blockUser(_, let reason):
            return reason != nil ? ["reason": reason!] : nil
        case .requestDeletion(let reason):
            return reason != nil ? ["reason": reason!] : nil
        case .muteThread(_, let phut):
            // Gửi NSNull chứ không bỏ trắng: bỏ trắng thì backend đọc ra
            // `undefined` và cũng hiểu là vô thời hạn, nhưng gửi thẳng cho rõ.
            return ["durationMinutes": phut as Any? ?? NSNull()]
        case .markNotificationsRead(let ids):
            // Thân rỗng cũng được hiểu là "tất cả", nhưng gửi rõ ràng để
            // không phụ thuộc vào hành vi mặc định của backend.
            return ids.map { ["ids": $0] } ?? ["all": true]
        case .refreshToken(let t): return ["refreshToken": t]
        default: return nil
        }
    }

    var queryParams: [String: Any]? {
        switch self {
        case .getFeed(let c, let l, let t, let v):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            if let type = t { m["type"] = type }
            if let vid = v { m["videoCategoryId"] = vid }
            return m
        case .getComments(_, let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .getUserPosts(_, let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .getThreads(let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .getMessages(_, let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .getCourses(let p, let s, let k):
            var m: [String: Any] = ["page": p, "size": s]
            if let keyword = k { m["keyword"] = keyword }
            return m
        case .getNotifications(let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .searchUsers(let q):
            return ["q": q, "limit": 20]
        default: return nil
        }
    }
}
