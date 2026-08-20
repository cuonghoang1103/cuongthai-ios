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
    /// Bảng tin. `hashtag` lọc theo một thẻ (dùng cho từng loạt bài),
    /// `excludeSeries` thì ngược lại — bỏ hẳn bài của MỌI loạt, để bảng tin
    /// chung không bị 135 bài học dìm mất bài thường.
    /// (Swift không cho enum case có tham số mặc định, nên phải truyền đủ.)
    case getFeed(cursor: Int?, limit: Int, type: String?, videoCategoryId: Int?,
                 hashtag: String?, excludeSeries: Bool)
    /// Số bài mỗi tab. `excludeSeries` phải truyền GIỐNG hệt lúc gọi `getFeed`,
    /// không thì con số trên tab đếm cả bài của các loạt mà danh sách bên dưới
    /// lại không hiện chúng.
    case getPostCounts(excludeSeries: Bool)
    /// Mục lục một loạt bài nhiều kỳ: [{ day, postId, title }]. Công khai.
    case getSeries(slug: String)
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
    case sendMessage(threadId: Int, content: String, type: String, parentMessageId: Int?)
    /// Gửi tin có file đính kèm. Máy chủ nhận `fileIds: [Int]` (id hàng
    /// `FileAttachment` do `POST /messages/upload` tạo ra), KHÔNG nhận URL.
    case sendMessageWithFiles(threadId: Int, content: String, fileIds: [Int])
    /// Mốc đọc của từng người trong hội thoại — để vẽ "Đã xem".
    case getThreadReads(threadId: Int)
    /// Gửi GIF / nhãn dán. Máy chủ nhận `media: {url, kind}` với kind là
    /// `gif` hoặc `sticker` — KHÔNG phải file đính kèm.
    case sendMessageMedia(threadId: Int, url: String, kind: String)
    /// Bật/tắt một cảm xúc trên tin nhắn (gọi lại cùng emoji là gỡ).
    case toggleMessageReaction(messageId: Int, emoji: String)
    case recallMessage(messageId: Int)
    case deleteMessage(messageId: Int)
    /// Tìm GIF qua proxy GIPHY của backend. `q` rỗng = đang thịnh hành.
    case searchGifs(q: String)
    /// Đổi MỘT ô tuỳ chọn của hội thoại. `slot` là một trong
    /// `pinnedAt` / `mutedUntil` / `archivedAt` / `markedUnreadAt`;
    /// `value` là mốc ISO, hoặc `nil` để xoá ô đó.
    case datTuyChonHoiThoai(threadId: Int, slot: String, value: String?)
    case boLuuTruHoiThoai(threadId: Int)
    case danhDauChuaDoc(threadId: Int)
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
    /// Mục lục khoá — trả MẢNG chương ở tầng gốc, đi qua `requestList`.
    case getCurriculum(courseId: Int)
    /// 9 học kỳ của chương trình FPT.
    /// Bài đã lưu. `{ data: [...], pagination }` — đi qua `requestList`.
    case getSavedPosts(cursor: Int?, limit: Int)
    /// Khoá đã ghi danh — trả bản ghi ghi danh kèm tiến độ, không phải Course.
    case getMyCourses
    case getSemesters
    /// Các môn của một học kỳ — 50 môn `academyType: "FPT"` chỉ lấy được ở đây,
    /// `/courses` KHÔNG trả chúng.
    case getCoursesBySemester(semesterId: Int)
    /// Nội dung đầy đủ một bài (có kiểm quyền truy cập).
    case getLesson(courseId: Int, lessonId: Int)
    case getCourseProgress(courseId: Int)
    /// Lưu tiến độ. `lastPositionSeconds` cho phép mở lại đúng chỗ đang dở.
    case saveLessonProgress(courseId: Int, lessonId: Int, isCompleted: Bool?, watchTimeSeconds: Int?, lastPositionSeconds: Int?)

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
        case .getPostCounts: return "/api/v1/social/posts/counts"
        case .getSeries(let slug): return "/api/v1/social/series/\(slug)"
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
        case .sendMessage(let threadId, _, _, _): return "/api/v1/messages/threads/\(threadId)/messages"
        case .sendMessageWithFiles(let threadId, _, _): return "/api/v1/messages/threads/\(threadId)/messages"
        case .getThreadReads(let threadId): return "/api/v1/messages/threads/\(threadId)/reads"
        case .sendMessageMedia(let threadId, _, _): return "/api/v1/messages/threads/\(threadId)/messages"
        case .toggleMessageReaction(let id, _): return "/api/v1/messages/messages/\(id)/reactions"
        case .recallMessage(let id): return "/api/v1/messages/messages/\(id)/recall"
        case .deleteMessage(let id): return "/api/v1/messages/messages/\(id)"
        case .searchGifs: return "/api/v1/gifs"
        case .datTuyChonHoiThoai(let id, _, _): return "/api/v1/messages/threads/\(id)/preference"
        case .boLuuTruHoiThoai(let id): return "/api/v1/messages/threads/\(id)/unarchive"
        case .danhDauChuaDoc(let id): return "/api/v1/messages/threads/\(id)/mark-unread"
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
        case .getCurriculum(let id): return "/api/v1/courses/\(id)/curriculum"
        case .getSavedPosts: return "/api/v1/social/saves"
        case .getMyCourses: return "/api/v1/courses/my"
        case .getSemesters: return "/api/v1/academy/semesters"
        case .getCoursesBySemester(let id): return "/api/v1/courses/semester/\(id)"
        case .getLesson(let c, let l): return "/api/v1/courses/\(c)/lessons/\(l)"
        case .getCourseProgress(let id): return "/api/v1/courses/\(id)/progress"
        case .saveLessonProgress(let id, _, _, _, _): return "/api/v1/courses/\(id)/progress"

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
             .createComment, .savePost, .sendMessage, .sendMessageWithFiles, .enrollCourse,
             .sendMessageMedia, .toggleMessageReaction, .recallMessage,
             .boLuuTruHoiThoai, .danhDauChuaDoc,
             .createNote, .reportPost, .reportThread, .blockUser, .requestDeletion,
             .openThread, .muteThread, .saveLessonProgress:
            return "POST"
        case .updateProfile:
            return "PUT"
        case .updateNote, .markRead, .reactPost, .markNotificationsRead, .datTuyChonHoiThoai:
            return "PATCH"
        case .deletePost, .unlikePost, .unsavePost, .deleteNote,
             .unblockUser, .cancelDeletionRequest, .deleteMessage:
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
        case .sendMessageMedia(_, let u, let k):
            return ["media": ["url": u, "kind": k]]
        case .toggleMessageReaction(_, let e):
            return ["emoji": e]
        case .datTuyChonHoiThoai(_, let slot, let v):
            // `value: nil` PHẢI gửi thành JSON `null` chứ không được bỏ khoá —
            // máy chủ hiểu `null` là "xoá ô này", còn thiếu khoá cũng ra null
            // nhưng dựa vào đó là dựa vào một sự trùng hợp.
            return ["slot": slot, "value": v as Any]
        case .searchGifs(let q):
            return q.isEmpty ? [:] : ["q": q]
        case .sendMessageWithFiles(_, let c, let ids):
            // `content` rỗng vẫn phải gửi khoá: tin chỉ có ảnh là hợp lệ.
            return ["content": c, "fileIds": ids]
        case .sendMessage(_, let c, let t, let cha):
            var m: [String: Any] = ["content": c, "type": t]
            if let cha { m["parentMessageId"] = cha }
            return m
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
        case .saveLessonProgress(_, let lessonId, let xong, let daXem, let viTri):
            var m: [String: Any] = ["lessonId": lessonId]
            if let xong { m["isCompleted"] = xong }
            if let daXem { m["watchTimeSeconds"] = daXem }
            if let viTri { m["lastPositionSeconds"] = viTri }
            return m
        case .refreshToken(let t): return ["refreshToken": t]
        default: return nil
        }
    }

    var queryParams: [String: Any]? {
        switch self {
        case .getFeed(let c, let l, let t, let v, let h, let boLoat):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            if let type = t { m["type"] = type }
            if let vid = v { m["videoCategoryId"] = vid }
            if let tag = h { m["hashtag"] = tag }
            if boLoat { m["excludeSeries"] = "true" }
            return m
        case .getPostCounts(let boLoat):
            return boLoat ? ["excludeSeries": "true"] : [:]
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
        case .getSavedPosts(let c, let l):
            var m: [String: Any] = ["limit": l]
            if let cursor = c { m["cursor"] = cursor }
            return m
        case .searchUsers(let q):
            return ["q": q, "limit": 20]
        default: return nil
        }
    }
}
