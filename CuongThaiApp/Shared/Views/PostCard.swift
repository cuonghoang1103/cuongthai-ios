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
    /// Bật một nhịp để biểu tượng cảm xúc nảy lên rồi về.
    @State private var nayCamXuc = false
    /// Emoji ngón tay đang trượt qua — để phóng to đúng cái đó.
    @State private var camXucDangDi: String?
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

    /// Thẻ trong bảng tin chỉ hiện phần XEM TRƯỚC, cắt ở khối mã đầu tiên.
    ///
    /// Cố ý KHÔNG dựng đầy đủ như màn chi tiết: một bài giảng 4000 ký tự với 5
    /// khối mã dựng hết ra thì thẻ dài bằng ba màn hình, và cuộn bảng tin phải
    /// tính bố cục cho từng khối — giật ngay trên máy cũ.
    private var postContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let td = BoTachBaiViet.tach(xemTruoc).first,
               case .tieuDeBai(let e, let c) = td {
                HStack(alignment: .top, spacing: 6) {
                    Text(e).font(.system(size: 15))
                    Text(c)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                }
                Text(BoTachBaiViet.lotDauMarkdown(
                        xemTruoc.components(separatedBy: "\n").dropFirst()
                            .joined(separator: " ")))
                    .font(.bodyText)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(6)
            } else {
                Text(BoTachBaiViet.lotDauMarkdown(post.content))
                    .font(.bodyText)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Cắt trước khối mã đầu tiên — dấu ``` hiện trần trong bảng tin trông
    /// như lỗi hiển thị.
    private var xemTruoc: String {
        if let r = post.content.range(of: "```") {
            return String(post.content[..<r.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return post.content
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
            // BẢY loại (LIKE/LOVE/CARE/HAHA/WOW/SAD/ANGRY) qua `reactPost`,
            // nhưng app trước đây chỉ dùng được đúng một loại.
            Button { Task { await toggleLike() } } label: {
                HStack(spacing: 4) {
                    Text(bieuTuongCamXuc)
                        // Nảy to rồi về — đây là phần "đã ghi nhận" mà thiếu
                        // nó thì chọn xong không biết máy có nhận hay chưa.
                        .scaleEffect(nayCamXuc ? 1.55 : 1)
                        .rotationEffect(.degrees(nayCamXuc ? -12 : 0))
                    Text(nhanCamXuc)
                }
                .font(.caption)
                .foregroundColor(camXuc != nil || isLiked ? AppColors.like : AppColors.textSecondary)
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
        ("CARE", "🥰", "Thương thương"),
        ("HAHA", "😂", "Haha"),
        ("WOW", "😮", "Wow"),
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
            ForEach(Array(Self.cacCamXuc.enumerated()), id: \.element.0) { i, muc in
                let (loai, hinh, nhan) = muc
                Button {
                    Haptics.xong()
                    withAnimation(.snappy(duration: 0.2)) { hienChonCamXuc = false }
                    Task { await datCamXuc(loai) }
                } label: {
                    VStack(spacing: 2) {
                        // Nhãn tên NẰM TRÊN như Facebook — chỉ có emoji thì
                        // người dùng phải đoán 😢 là "Buồn" hay "Thương".
                        Text(nhan)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.black.opacity(0.72)))
                        Text(hinh)
                            .font(.system(size: 28))
                            .scaleEffect(camXucDangDi == loai ? 1.6 : 1)
                            .animation(.spring(response: 0.25, dampingFraction: 0.55),
                                       value: camXucDangDi)
                    }
                    // Vùng chạm rộng hơn emoji để ngón tay trượt qua là bắt
                    // được — Facebook phóng to theo ngón tay trượt.
                    .contentShape(Rectangle())
                    .onHover { camXucDangDi = $0 ? loai : nil }
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

        // Nhịp NẢY: phóng to rồi về. Chạy ngay, không đợi máy chủ — người dùng
        // cần thấy phản hồi tức thì, còn máy chủ mất vài trăm mili giây.
        withAnimation(.spring(response: 0.22, dampingFraction: 0.42)) { nayCamXuc = true }
        Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) { nayCamXuc = false }
        }

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

    /// Chiều cao theo tỉ lệ thật, chặn hai đầu.
    ///
    /// Trần 560pt: ảnh dọc rất dài mà cho hiện trọn thì một bài chiếm hết màn
    /// hình và cuộn bảng tin thành cuộn ảnh. Sàn 180pt: ảnh ngang rất bẹt thì
    /// nhỏ tới mức không nhìn ra gì.
    private func caoTheoAnh(_ m: SocialMedia) -> CGFloat {
        // ⚠️ Trần 700pt: `UIScreen.main` cho bề ngang MÀN HÌNH, mà từ
        // 16/09/2026 bảng tin có thể nằm trong cột phải của `BoCucCotDoi` trên
        // iPad — hẹp hơn màn hình. Không chặn thì trên iPad 13" nằm ngang nó
        // tính theo 1334pt: mọi ảnh dọc đều đụng trần 560pt và bị cắt, dù ô
        // thật chỉ rộng chừng một nửa chỗ đó.
        #if os(iOS)
        let rong = min(UIScreen.main.bounds.width - 32, 700)
        #else
        let rong: CGFloat = 420
        #endif
        guard let w = m.width, let h = m.height, w > 0, h > 0 else { return 300 }
        return min(max(rong * CGFloat(h) / CGFloat(w), 180), 560)
    }

    /// Ảnh có bị trần 560pt cắt mất phần nào không — để nói cho người dùng
    /// biết còn nội dung bên dưới, thay vì để họ tưởng ảnh chỉ có bấy nhiêu.
    private func biCat(_ m: SocialMedia) -> Bool {
        // ⚠️ Trần 700pt: `UIScreen.main` cho bề ngang MÀN HÌNH, mà từ
        // 16/09/2026 bảng tin có thể nằm trong cột phải của `BoCucCotDoi` trên
        // iPad — hẹp hơn màn hình. Không chặn thì trên iPad 13" nằm ngang nó
        // tính theo 1334pt: mọi ảnh dọc đều đụng trần 560pt và bị cắt, dù ô
        // thật chỉ rộng chừng một nửa chỗ đó.
        #if os(iOS)
        let rong = min(UIScreen.main.bounds.width - 32, 700)
        #else
        let rong: CGFloat = 420
        #endif
        guard let w = m.width, let h = m.height, w > 0, h > 0 else { return false }
        return rong * CGFloat(h) / CGFloat(w) > 560
    }

    var body: some View {
        if media.count == 1 {
            nut(0) {
                // ⚠️ PHẢI có `.clipped()`. `aspectRatio(.fill)` không cắt gì —
                // ảnh tràn ra NGOÀI khung và vẽ đè lên hàng bên trên/bên dưới.
                // Đường nhiều ảnh vốn đã có, đường một ảnh thì thiếu, nên ảnh
                // bài giảng dạng dọc đè lên cả hàng "Thích · Bình luận".
                //
                // Và dùng TỈ LỆ THẬT của ảnh: ảnh hạ tầng bài học là ảnh DỌC
                // dài; ép vào khung 300pt cố định thì chỉ thấy khúc giữa, mất
                // cả tiêu đề lẫn phần kết.
                MediaItemView(media: media[0])
                    // `.top`: ảnh dọc bị chặn trần thì cắt từ ĐÁY, giữ lại
                    // phần đầu — đó là chỗ có tiêu đề. Căn giữa (mặc định) thì
                    // mất cả tiêu đề lẫn phần kết, còn lại khúc giữa vô nghĩa.
                    .frame(height: caoTheoAnh(media[0]), alignment: .top)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        if biCat(media[0]) {
                            Text("Chạm để xem trọn ảnh")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(.black.opacity(0.55)))
                                .padding(.bottom, 8)
                        }
                    }
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
            // ⚠️⚠️ ẢNH PHẢI NẰM TRONG `.overlay`, KHÔNG ĐƯỢC ĐỂ TRẦN Ở ZStack.
            //
            // `aspectRatio(.fill)` KHÔNG tự bó vào bề ngang cha — nó tính bề
            // ngang theo tỉ lệ THẬT của ảnh rồi ĐÒI đúng chừng đó. Cha chỉ
            // ghim chiều cao (`frame(height:)` ở `luoiAnh`) nên ảnh dọc đòi
            // bề ngang lớn hơn màn hình, và ZStack nở theo ⇒ CẢ THẺ BÀI VIẾT
            // rộng hơn màn hình: tên người đăng cụt bên trái, "0 bình luận"
            // cụt bên phải. `.clipped()` ở ngoài KHÔNG cứu được — nó cắt phần
            // vẽ, còn kích thước đã báo lên cha thì vẫn sai.
            //
            // Lớp phủ thì KHÔNG BAO GIỜ ảnh hưởng kích thước bố cục. Khung do
            // `Color.clear` quyết định: rộng co theo cha, cao do cha ghim.
            // Cùng bản vá đã dùng cho ảnh bìa trang cá nhân — đo thật ở đó:
            // 480pt → 10pt.
            Color.clear
                .overlay {
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
                }
                .clipped()

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
