import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Post Detail View
struct PostDetailView: View {
    let post: SocialPost
    @StateObject private var viewModel = PostDetailViewModel()
    @State private var commentText = ""
    @State private var replyingTo: Comment?
    @State private var showReactions = false
    @State private var showShareSheet = false
    @State private var activeReport: ReportSheet.Target?
    @State private var showBlockConfirm = false
    @State private var didCopyLink = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                postContent
                reactionsSection
                commentsSection
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task { await viewModel.toggleSave() }
                    } label: {
                        Label(viewModel.isSaved ? "Bỏ lưu" : "Lưu bài viết",
                              systemImage: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                    }

                    Button {
                        copyLink()
                    } label: {
                        Label(didCopyLink ? "Đã sao chép" : "Sao chép liên kết", systemImage: "link")
                    }

                    Button {
                        ModerationStore.shared.hide(postId: post.id)
                        dismiss()
                    } label: {
                        Label("Ẩn bài viết này", systemImage: "eye.slash")
                    }

                    Button(role: .destructive) {
                        activeReport = .post(id: post.id, authorId: post.author.id, authorName: post.author.name)
                    } label: {
                        Label("Báo cáo bài viết", systemImage: "flag")
                    }

                    Button(role: .destructive) {
                        showBlockConfirm = true
                    } label: {
                        Label("Chặn \(post.author.name)", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            commentInputBar
        }
        .onAppear {
            viewModel.post = post
            viewModel.isSaved = post.isSaved
        }
        .sheet(item: $activeReport) { target in
            ReportSheet(target: target)
        }
        .alert("Chặn \(post.author.name)?", isPresented: $showBlockConfirm) {
            Button("Huỷ", role: .cancel) { }
            Button("Chặn", role: .destructive) {
                Task {
                    try? await ModerationStore.shared.block(userId: post.author.id)
                    dismiss()
                }
            }
        } message: {
            Text("Bạn sẽ không thấy bài viết của người này nữa và họ không thể nhắn tin cho bạn.")
        }
    }

    private func copyLink() {
        let link = "https://cuongthai.com/feed/\(post.id)"
        #if os(iOS)
        UIPasteboard.general.string = link
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
        #endif
        didCopyLink = true
    }

    private var postContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Author Header
            postHeader

            // Post Content
            Text(post.content)
                .font(.bodyLarge)
                .foregroundColor(AppColors.textPrimary)
                .textSelection(.enabled)

            // Media
            if let media = post.media, !media.isEmpty {
                mediaCarousel(media)
            }

            // Poll
            if let poll = post.poll {
                pollView(poll)
            }

            // Music Track
            if let music = post.musicTrack {
                musicTrackView(music)
            }

            // Reactions summary
            if let breakdown = post.reactionBreakdown {
                reactionsBreakdownView(breakdown)
            }

            // Stats
            statsRow
        }
        .padding(Spacing.md)
    }

    private var postHeader: some View {
        HStack(spacing: Spacing.md) {
            NavigationLink(destination: UserProfileView(userId: post.author.id)) {
                UserAvatarView(url: post.author.avatarUrl, size: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                NavigationLink(destination: UserProfileView(userId: post.author.id)) {
                    HStack(spacing: 4) {
                        Text(post.author.name)
                            .font(.titleSmall)
                            .foregroundColor(AppColors.textPrimary)

                        if post.author.isFollowing == true {
                            Text("•")
                                .foregroundColor(AppColors.textSecondary)
                            Text("Theo dõi")
                                .font(.caption)
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }

                HStack(spacing: 4) {
                    Text("@\(post.author.username)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Text("•")
                        .foregroundColor(AppColors.textSecondary)

                    Text(TimeFormatter.formatTimeAgo(post.createdAt))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Text("•")
                        .foregroundColor(AppColors.textSecondary)

                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(AppColors.textSecondary)
                    .padding(Spacing.sm)
                    .background(AppColors.backgroundTertiary)
                    .clipShape(Circle())
            }
        }
    }

    private func mediaCarousel(_ media: [SocialMedia]) -> some View {
        VStack(spacing: Spacing.sm) {
            TabView {
                ForEach(media) { item in
                    ZStack {
                        #if canImport(Kingfisher)
                        if let url = URL(string: item.thumbnail ?? item.url) {
                            KFImage(url)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 400)
                        }
                        #endif

                        if item.type == "VIDEO" {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(radius: 4)
                        }
                    }
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))
            #endif
            .frame(height: media.count > 1 ? 350 : nil)

            if media.count > 1 {
                HStack(spacing: 4) {
                    ForEach(0..<media.count, id: \.self) { index in
                        Circle()
                            .fill(index == 0 ? AppColors.primary : AppColors.textTertiary)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }

    private func pollView(_ poll: SocialPoll) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(poll.question)
                .font(.titleSmall)
                .foregroundColor(AppColors.textPrimary)

            ForEach(poll.options ?? []) { option in
                pollOptionRow(option, poll: poll)
            }

            HStack {
                Text("\(poll.totalVotes ?? 0) bình chọn")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                if let closesAt = poll.closesAt {
                    Text("•")
                        .foregroundColor(AppColors.textSecondary)
                    Text("Kết thúc \(TimeFormatter.formatTimeAgo(closesAt))")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.medium)
    }

    private func pollOptionRow(_ option: PollOption, poll: SocialPoll) -> some View {
        Button {
            Task {
                await viewModel.votePoll(optionId: option.id, pollId: poll.id)
            }
        } label: {
            HStack {
                Text(option.text)
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if let percentage = option.percentage {
                    Text("\(Int(percentage * 100))%")
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(Spacing.md)
            .background(
                poll.userVotes?.contains(option.id) == true
                    ? AppColors.primary.opacity(0.2)
                    : AppColors.backgroundSecondary
            )
            .overlay(
                GeometryReader { geo in
                    if let percentage = option.percentage {
                        Rectangle()
                            .fill(AppColors.primary.opacity(0.3))
                            .frame(width: geo.size.width * percentage)
                    }
                }
            )
            .cornerRadius(CornerRadius.small)
        }
        .disabled(poll.userVotes != nil)
    }

    private func musicTrackView(_ track: MusicTrackInfo) -> some View {
        HStack(spacing: Spacing.md) {
            #if canImport(Kingfisher)
            if let coverURL = track.coverImage, let url = URL(string: coverURL) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .cornerRadius(CornerRadius.small)
            } else {
                musicPlaceholder
            }
            #else
            musicPlaceholder
            #endif

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Label only — the app does not stream music (see APP_REVIEW_NOTES.md).
            Image(systemName: "music.note")
                .font(.system(size: 24))
                .foregroundColor(AppColors.primary)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.medium)
    }

    private var musicPlaceholder: some View {
        RoundedRectangle(cornerRadius: CornerRadius.small)
            .fill(AppColors.backgroundSecondary)
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(AppColors.textSecondary)
            )
    }

    private func reactionsBreakdownView(_ breakdown: ReactionBreakdown) -> some View {
        HStack(spacing: Spacing.sm) {
            if let like = breakdown.LIKE, like > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "hand.thumbsup.fill")
                        .foregroundColor(AppColors.like)
                    Text("\(like)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if let love = breakdown.LOVE, love > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(AppColors.love)
                    Text("\(love)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if let haha = breakdown.HAHA, haha > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "face.smiling")
                        .foregroundColor(AppColors.haha)
                    Text("\(haha)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()
        }
    }

    private var statsRow: some View {
        HStack {
            Text("\(post.viewsCount ?? post.likesCount) lượt xem")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            if post.commentsCount > 0 {
                Text("\(post.commentsCount) bình luận")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            if post.sharesCount > 0 {
                Text("•")
                    .foregroundColor(AppColors.textSecondary)
                Text("\(post.sharesCount) chia sẻ")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private var reactionsSection: some View {
        VStack(spacing: Spacing.sm) {
            Divider()
                .background(AppColors.divider)

            // Quick reactions
            HStack(spacing: Spacing.lg) {
                reactionButton(emoji: "👍", label: "Thích", count: post.likesCount) {
                    Task {
                        await viewModel.toggleLike()
                    }
                }

                reactionButton(emoji: "❤️", label: "Yêu thích", count: nil) {
                    Task {
                        await viewModel.react(type: "LOVE")
                    }
                }

                reactionButton(emoji: "😂", label: "Haha", count: nil) {
                    Task {
                        await viewModel.react(type: "HAHA")
                    }
                }

                reactionButton(emoji: nil, label: "Bình luận", count: nil) {
                    isCommentFocused = true
                }

                Spacer()

                // ShareLink của hệ thống: người dùng chọn gửi đi đâu bằng
                // bảng chia sẻ chuẩn của iOS, không phải dựng lại tay.
                ShareLink(
                    item: URL(string: "https://cuongthai.com/feed/\(post.id)")!,
                    subject: Text(post.author.name),
                    message: Text(post.content.prefix(120)),
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Chia sẻ")
                    }
                    .font(.buttonSmall)
                    .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    private func reactionButton(emoji: String?, label: String, count: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.title3)
                } else {
                    Image(systemName: label == "Bình luận" ? "bubble.right" : "hand.thumbsup")
                        .foregroundColor(AppColors.textSecondary)
                }
                Text(label)
                    .font(.buttonSmall)
                    .foregroundColor(AppColors.textSecondary)

                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Bình luận")
                    .font(.titleMedium)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Menu {
                    Button("Mới nhất") { viewModel.sortOrder = .newest }
                    Button("Cũ nhất") { viewModel.sortOrder = .oldest }
                    Button("Phổ biến nhất") { viewModel.sortOrder = .popular }
                } label: {
                    HStack(spacing: 4) {
                        Text("Sắp xếp")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.primary)
                }
            }
            .padding(.horizontal, Spacing.md)

            if viewModel.isLoading && viewModel.comments.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, Spacing.xl)
            } else if viewModel.comments.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)

                    Text("Chưa có bình luận nào")
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)

                    Text("Hãy là người đầu tiên bình luận!")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
            } else {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(viewModel.comments) { comment in
                        CommentRow(
                            comment: comment,
                            onReply: {
                                replyingTo = comment
                                isCommentFocused = true
                            },
                            onLike: {
                                Task {
                                    await viewModel.likeComment(commentId: comment.id)
                                }
                            },
                            onReport: {
                                activeReport = .comment(
                                    postId: post.id,
                                    commentId: comment.id,
                                    authorName: comment.author.name
                                )
                            }
                        )
                    }

                    if viewModel.hasMore {
                        ProgressView()
                            .padding()
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreComments()
                                }
                            }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
        .padding(.top, Spacing.md)
    }

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.divider)

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                UserAvatarView(url: AppState.shared.currentUser?.avatarUrl, size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    if let replying = replyingTo {
                        HStack(spacing: Spacing.sm) {
                            Text("Trả lời @\(replying.author.username)")
                                .font(.caption)
                                .foregroundColor(AppColors.primary)

                            Button {
                                replyingTo = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }

                    TextField("Viết bình luận...", text: $commentText, axis: .vertical)
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1...5)
                        .focused($isCommentFocused)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.sm)
                        .background(AppColors.backgroundTertiary)
                        .cornerRadius(CornerRadius.large)
                }

                Button {
                    Task {
                        await viewModel.addComment(content: commentText, parentId: replyingTo?.id)
                        commentText = ""
                        replyingTo = nil
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(commentText.isEmpty ? AppColors.textTertiary : AppColors.primary)
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.backgroundSecondary)
        }
    }
}

// MARK: - Comment Row
struct CommentRow: View {
    let comment: Comment
    let onReply: () -> Void
    let onLike: () -> Void
    var onReport: (() -> Void)? = nil

    @State private var showReplies = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                NavigationLink(destination: UserProfileView(userId: comment.author.id)) {
                    UserAvatarView(url: comment.author.avatarUrl, size: 36)
                }

                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        NavigationLink(destination: UserProfileView(userId: comment.author.id)) {
                            Text(comment.author.name)
                                .font(.titleSmall)
                                .foregroundColor(AppColors.textPrimary)
                        }

                        Text(comment.content)
                            .font(.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: Spacing.md) {
                        Text(TimeFormatter.formatTimeAgo(comment.createdAt))
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)

                        Button {
                            onLike()
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                                    .font(.caption)
                                if comment.likesCount > 0 {
                                    Text("\(comment.likesCount)")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(comment.isLiked ? AppColors.love : AppColors.textTertiary)
                        }

                        Button {
                            onReply()
                        } label: {
                            Text("Trả lời")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }

                        if let onReport {
                            Menu {
                                Button(role: .destructive, action: onReport) {
                                    Label("Báo cáo bình luận", systemImage: "flag")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                }

                Spacer()
            }

            // Replies toggle
            if let repliesCount = comment.repliesCount, repliesCount > 0 {
                Button {
                    withAnimation {
                        showReplies.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(AppColors.divider)
                            .frame(width: 24, height: 1)
                        Text(showReplies ? "Ẩn trả lời" : "Xem \(repliesCount) trả lời")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
    }
}

// MARK: - Post Detail View Model
@MainActor
class PostDetailViewModel: ObservableObject {
    @Published var post: SocialPost?
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasMore = true
    @Published var sortOrder: CommentSortOrder = .newest

    private var cursor: Int?

    /// Mirrors `post.isSaved` so the toolbar label flips without a refetch.
    @Published var isSaved = false

    func toggleSave() async {
        guard let post else { return }
        let target = !isSaved
        isSaved = target
        do {
            try await APIClient.shared.send(target ? .savePost(id: post.id, folder: nil)
                                                   : .unsavePost(id: post.id))
        } catch {
            isSaved = !target
            self.error = error.localizedDescription
        }
    }

    func loadComments() async {
        guard let postId = post?.id else { return }

        isLoading = true
        cursor = nil

        do {
            let response: CommentsResponse = try await APIClient.shared.request(
                .getComments(postId: postId, cursor: nil, limit: 20)
            )
            comments = response.items
            cursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreComments() async {
        guard let postId = post?.id, hasMore, !isLoading else { return }

        do {
            let response: CommentsResponse = try await APIClient.shared.request(
                .getComments(postId: postId, cursor: cursor, limit: 20)
            )
            comments.append(contentsOf: response.items)
            cursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addComment(content: String, parentId: Int?) async {
        guard let postId = post?.id else { return }

        let tempComment = Comment(
            id: Int.random(in: 100000...999999),
            content: content,
            author: AppState.shared.currentUser ?? User(id: 0, username: "temp", email: nil, fullName: "Temp", displayName: nil, avatarUrl: nil, coverPhotoUrl: nil, bio: nil, isFollowing: nil, isFollowedBy: nil, followersCount: nil, followingCount: nil, postsCount: nil, createdAt: nil),
            likesCount: 0,
            repliesCount: nil,
            isLiked: false,
            parentId: parentId,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        comments.insert(tempComment, at: 0)

        do {
            let newComment: Comment = try await APIClient.shared.request(
                .createComment(postId: postId, content: content, parentId: parentId)
            )

            if let index = comments.firstIndex(where: { $0.id == tempComment.id }) {
                comments[index] = newComment
            }
        } catch {
            comments.removeAll { $0.id == tempComment.id }
            self.error = error.localizedDescription
        }
    }

    func likeComment(commentId: Int) async {
        // Toggle like locally
        if let index = comments.firstIndex(where: { $0.id == commentId }) {
            var comment = comments[index]
            let wasLiked = comment.isLiked
            comments[index] = Comment(
                id: comment.id,
                content: comment.content,
                author: comment.author,
                likesCount: wasLiked ? comment.likesCount - 1 : comment.likesCount + 1,
                repliesCount: comment.repliesCount,
                isLiked: !wasLiked,
                parentId: comment.parentId,
                createdAt: comment.createdAt
            )
        }
    }

    func toggleLike() async {
        guard let postId = post?.id else { return }

        // Toggle locally
        post = SocialPost(
            id: post!.id,
            content: post!.content,
            author: post!.author,
            media: post!.media,
            poll: post!.poll,
            youtubeUrl: post!.youtubeUrl,
            musicTrack: post!.musicTrack,
            type: post!.type,
            visibility: post!.visibility,
            likesCount: post!.isLiked ? post!.likesCount - 1 : post!.likesCount + 1,
            commentsCount: post!.commentsCount,
            sharesCount: post!.sharesCount,
            savesCount: post!.savesCount,
            viewsCount: post!.viewsCount,
            isLiked: !post!.isLiked,
            isSaved: post!.isSaved,
            myReaction: post!.myReaction,
            reactionBreakdown: post!.reactionBreakdown,
            createdAt: post!.createdAt,
            updatedAt: post!.updatedAt
        )

        do {
            if post!.isLiked {
                let _: EmptyResponse = try await APIClient.shared.request(.likePost(id: postId))
            } else {
                let _: EmptyResponse = try await APIClient.shared.request(.unlikePost(id: postId))
            }
        } catch {
            // Revert
            post = SocialPost(
                id: post!.id,
                content: post!.content,
                author: post!.author,
                media: post!.media,
                poll: post!.poll,
                youtubeUrl: post!.youtubeUrl,
                musicTrack: post!.musicTrack,
                type: post!.type,
                visibility: post!.visibility,
                likesCount: post!.isLiked ? post!.likesCount - 1 : post!.likesCount + 1,
                commentsCount: post!.commentsCount,
                sharesCount: post!.sharesCount,
                savesCount: post!.savesCount,
                viewsCount: post!.viewsCount,
                isLiked: !post!.isLiked,
                isSaved: post!.isSaved,
                myReaction: post!.myReaction,
                reactionBreakdown: post!.reactionBreakdown,
                createdAt: post!.createdAt,
                updatedAt: post!.updatedAt
            )
        }
    }

    func react(type: String) async {
        guard let postId = post?.id else { return }

        do {
            let _: EmptyResponse = try await APIClient.shared.request(.reactPost(id: postId, type: type))
            // Update reaction locally
            post = SocialPost(
                id: post!.id,
                content: post!.content,
                author: post!.author,
                media: post!.media,
                poll: post!.poll,
                youtubeUrl: post!.youtubeUrl,
                musicTrack: post!.musicTrack,
                type: post!.type,
                visibility: post!.visibility,
                likesCount: post!.likesCount + 1,
                commentsCount: post!.commentsCount,
                sharesCount: post!.sharesCount,
                savesCount: post!.savesCount,
                viewsCount: post!.viewsCount,
                isLiked: true,
                isSaved: post!.isSaved,
                myReaction: type,
                reactionBreakdown: post!.reactionBreakdown,
                createdAt: post!.createdAt,
                updatedAt: post!.updatedAt
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func votePoll(optionId: Int, pollId: Int) async {
        // Vote locally would be implemented
    }
}

// MARK: - Comment Sort Order
enum CommentSortOrder {
    case newest
    case oldest
    case popular
}

#Preview {
    NavigationStack {
        PostDetailView(post: SocialPost(
            id: 1,
            content: "Đây là một bài viết mẫu với nội dung dài để test UI. Bài viết này có thể chứa nhiều dòng text khác nhau.",
            author: User(id: 1, username: "testuser", email: nil, fullName: "Test User", displayName: nil, avatarUrl: nil, coverPhotoUrl: nil, bio: nil, isFollowing: nil, isFollowedBy: nil, followersCount: 100, followingCount: 50, postsCount: 10, createdAt: nil),
            media: nil,
            poll: nil,
            youtubeUrl: nil,
            musicTrack: nil,
            type: "post",
            visibility: "public",
            likesCount: 42,
            commentsCount: 5,
            sharesCount: 3,
            savesCount: 1,
            viewsCount: 100,
            isLiked: false,
            isSaved: false,
            myReaction: nil,
            reactionBreakdown: nil,
            createdAt: "2024-01-15T10:30:00Z",
            updatedAt: "2024-01-15T10:30:00Z"
        ))
    }
}
