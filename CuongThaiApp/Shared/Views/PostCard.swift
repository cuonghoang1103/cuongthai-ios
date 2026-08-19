import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Post Card
struct PostCard: View {
    let post: SocialPost
    /// Bấm "Bình luận" — màn cha mở chi tiết bài. Truyền lên thay vì tự điều
    /// hướng: thẻ này đã nằm trong một NavigationLink, lồng thêm một cái nữa
    /// là hai đích cãi nhau.
    var onComment: (() -> Void)?

    @State private var likesCount: Int
    @State private var isLiked: Bool
    @State private var daLuu: Bool
    @State private var camXuc: String?
    @State private var hienChonCamXuc = false
    @State private var mediaDangXem: Int?

    init(post: SocialPost, onComment: (() -> Void)? = nil) {
        self.post = post
        self.onComment = onComment
        _likesCount = State(initialValue: post.likesCount)
        _isLiked = State(initialValue: post.isLiked)
        _daLuu = State(initialValue: post.isSaved)
        _camXuc = State(initialValue: post.myReaction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            postHeader
            postContent
            if let media = post.media, !media.isEmpty {
                MediaGridView(media: media) { i in mediaDangXem = i }
            }
            if let poll = post.poll {
                PollView(poll: poll)
            }
            if let music = post.musicTrack {
                MusicStickerView(track: music)
            }
            statsRow
            Divider().background(Color.gray.opacity(0.3))
            actionsRow
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
        // `fullScreenCover` chỉ có trên iOS; macOS dùng `sheet`. Không bọc
        // `#if` thì target macOS đỏ với "unavailable in macOS".
        #if os(iOS)
        .fullScreenCover(item: $mediaDangXem) { i in
            MediaViewer(media: post.media ?? [], batDauTai: i)
        }
        #else
        .sheet(item: $mediaDangXem) { i in
            MediaViewer(media: post.media ?? [], batDauTai: i)
        }
        #endif
    }

    private var postHeader: some View {
        HStack(spacing: Spacing.sm) {
            UserAvatarView(url: post.author.avatarUrl, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.author.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    if post.author.isFollowing == true {
                        Text("•")
                            .foregroundColor(AppColors.textSecondary)
                        Text("Theo dõi")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
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
                }
            }

            Spacer()
            // The ••• moderation menu is overlaid by the container (HomeView /
            // PostDetailView) — a Menu nested inside a NavigationLink label
            // swallows its own taps, so the card only reserves the space.
            Color.clear.frame(width: 32, height: 32)
        }
    }

    private var postContent: some View {
        Text(post.content)
            .font(.bodyText)
            .foregroundColor(AppColors.textPrimary)
            .lineLimit(10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsRow: some View {
        HStack {
            HStack(spacing: -8) {
                ForEach(["❤️", "😂", "😢", "😡"], id: \.self) { emoji in
                    Text(emoji)
                        .font(.caption)
                        .padding(4)
                        .background(AppColors.backgroundCard)
                        .clipShape(Circle())
                }
            }
            Spacer()
            HStack(spacing: Spacing.md) {
                Text("\(likesCount)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                Text("\(post.commentsCount) bình luận")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                Text("\(post.sharesCount) chia sẻ")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private var actionsRow: some View {
        HStack {
            // Chạm: thích/bỏ thích. GIỮ LÂU: chọn cảm xúc — backend có sẵn
            // 5 loại (LIKE/LOVE/HAHA/SAD/ANGRY) qua `reactPost`, nhưng app
            // trước đây chỉ dùng được đúng một loại.
            Button { Task { await toggleLike() } } label: {
                HStack(spacing: 4) {
                    Text(bieuTuongCamXuc)
                    Text(nhanCamXuc)
                }
                .font(.caption)
                .foregroundColor(camXuc != nil || isLiked ? AppColors.like : AppColors.textSecondary)
            }
            .onLongPressGesture(minimumDuration: 0.35) {
                Haptics.cham()
                withAnimation(.snappy(duration: 0.2)) { hienChonCamXuc = true }
            }

            Spacer()

            Button {
                Haptics.cham()
                onComment?()
            } label: {
                nhan("bubble.right", "Bình luận")
            }

            Spacer()

            ShareLink(item: duongDanBai) {
                nhan("square.and.arrow.up", "Chia sẻ")
            }

            Spacer()

            Button { Task { await doiLuu() } } label: {
                HStack(spacing: 4) {
                    Image(systemName: daLuu ? "bookmark.fill" : "bookmark")
                    Text("Lưu")
                }
                .font(.caption)
                .foregroundColor(daLuu ? AppColors.primary : AppColors.textSecondary)
            }
        }
        .overlay(alignment: .topLeading) {
            if hienChonCamXuc { bangChonCamXuc }
        }
    }

    private func nhan(_ icon: String, _ chu: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(chu)
        }
        .font(.caption)
        .foregroundColor(AppColors.textSecondary)
    }

    private var duongDanBai: URL {
        URL(string: "https://cuongthai.com/feed/\(post.id)")!
    }

    private static let cacCamXuc: [(String, String, String)] = [
        ("LIKE", "👍", "Thích"),
        ("LOVE", "❤️", "Yêu thích"),
        ("HAHA", "😂", "Haha"),
        ("SAD", "😢", "Buồn"),
        ("ANGRY", "😡", "Phẫn nộ"),
    ]

    private var bieuTuongCamXuc: String {
        if let c = camXuc, let m = Self.cacCamXuc.first(where: { $0.0 == c }) { return m.1 }
        return isLiked ? "❤️" : "🤍"
    }

    private var nhanCamXuc: String {
        if let c = camXuc, let m = Self.cacCamXuc.first(where: { $0.0 == c }) { return m.2 }
        return "Thích"
    }

    private var bangChonCamXuc: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Self.cacCamXuc, id: \.0) { loai, hinh, _ in
                Button {
                    Task { await datCamXuc(loai) }
                } label: {
                    Text(hinh).font(.system(size: 28))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundTertiary)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .offset(y: -52)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    private func datCamXuc(_ loai: String) async {
        Haptics.xong()
        let truoc = camXuc
        withAnimation(.snappy(duration: 0.2)) {
            camXuc = loai
            hienChonCamXuc = false
        }
        if !isLiked { isLiked = true; likesCount += 1 }
        do {
            try await APIClient.shared.send(.reactPost(id: post.id, type: loai))
        } catch {
            camXuc = truoc
            Haptics.hong()
        }
    }

    private func doiLuu() async {
        Haptics.cham()
        let muon = !daLuu
        daLuu = muon
        do {
            try await APIClient.shared.send(
                muon ? .savePost(id: post.id, folder: nil) : .unsavePost(id: post.id),
            )
        } catch {
            daLuu = !muon
            Haptics.hong()
        }
    }

    private func toggleLike() async {
        Haptics.cham()
        isLiked.toggle()
        likesCount += isLiked ? 1 : -1
        do {
            if isLiked {
                let _: EmptyResponse = try await APIClient.shared.request(.likePost(id: post.id))
            } else {
                let _: EmptyResponse = try await APIClient.shared.request(.unlikePost(id: post.id))
            }
        } catch {
            isLiked.toggle()
            likesCount += isLiked ? 1 : -1
        }
    }
}

// MARK: - User Avatar
struct UserAvatarView: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        Group {
            #if canImport(Kingfisher)
            if let urlString = url, let imageURL = URL(string: urlString) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
            #else
            avatarPlaceholder
            #endif
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(AppColors.backgroundTertiary)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(AppColors.textSecondary)
                    .font(.system(size: size * 0.5))
            )
    }
}

// MARK: - Media Grid
struct MediaGridView: View {
    let media: [SocialMedia]
    var chon: ((Int) -> Void)?

    var body: some View {
        if media.count == 1 {
            nut(0) {
                MediaItemView(media: media[0]).frame(height: 300)
            }
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                ForEach(Array(media.prefix(4).enumerated()), id: \.offset) { i, item in
                    nut(i) {
                        ZStack(alignment: .center) {
                            MediaItemView(media: item)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                            // Ảnh thứ 5 trở đi không hiện — nói rõ còn bao
                            // nhiêu thay vì im lặng giấu mất.
                            if i == 3, media.count > 4 {
                                Color.black.opacity(0.55)
                                Text("+\(media.count - 4)")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .frame(height: 300)
        }
    }

    private func nut<N: View>(_ i: Int, @ViewBuilder _ noi: () -> N) -> some View {
        Button { chon?(i) } label: { noi() }
            .buttonStyle(.plain)
    }
}

struct MediaItemView: View {
    let media: SocialMedia

    var body: some View {
        ZStack {
            #if canImport(Kingfisher)
            if let url = URL(string: media.thumbnail ?? media.url) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                AppColors.backgroundTertiary
            }
            #else
            AppColors.backgroundTertiary
            #endif

            if media.type == "VIDEO" {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(AppColors.onPrimary)
                    .shadow(radius: 4)
            }
        }
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Poll View
struct PollView: View {
    let poll: SocialPoll

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(poll.question)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            ForEach(poll.options ?? []) { option in
                HStack {
                    Text(option.text)
                        .font(.caption)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    if let pct = option.percentage {
                        Text("\(Int(pct * 100))%")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.small)
            }

            Text("\(poll.totalVotes ?? 0) bình chọn")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Music Sticker View
struct MusicStickerView: View {
    let track: MusicTrackInfo

    var body: some View {
        HStack(spacing: Spacing.md) {
            #if canImport(Kingfisher)
            if let coverURL = track.coverImage, let url = URL(string: coverURL) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .cornerRadius(CornerRadius.small)
            } else {
                musicPlaceholder
            }
            #else
            musicPlaceholder
            #endif

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
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
                .font(.system(size: 20))
                .foregroundColor(AppColors.primary)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
    }

    private var musicPlaceholder: some View {
        RoundedRectangle(cornerRadius: CornerRadius.small)
            .fill(AppColors.backgroundTertiary)
            .frame(width: 48, height: 48)
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(AppColors.textSecondary)
            )
    }
}
