import SwiftUI
import Combine
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
    @State private var dangTimKiem = false
    @State private var tuKhoa = ""
    @State private var hienEmoji = false
    @State private var thongBaoTat: String?
    @ObservedObject private var realtime = RealtimeClient.shared
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if dangTimKiem { thanhTimKiem }
            messagesList
            if hienEmoji { bangEmoji }
            inputBar
        }
        .background(AppColors.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                chatHeader
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                // Gọi video / gọi thoại đã GỠ: backend không có kênh gọi nào,
                // để nút đó lại chỉ tạo ra hai chỗ bấm không ăn — đúng thứ
                // App Store đánh rớt theo 2.1.
                Menu {
                    Button {
                        withAnimation { dangTimKiem.toggle() }
                        if !dangTimKiem { tuKhoa = "" }
                    } label: {
                        Label(dangTimKiem ? "Đóng tìm kiếm" : "Tìm trong hội thoại",
                              systemImage: "magnifyingglass")
                    }

                    Divider()

                    Menu {
                        Button("15 phút") { Task { await tatThongBao(15) } }
                        Button("1 giờ") { Task { await tatThongBao(60) } }
                        Button("8 giờ") { Task { await tatThongBao(480) } }
                        Button("1 ngày") { Task { await tatThongBao(1440) } }
                        Button("Cho tới khi bật lại") { Task { await tatThongBao(nil) } }
                        Divider()
                        Button("Bật lại thông báo") { Task { await tatThongBao(0) } }
                    } label: {
                        Label("Tắt thông báo", systemImage: "bell.slash")
                    }

                    Button(role: .destructive) {
                        Task { await baoCaoHoiThoai() }
                    } label: {
                        Label("Báo cáo hội thoại", systemImage: "flag")
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
            AppState.shared.hoiThoaiDangMo = thread.id
            // Hội thoại vừa tạo chưa có trong danh sách máy chủ tự cho vào
            // lúc bắt tay, nên phải xin vào phòng.
            realtime.vaoPhong(threadId: thread.id)
            Task {
                await viewModel.loadMessages()
            }
        }
        // Tin mới đẩy thẳng vào danh sách, không hỏi lại API.
        .onReceive(realtime.tinMoi) { su in
            guard su.threadId == thread.id else { return }
            viewModel.chenTinMoi(su.message)
        }
        .onChange(of: messageText) { cu, moi in
            // Chỉ báo khi VỪA bắt đầu gõ và khi vừa xoá sạch, không phải mỗi
            // ký tự: gõ một câu 40 chữ là 40 gói tin cho cùng một thông tin.
            if cu.isEmpty && !moi.isEmpty {
                realtime.baoDangGo(threadId: thread.id, dangGo: true)
            } else if !cu.isEmpty && moi.isEmpty {
                realtime.baoDangGo(threadId: thread.id, dangGo: false)
            }
        }
        .onDisappear {
            AppState.shared.hoiThoaiDangMo = nil
            realtime.baoDangGo(threadId: thread.id, dangGo: false)
            Task {
                await viewModel.markAsRead()
            }
        }
        .alert("Hội thoại", isPresented: .constant(thongBaoTat != nil)) {
            Button("OK") { thongBaoTat = nil }
        } message: {
            Text(thongBaoTat ?? "")
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

                    // Trước đây dòng này ghi cứng "Đang hoạt động" cho mọi
                    // người, kể cả người đã offline hàng tháng — một lời nói
                    // dối nhỏ mà người dùng phát hiện ngay.
                    Text(dongTrangThai)
                        .font(.caption)
                        .foregroundColor(mauTrangThai)
                }
            }
        }
    }

    /// Người bên kia có đang gõ không.
    private var doiPhuongDangGo: Bool {
        guard let tap = realtime.dangGo[thread.id] else { return false }
        return tap.contains { $0 != AppState.shared.currentUser?.id }
    }

    private var dongTrangThai: String {
        if doiPhuongDangGo { return "đang gõ…" }
        if let id = thread.participants?.first?.id, realtime.truyenTuyen.contains(id) {
            return "Đang hoạt động"
        }
        return realtime.trangThai == .daNoi ? "Ngoại tuyến" : realtime.trangThai.moTa
    }

    private var mauTrangThai: Color {
        if doiPhuongDangGo { return AppColors.primary }
        if let id = thread.participants?.first?.id, realtime.truyenTuyen.contains(id) {
            return AppColors.success
        }
        return AppColors.textTertiary
    }

    /// Các nhóm tin sau khi lọc theo từ khoá. Lọc ngay trên máy vì backend
    /// không có endpoint tìm trong hội thoại — chỉ tìm được trong số tin ĐÃ
    /// tải; thanh tìm kiếm nói rõ điều đó thay vì im lặng để người dùng tưởng
    /// đã tìm hết lịch sử.
    private var nhomHienThi: [MessageGroup] {
        let goc = viewModel.groupedMessages
        let khoa = tuKhoa.trimmingCharacters(in: .whitespaces)
        guard !khoa.isEmpty else { return goc }
        return goc.compactMap { nhom in
            let khop = nhom.messages.filter { $0.content.localizedCaseInsensitiveContains(khoa) }
            return khop.isEmpty ? nil : MessageGroup(date: nhom.date, messages: khop)
        }
    }

    private var soTinKhop: Int { nhomHienThi.reduce(0) { $0 + $1.messages.count } }

    private var thanhTimKiem: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textSecondary)
                TextField("Tìm trong hội thoại", text: $tuKhoa)
                    .foregroundColor(AppColors.textPrimary)
                    .autocorrectionDisabled()
                if !tuKhoa.isEmpty {
                    Button {
                        tuKhoa = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                Button("Đóng") {
                    withAnimation { dangTimKiem = false }
                    tuKhoa = ""
                }
                .font(.buttonSmall)
                .foregroundColor(AppColors.primary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            if !tuKhoa.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(soTinKhop == 0
                     ? "Không thấy tin nào khớp trong \(viewModel.messages.count) tin đã tải"
                     : "\(soTinKhop) tin khớp trong \(viewModel.messages.count) tin đã tải")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.sm)
            }
        }
        .background(AppColors.backgroundSecondary)
    }

    private var bangEmoji: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(Self.emojiHayDung, id: \.self) { e in
                    Button {
                        messageText += e
                    } label: {
                        Text(e).font(.system(size: 30))
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(AppColors.backgroundSecondary)
    }

    private static let emojiHayDung = [
        "❤️", "😂", "😍", "👍", "🔥", "🎉", "😊", "😢", "😮", "😡",
        "🙏", "👏", "💯", "✅", "🤔", "😅", "🥰", "😭", "🤣", "💪",
    ]

    // MARK: - Hành động

    private func tatThongBao(_ phut: Int?) async {
        guard let id = viewModel.thread?.id else { return }
        do {
            try await APIClient.shared.send(.muteThread(id: id, durationMinutes: phut))
            thongBaoTat = phut == 0 ? "Đã bật lại thông báo" : "Đã tắt thông báo hội thoại này"
        } catch {
            thongBaoTat = error.localizedDescription
        }
    }

    private func baoCaoHoiThoai() async {
        guard let id = viewModel.thread?.id else { return }
        do {
            try await APIClient.shared.send(.reportThread(id: id, reason: "HARASSMENT"))
            thongBaoTat = "Đã gửi báo cáo. Đội kiểm duyệt xem xét trong 24 giờ."
        } catch {
            thongBaoTat = error.localizedDescription
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
                        ForEach(nhomHienThi, id: \.date) { group in
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
                        withAnimation { hienEmoji.toggle() }
                        if hienEmoji { isInputFocused = false }
                    } label: {
                        Image(systemName: hienEmoji ? "keyboard" : "face.smiling")
                            .font(.title3)
                            .foregroundColor(hienEmoji ? AppColors.primary : AppColors.textSecondary)
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
        Haptics.cham()

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

    /// Chèn tin nhận qua socket. Bỏ qua nếu đã có — tin do CHÍNH MÌNH gửi
    /// quay về qua socket sẽ trùng với bản đã thêm lạc quan lúc bấm Gửi.
    func chenTinMoi(_ tin: Message) {
        guard !messages.contains(where: { $0.id == tin.id }) else { return }
        messages.append(tin)
    }

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
