import SwiftUI
import Combine

// MARK: - Home View Model
@MainActor
class HomeViewModel: ObservableObject {
    @Published var posts: [SocialPost] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    private var cursor: Int?
    private var hasMore = true

    func loadFeed(type: String? = nil) async {
        isLoading = true
        error = nil
        do {
            let res: FeedResponse = try await APIClient.shared.request(
                .getFeed(cursor: nil, limit: 20, type: type, videoCategoryId: nil)
            )
            posts = res.items
            cursor = res.nextCursor
            hasMore = res.hasMore
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore(type: String? = nil) async {
        guard !isLoadingMore && hasMore, let cursor = cursor else { return }
        isLoadingMore = true
        do {
            let res: FeedResponse = try await APIClient.shared.request(
                .getFeed(cursor: cursor, limit: 20, type: type, videoCategoryId: nil)
            )
            posts.append(contentsOf: res.items)
            self.cursor = res.nextCursor
            hasMore = res.hasMore
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingMore = false
    }

    func refresh(type: String? = nil) async {
        await loadFeed(type: type)
    }
}

// MARK: - Home View
struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @ObservedObject private var moderation = ModerationStore.shared
    @State private var quickSheet: QuickSheet?

    // One `.sheet(item:)` rather than two `.sheet(isPresented:)` — SwiftUI
    // only honours the last presentation modifier attached to a view.
    enum QuickSheet: String, Identifiable {
        case search, notes
        var id: String { rawValue }
    }
    @State private var selectedType: String?
    @State private var selectedFilter = 0

    let filters = ["Tất cả", "Bài viết", "Video", "File"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    filterBar
                    feedContent
                }
            }
            .navigationTitle("CuongThai")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("CuongThai")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.55, green: 0.35, blue: 0.96),
                                    Color(red: 0.02, green: 0.71, blue: 0.83)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: Spacing.md) {
                        // Presented as sheets, not pushed: both views carry
                        // their own NavigationStack.
                        Button { quickSheet = .search } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        Button { quickSheet = .notes } label: {
                            Image(systemName: "note.text")
                        }
                    }
                    .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .sheet(item: $quickSheet) { sheet in
            switch sheet {
            case .search: SearchView()
            case .notes: NotesView()
            }
        }
        .task {
            await vm.loadFeed(type: selectedType)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(Array(filters.enumerated()), id: \.offset) { index, filter in
                    FilterPill(
                        title: filter,
                        isSelected: selectedFilter == index
                    ) {
                        selectedFilter = index
                        switch index {
                        case 0: selectedType = nil
                        case 1: selectedType = "POST"
                        case 2: selectedType = "VIDEO"
                        case 3: selectedType = "FILE"
                        default: selectedType = nil
                        }
                        Task { await vm.loadFeed(type: selectedType) }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    private var feedContent: some View {
        Group {
            if vm.isLoading && vm.posts.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if moderation.filter(vm.posts).isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "newspaper",
                    title: "Chưa có bài viết",
                    subtitle: "Hãy là người đầu tiên chia sẻ!"
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        // Blocked authors and hidden posts never reach the screen.
                        ForEach(moderation.filter(vm.posts)) { post in
                            ZStack(alignment: .topTrailing) {
                                NavigationLink(destination: PostDetailView(post: post)) {
                                    PostCard(post: post)
                                }
                                .buttonStyle(.plain)

                                PostModerationMenu(post: post)
                                    .padding(.top, Spacing.md)
                                    .padding(.trailing, Spacing.md)
                            }
                            .onAppear {
                                if post.id == vm.posts.last?.id {
                                    Task { await vm.loadMore(type: selectedType) }
                                }
                            }
                        }
                        if vm.isLoadingMore {
                            ProgressView().padding()
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .refreshable {
                    await vm.refresh(type: selectedType)
                }
            }
        }
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    isSelected
                        ? Color(red: 0.55, green: 0.35, blue: 0.96)
                        : Color(red: 0.1, green: 0.1, blue: 0.14)
                )
                .cornerRadius(20)
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
}
