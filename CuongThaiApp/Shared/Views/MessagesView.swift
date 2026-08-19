import SwiftUI

// MARK: - Messages View
struct MessagesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = MessagesViewModel()
    @State private var searchQuery = ""
    @State private var showNewMessage = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                filterTabs
                threadsList
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Tin nhắn")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewMessage = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showNewMessage) {
                NewMessageView()
            }
            .refreshable {
                await viewModel.loadThreads()
            }
            .onAppear {
                Task {
                    await viewModel.loadThreads()
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)

            TextField("Tìm kiếm tin nhắn", text: $searchQuery)
                .foregroundColor(AppColors.textPrimary)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(Spacing.sm)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.medium)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(MessageFilter.allCases, id: \.self) { filter in
                    MessageFilterChip(
                        filter: filter,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        viewModel.selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(AppColors.backgroundSecondary)
    }

    private var threadsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoading && viewModel.threads.isEmpty {
                    loadingView
                } else if viewModel.threads.isEmpty {
                    emptyStateView
                } else {
                    ForEach(viewModel.filteredThreads(searchQuery: searchQuery)) { thread in
                        NavigationLink(destination: ChatView(thread: thread)) {
                            ThreadRow(thread: thread)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .background(AppColors.divider)
                            .padding(.leading, 76)
                    }

                    if viewModel.hasMore {
                        ProgressView()
                            .padding()
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreThreads()
                                }
                            }
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Đang tải tin nhắn...")
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.top, Spacing.xxl)
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: Spacing.sm) {
                Text("Không có tin nhắn nào")
                    .font(.titleLarge)
                    .foregroundColor(AppColors.textPrimary)

                Text("Bắt đầu cuộc trò chuyện với bạn bè")
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showNewMessage = true
            } label: {
                Text("Tin nhắn mới")
                    .primaryButtonStyle()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.md)
        }
        .padding(.top, Spacing.xxl)
    }
}

// MARK: - Message Filter
enum MessageFilter: String, CaseIterable {
    case all = "Tất cả"
    case unread = "Chưa đọc"
    case personal = "Cá nhân"
    case group = "Nhóm"

    var icon: String {
        switch self {
        case .all: return "tray"
        case .unread: return "envelope.badge"
        case .personal: return "person"
        case .group: return "person.3"
        }
    }
}

// MARK: - Message Filter Chip
struct MessageFilterChip: View {
    let filter: MessageFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.rawValue)
                    .font(.buttonSmall)
            }
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(isSelected ? AppColors.primary : AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.full)
        }
    }
}

// MARK: - Thread Row
struct ThreadRow: View {
    let thread: MessageThread
    @State private var isOnline = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                UserAvatarView(url: thread.avatarUrl, size: 56)

                if thread.type == "direct" && isOnline {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(AppColors.backgroundPrimary, lineWidth: 2)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(thread.displayName)
                        .font(.titleSmall)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if let lastMessage = thread.lastMessage {
                        Text(TimeFormatter.formatTimeAgo(lastMessage.createdAt))
                            .font(.caption)
                            .foregroundColor(thread.unreadCount > 0 ? AppColors.primary : AppColors.textTertiary)
                    }
                }

                HStack {
                    if let lastMessage = thread.lastMessage {
                        Text(lastMessage.content)
                            .font(.bodyMedium)
                            .foregroundColor(thread.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Chưa có tin nhắn")
                            .font(.bodyMedium)
                            .foregroundColor(AppColors.textTertiary)
                            .italic()
                    }

                    Spacer()

                    if thread.unreadCount > 0 {
                        Text("\(thread.unreadCount)")
                            .font(.captionBold)
                            .foregroundColor(AppColors.onPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(thread.unreadCount > 0 ? AppColors.primary.opacity(0.05) : Color.clear)
    }
}

// MARK: - Messages View Model
@MainActor
class MessagesViewModel: ObservableObject {
    @Published var threads: [MessageThread] = []
    @Published var selectedFilter: MessageFilter = .all
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasMore = true

    private var cursor: Int?

    func loadThreads() async {
        isLoading = true
        error = nil
        cursor = nil

        do {
            let response: (items: [MessageThread], nextCursor: Int?, hasMore: Bool) = try await APIClient.shared.requestList(
                .getThreads(cursor: nil, limit: 20)
            )
            threads = response.items
            cursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreThreads() async {
        guard hasMore, !isLoading else { return }

        do {
            let response: (items: [MessageThread], nextCursor: Int?, hasMore: Bool) = try await APIClient.shared.requestList(
                .getThreads(cursor: cursor, limit: 20)
            )
            threads.append(contentsOf: response.items)
            cursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }
    }

    func filteredThreads(searchQuery: String) -> [MessageThread] {
        var filtered = threads

        // Filter by type
        switch selectedFilter {
        case .all:
            break
        case .unread:
            filtered = filtered.filter { $0.unreadCount > 0 }
        case .personal:
            filtered = filtered.filter { $0.type == "direct" }
        case .group:
            filtered = filtered.filter { $0.type == "group" }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            filtered = filtered.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
                ($0.lastMessage?.content.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }

        return filtered
    }
}

// MARK: - New Message View
struct NewMessageView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = NewMessageViewModel()
    @State private var hoiThoaiMo: MessageThread?
    @State private var dangMo: Int?
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textTertiary)

                    TextField("Tìm người dùng", text: $viewModel.searchQuery)
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(Spacing.sm)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.medium)
                .padding(Spacing.md)

                // Results
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, Spacing.xxl)
                } else if viewModel.users.isEmpty && !viewModel.searchQuery.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.textTertiary)
                        Text("Không tìm thấy người dùng")
                            .font(.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, Spacing.xxl)
                } else {
                    List(viewModel.users) { user in
                        Button {
                            Task { await moHoiThoai(voi: user) }
                        } label: {
                            HStack(spacing: Spacing.md) {
                                UserAvatarView(url: user.avatarUrl, size: 44)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.name)
                                        .font(.titleSmall)
                                        .foregroundColor(AppColors.textPrimary)

                                    Text("@\(user.username)")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Spacer()
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppColors.backgroundPrimary)
            // Điều hướng NGAY TRONG sheet này thay vì đóng sheet rồi nhờ màn
            // cha mở hộ: màn cha phải chờ tải lại danh sách hội thoại mới thấy
            // hội thoại vừa tạo, nên người dùng bấm xong thấy... không có gì.
            .navigationDestination(item: $hoiThoaiMo) { thread in
                ChatView(thread: thread)
            }
            .alert("Không mở được hội thoại", isPresented: .constant(loi != nil)) {
                Button("OK") { loi = nil }
            } message: {
                Text(loi ?? "")
            }
            .navigationTitle("Tin nhắn mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// `POST /messages/threads/user/:peerId` — máy chủ trả hội thoại đã có,
    /// hoặc tạo mới nếu hai người chưa từng nhắn. Không cần kiểm trước.
    private func moHoiThoai(voi user: User) async {
        guard dangMo == nil else { return }
        dangMo = user.id
        defer { dangMo = nil }
        do {
            let thread: MessageThread = try await APIClient.shared.request(.openThread(peerId: user.id))
            hoiThoaiMo = thread
        } catch {
            loi = error.localizedDescription
        }
    }
}

// MARK: - New Message View Model
@MainActor
class NewMessageViewModel: ObservableObject {
    @Published var searchQuery = "" {
        didSet {
            searchUsers()
        }
    }
    @Published var users: [User] = []
    @Published var isLoading = false

    private var searchTask: Task<Void, Never>?

    private func searchUsers() {
        searchTask?.cancel()

        guard searchQuery.count >= 2 else {
            users = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }

            isLoading = true

            do {
                let response: UsersSearchResponse = try await APIClient.shared.request(
                    .searchUsers(q: searchQuery)
                )
                users = response.users
            } catch {
                // Handle error silently
            }

            isLoading = false
        }
    }
}

#Preview {
    MessagesView()
        .environmentObject(AppState.shared)
}
