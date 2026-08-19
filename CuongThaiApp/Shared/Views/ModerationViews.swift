import SwiftUI

// MARK: - Report sheet (App Store Guideline 1.2)

struct ReportSheet: View {
    enum Target: Identifiable {
        case post(id: Int, authorId: Int, authorName: String)
        case comment(postId: Int, commentId: Int, authorName: String)

        // Two `.sheet` modifiers on one view fight over the presentation slot
        // in SwiftUI — every screen here presents ONE `.sheet(item:)` instead.
        var id: String {
            switch self {
            case .post(let id, _, _): return "post-\(id)"
            case .comment(_, let commentId, _): return "comment-\(commentId)"
            }
        }

        var title: String {
            switch self {
            case .post: return "Báo cáo bài viết"
            case .comment: return "Báo cáo bình luận"
            }
        }

        var authorName: String {
            switch self {
            case .post(_, _, let name), .comment(_, _, let name): return name
            }
        }
    }

    let target: Target
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var moderation = ModerationStore.shared

    @State private var reason: ReportReason = .harassment
    @State private var details = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var didSend = false
    @State private var alsoBlockAuthor = false

    var body: some View {
        NavigationStack {
            Form {
                if didSend {
                    Section {
                        Label("Đã gửi báo cáo", systemImage: "checkmark.seal.fill")
                            .foregroundColor(AppColors.success)
                        Text("Đội kiểm duyệt sẽ xem xét trong vòng 24 giờ. Nội dung này đã được ẩn khỏi màn hình của bạn.")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    }
                } else {
                    Section("Lý do") {
                        Picker("Lý do", selection: $reason) {
                            ForEach(ReportReason.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }

                    Section("Mô tả thêm (không bắt buộc)") {
                        TextField("Điều gì khiến bạn thấy nội dung này vi phạm?", text: $details, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    if case .post(_, let authorId, let name) = target, authorId > 0 {
                        Section {
                            Toggle("Chặn luôn \(name)", isOn: $alsoBlockAuthor)
                        } footer: {
                            Text("Chặn sẽ ẩn toàn bộ bài viết của người này và chặn họ nhắn tin cho bạn.")
                        }
                    }

                    if let errorMessage {
                        Section { Text(errorMessage).foregroundColor(AppColors.error) }
                    }

                    Section {
                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                Spacer()
                                if isSending { ProgressView() } else { Text("Gửi báo cáo") }
                                Spacer()
                            }
                        }
                        .disabled(isSending)
                    }
                }
            }
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(didSend ? "Xong" : "Huỷ") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        isSending = true
        errorMessage = nil
        do {
            switch target {
            case .post(let id, let authorId, _):
                try await moderation.report(postId: id, reason: reason, details: details)
                if alsoBlockAuthor, authorId > 0 {
                    try await moderation.block(userId: authorId, reason: reason.rawValue)
                }
            case .comment(let postId, let commentId, _):
                try await moderation.reportComment(
                    postId: postId, commentId: commentId, reason: reason, details: details
                )
            }
            didSend = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}

// MARK: - The ••• menu shown on every post

struct PostModerationMenu: View {
    let post: SocialPost
    var isOwnPost: Bool = false

    @ObservedObject private var moderation = ModerationStore.shared
    @State private var showReport = false
    @State private var showBlockConfirm = false

    var body: some View {
        Menu {
            Button {
                moderation.hide(postId: post.id)
            } label: {
                Label("Ẩn bài viết này", systemImage: "eye.slash")
            }

            if !isOwnPost {
                Button(role: .destructive) {
                    showReport = true
                } label: {
                    Label("Báo cáo bài viết", systemImage: "flag")
                }

                Button(role: .destructive) {
                    showBlockConfirm = true
                } label: {
                    Label("Chặn \(post.author.name)", systemImage: "hand.raised")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.gray)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(target: .post(id: post.id, authorId: post.author.id, authorName: post.author.name))
        }
        .alert("Chặn \(post.author.name)?", isPresented: $showBlockConfirm) {
            Button("Huỷ", role: .cancel) { }
            Button("Chặn", role: .destructive) {
                Task { try? await moderation.block(userId: post.author.id) }
            }
        } message: {
            Text("Bạn sẽ không thấy bài viết của người này nữa và họ không thể nhắn tin cho bạn. Có thể bỏ chặn trong Cài đặt.")
        }
    }
}

// MARK: - Blocked users (Settings → Danh sách chặn)

struct BlockedUsersView: View {
    @ObservedObject private var moderation = ModerationStore.shared
    @State private var errorMessage: String?

    var body: some View {
        List {
            if moderation.blockedUsers.isEmpty {
                Section {
                    Text(moderation.isLoading ? "Đang tải…" : "Bạn chưa chặn ai.")
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                Section {
                    ForEach(moderation.blockedUsers) { user in
                        HStack(spacing: Spacing.md) {
                            UserAvatarView(url: user.avatarUrl, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            Button("Bỏ chặn") {
                                Task {
                                    do { try await moderation.unblock(userId: user.id) }
                                    catch { errorMessage = error.localizedDescription }
                                }
                            }
                            .buttonStyle(.borderless)
                            .font(.buttonSmall)
                        }
                    }
                } footer: {
                    Text("Người bị chặn không thể nhắn tin cho bạn, và bài viết của họ được ẩn khỏi bảng tin.")
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundColor(AppColors.error) }
            }
        }
        .navigationTitle("Danh sách chặn")
        .navigationBarTitleDisplayMode(.inline)
        .task { await moderation.refreshBlocks() }
        .refreshable { await moderation.refreshBlocks() }
    }
}
