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
    case createComment(postId: Int, content: String, parentId: Int?, mediaUrl: String? = nil, mediaKind: String? = nil)
    /// Thích bình luận — máy chủ TỰ ĐẢO trạng thái, một đường cho cả hai chiều.
    case likeComment(id: Int)
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
    /// Đặt/xoá biệt danh cho người kia trong hội thoại. `alias` rỗng = xoá.
    case datBietDanh(threadId: Int, targetId: Int, alias: String)
    /// Một hội thoại. ⚠️ Đường này gọi serializer KHÔNG kèm bản đồ biệt danh,
    /// nên `peer.displayName` luôn là TÊN THẬT — dùng nó để lấy lại tên thật
    /// sau khi xoá biệt danh, đừng dùng để làm mới sau khi ĐẶT biệt danh.
    case layHoiThoai(threadId: Int)
    /// Hàng tin: MỘT tin mới nhất cho mỗi người.
    case dangKyThietBi(token: String, sandbox: Bool)
    case goThietBi(token: String)
    case layHangTin
    /// Đủ tin của một người, để lật qua từng tin.
    case layTinCuaNguoi(userId: Int)
    case danhDauDaXemTin(storyId: Int)
    case taoTin(mediaUrl: String, mediaType: String, caption: String?)
    case xoaTin(storyId: Int)
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
    case layGhiChu(id: Int)
    /// Tìm ghi chú. `q` rỗng + `tag` rỗng = trả tất cả (máy chủ tự lo).
    case timGhiChu(q: String, subjectId: Int?, tag: String?)
    case layThe
    case taoChuong(subjectId: Int, title: String)
    case taoMon(name: String, color: String?, emoji: String?)
    case suaMon(id: Int, [String: Any])
    case xoaMon(id: Int)
    case suaChuong(id: Int, title: String)
    case xoaChuong(id: Int)
    case nhanBanGhiChu(id: Int)
    case locGhiChu(f: String)
    case khoiPhucGhiChu(id: Int)
    case xoaVinhVien(id: Int)
    case layLienKetNguoc(id: Int)

    // ─── Từ vựng & thẻ ghi nhớ ───────────────────────────────
    // ─── Bài viết của chính mình ─────────────────────────────
    /// Báo cáo một câu trả lời AI. Máy chủ đòi `rating` 1-5; báo cáo là mức
    /// thấp nhất (1) kèm loại.
    case baoCaoTraLoiAI(messageId: Int?)
    // ─── Phiên chat AI ───────────────────────────────────────
    /// `archived=1` là màn LƯU TRỮ; không truyền là danh sách thường.
    /// Hai bộ lọc LOẠI TRỪ nhau — backend cố ý không có nhánh "xem tất cả".
    case dsPhienChat(luuTru: Bool, thuMucId: String?)
    case lichSuPhienChat(id: String)
    case taoPhienChat(title: String?)
    /// Đổi tên / ghim / lưu trữ — cùng một đường PATCH.
    case suaPhienChat(id: String, [String: Any])
    case xoaPhienChat(id: String)
    case dsThuMucChat
    case taoThuMucChat(ten: String, mau: String?)
    case xoaThuMucChat(id: String)
    case chuyenThuMuc(id: String, thuMucId: String?)
    /// Tách nhánh từ một lượt: giữ các tin TRƯỚC `denChiSo`, tạo phiên mới.
    case tachNhanhPhien(id: String, denChiSo: Int)
    /// Cắt bỏ từ một lượt trở đi — dùng khi sửa câu hỏi rồi hỏi lại.
    case catPhien(id: String, tuChiSo: Int)
    /// Đặt việc đọc — trả `{ jobId }`, KHÔNG trả tiếng ngay. Xem `MayDoc`.
    case datViecDoc(text: String)
    case xoaBaiViet(id: Int)
    /// Đổi nội dung và/hoặc quyền riêng tư. Máy chủ nhận `content`,
    /// `visibility` (PUBLIC | FRIENDS | PRIVATE).
    case suaBaiViet(id: Int, [String: Any])
    /// Ghim/bỏ ghim — máy chủ TỰ ĐẢO, một đường cho cả hai chiều.
    /// ⚠️ Mỗi người chỉ ghim được MỘT bài: nó lưu ở `userProfile.pinnedPostId`,
    /// ghim bài mới là bài cũ tự bỏ ghim.
    case ghimBaiViet(id: Int)

    case layTuVung(noteId: Int)
    case themTuVung(noteId: Int, term: String, reading: String?, meaning: String?, example: String?)
    case suaTuVung(id: Int, [String: Any])
    case xoaTuVung(id: Int)
    case layBoThe(noteId: Int)
    /// `known: true` = nhớ được. Máy chủ tự cộng chuỗi đúng và số lần ôn.
    case chamThe(vocabId: Int, known: Bool)
    case datLaiThe(vocabId: Int)
    case layPhienBan(noteId: Int)
    case layMotPhienBan(noteId: Int, version: Int)
    case luuMocPhienBan(noteId: Int)
    case khoiPhucPhienBan(noteId: Int, version: Int)
    case layViecAI
    case chayViecAI(action: String, selection: String)
    case hoiTroLyGhiChu(question: String)
    case laySoDoGhiChu
    case layBangTheoMon(subjectId: Int)
    case layBang(databaseId: Int)
    case taoDongBang(databaseId: Int)
    case suaDongBang(rowId: Int, values: [String: Any])
    case xoaDongBang(rowId: Int)

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
        // ⚠️ TẠO bình luận là `POST /social/comments` với `postId` trong THÂN.
        // Bản cũ gọi `/social/posts/{id}/comments` — đường đó chỉ có GET, nên
        // POST trả 404, bình luận vừa chèn tạm bị gỡ đi, và nhìn từ ngoài
        // đúng là "ấn gửi mà không thấy gì".
        case .createComment: return "/api/v1/social/comments"
        case .likeComment(let id): return "/api/v1/social/comments/\(id)/like"
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
        case .datBietDanh(let id, _, _): return "/api/v1/messages/threads/\(id)/nickname"
        case .layHoiThoai(let id): return "/api/v1/messages/threads/\(id)"
        case .dangKyThietBi: return "/api/v1/devices"
        case .goThietBi(let t): return "/api/v1/devices/\(t)"
        case .layHangTin: return "/api/v1/stories/feed"
        case .layTinCuaNguoi(let id): return "/api/v1/stories/user/\(id)"
        case .danhDauDaXemTin(let id): return "/api/v1/stories/\(id)/view"
        case .taoTin: return "/api/v1/stories"
        case .xoaTin(let id): return "/api/v1/stories/\(id)"
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
        case .layGhiChu(let id): return "/api/v1/notes/notes/\(id)"
        case .timGhiChu: return "/api/v1/notes/search"
        case .layThe: return "/api/v1/notes/tags"
        case .taoChuong: return "/api/v1/notes/chapters"
        case .taoMon: return "/api/v1/notes/subjects"
        case .suaMon(let id, _): return "/api/v1/notes/subjects/\(id)"
        case .xoaMon(let id): return "/api/v1/notes/subjects/\(id)"
        case .suaChuong(let id, _): return "/api/v1/notes/chapters/\(id)"
        case .xoaChuong(let id): return "/api/v1/notes/chapters/\(id)"
        case .nhanBanGhiChu(let id): return "/api/v1/notes/notes/\(id)/duplicate"
        case .locGhiChu: return "/api/v1/notes/notes/filter"
        case .khoiPhucGhiChu(let id): return "/api/v1/notes/notes/\(id)/restore"
        case .xoaVinhVien(let id): return "/api/v1/notes/notes/\(id)/permanent"
        case .layLienKetNguoc(let id): return "/api/v1/notes/notes/\(id)/backlinks"
        case .baoCaoTraLoiAI: return "/api/v1/ai/feedback"
        case .dsPhienChat: return "/api/v1/ai/chat/sessions"
        case .lichSuPhienChat(let id): return "/api/v1/ai/chat/history/\(id)"
        case .taoPhienChat: return "/api/v1/ai/chat/sessions"
        case .suaPhienChat(let id, _): return "/api/v1/ai/chat/sessions/\(id)"
        case .xoaPhienChat(let id): return "/api/v1/ai/chat/sessions/\(id)"
        case .dsThuMucChat, .taoThuMucChat: return "/api/v1/ai/chat/folders"
        case .xoaThuMucChat(let id): return "/api/v1/ai/chat/folders/\(id)"
        case .chuyenThuMuc(let id, _): return "/api/v1/ai/chat/sessions/\(id)/folder"
        case .tachNhanhPhien(let id, _): return "/api/v1/ai/chat/sessions/\(id)/fork"
        case .catPhien(let id, _): return "/api/v1/ai/chat/sessions/\(id)/cat"
        case .datViecDoc: return "/api/v1/voice-mini/tts"
        case .xoaBaiViet(let id): return "/api/v1/social/posts/\(id)"
        case .suaBaiViet(let id, _): return "/api/v1/social/posts/\(id)"
        case .ghimBaiViet(let id): return "/api/v1/social/posts/\(id)/pin"
        case .layTuVung: return "/api/v1/notes/vocab"
        case .themTuVung: return "/api/v1/notes/vocab"
        case .suaTuVung(let id, _): return "/api/v1/notes/vocab/\(id)"
        case .xoaTuVung(let id): return "/api/v1/notes/vocab/\(id)"
        case .layBoThe: return "/api/v1/notes/flashcards"
        case .chamThe: return "/api/v1/notes/flashcards/grade"
        case .datLaiThe: return "/api/v1/notes/flashcards/reset"
        case .layPhienBan(let id): return "/api/v1/notes/notes/\(id)/versions"
        case .layMotPhienBan(let id, let v): return "/api/v1/notes/notes/\(id)/versions/\(v)"
        case .luuMocPhienBan(let id): return "/api/v1/notes/notes/\(id)/versions"
        case .khoiPhucPhienBan(let id, let v): return "/api/v1/notes/notes/\(id)/versions/\(v)/restore"
        case .layViecAI: return "/api/v1/notes/ai/actions"
        case .chayViecAI: return "/api/v1/notes/ai/assist"
        case .hoiTroLyGhiChu: return "/api/v1/notes/ai/hoi"
        case .laySoDoGhiChu: return "/api/v1/notes/graph"
        case .layBangTheoMon(let id): return "/api/v1/notes-databases/subject/\(id)"
        case .layBang(let id): return "/api/v1/notes-databases/\(id)"
        case .taoDongBang(let id): return "/api/v1/notes-databases/\(id)/rows"
        case .suaDongBang(let id, _): return "/api/v1/notes-databases/rows/\(id)"
        case .xoaDongBang(let id): return "/api/v1/notes-databases/rows/\(id)"

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
             .createComment, .likeComment, .savePost, .sendMessage, .sendMessageWithFiles, .enrollCourse,
             .sendMessageMedia, .toggleMessageReaction, .recallMessage,
             .boLuuTruHoiThoai, .danhDauChuaDoc, .danhDauDaXemTin, .taoTin, .taoChuong,
             .luuMocPhienBan, .khoiPhucPhienBan, .chayViecAI, .hoiTroLyGhiChu, .taoDongBang,
             .taoMon, .nhanBanGhiChu, .khoiPhucGhiChu, .dangKyThietBi,
             .themTuVung, .chamThe, .datLaiThe, .ghimBaiViet, .baoCaoTraLoiAI,
             .createNote, .reportPost, .reportThread, .blockUser, .requestDeletion,
             .openThread, .muteThread, .saveLessonProgress,
             .taoPhienChat, .taoThuMucChat, .tachNhanhPhien, .catPhien, .datViecDoc:
            return "POST"
        case .updateProfile, .datBietDanh:
            return "PUT"
        case .updateNote, .markRead, .reactPost, .markNotificationsRead, .datTuyChonHoiThoai,
             .suaDongBang, .suaMon, .suaChuong, .suaTuVung, .suaBaiViet,
             .suaPhienChat, .chuyenThuMuc:
            return "PATCH"
        case .deletePost, .unlikePost, .unsavePost, .deleteNote,
             .unblockUser, .cancelDeletionRequest, .deleteMessage, .xoaTin, .xoaDongBang,
             .xoaMon, .xoaChuong, .xoaVinhVien, .goThietBi, .xoaTuVung, .xoaBaiViet,
             .xoaPhienChat, .xoaThuMucChat:
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
        case .createComment(let postId, let c, let p, let mUrl, let mKind):
            var m: [String: Any] = ["postId": postId, "content": c]
            if let p { m["parentId"] = p }
            // Máy chủ chỉ nhận media khi CÓ ĐỦ cặp url + kind, và kind phải là
            // gif | sticker | image.
            if let mUrl, let mKind, !mUrl.isEmpty { m["mediaUrl"] = mUrl; m["mediaKind"] = mKind }
            return m
        case .savePost(_, let f):
            return f != nil ? ["folder": f!] : nil
        case .sendMessageMedia(_, let u, let k):
            return ["media": ["url": u, "kind": k]]
        case .toggleMessageReaction(_, let e):
            return ["emoji": e]
        case .suaDongBang(_, let v):
            // Máy chủ nhận NGUYÊN bản đồ `values`, không nhận từng ô lẻ.
            return ["values": v]
        case .chayViecAI(let a, let sel):
            return ["action": a, "selection": sel]
        case .hoiTroLyGhiChu(let q):
            return ["question": q]
        case .taoPhienChat(let t):
            return t.map { ["title": $0] } ?? [:]
        case .suaPhienChat(_, let d): return d
        case .taoThuMucChat(let ten, let mau):
            var d: [String: Any] = ["ten": ten]
            if let mau { d["mau"] = mau }
            return d
        case .chuyenThuMuc(_, let fid):
            // `null` là BỎ khỏi thư mục — khác hẳn không gửi trường.
            return ["folderId": fid as Any]
        case .datViecDoc(let t): return ["text": t]
        case .tachNhanhPhien(_, let i): return ["denChiSo": i]
        case .catPhien(_, let i): return ["tuChiSo": i]
        case .baoCaoTraLoiAI(let mid):
            return ["messageId": mid ?? 0, "rating": 1, "feedbackType": "REPORT",
                    "comment": "Người dùng báo cáo từ app iOS"]
        case .suaBaiViet(_, let d): return d
        case .themTuVung(let nid, let t, let r, let m, let e):
            var d: [String: Any] = ["noteId": nid, "term": t]
            if let r, !r.isEmpty { d["reading"] = r }
            if let m, !m.isEmpty { d["meaning"] = m }
            if let e, !e.isEmpty { d["example"] = e }
            return d
        case .suaTuVung(_, let d): return d
        case .chamThe(let vid, let k): return ["vocabId": vid, "known": k]
        case .datLaiThe(let vid): return ["vocabId": vid]
        case .taoChuong(let sid, let t):
            return ["subjectId": sid, "title": t]
        case .taoMon(let n, let c, let e):
            var m: [String: Any] = ["name": n]
            if let c { m["color"] = c }
            if let e { m["emoji"] = e }
            return m
        case .suaMon(_, let d): return d
        case .suaChuong(_, let t): return ["title": t]
        case .dangKyThietBi(let t, let sb):
            return ["token": t, "platform": "ios", "sandbox": sb]
        case .taoTin(let u, let k, let c):
            var m: [String: Any] = ["mediaUrl": u, "mediaType": k, "visibility": "PUBLIC"]
            if let c, !c.isEmpty { m["caption"] = c }
            return m
        case .datBietDanh(_, let t, let a):
            return ["targetId": t, "alias": a]
        case .datTuyChonHoiThoai(_, let slot, let v):
            // `value: nil` PHẢI gửi thành JSON `null` chứ không được bỏ khoá —
            // máy chủ hiểu `null` là "xoá ô này", còn thiếu khoá cũng ra null
            // nhưng dựa vào đó là dựa vào một sự trùng hợp.
            return ["slot": slot, "value": v as Any]
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
        // ⚠️ Tham số của GET PHẢI ở ĐÂY, không phải ở `body`. Đặt `httpBody`
        // lên một yêu cầu GET thì URLSession ném
        // `NSURLErrorDataLengthExceedsMaximum` — hiện ra thành câu
        // "resource exceeds maximum size", nghe như ảnh quá nặng nên rất khó
        // lần ra. Ba đường dưới đây từng dính đúng lỗi này: bảng GIF không tải
        // được, và tìm/lọc ghi chú cũng hỏng câm y hệt.
        case .searchGifs(let q):
            return q.isEmpty ? nil : ["q": q]
        case .dsPhienChat(let luuTru, let fid):
            var d: [String: Any] = [:]
            // Chỉ gửi khi BẬT: backend đọc `archived === '1'`, gửi "0" cũng
            // vô hại nhưng thừa một tham số trong mọi URL.
            if luuTru { d["archived"] = "1" }
            if let fid { d["folderId"] = fid }
            return d.isEmpty ? nil : d
        case .timGhiChu(let q, let sid, let tag):
            var m: [String: Any] = [:]
            if !q.isEmpty { m["q"] = q }
            if let sid { m["subjectId"] = sid }
            if let tag, !tag.isEmpty { m["tag"] = tag }
            return m.isEmpty ? nil : m
        case .locGhiChu(let f):
            return ["f": f]
        // Hai đường này là GET — tham số PHẢI ở đây, không phải `body`.
        // Đặt vào body thì URLSession ném "resource exceeds maximum size".
        case .layTuVung(let nid): return ["noteId": nid]
        case .layBoThe(let nid): return ["noteId": nid]
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
