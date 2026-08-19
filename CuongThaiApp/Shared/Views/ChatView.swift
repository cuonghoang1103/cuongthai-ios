import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Chat View
struct ChatView: View {
    let thread: MessageThread
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var showAttachmentOptions = false
    @State private var showUserProfile = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            inputBar
        }
        .background(AppColors.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                chatHeader
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        // Video call
                    } label: {
                        Label("Gọi video", systemImage: "video")
                    }

                    Button {
                        // Voice call
                    } label: {
                        Label("Gọi thoại", systemImage: "phone")
                    }

                    Button {
                        // Search messages
                    } label: {
                        Label("Tìm kiếm", systemImage: "magnifyingglass")
                    }

                    Divider()

                    Button(role: .destructive) {
                        // Mute notifications
                    } label: {
                        Label("Tắt thông báo", systemImage: "bell.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .sheet(isPresented: $showUserProfile) {
            if let userId = thread.participants?.first?.id {
                UserProfileView(userId: userId)
            }
        }
        .onAppear {
            viewModel.thread = thread
            Task {
                await viewModel.loadMessages()
            }
        }
        .onDisappear {
            Task {
                await viewModel.markAsRead()
            }
        }
    }

    private var chatHeader: some View {
        Button {
            showUserProfile = true
        } label: {
            HStack(spacing: Spacing.sm) {
                UserAvatarView(url: thread.avatarUrl, size: 36)

                VStack(alignment: .leading, spacing: 0) {
                    Text(thread.displayName)
                        .font(.titleSmall)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Đang hoạt động")
                        .font(.caption)
                        .foregroundColor(AppColors.success)
                }
            }
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if viewModel.isLoading && viewModel.messages.isEmpty {
                        ProgressView()
                            .padding(.top, Spacing.xxl)
                    } else {
                        ForEach(viewModel.groupedMessages, id: \.date) { group in
                            // Date header
                            Text(group.date)
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                                .padding(.vertical, Spacing.sm)

                            ForEach(group.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromCurrentUser: viewModel.isFromCurrentUser(message),
                                    showAvatar: viewModel.shouldShowAvatar(for: message, in: group.messages)
                                )
                                .id(message.id)
                            }
                        }

                        if viewModel.hasMore {
                            ProgressView()
                                .padding()
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreMessages()
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.divider)

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                // Attachment button
                Button {
                    showAttachmentOptions.toggle()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.primary)
                }

                // Text input
                HStack(alignment: .bottom, spacing: Spacing.sm) {
                    TextField("Tin nhắn", text: $messageText, axis: .vertical)
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.sm)
                        .background(AppColors.backgroundTertiary)
                        .cornerRadius(CornerRadius.large)

                    // Emoji button
                    Button {
                        // Show emoji picker
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.title3)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(messageText.isEmpty ? AppColors.textTertiary : AppColors.primary)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.backgroundSecondary)

            // Attachment options
            if showAttachmentOptions {
                attachmentOptions
            }
        }
    }

    private var attachmentOptions: some View {
        HStack(spacing: Spacing.xl) {
            attachmentButton(icon: "photo", title: "Ảnh") {
                // Photo picker
            }

            attachmentButton(icon: "video", title: "Video") {
                // Video picker
            }

            attachmentButton(icon: "folder", title: "File") {
                // File picker
            }

            attachmentButton(icon: "location", title: "Vị trí") {
                // Location
            }

            attachmentButton(icon: "person.crop.circle.badge.plus", title: "Liên hệ") {
                // Contact
            }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundSecondary)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func attachmentButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(AppColors.primary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.primary.opacity(0.1))
                    .clipShape(Circle())

                Text(title)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task {
            await viewModel.sendMessage(messageText)
            messageText = ""
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let showAvatar: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            } else {
                if showAvatar {
                    UserAvatarView(url: message.sender?.avatarUrl, size: 28)
                } else {
                    Spacer().frame(width: 28)
                }
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                // Message content
                Group {
                    if message.type == "text" || message.type == nil {
                        Text(message.content)
                            .font(.bodyMedium)
                            .foregroundColor(isFromCurrentUser ? .white : AppColors.textPrimary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(isFromCurrentUser ? AppColors.primary : AppColors.backgroundTertiary)
                            .cornerRadius(CornerRadius.large)
                    } else if message.type == "image" {
                        #if canImport(Kingfisher)
                        if let url = URL(string: message.mediaUrl ?? "") {
                            KFImage(url)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: 200, maxHeight: 200)
                                .cornerRadius(CornerRadius.medium)
                        }
                        #endif
                    }
                }

                // Timestamp and status
                HStack(spacing: 4) {
                    Text(TimeFormatter.formatTimeAgo(message.createdAt))
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)

                    if isFromCurrentUser {
                        Image(systemName: message.readAt != nil ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(message.readAt != nil ? AppColors.primary : AppColors.textTertiary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Grouped Messages
struct MessageGroup {
    let date: String
    let messages: [Message]
}

// MARK: - Chat View Model
@MainActor
class ChatViewModel: ObservableObject {
    @Published var thread: MessageThread?
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasMore = true
    @Published private(set) var localUnreadCount: Int = 0

    private var cursor: Int?

    func loadMessages() async {
        guard let threadId = thread?.id else { return }

        isLoading = true
        cursor = nil

        do {
            let response: MessagesResponse = try await APIClient.shared.request(
                .getMessages(threadId: threadId, cursor: nil, limit: 50)
            )
            messages = response.items.reversed()
            cursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreMessages() async {
        guard let threadId = thread?.id, hasMore, !isLoading else { return }

        do {
            let response: MessagesResponse = try await APIClient.shared.request(
                .getMessages(threadId: threadId, cursor: cursor, limit: 50)
            )
            messages.insert(contentsOf: response.items.reversed(), at: 0)
            cursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendMessage(_ content: String) async {
        guard let threadId = thread?.id else { return }

        // Optimistically add message
        let tempMessage = Message(
            id: Int.random(in: 100000...999999),
            senderId: AppState.shared.currentUser?.id ?? 0,
            sender: AppState.shared.currentUser,
            content: content,
            type: "text",
            mediaUrl: nil,
            thumbnailUrl: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            readAt: nil
        )

        messages.append(tempMessage)

        do {
            let newMessage: Message = try await APIClient.shared.request(
                .sendMessage(threadId: threadId, content: content, type: "text")
            )

            // Replace temp message with real one
            if let index = messages.firstIndex(where: { $0.id == tempMessage.id }) {
                messages[index] = newMessage
            }
        } catch {
            // Remove temp message on error
            messages.removeAll { $0.id == tempMessage.id }
            self.error = error.localizedDescription
        }
    }

    func markAsRead() async {
        guard let threadId = thread?.id else { return }

        do {
            let _: EmptyResponse = try await APIClient.shared.request(.markRead(threadId: threadId))
            localUnreadCount = 0
        } catch {
            // Silently fail
        }
    }

    var groupedMessages: [MessageGroup] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let calendar = Calendar.current
        var groups: [String: [Message]] = [:]

        for message in messages {
            let date = ISO8601DateFormatter().date(from: message.createdAt) ?? Date()
            let key: String

            if calendar.isDateInToday(date) {
                key = "Hôm nay"
            } else if calendar.isDateInYesterday(date) {
                key = "Hôm qua"
            } else {
                key = formatter.string(from: date)
            }

            groups[key, default: []].append(message)
        }

        return groups.map { MessageGroup(date: $0.key, messages: $0.value) }
            .sorted { group1, group2 in
                guard let msg1 = group1.messages.first,
                      let msg2 = group2.messages.first else { return false }
                let date1 = ISO8601DateFormatter().date(from: msg1.createdAt) ?? Date()
                let date2 = ISO8601DateFormatter().date(from: msg2.createdAt) ?? Date()
                return date1 < date2
            }
    }

    func isFromCurrentUser(_ message: Message) -> Bool {
        message.senderId == AppState.shared.currentUser?.id
    }

    func shouldShowAvatar(for message: Message, in messages: [Message]) -> Bool {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return true }

        if index == messages.count - 1 { return true }

        let nextMessage = messages[index + 1]
        return nextMessage.senderId != message.senderId
    }
}

#Preview {
    NavigationStack {
        ChatView(thread: MessageThread(
            id: 1,
            type: "direct",
            participants: [User(id: 1, username: "test", email: nil, fullName: "Test User", displayName: nil, avatarUrl: nil, coverPhotoUrl: nil, bio: nil, isFollowing: nil, isFollowedBy: nil, followersCount: nil, followingCount: nil, postsCount: nil, createdAt: nil)],
            lastMessage: nil,
            unreadCount: 0,
            createdAt: nil,
            updatedAt: nil
        ))
    }
}
