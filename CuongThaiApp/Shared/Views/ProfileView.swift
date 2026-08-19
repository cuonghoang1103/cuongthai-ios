import SwiftUI
import PhotosUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @State private var sheet: ProfileSheet?
    @State private var avatarItem: PhotosPickerItem?
    @State private var coverItem: PhotosPickerItem?

    // MỘT `.sheet(item:)` cho cả hai màn: hai `.sheet(isPresented:)` trên cùng
    // một view thì chỉ cái cuối chạy, cái kia bấm im lặng.
    enum ProfileSheet: String, Identifiable {
        case settings, editProfile
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    profileStats
                    profileActions
                    contentTabs
                    noiDungTheoTab
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sheet = .settings
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .sheet(item: $sheet) { which in
                switch which {
                case .settings: SettingsView()
                case .editProfile: NavigationStack { EditProfileView() }
                }
            }
            // Đổi ảnh: chọn xong là tải lên rồi ghi vào hồ sơ ngay, không có
            // bước "Lưu" riêng — người dùng chọn ảnh là đã quyết định rồi.
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task { await viewModel.doiAnh(item, truong: .avatar) }
            }
            .onChange(of: coverItem) { _, item in
                guard let item else { return }
                Task { await viewModel.doiAnh(item, truong: .bia) }
            }
            .alert("Không đổi được ảnh", isPresented: .constant(viewModel.loiDoiAnh != nil)) {
                Button("OK") { viewModel.loiDoiAnh = nil }
            } message: {
                Text(viewModel.loiDoiAnh ?? "")
            }
            // `init()` của ViewModel gọi loadProfile() ngay lập tức, nhưng
            // lúc đó `currentUser` thường CHƯA về (fetchProfile chạy bất đồng
            // bộ sau đăng nhập). Khi đó `if let userId = ...` trong loadProfile
            // trượt, hàm im lặng không làm gì, và màn hình đứng nguyên ở dữ
            // liệu mẫu "User / @username / 0 bài viết". Đặt userId KHÔNG tự
            // nạp lại, nên phải gọi tay.
            .task(id: appState.currentUser?.id) {
                guard let id = appState.currentUser?.id else { return }
                if viewModel.userId != id || viewModel.profile == nil {
                    viewModel.userId = id
                    await viewModel.loadProfile()
                }
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 0) {
            // Cover Photo
            ZStack(alignment: .bottom) {
                if let coverUrl = viewModel.profile?.coverPhotoUrl,
                   let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }
                    .frame(height: 180)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 180)
                }

                // Edit Cover Button
                if viewModel.isCurrentUser {
                    PhotosPicker(selection: $coverItem, matching: .images) {
                        Group {
                            if viewModel.dangTaiAnhBia {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "camera.fill").foregroundColor(AppColors.onPrimary)
                            }
                        }
                        .padding(Spacing.sm)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                    }
                    .disabled(viewModel.dangTaiAnhBia)
                    .padding(.trailing, Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(y: -20)
                }
            }

            // Avatar and Info
            HStack(alignment: .bottom, spacing: Spacing.md) {
                ZStack(alignment: .bottomTrailing) {
                    UserAvatarView(url: viewModel.profile?.avatarUrl, size: 90)

                    if viewModel.isCurrentUser {
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            Group {
                                if viewModel.dangTaiAvatar {
                                    ProgressView().tint(.white).scaleEffect(0.7)
                                } else {
                                    Image(systemName: "camera.fill").font(.caption).foregroundColor(AppColors.onPrimary)
                                }
                            }
                            .padding(6)
                            .background(AppColors.primary)
                            .clipShape(Circle())
                        }
                        .disabled(viewModel.dangTaiAvatar)
                    }
                }
                .offset(y: -45)

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.sm) {
                    if !viewModel.isCurrentUser {
                        if viewModel.profile?.isFollowing == true {
                            Button("Đang theo dõi") {
                                Task { await viewModel.toggleFollow() }
                            }
                            .font(.buttonSmall)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(AppColors.backgroundTertiary)
                            .cornerRadius(CornerRadius.medium)
                        } else {
                            Button {
                                Task { await viewModel.toggleFollow() }
                            } label: {
                                Text("Theo dõi")
                                    .font(.buttonSmall)
                                    .foregroundColor(AppColors.onPrimary)
                                    .padding(.horizontal, Spacing.md)
                                    .padding(.vertical, Spacing.sm)
                                    .background(AppColors.primary)
                                    .cornerRadius(CornerRadius.medium)
                            }
                            .disabled(viewModel.isLoading)
                        }
                    } else {
                        Button {
                            sheet = .editProfile
                        } label: {
                            Text("Chỉnh sửa")
                                .font(.buttonSmall)
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(AppColors.backgroundTertiary)
                                .cornerRadius(CornerRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                        }
                    }
                }
                .offset(y: -20)
            }
            .padding(.horizontal, Spacing.md)

            // User Info
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Text(viewModel.profile?.name ?? "User")
                        .font(.titleLarge)
                        .foregroundColor(AppColors.textPrimary)

                    if let verified = viewModel.profile?.isVerified, verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppColors.primary)
                    }
                }

                Text("@\(viewModel.profile?.username ?? "username")")
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)

                if let bio = viewModel.profile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.top, Spacing.xs)
                }

                // Social Links
                if let links = viewModel.profile?.socialLinks, !links.isEmpty {
                    HStack(spacing: Spacing.md) {
                        ForEach(links, id: \.self) { link in
                            Link(destination: URL(string: link) ?? URL(string: "https://example.com")!) {
                                Image(systemName: "link")
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                    .padding(.top, Spacing.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .offset(y: -20)
        }
    }

    private var profileStats: some View {
        HStack(spacing: 0) {
            statItem(value: viewModel.profile?.postsCount ?? 0, label: "Bài viết")
            Divider().frame(height: 30)
            statItem(value: viewModel.profile?.followersCount ?? 0, label: "Người theo dõi")
            Divider().frame(height: 30)
            statItem(value: viewModel.profile?.followingCount ?? 0, label: "Đang theo dõi")
        }
        .padding(.vertical, Spacing.md)
        .background(AppColors.backgroundSecondary)
        .padding(.top, -Spacing.md)
    }

    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(formatCount(value))
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var profileActions: some View {
        HStack(spacing: Spacing.sm) {
            actionButton(icon: "square.grid.2x2", title: "Bài viết", isActive: viewModel.selectedTab == .posts) {
                viewModel.selectedTab = .posts
            }

            // "Đã lưu" và "Khoá học" là thông tin RIÊNG TƯ — chỉ hiện ở hồ sơ
            // của chính mình, không khoe ở hồ sơ người khác.
            if viewModel.isCurrentUser {
                actionButton(icon: "bookmark", title: "Đã lưu", isActive: viewModel.selectedTab == .saved) {
                    viewModel.selectedTab = .saved
                }

            // Tab Nhạc đã GỠ: module nhạc bị bỏ khỏi app vì App Store
            // Guideline 5.2.3 (rút audio từ YouTube). Để lại một tab mở ra
            // màn trống còn tệ hơn không có tab.
                actionButton(icon: "graduationcap", title: "Khoá học", isActive: viewModel.selectedTab == .courses) {
                    viewModel.selectedTab = .courses
                }
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private func actionButton(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.bodyMedium)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isActive ? AppColors.primary : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(isActive ? AppColors.primary.opacity(0.1) : Color.clear)
            .cornerRadius(CornerRadius.small)
        }
    }

    private var contentTabs: some View {
        Divider()
            .background(AppColors.divider)
    }

    /// Phần dưới hồ sơ, đổi theo tab đang chọn.
    /// Trước đây LUÔN vẽ `viewModel.posts` bất kể tab nào — nên hai tab kia
    /// bấm vào chỉ đổi màu biểu tượng, nội dung y nguyên.
    @ViewBuilder
    private var noiDungTheoTab: some View {
        switch viewModel.selectedTab {
        case .posts: postsGrid
        case .saved: khoiDaLuu
        case .courses: khoiKhoaHoc
        }
    }

    private var khoiDaLuu: some View {
        LazyVStack(spacing: Spacing.md) {
            if viewModel.dangTaiDaLuu && viewModel.baiDaLuu.isEmpty {
                ProgressView().padding(.top, Spacing.xxl)
            } else if viewModel.baiDaLuu.isEmpty {
                khoiRong(icon: "bookmark", tieuDe: "Chưa lưu bài nào",
                         phu: "Chạm ••• trên một bài viết rồi chọn Lưu để đọc lại sau.")
            } else {
                ForEach(viewModel.baiDaLuu) { post in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink(destination: PostDetailView(post: post)) {
                            PostCard(post: post)
                        }
                        .buttonStyle(.plain)
                        PostModerationMenu(post: post)
                            .padding(.top, Spacing.md)
                            .padding(.trailing, Spacing.md)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .task { await viewModel.taiBaiDaLuu() }
    }

    private var khoiKhoaHoc: some View {
        LazyVStack(spacing: Spacing.sm) {
            if viewModel.dangTaiKhoa && viewModel.khoaDaHoc.isEmpty {
                ProgressView().padding(.top, Spacing.xxl)
            } else if viewModel.khoaDaHoc.isEmpty {
                khoiRong(icon: "graduationcap", tieuDe: "Chưa ghi danh khoá nào",
                         phu: "Vào tab Học, chọn một khoá và bấm Ghi danh.")
            } else {
                ForEach(viewModel.khoaDaHoc) { gd in
                    NavigationLink(destination: CourseDetailView(slug: gd.courseSlug)) {
                        hangKhoaHoc(gd)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .task { await viewModel.taiKhoaDaHoc() }
    }

    private func hangKhoaHoc(_ gd: Enrollment) -> some View {
        HStack(spacing: Spacing.md) {
            #if canImport(Kingfisher)
            if let t = gd.courseThumbnail, let url = URL(string: t) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(width: 96, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            #endif

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let ma = gd.courseCode {
                        Text(ma)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.secondary)
                    }
                    Text(gd.nhanTrangThai)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(gd.daXong ? AppColors.success : AppColors.textTertiary)
                }

                Text(gd.courseTitle)
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Thanh tiến độ + phần trăm, đều do máy chủ tính sẵn.
                HStack(spacing: Spacing.sm) {
                    ProgressView(value: Double(gd.progressPercent ?? 0), total: 100)
                        .tint(gd.daXong ? AppColors.success : AppColors.primary)
                    Text("\(gd.progressPercent ?? 0)%")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
        .contentShape(Rectangle())
    }

    private func khoiRong(icon: String, tieuDe: String, phu: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(AppColors.textTertiary)
            Text(tieuDe)
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)
            Text(phu)
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, Spacing.lg)
    }

    private var postsGrid: some View {
        LazyVStack(spacing: Spacing.md) {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView()
                    .padding(.top, Spacing.xxl)
            } else if viewModel.posts.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.posts) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        PostCard(post: post)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if post == viewModel.posts.last {
                            Task {
                                await viewModel.loadMorePosts()
                            }
                        }
                    }
                }

                if viewModel.hasMore {
                    ProgressView()
                        .padding()
                }
            }
        }
        .padding(Spacing.md)
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundColor(AppColors.textTertiary)

            Text("Chưa có bài viết nào")
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)

            Text(viewModel.isCurrentUser ? "Tạo bài viết đầu tiên của bạn" : "Người dùng này chưa đăng bài viết nào")
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            if viewModel.isCurrentUser {
                Button {
                    appState.selectedTab = .create
                } label: {
                    Text("Tạo bài viết")
                        .primaryButtonStyle()
                }
                .padding(.top, Spacing.md)
            }
        }
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, Spacing.xl)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - User Profile View (for other users)
struct UserProfileView: View {
    let userId: Int
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        ProfileView()
            .environmentObject(AppState.shared)
            .onAppear {
                viewModel.userId = userId
            }
    }
}

// MARK: - Profile View Model
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userId: Int?
    @Published var profile: UserProfile?
    @Published var posts: [SocialPost] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasMore = true
    @Published var selectedTab: ProfileTab = .posts

    private var cursor: Int?

    // ── Bài đã lưu & khoá đã ghi danh ─────────────────────────────
    @Published var baiDaLuu: [SocialPost] = []
    @Published var khoaDaHoc: [Enrollment] = []
    @Published var dangTaiDaLuu = false
    @Published var dangTaiKhoa = false

    /// Nạp một lần rồi thôi — người dùng gạt qua gạt lại giữa các tab liên
    /// tục, gọi lại mỗi lần là phí. Kéo-để-làm-mới vẫn nạp lại được.
    func taiBaiDaLuu(batBuoc: Bool = false) async {
        guard batBuoc || (baiDaLuu.isEmpty && !dangTaiDaLuu) else { return }
        dangTaiDaLuu = true
        defer { dangTaiDaLuu = false }
        do {
            let ds: (items: [SocialPost], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getSavedPosts(cursor: nil, limit: 30))
            baiDaLuu = ds.items
        } catch {
            self.error = error.localizedDescription
        }
    }

    func taiKhoaDaHoc(batBuoc: Bool = false) async {
        guard batBuoc || (khoaDaHoc.isEmpty && !dangTaiKhoa) else { return }
        dangTaiKhoa = true
        defer { dangTaiKhoa = false }
        do {
            let ds: (items: [Enrollment], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getMyCourses)
            // Khoá đang học lên trước, xong rồi xuống dưới; cùng nhóm thì cái
            // vừa học gần nhất lên trên.
            khoaDaHoc = ds.items.sorted {
                if $0.daXong != $1.daXong { return !$0.daXong }
                return ($0.lastAccessedAt ?? "") > ($1.lastAccessedAt ?? "")
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // ── Đổi ảnh đại diện / ảnh bìa ────────────────────────────────
    @Published var dangTaiAvatar = false
    @Published var dangTaiAnhBia = false
    @Published var loiDoiAnh: String?

    enum TruongAnh {
        case avatar, bia
        /// Tên trường trong `PUT /api/v1/profile`.
        var khoa: String { self == .avatar ? "avatarUrl" : "coverPhotoUrl" }
        var thuMuc: String { self == .avatar ? "avatar" : "cover" }
    }

    func doiAnh(_ item: PhotosPickerItem, truong: TruongAnh) async {
        if truong == .avatar { dangTaiAvatar = true } else { dangTaiAnhBia = true }
        defer { if truong == .avatar { dangTaiAvatar = false } else { dangTaiAnhBia = false } }
        loiDoiAnh = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let anh = PlatformImage(data: data),
                  let jpeg = anh.jpegDataForUpload()
            else {
                loiDoiAnh = "Không đọc được ảnh vừa chọn."
                return
            }

            let file = try await APIClient.shared.upload(
                data: jpeg,
                fileName: "\(truong.thuMuc)-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg",
                category: truong.thuMuc,
            )
            try await APIClient.shared.send(.updateProfile([truong.khoa: file.url]))

            // Nạp lại từ máy chủ thay vì tự sửa `profile` tại chỗ: máy chủ có
            // thể đổi URL (đưa qua CDN, thêm hậu tố kích cỡ), và nếu ta đoán
            // sai thì ảnh hiện đúng cho tới lần mở app sau rồi biến mất.
            await loadProfile()
            await AppState.shared.fetchProfile()
        } catch {
            loiDoiAnh = error.localizedDescription
        }
    }

    var isCurrentUser: Bool {
        guard let profileId = profile?.id, let currentId = AppState.shared.currentUser?.id else {
            return userId == AppState.shared.currentUser?.id
        }
        return profileId == currentId
    }

    init() {
        // Load profile on init
        Task {
            await loadProfile()
        }
    }

    func loadProfile() async {
        isLoading = true
        error = nil

        do {
            if let userId = userId ?? AppState.shared.currentUser?.id {
                let user: User = try await APIClient.shared.request(.getUserProfile(id: userId))
                profile = UserProfile(from: user)
                cursor = nil
                posts = []
                hasMore = true
                await loadPosts(reset: true)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadPosts(reset: Bool = false) async {
        guard let userId = userId ?? AppState.shared.currentUser?.id else { return }

        if reset {
            cursor = nil
            posts = []
            hasMore = true
        }

        guard hasMore else { return }

        do {
            let response: FeedResponse = try await APIClient.shared.request(
                .getUserPosts(id: userId, cursor: cursor, limit: 10)
            )

            if reset {
                posts = response.items
            } else {
                posts.append(contentsOf: response.items)
            }

            cursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadMorePosts() async {
        guard !isLoading && hasMore else { return }
        await loadPosts()
    }

    func toggleFollow() async {
        guard let userId = profile?.id else { return }

        do {
            if profile?.isFollowing == true {
                let _: EmptyResponse = try await APIClient.shared.request(.unfollowUser(id: userId))
                profile?.isFollowing = false
            } else {
                let _: EmptyResponse = try await APIClient.shared.request(.followUser(id: userId))
                profile?.isFollowing = true
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Profile Tab
enum ProfileTab {
    case posts
    case saved
    case courses
}

// MARK: - User Profile (extended user info)
struct UserProfile {
    let id: Int
    let username: String
    let email: String?
    let fullName: String?
    let displayName: String?
    let avatarUrl: String?
    let coverPhotoUrl: String?
    let bio: String?
    var isFollowing: Bool?
    let isFollowedBy: Bool?
    let followersCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let isVerified: Bool?
    let socialLinks: [String]?
    let createdAt: String?

    var name: String {
        displayName ?? fullName ?? username
    }

    init(from user: User) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
        self.fullName = user.fullName
        self.displayName = user.displayName
        self.avatarUrl = user.avatarUrl
        self.coverPhotoUrl = user.coverPhotoUrl
        self.bio = user.bio
        self.isFollowing = user.isFollowing
        self.isFollowedBy = user.isFollowedBy
        self.followersCount = user.followersCount
        self.followingCount = user.followingCount
        self.postsCount = user.postsCount
        self.isVerified = false
        self.socialLinks = nil
        self.createdAt = user.createdAt
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Account
                Section("Tài khoản") {
                    NavigationLink("Chỉnh sửa hồ sơ") { EditProfileView() }
                    NavigationLink("Đổi mật khẩu") { ChangePasswordView() }
                }

                // Safety & privacy — App Store Guideline 1.2 surfaces
                Section {
                    NavigationLink("Danh sách chặn") { BlockedUsersView() }
                    NavigationLink("Quy tắc cộng đồng & Điều khoản") { TermsView() }
                    NavigationLink("Chính sách bảo mật") { PrivacyPolicyView() }
                } header: {
                    Text("An toàn & quyền riêng tư")
                } footer: {
                    Text("Chúng tôi không khoan nhượng với nội dung phản cảm. Mọi báo cáo được xử lý trong 24 giờ.")
                }

                // Support
                Section("Hỗ trợ") {
                    NavigationLink("Trợ giúp & liên hệ") { HelpView() }
                    HStack {
                        Text("Email hỗ trợ")
                        Spacer()
                        Text(SupportContact.email)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .textSelection(.enabled)
                    }
                }

                // About
                Section("Giới thiệu") {
                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text(Bundle.main.appVersionString)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Session
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        HStack { Spacer(); Text("Đăng xuất"); Spacer() }
                    }
                }

                // Account erasure — App Store Guideline 5.1.1(v)
                Section {
                    NavigationLink {
                        DeleteAccountView()
                    } label: {
                        Text("Xoá tài khoản")
                            .foregroundColor(AppColors.error)
                    }
                } footer: {
                    Text("Xoá vĩnh viễn tài khoản và dữ liệu cá nhân của bạn.")
                }
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
            .alert("Đăng xuất", isPresented: $showLogoutAlert) {
                Button("Hủy", role: .cancel) { }
                Button("Đăng xuất", role: .destructive) {
                    appState.logout()
                    dismiss()
                }
            } message: {
                Text("Bạn có chắc muốn đăng xuất không?")
            }
        }
    }
}

extension Bundle {
    /// "1.0.0 (12)" — reviewers ask for the build number, and a hard-coded
    /// string here would drift from the one in Info.plist.
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState.shared)
}
