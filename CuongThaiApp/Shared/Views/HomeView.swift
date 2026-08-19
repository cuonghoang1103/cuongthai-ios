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
    @EnvironmentObject private var appState: AppState
    @State private var quickSheet: QuickSheet?

    // One `.sheet(item:)` rather than two `.sheet(isPresented:)` — SwiftUI
    // only honours the last presentation modifier attached to a view.
    enum QuickSheet: String, Identifiable {
        case search, notes, notifications
        var id: String { rawValue }
    }
    @State private var selectedType: String?
    @State private var selectedFilter = 0

    let filters = ["Tất cả", "Bài viết", "Video", "File"]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

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
                                    AppColors.primary,
                                    AppColors.secondary
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
                        Button { quickSheet = .notifications } label: {
                            // Huy hiệu vẽ chồng thay vì dùng `.badge`:
                            // `.badge` chỉ có tác dụng trên tab và List.
                            Image(systemName: "bell")
                                .overlay(alignment: .topTrailing) {
                                    if appState.unreadNotifications > 0 {
                                        Text(appState.unreadNotifications > 99
                                             ? "99+" : "\(appState.unreadNotifications)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(AppColors.onPrimary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(AppColors.error))
                                            .offset(x: 10, y: -8)
                                            .fixedSize()
                                    }
                                }
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
            case .notifications: NotificationsView()
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
                // Khung xương thay vòng xoay: thấy trước bố cục nên lúc dữ
                // liệu về màn hình không "nhảy" một cái.
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(0..<3, id: \.self) { _ in PostSkeleton() }
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .disabled(true)
            } else if let loi = vm.error, vm.posts.isEmpty {
                // Trước đây lỗi mạng cũng rơi vào nhánh "Chưa có bài viết" —
                // báo mất mạng thành "không có nội dung" là nói sai, và người
                // dùng không có lý do gì để thử lại.
                Spacer()
                ErrorStateView(message: loi) {
                    Task { await vm.loadFeed(type: selectedType) }
                }
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
                        ? AppColors.primary
                        : AppColors.backgroundCard
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
                .foregroundColor(AppColors.textSecondary)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding()
    }
}
