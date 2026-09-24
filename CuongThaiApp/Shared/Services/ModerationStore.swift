	import Foundation
import Combine

// MARK: - Moderation
//
// App Store Guideline 1.2 ("User-Generated Content") requires FOUR things
// from any app with a public feed. This file is the client half of all four:
//
//   1. a method for filtering objectionable content  → `hide(post:)`
//   2. a mechanism to report offensive content       → `report(postId:…)`
//   3. the ability to block abusive users            → `block(userId:)`
//   4. published contact info for moderation         → see LegalViews.swift
//
// Blocks are server-side (`/messages/blocks`, shared with the web) so they
// follow the account across devices. They are ALSO mirrored to a local set
// because the feed endpoint does not filter blocked authors itself — the
// mirror makes a block take effect instantly, before the next fetch.
//
// `hiddenPostIds` is a purely local "hide this post" list: Apple expects a
// user to be able to make an offensive post go away immediately, without
// waiting for a moderator.

struct BlockedUser: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let displayName: String
    let avatarUrl: String?
    let reason: String?
}

enum ReportReason: String, CaseIterable, Identifiable {
    case spam = "SPAM"
    case misinformation = "MISINFORMATION"
    case harassment = "HARASSMENT"
    case violence = "VIOLENCE"
    case other = "OTHER"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam: return "Spam hoặc lừa đảo"
        case .misinformation: return "Thông tin sai sự thật"
        case .harassment: return "Quấy rối, xúc phạm, thù ghét"
        case .violence: return "Bạo lực hoặc nội dung nguy hiểm"
        case .other: return "Lý do khác"
        }
    }
}

@MainActor
final class ModerationStore: ObservableObject {
    static let shared = ModerationStore()

    @Published private(set) var blockedUserIds: Set<Int> = []
    @Published private(set) var hiddenPostIds: Set<Int> = []
    @Published private(set) var blockedUsers: [BlockedUser] = []
    @Published private(set) var isLoading = false

    private let defaults = UserDefaults.standard
    private let blockedKey = "com.cuongthai.app.blocked_user_ids"
    private let hiddenKey = "com.cuongthai.app.hidden_post_ids"

    private init() {
        blockedUserIds = Set(defaults.array(forKey: blockedKey) as? [Int] ?? [])
        hiddenPostIds = Set(defaults.array(forKey: hiddenKey) as? [Int] ?? [])
    }

    // MARK: - Filtering

    /// True when a post must not be rendered for this viewer.
    func isHidden(_ post: SocialPost) -> Bool {
        hiddenPostIds.contains(post.id) || blockedUserIds.contains(post.author.id)
    }

    func filter(_ posts: [SocialPost]) -> [SocialPost] {
        posts.filter { !isHidden($0) }
    }

    func hide(postId: Int) {
        hiddenPostIds.insert(postId)
        persistHidden()
    }

    func unhideAll() {
        hiddenPostIds.removeAll()
        persistHidden()
    }

    // MARK: - Blocking

    func refreshBlocks() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let list: [BlockedUser] = try await APIClient.shared.request(.listBlocks)
            blockedUsers = list
            blockedUserIds = Set(list.map(\.id))
            persistBlocked()
        } catch {
            // Offline or 401 — keep the local mirror rather than un-blocking.
        }
    }

    func block(userId: Int, reason: String? = nil) async throws {
        try await APIClient.shared.send(.blockUser(id: userId, reason: reason))
        blockedUserIds.insert(userId)
        persistBlocked()
        await refreshBlocks()
    }

    func unblock(userId: Int) async throws {
        try await APIClient.shared.send(.unblockUser(id: userId))
        blockedUserIds.remove(userId)
        blockedUsers.removeAll { $0.id == userId }
        persistBlocked()
    }

    // MARK: - Reporting

    func report(postId: Int, reason: ReportReason, details: String?) async throws {
        try await APIClient.shared.send(
            .reportPost(id: postId, reason: reason.rawValue, details: details)
        )
        // A reported post disappears for the reporter straight away.
        hide(postId: postId)
    }

    /// Comments have no dedicated endpoint on the backend, so a comment report
    /// is filed against its parent post with the comment id in the details —
    /// the moderator queue shows the full text either way.
    func reportComment(postId: Int, commentId: Int, reason: ReportReason, details: String?) async throws {
        let note = "Bình luận #\(commentId): " + (details ?? "")
        try await APIClient.shared.send(
            .reportPost(id: postId, reason: reason.rawValue, details: note)
        )
    }

    /// Báo cáo nội dung KHÔNG phải bài viết: tin 24h, bình luận câu hỏi thi,
    /// hồ sơ người dùng, câu trả lời AI ở các màn không lưu tin nhắn.
    ///
    /// Backend chưa có endpoint báo cáo chung (chỉ có bài viết, hội thoại,
    /// bình luận tư vấn, bình luận CT Work). `POST /academy/advisor/report-answer`
    /// là đường DUY NHẤT nhận văn bản tự do và đẩy thẳng vào hàng thông báo
    /// `BAO_CAO` của admin — `facultyId` được in vào tiêu đề nên dùng làm nhãn
    /// nguồn ("TIN 24H #12 · user #5"). KHÔNG dùng `reportPost` với id của thứ
    /// khác: bảng `post_reports` có khoá ngoại tới `posts`, id tin/bình luận
    /// sẽ trỏ nhầm sang một bài viết không liên quan hoặc hỏng hẳn.
    func baoCaoNoiDung(nhan: String, noiDung: String, ngucanh: String?,
                       lyDo: ReportReason, chiTiet: String?) async throws {
        let chu = noiDung.trimmingCharacters(in: .whitespacesAndNewlines)
        var lyDoDayDu = lyDo.label
        if let c = chiTiet?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            lyDoDayDu += " — " + c
        }
        try await APIClient.shared.send(.tuVanBaoCaoTraLoi(than: [
            "answer": chu.isEmpty ? "(không có chữ)" : chu,
            "question": ngucanh ?? "",
            "reason": lyDoDayDu,
            "facultyId": String(nhan.prefix(64)),
            // Backend in `nguon` vào tiêu đề ("Báo cáo nội dung: …") thay cho
            // câu mặc định "câu trả lời AI ở Phòng tư vấn".
            "nguon": String(nhan.prefix(64)),
        ]))
    }

    // MARK: - Persistence

    private func persistBlocked() {
        defaults.set(Array(blockedUserIds), forKey: blockedKey)
    }

    private func persistHidden() {
        defaults.set(Array(hiddenPostIds), forKey: hiddenKey)
    }

    func reset() {
        blockedUserIds = []
        hiddenPostIds = []
        blockedUsers = []
        defaults.removeObject(forKey: blockedKey)
        defaults.removeObject(forKey: hiddenKey)
    }
}
