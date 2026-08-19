import SwiftUI

// MARK: - Search View
struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeader
                filterTabs
                searchResults
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Tìm kiếm")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchQuery, prompt: "Tìm kiếm người dùng, bài viết...")
            .onSubmit(of: .search) {
                Task {
                    await viewModel.performSearch()
                }
            }
        }
    }

    private var searchHeader: some View {
        VStack(spacing: Spacing.sm) {
            if viewModel.isLoading && !viewModel.users.isEmpty {
                ProgressView()
                    .tint(AppColors.primary)
            }
        }
        .frame(height: 30)
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(SearchFilter.allCases, id: \.self) { filter in
                    SearchFilterChip(
                        filter: filter,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        viewModel.selectedFilter = filter
                        if !viewModel.searchQuery.isEmpty {
                            Task {
                                await viewModel.performSearch()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(AppColors.backgroundSecondary)
    }

    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                if viewModel.searchQuery.isEmpty {
                    emptySearchState
                } else if viewModel.isLoading && viewModel.users.isEmpty && viewModel.posts.isEmpty {
                    loadingView
                } else if viewModel.users.isEmpty && viewModel.posts.isEmpty {
                    noResultsView
                } else {
                    switch viewModel.selectedFilter {
                    case .all:
                        allResultsView
                    case .users:
                        usersListView
                    case .posts:
                        postsListView
                    case .courses, .music:
                        EmptyView()
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: Spacing.sm) {
                Text("Tìm kiếm")
                    .font(.titleLarge)
                    .foregroundColor(AppColors.textPrimary)

                Text("Tìm kiếm người dùng, bài viết, khóa học và nhiều hơn nữa")
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            recentSearchesView
        }
        .padding(.top, Spacing.xxl)
    }

    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Tìm kiếm gần đây")
                    .font(.titleSmall)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button("Xóa") {
                    viewModel.clearRecentSearches()
                }
                .font(.caption)
                .foregroundColor(AppColors.primary)
            }
            .padding(.horizontal, Spacing.md)

            ForEach(viewModel.recentSearches, id: \.self) { search in
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(AppColors.textTertiary)

                    Text(search)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Button {
                        viewModel.searchQuery = search
                        Task {
                            await viewModel.performSearch()
                        }
                    } label: {
                        Image(systemName: "arrow.up.left")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
        }
        .padding(.top, Spacing.xl)
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Đang tìm kiếm...")
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.top, Spacing.xxl)
    }

    private var noResultsView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "person.slash")
                .font(.system(size: 50))
                .foregroundColor(AppColors.textTertiary)

            Text("Không tìm thấy kết quả")
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)

            Text("Thử tìm kiếm với từ khóa khác")
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.top, Spacing.xxl)
    }

    @ViewBuilder
    private var allResultsView: some View {
        if !viewModel.users.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                sectionHeader("Mọi người")
                ForEach(viewModel.users.prefix(5)) { user in
                    NavigationLink(destination: UserProfileView(userId: user.id)) {
                        UserSearchRow(user: user)
                    }
                }
            }
        }

        if !viewModel.posts.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                sectionHeader("Bài viết")
                ForEach(viewModel.posts.prefix(5)) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        PostSearchRow(post: post)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var usersListView: some View {
        ForEach(viewModel.users) { user in
            NavigationLink(destination: UserProfileView(userId: user.id)) {
                UserSearchRow(user: user)
            }
        }
    }

    @ViewBuilder
    private var postsListView: some View {
        ForEach(viewModel.posts) { post in
            NavigationLink(destination: PostDetailView(post: post)) {
                PostSearchRow(post: post)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.titleSmall)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            NavigationLink("Xem tất cả") {
                // Full list view
            }
            .font(.caption)
            .foregroundColor(AppColors.primary)
        }
    }
}

// MARK: - Search Filter
enum SearchFilter: String, CaseIterable {
    case all = "Tất cả"
    case users = "Mọi người"
    case posts = "Bài viết"
    case courses = "Khóa học"
    case music = "Nhạc"
}

// MARK: - Search Filter Chip
struct SearchFilterChip: View {
    let filter: SearchFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(filter.rawValue)
                .font(.buttonSmall)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? AppColors.primary : AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.full)
        }
    }
}

// MARK: - User Search Row
struct UserSearchRow: View {
    let user: User

    var body: some View {
        HStack(spacing: Spacing.md) {
            UserAvatarView(url: user.avatarUrl, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.titleSmall)
                    .foregroundColor(AppColors.textPrimary)

                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }

                if let followers = user.followersCount {
                    Text("\(followers) người theo dõi")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Post Search Row
struct PostSearchRow: View {
    let post: SocialPost

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            if let media = post.media, let firstMedia = media.first,
               let thumbnailUrl = URL(string: firstMedia.thumbnail ?? firstMedia.url) {
                AsyncImage(url: thumbnailUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(AppColors.backgroundTertiary)
                }
                .frame(width: 80, height: 80)
                .cornerRadius(CornerRadius.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.sm) {
                    UserAvatarView(url: post.author.avatarUrl, size: 24)

                    Text(post.author.name)
                        .font(.captionBold)
                        .foregroundColor(AppColors.textPrimary)
                }

                Text(post.content)
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: Spacing.md) {
                    Label("\(post.likesCount)", systemImage: "heart")
                    Label("\(post.commentsCount)", systemImage: "bubble.right")
                    Label("\(post.sharesCount)", systemImage: "square.and.arrow.up")
                }
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Search View Model
@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var selectedFilter: SearchFilter = .all
    @Published var users: [User] = []
    @Published var posts: [SocialPost] = []
    @Published var isLoading = false
    @Published var error: String?

    private let recentSearchesKey = "recentSearches"
    private let maxRecentSearches = 10

    var recentSearches: [String] {
        UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    func performSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            users = []
            posts = []
            return
        }

        isLoading = true
        error = nil

        // Save to recent searches
        saveRecentSearch(searchQuery)

        do {
            // Search users
            let usersResponse: UsersSearchResponse = try await APIClient.shared.request(
                .searchUsers(q: searchQuery)
            )
            users = usersResponse.users

            // Get trending/filtered posts (for now, just show empty)
            posts = []

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func clearRecentSearches() {
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
        objectWillChange.send()
    }

    private func saveRecentSearch(_ query: String) {
        var searches = recentSearches
        searches.removeAll { $0.lowercased() == query.lowercased() }
        searches.insert(query, at: 0)
        if searches.count > maxRecentSearches {
            searches = Array(searches.prefix(maxRecentSearches))
        }
        UserDefaults.standard.set(searches, forKey: recentSearchesKey)
    }
}

// MARK: - Users Search Response
struct UsersSearchResponse: Codable {
    let users: [User]
}

// MARK: - String Extension for URL
extension String {
    var asURL: URL? {
        URL(string: self)
    }
}

#Preview {
    SearchView()
        .environmentObject(AppState.shared)
}
