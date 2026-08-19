import SwiftUI

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    profileStats
                    profileActions
                    contentTabs
                    postsGrid
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                if let currentUser = appState.currentUser {
                    viewModel.userId = currentUser.id
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
                    Button {
                        // Edit cover photo
                    } label: {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                            .padding(Spacing.sm)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
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
                        Button {
                            // Edit avatar
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(AppColors.primary)
                                .clipShape(Circle())
                        }
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
                                    .foregroundColor(.white)
                                    .padding(.horizontal, Spacing.md)
                                    .padding(.vertical, Spacing.sm)
                                    .background(AppColors.primary)
                                    .cornerRadius(CornerRadius.medium)
                            }
                            .disabled(viewModel.isLoading)
                        }
                    } else {
                        Button {
                            // Edit profile
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

            actionButton(icon: "bookmark", title: "Đã lưu", isActive: viewModel.selectedTab == .saved) {
                viewModel.selectedTab = .saved
            }

            actionButton(icon: "shield.checkerboard", title: "Khóa học", isActive: viewModel.selectedTab == .courses) {
                viewModel.selectedTab = .courses
            }

            actionButton(icon: "music.note.list", title: "Nhạc", isActive: viewModel.selectedTab == .music) {
                viewModel.selectedTab = .music
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
    case music
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
