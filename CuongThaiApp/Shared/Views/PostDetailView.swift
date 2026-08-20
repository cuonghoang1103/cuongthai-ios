import SwiftUI
#if os(iOS)
import PhotosUI
#endif
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Post Detail View
struct PostDetailView: View {
    let post: SocialPost
    @StateObject private var viewModel = PostDetailViewModel()
    @State private var commentText = ""
    @State private var replyingTo: Comment?
    @State private var anhKem: String?
    @State private var loaiAnhKem: String?
    @State private var dangGuiBinhLuan = false
    @State private var dangTaiAnhBinhLuan = false
    @State private var hienGifBinhLuan = false
    @State private var hienEmojiBinhLuan = false
    #if os(iOS)
    @State private var anhChonBinhLuan: [PhotosPickerItem] = []
    #endif
    @State private var showReactions = false
    @State private var showShareSheet = false
    @State private var activeReport: ReportSheet.Target?
    @State private var showBlockConfirm = false
    @State private var hienChonCamXuc = false
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

                    // Không báo cáo / chặn chính mình.
                    if post.author.id != AppState.shared.currentUser?.id {
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
        .task(id: post.id) {
            viewModel.post = post
            viewModel.isSaved = post.isSaved
            viewModel.daThich = post.isLiked
            viewModel.camXucHienTai = post.myReaction
            // `loadComments()` CHƯA TỪNG được gọi — nên bài ghi "3 bình luận"
            // mà bên dưới hiện "Chưa có bình luận nào". Hai con số ở hai chỗ,
            // không ai nối lại.
            await viewModel.loadComments()
        }
        .sheet(isPresented: $hienGifBinhLuan) {
            BangChonGif { url in
                anhKem = url
                loaiAnhKem = "gif"
            }
        }
        #if os(iOS)
        .onChange(of: anhChonBinhLuan) { _, moi in
            Task { await taiAnhBinhLuan(moi) }
        }
        #endif
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

            // Ảnh/video ĐẶT TRƯỚC nội dung. Bài giảng dài 4000+ ký tự mà để
            // ảnh ở dưới thì người đọc cuộn hết bài mới thấy — trên web ảnh là
            // thứ đập vào mắt đầu tiên.
            if let media = post.media, !media.isEmpty {
                mediaCarousel(media)
            }

            // Nội dung: tiêu đề, đường kẻ ngăn phần, khối mã tô màu — theo
            // ĐÚNG luật web dùng. Trước đây chỉ `Text(post.content)`, nên khối
            // mã hiện cả dấu ``` và không có phân đoạn nào.
            NoiDungBaiViet(noiDung: post.content)

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

    /// Tỉ lệ rộng/cao thật của ảnh; `nil` khi máy chủ không trả kích thước —
    /// lúc đó để SwiftUI tự co theo ảnh tải về.
    private func tiLe(_ m: SocialMedia) -> CGFloat? {
        guard let w = m.width, let h = m.height, w > 0, h > 0 else { return nil }
        return CGFloat(w) / CGFloat(h)
    }

    private func mediaCarousel(_ media: [SocialMedia]) -> some View {
        VStack(spacing: Spacing.sm) {
            TabView {
                ForEach(media) { item in
                    ZStack {
                        #if canImport(Kingfisher)
                        if let url = URL(string: item.thumbnail ?? item.url) {
                            // Ở màn CHI TIẾT hiện TRỌN ảnh theo tỉ lệ thật,
                            // không chặn chiều cao. Ảnh hạ tầng bài học là ảnh
                            // dọc 1080×1900 chứa cả bài — chặn ở 400pt là cắt
                            // mất hơn nửa nội dung mà người dùng vừa mở ra để
                            // đọc. Một ảnh thì nhiều ảnh mới cần khung cố định
                            // (để vuốt qua lại không nhảy chiều cao).
                            KFImage(url)
                                .resizable()
                                .aspectRatio(tiLe(item), contentMode: .fit)
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

    /// Hàng nút dưới bài — ĐÚNG BA nút chia đều, như Facebook.
    ///
    /// Bản cũ nhồi 5 mục (Thích/Yêu thích/Haha/Bình luận/Chia sẻ) vào một hàng
    /// ngang. Trên máy thật chữ vỡ thành "Thí ch", "Yêu thíc h", "Hah a" —
    /// user chụp lại đúng cảnh đó. Ba nút thì đủ chỗ ở mọi cỡ máy, và các cảm
    /// xúc còn lại chuyển vào thao tác GIỮ LÂU, giống hệt Facebook.
    private var reactionsSection: some View {
        VStack(spacing: 0) {
            Divider().background(AppColors.divider)

            HStack(spacing: 0) {
                Button {
                    Task { await viewModel.toggleLike() }
                } label: {
                    nutHanhDong(
                        bieuTuong: viewModel.camXucHienTai != nil ? nil : "hand.thumbsup",
                        hinh: hinhCamXuc,
                        chu: chuCamXuc,
                        noiBat: viewModel.camXucHienTai != nil || viewModel.daThich,
                    )
                }
                // ⚠️ PHẢI là `simultaneousGesture`, KHÔNG phải `onLongPressGesture`.
                // Gắn `.onLongPressGesture` lên một `Button` thì bộ nhận cử chỉ của
                // chính Button giành quyền trước và cú giữ KHÔNG bao giờ tới nơi —
                // bấm giữ mãi mà bảng cảm xúc không hiện. `simultaneousGesture`
                // chạy SONG SONG với cử chỉ của Button nên cả chạm lẫn giữ đều ăn.
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                        Haptics.cham()
                        withAnimation(.snappy(duration: 0.22)) { hienChonCamXuc = true }
                    }
                )

                Button {
                    isCommentFocused = true
                } label: {
                    nutHanhDong(bieuTuong: "bubble.right", hinh: nil, chu: "Bình luận", noiBat: false)
                }

                ShareLink(
                    item: URL(string: "https://cuongthai.com/feed/\(post.id)")!,
                    subject: Text(post.author.name),
                    message: Text(post.content.prefix(120)),
                ) {
                    nutHanhDong(bieuTuong: "square.and.arrow.up", hinh: nil, chu: "Chia sẻ", noiBat: false)
                }
            }
            .padding(.vertical, 2)
            .overlay(alignment: .topLeading) {
                if hienChonCamXuc { bangChonCamXuc }
            }

            Divider().background(AppColors.divider)
        }
    }

    /// Một ô nút chiếm đúng 1/3 chiều ngang. `minimumScaleFactor` là lưới đỡ
    /// cuối: máy hẹp hay cỡ chữ trợ năng lớn thì chữ co lại thay vì xuống dòng.
    private func nutHanhDong(bieuTuong: String?, hinh: String?, chu: String, noiBat: Bool) -> some View {
        HStack(spacing: 5) {
            if let hinh {
                Text(hinh).font(.system(size: 17))
            } else if let bieuTuong {
                Image(systemName: bieuTuong).font(.system(size: 15))
            }
            Text(chu)
                .font(.system(size: 14, weight: noiBat ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(noiBat ? AppColors.primary : AppColors.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private static let cacCamXuc: [(String, String, String)] = [
        ("LIKE", "👍", "Thích"), ("LOVE", "❤️", "Yêu thích"), ("CARE", "🥰", "Thương thương"),
        ("HAHA", "😂", "Haha"), ("WOW", "😮", "Wow"),
        ("SAD", "😢", "Buồn"), ("ANGRY", "😡", "Phẫn nộ"),
    ]

    private var hinhCamXuc: String? {
        guard let c = viewModel.camXucHienTai else { return viewModel.daThich ? "👍" : nil }
        return Self.cacCamXuc.first { $0.0 == c }?.1
    }

    private var chuCamXuc: String {
        guard let c = viewModel.camXucHienTai else { return "Thích" }
        return Self.cacCamXuc.first { $0.0 == c }?.2 ?? "Thích"
    }

    private var bangChonCamXuc: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Array(Self.cacCamXuc.enumerated()), id: \.element.0) { i, muc in
                let (loai, hinh, nhan) = muc
                Button {
                    Haptics.xong()
                    withAnimation(.snappy(duration: 0.2)) { hienChonCamXuc = false }
                    Task { await viewModel.datCamXuc(loai) }
                } label: {
                    VStack(spacing: 2) {
                        // Nhãn tên NẰM TRÊN như Facebook — chỉ có emoji thì
                        // người dùng phải đoán 😢 là "Buồn" hay "Thương".
                        Text(nhan)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.black.opacity(0.72)))
                        Text(hinh).font(.system(size: 30))
                    }
                }
                .buttonStyle(.plain)
                // Nảy LẦN LƯỢT từ trái sang, mỗi cái trễ 40ms — đó là thứ làm
                // bảng cảm xúc của Facebook trông "sống" chứ không bật cả cụm.
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.3).combined(with: .opacity)
                        .animation(.spring(response: 0.34, dampingFraction: 0.62)
                            .delay(Double(i) * 0.04)),
                    removal: .scale(scale: 0.8).combined(with: .opacity)))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundTertiary)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .offset(x: Spacing.sm, y: -54)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
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
                                    authorName: (comment.tacGia?.name ?? "Người dùng")
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
                            Text("Trả lời @\(replying.tacGia?.username ?? "…")")
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

                    TextField(anhKem == nil ? "Viết bình luận…" : "Thêm chú thích (không bắt buộc)…",
                              text: $commentText, axis: .vertical)
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
                    guiBinhLuan()
                } label: {
                    if dangGuiBinhLuan {
                        ProgressView().frame(width: 30, height: 30)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(guiDuoc ? AppColors.primary : AppColors.textTertiary)
                    }
                }
                .disabled(!guiDuoc || dangGuiBinhLuan)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            thanhCongCuBinhLuan
        }
        .background(AppColors.backgroundSecondary)
    }

    // MARK: Soạn bình luận

    private var guiDuoc: Bool {
        anhKem != nil || !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Ảnh/GIF đã chọn, hiện ngay trên ô nhập để người dùng thấy mình sắp gửi
    /// gì — chọn xong mà không thấy gì đổi thì tưởng bấm hụt.
    @ViewBuilder
    private var thanhCongCuBinhLuan: some View {
        if let a = anhKem {
            HStack(spacing: Spacing.sm) {
                AsyncImage(url: URL(string: a)) { pha in
                    if let img = try? pha.image { img.resizable().aspectRatio(contentMode: .fill) }
                    else { AppColors.backgroundTertiary }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(loaiAnhKem == "gif" ? "GIF đã chọn" : "Ảnh đã chọn")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Button { anhKem = nil; loaiAnhKem = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.sm)
        }

        HStack(spacing: Spacing.lg) {
            #if os(iOS)
            PhotosPicker(selection: $anhChonBinhLuan, maxSelectionCount: 1, matching: .images) {
                nutBinhLuan("photo", "Ảnh")
            }
            #endif
            Button { hienGifBinhLuan = true } label: { nutBinhLuan("square.stack.3d.down.right", "GIF") }
                .buttonStyle(.plain)
            Button { withAnimation { hienEmojiBinhLuan.toggle() } } label: {
                nutBinhLuan(hienEmojiBinhLuan ? "keyboard" : "face.smiling", "Emoji")
            }
            .buttonStyle(.plain)
            Spacer()
            if dangTaiAnhBinhLuan { ProgressView().scaleEffect(0.7) }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)

        if hienEmojiBinhLuan {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(["❤️","😂","😍","👍","🔥","🎉","😊","😢","😮","😡",
                             "🙏","👏","💯","✅","🤔","😅","🥰","😭","🤣","💪"], id: \.self) { e in
                        Button { commentText += e } label: { Text(e).font(.system(size: 26)) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.sm)
            }
        }
    }

    private func nutBinhLuan(_ icon: String, _ ten: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 15))
            Text(ten).font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(AppColors.primary)
    }

    private func guiBinhLuan() {
        let chu = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = anhKem, k = loaiAnhKem
        guard !chu.isEmpty || a != nil else { return }
        Haptics.cham()
        dangGuiBinhLuan = true
        // Xoá ô nhập NGAY, không đợi máy chủ: chờ mà ô vẫn còn chữ thì người
        // dùng bấm gửi lần nữa và thành hai bình luận trùng.
        commentText = ""; anhKem = nil; loaiAnhKem = nil; replyingTo = nil
        Task {
            await viewModel.addComment(content: chu, parentId: replyingTo?.id,
                                       anhKem: a, loaiAnhKem: k)
            dangGuiBinhLuan = false
        }
    }

    #if os(iOS)
    private func taiAnhBinhLuan(_ items: [PhotosPickerItem]) async {
        guard let item = items.first else { return }
        dangTaiAnhBinhLuan = true
        defer { dangTaiAnhBinhLuan = false; anhChonBinhLuan = [] }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        do {
            // Bình luận nhận `mediaUrl` dạng CHUỖI, nên đi `/files/upload`
            // (trả url) chứ không phải `/messages/upload` (trả fileId).
            let loai = item.supportedContentTypes.first
            let tep = try await APIClient.shared.upload(
                data: data,
                fileName: "binh-luan.\(loai?.preferredFilenameExtension ?? "jpg")",
                mimeType: loai?.preferredMIMEType ?? "image/jpeg",
                category: "social")
            anhKem = tep.url
            loaiAnhKem = "image"
        } catch {
            viewModel.error = error.localizedDescription
        }
    }
    #endif
}

// MARK: - Comment Row
struct CommentRow: View {
    let comment: Comment
    /// Ảnh đang mở toàn màn hình — `nil` là không mở.
    @State private var anhPhongTo: String?
    let onReply: () -> Void
    let onLike: () -> Void
    var onReport: (() -> Void)? = nil
    /// Trả lời thì thụt vào, avatar nhỏ hơn — như Facebook.
    var laTraLoi: Bool = false

    @State private var daThich: Bool
    @State private var soThich: Int

    init(comment: Comment, onReply: @escaping () -> Void, onLike: @escaping () -> Void,
         onReport: (() -> Void)? = nil, laTraLoi: Bool = false) {
        self.comment = comment
        self.onReply = onReply
        self.onLike = onLike
        self.onReport = onReport
        self.laTraLoi = laTraLoi
        _daThich = State(initialValue: comment.daThich)
        _soThich = State(initialValue: comment.soThich)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            NavigationLink(destination: UserProfileView(userId: (comment.tacGia?.id ?? 0))) {
                UserAvatarView(url: comment.tacGia?.avatarUrl, size: laTraLoi ? 28 : 34)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                // BONG BÓNG: tên + nội dung trong một khối bo tròn, đúng lối
                // Facebook/Messenger. Bản cũ đổ tên và nội dung ra thành hai
                // dòng chữ trần, không có ranh giới nào giữa các bình luận.
                VStack(alignment: .leading, spacing: 2) {
                    Text((comment.tacGia?.name ?? "Người dùng"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    if !comment.noiDung.isEmpty {
                        Text(comment.noiDung)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Ảnh / GIF kèm bình luận. Không dựng chỗ này thì gửi ảnh
                    // xong bình luận hiện ra RỖNG — người dùng tưởng mất.
                    if let a = comment.mediaUrl, !a.isEmpty, let url = URL(string: a) {
                        AsyncImage(url: url) { pha in
                            switch pha {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fit)
                            case .failure:
                                HStack(spacing: 4) {
                                    Image(systemName: "photo")
                                    Text("Không tải được ảnh").font(.system(size: 12))
                                }
                                .foregroundColor(AppColors.textTertiary)
                                .frame(height: 60)
                            default:
                                ProgressView().frame(height: 100)
                            }
                        }
                        .frame(maxWidth: 220, maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 2)
                        // Ảnh 220pt thì không đọc được gì — chạm để mở trình
                        // xem toàn màn hình có phóng to, đúng như ảnh trong bài.
                        .contentShape(Rectangle())
                        .onTapGesture { anhPhongTo = a }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Hàng hành động NGOÀI bong bóng, chữ nhỏ — cũng như Facebook.
                HStack(spacing: Spacing.md) {
                    Text(TimeFormatter.formatTimeAgo(comment.createdAt))

                    Button {
                        doiThich()
                    } label: {
                        Text(daThich ? "Đã thích" : "Thích")
                            .fontWeight(daThich ? .bold : .semibold)
                            .foregroundColor(daThich ? AppColors.primary : AppColors.textSecondary)
                    }

                    Button("Trả lời", action: onReply)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)

                    if let onReport {
                        Menu {
                            Button(role: .destructive, action: onReport) {
                                Label("Báo cáo bình luận", systemImage: "flag")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Spacer(minLength: 0)

                    // Số lượt thích bám vào MÉP PHẢI của bong bóng, như một
                    // huy hiệu — thay vì nằm lẫn trong hàng chữ.
                    if soThich > 0 {
                        HStack(spacing: 3) {
                            Text("👍").font(.system(size: 11))
                            Text("\(soThich)")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.backgroundSecondary)
                        .clipShape(Capsule())
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
                .padding(.leading, 4)
            }
        }
        .padding(.leading, laTraLoi ? Spacing.xl : 0)
        #if os(iOS)
        .fullScreenCover(item: Binding(
            get: { anhPhongTo.map { AnhMo(url: $0) } },
            set: { if $0 == nil { anhPhongTo = nil } })) { a in
            MediaViewer(media: [SocialMedia(id: 0, type: "IMAGE", url: a.url, thumbnail: nil,
                                            width: nil, height: nil, duration: nil,
                                            fileSize: nil, mimeType: nil, fileName: nil,
                                            alt: nil, sortOrder: nil)])
        }
        #endif

    }

    private func doiThich() {
        Haptics.cham()
        let muon = !daThich
        daThich = muon
        soThich += muon ? 1 : -1
        onLike()
    }
}

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

    /// Cảm xúc hiện tại của mình với bài này (LIKE/LOVE/HAHA/SAD/ANGRY) và cờ
    /// đã-thích. Tách khỏi `post` vì `post` là `let` hết, sửa tại chỗ không
    /// được, mà dựng lại cả đối tượng chỉ để đổi một cờ thì vừa dài vừa dễ
    /// quên một trường.
    @Published var camXucHienTai: String?
    @Published var daThich = false

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
            let response: (items: [Comment], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(
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
            let response: (items: [Comment], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(
                    .getComments(postId: postId, cursor: cursor, limit: 20)
                )
            let daCo = Set(comments.map(\.id))
            comments.append(contentsOf: response.items.filter { !daCo.contains($0.id) })
            cursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addComment(content: String, parentId: Int?, anhKem: String? = nil, loaiAnhKem: String? = nil) async {
        guard let postId = post?.id else { return }

        // Id ÂM để chắc chắn không đụng id thật — bốc số ngẫu nhiên trong
        // 100000...999999 thì id thật rơi vào đúng khoảng đó là thay nhầm.
        let tempComment = Comment(
            id: -Int(Date().timeIntervalSince1970 * 1000) % 1_000_000_000,
            content: content,
            user: AppState.shared.currentUser,
            likesCount: 0,
            repliesCount: nil,
            isLiked: false,
            parentId: parentId,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            mediaUrl: anhKem,
            mediaKind: loaiAnhKem,
            replies: nil
        )

        comments.insert(tempComment, at: 0)

        do {
            let newComment: Comment = try await APIClient.shared.request(
                .createComment(postId: postId, content: content, parentId: parentId,
                               mediaUrl: anhKem, mediaKind: loaiAnhKem)
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
        guard let i = comments.firstIndex(where: { $0.id == commentId }) else { return }
        let cu = comments[i]
        let thich = !cu.daThich
        comments[i] = cu.doiThich(thich, thich ? cu.soThich + 1 : max(0, cu.soThich - 1))
        do {
            let _: EmptyResponse = try await APIClient.shared
                .request(.likeComment(id: commentId))
        } catch {
            if let j = comments.firstIndex(where: { $0.id == commentId }) { comments[j] = cu }
        }
    }

    /// Đặt cảm xúc. Đổi trên máy trước cho tay bấm thấy ngay, hỏng thì trả lại.
    func datCamXuc(_ loai: String) async {
        let truoc = camXucHienTai
        let truocThich = daThich
        camXucHienTai = loai
        daThich = true
        do {
            try await APIClient.shared.send(.reactPost(id: post?.id ?? 0, type: loai))
        } catch {
            camXucHienTai = truoc
            daThich = truocThich
            Haptics.hong()
        }
    }

    func toggleLike() async {
        daThich.toggle()
        if !daThich { camXucHienTai = nil } else if camXucHienTai == nil { camXucHienTai = "LIKE" }
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


/// Bọc chuỗi URL thành `Identifiable` để `fullScreenCover(item:)` nhận được.
struct AnhMo: Identifiable {
    let url: String
    var id: String { url }
}
