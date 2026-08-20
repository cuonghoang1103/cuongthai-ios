import SwiftUI
import Combine
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif
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
    #if os(iOS)
    @State private var anhDangChon: [PhotosPickerItem] = []
    #endif
    @State private var hienChonTep = false
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
        .modifier(VongDoiChat(thread: thread, viewModel: viewModel, realtime: realtime,
                              messageText: $messageText, thongBaoTat: $thongBaoTat))
        .modifier(DinhKemChat(hienChonTep: $hienChonTep, guiTep: guiTep))
        #if os(iOS)
        .onChange(of: anhDangChon) { _, moi in
            Task { await guiAnhDaChon(moi) }
        }
        #endif
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
            let khop = nhom.messages.filter { $0.noiDung.localizedCaseInsensitiveContains(khoa) }
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
                        // Tin CŨ nằm trên đỉnh, nên móc "tải thêm" phải ở đây.
                        // Bản cũ đặt nó dưới đáy — tức cuộn xuống tin MỚI NHẤT
                        // mới đi tải tin cũ, và ở đáy thì nó luôn hiện sẵn nên
                        // vòng tải chạy ngay lúc mở.
                        if viewModel.hasMore {
                            HStack(spacing: 6) {
                                if viewModel.dangTaiThem {
                                    ProgressView().scaleEffect(0.7)
                                    Text("Đang tải tin cũ…")
                                } else {
                                    Text("Kéo lên để xem tin cũ hơn")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .onAppear {
                                Task { await viewModel.loadMoreMessages() }
                            }
                        }

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
                                    showAvatar: viewModel.shouldShowAvatar(for: message, in: group.messages),
                                    daXem: viewModel.tinCuoiDaXem == message.id
                                )
                                .id(message.id)
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

    // Chỉ giữ hai nút LÀM ĐƯỢC THẬT. Video / Vị trí / Liên hệ trước đây là
    // nút rỗng — bấm vào không có gì xảy ra, trông y như app hỏng. Cả hai nút
    // dưới đi chung đường `POST /messages/upload` (trần 10MB).
    private var attachmentOptions: some View {
        HStack(spacing: Spacing.xl) {
            #if os(iOS)
            PhotosPicker(selection: $anhDangChon, maxSelectionCount: 5, matching: .images) {
                nutDinhKem(icon: "photo", title: "Ảnh")
            }
            #endif

            Button {
                hienChonTep = true
            } label: {
                nutDinhKem(icon: "folder", title: "Tệp")
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundSecondary)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func nutDinhKem(icon: String, title: String) -> some View {
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

    #if os(iOS)
    /// Đọc ảnh đã chọn rồi gửi. `loadTransferable` trả `Data` ĐÃ giải mã sang
    /// định dạng gốc của ảnh — kể cả ảnh HEIC của iPhone, nên không phải tự
    /// chuyển đổi.
    private func guiAnhDaChon(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var gui: [(data: Data, ten: String, mime: String)] = []
        for (i, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            // `supportedContentTypes` có thể RỖNG với ảnh chụp màn hình và ảnh
            // đồng bộ từ iCloud — mặc định về jpeg thay vì bỏ qua tấm ảnh.
            let loai = item.supportedContentTypes.first
            let duoi = loai?.preferredFilenameExtension ?? "jpg"
            let mime = loai?.preferredMIMEType ?? "image/jpeg"
            gui.append((data, "anh-\(i + 1).\(duoi)", mime))
        }
        guard !gui.isEmpty else { return }
        await viewModel.guiAnh(gui, kem: messageText.trimmingCharacters(in: .whitespacesAndNewlines))
        messageText = ""
        anhDangChon = []
        withAnimation { showAttachmentOptions = false }
    }
    #endif

    private func guiTep(_ ketQua: Result<URL, Error>) {
        guard case .success(let url) = ketQua else { return }
        Task {
            // File ngoài hộp cát của app cần xin quyền đọc rồi TRẢ LẠI, không
            // thì lần chọn sau bị từ chối im lặng.
            let mo = url.startAccessingSecurityScopedResource()
            defer { if mo { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                viewModel.error = "Không đọc được tệp này."
                return
            }
            await viewModel.guiAnh([(data, url.lastPathComponent, "application/octet-stream")],
                                   kem: messageText.trimmingCharacters(in: .whitespacesAndNewlines))
            messageText = ""
            withAnimation { showAttachmentOptions = false }
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
    /// Vẽ "Đã xem" dưới ĐÚNG tin cuối người kia đã đọc, như Messenger.
    var daXem: Bool = false

    private var mauChu: Color { isFromCurrentUser ? AppColors.onPrimary : AppColors.textPrimary }
    private var mauNen: Color { isFromCurrentUser ? AppColors.primary : AppColors.backgroundTertiary }

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

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 3) {
                if message.daXoaHoacThuHoi {
                    Text("Tin nhắn đã được thu hồi")
                        .font(.bodyMedium)
                        .italic()
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.large)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                } else {
                    if let cha = message.parentMessage {
                        traLoiTrichDan(cha)
                    }

                    // Ảnh trước, chữ sau — giống Messenger, và tin chỉ có ảnh
                    // thì không vẽ bong bóng rỗng bên dưới.
                    if !message.anh.isEmpty {
                        luoiAnh(message.anh)
                    }

                    ForEach(message.tepKhongPhaiAnh) { tep in
                        theTep(tep)
                    }

                    if !message.noiDung.isEmpty {
                        Text(message.noiDung)
                            .font(.bodyMedium)
                            .foregroundColor(mauChu)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(mauNen)
                            .cornerRadius(CornerRadius.large)
                            .textSelection(.enabled)
                    }
                }

                HStack(spacing: 4) {
                    Text(TimeFormatter.formatTimeAgo(message.createdAt))
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    if isFromCurrentUser && daXem {
                        // Chữ chứ không phải dấu tích: hai dấu tích đặc/rỗng
                        // trông gần giống nhau, nhìn lướt không phân biệt được.
                        Text("· Đã xem")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Ảnh

    @ViewBuilder
    private func luoiAnh(_ ds: [String]) -> some View {
        let rong: CGFloat = ds.count == 1 ? 220 : 108
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(rong), spacing: 4),
                                 count: ds.count == 1 ? 1 : 2),
                  spacing: 4) {
            ForEach(Array(ds.enumerated()), id: \.offset) { _, duong in
                anhMot(duong, canh: rong)
            }
        }
    }

    @ViewBuilder
    private func anhMot(_ duong: String, canh: CGFloat) -> some View {
        if let url = URL(string: duong) {
            AsyncImage(url: url) { pha in
                switch pha {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        AppColors.backgroundTertiary
                        Image(systemName: "photo").foregroundColor(AppColors.textTertiary)
                    }
                default:
                    ZStack {
                        AppColors.backgroundTertiary
                        ProgressView().scaleEffect(0.7)
                    }
                }
            }
            .frame(width: canh, height: canh)
            .clipped()
            .cornerRadius(CornerRadius.medium)
        }
    }

    // MARK: Tệp không phải ảnh

    private func theTep(_ tep: MessageAttachment) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "doc.fill")
                .font(.system(size: 18))
                .foregroundColor(mauChu.opacity(0.9))
            VStack(alignment: .leading, spacing: 1) {
                Text(tep.fileName ?? "Tệp đính kèm")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(mauChu)
                    .lineLimit(1)
                if let n = tep.fileSize {
                    Text(Self.coChu(n))
                        .font(.system(size: 11))
                        .foregroundColor(mauChu.opacity(0.75))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(mauNen)
        .cornerRadius(CornerRadius.large)
        .onTapGesture { moTep(tep) }
    }

    private func moTep(_ tep: MessageAttachment) {
        guard let url = URL(string: tep.url) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private static func coChu(_ byte: Int) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(byte))
    }

    // MARK: Trích dẫn tin được trả lời

    private func traLoiTrichDan(_ cha: MessageParent) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(cha.senderName ?? "Tin nhắn")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
            Text((cha.content?.isEmpty ?? true) ? "Tin nhắn đã thu hồi" : (cha.content ?? ""))
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.backgroundTertiary.opacity(0.6))
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(AppColors.primary).frame(width: 2)
        }
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
    @Published var dangTaiThem = false
    @Published var dangGuiAnh = false
    /// Mốc người kia đã đọc tới. `nil` = chưa từng mở hội thoại.
    @Published var mocDocCuaNguoiKia: Date?
    @Published private(set) var localUnreadCount: Int = 0

    private var cursor: Int?

    /// Chèn tin nhận qua socket. Bỏ qua nếu đã có — tin do CHÍNH MÌNH gửi
    /// quay về qua socket sẽ trùng với bản đã thêm lạc quan lúc bấm Gửi.
    func chenTinMoi(_ tin: Message) {
        guard !messages.contains(where: { $0.id == tin.id }) else { return }
        messages.append(tin)
    }

    /// Số tin mỗi lượt. Máy chủ chặn trần ở 100.
    private static let moiLuot = 50

    func loadMessages() async {
        guard let threadId = thread?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // `/threads/:id/messages` trả MẢNG TRẦN, mới nhất trước, và KHÔNG
            // kèm con trỏ trang. Nhưng nó CÓ nhận `?cursor=` (máy chủ lọc
            // `id < cursor`), nên con trỏ phải tự suy ra từ id nhỏ nhất đang
            // giữ. Bản cũ đặt cứng `hasMore = false` vì tưởng máy chủ không
            // phân trang — thật ra có, chỉ là không trả con trỏ về.
            let response: (items: [Message], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(
                    .getMessages(threadId: threadId, cursor: nil, limit: Self.moiLuot)
                )
            messages = response.items.reversed()
            cursor = messages.first?.id
            hasMore = response.items.count >= Self.moiLuot
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadMoreMessages() async {
        guard let threadId = thread?.id, hasMore, !isLoading, !dangTaiThem,
              let cursor else { return }
        dangTaiThem = true
        defer { dangTaiThem = false }

        do {
            let response: (items: [Message], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(
                    .getMessages(threadId: threadId, cursor: cursor, limit: Self.moiLuot)
                )
            // Lọc trùng phòng khi có tin chen vào giữa hai lượt gọi.
            let daCo = Set(messages.map(\.id))
            let them = response.items.reversed().filter { !daCo.contains($0.id) }
            messages.insert(contentsOf: them, at: 0)
            self.cursor = messages.first?.id
            hasMore = response.items.count >= Self.moiLuot
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Gửi ảnh

    /// Tải ảnh lên rồi gửi kèm tin. Ảnh đi qua `POST /messages/upload` để lấy
    /// `fileId` — máy chủ nhận `fileIds: [Int]`, KHÔNG nhận URL.
    func guiAnh(_ duLieu: [(data: Data, ten: String, mime: String)], kem chu: String) async {
        guard let threadId = thread?.id, !duLieu.isEmpty else { return }
        dangGuiAnh = true
        defer { dangGuiAnh = false }

        do {
            var ids: [Int] = []
            for anh in duLieu {
                let ket = try await APIClient.shared.taiLenChat(
                    data: anh.data, fileName: anh.ten, mimeType: anh.mime
                )
                ids.append(ket.fileId)
            }
            let tin: Message = try await APIClient.shared.request(
                .sendMessageWithFiles(threadId: threadId, content: chu, fileIds: ids)
            )
            chenTinMoi(tin)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: "Đã xem"

    /// Mốc đọc của người kia. Tin nào gửi trước mốc này thì người ta đã xem.
    func taiMocDoc() async {
        guard let threadId = thread?.id else { return }
        guard let ds: [MocDoc] = try? await APIClient.shared
            .request(.getThreadReads(threadId: threadId)) else { return }
        let toi = AppState.shared.currentUser?.id
        mocDocCuaNguoiKia = ds.filter { $0.userId != toi }.compactMap(\.moc).max()
    }

    /// Socket `thread:read` bắn lúc người kia mở hội thoại — cập nhật ngay mà
    /// không phải gọi lại API.
    func capNhatMocDoc(_ moc: Date) {
        if let cu = mocDocCuaNguoiKia, cu >= moc { return }
        mocDocCuaNguoiKia = moc
    }

    /// Tin CUỐI CÙNG do mình gửi mà người kia đã đọc — chỉ vẽ "Đã xem" dưới
    /// đúng tin đó, như Messenger, thay vì gắn nhãn lên mọi tin.
    var tinCuoiDaXem: Int? {
        guard let moc = mocDocCuaNguoiKia, let toi = AppState.shared.currentUser?.id else { return nil }
        return messages.last(where: { $0.senderId == toi && ($0.ngayGio ?? .distantFuture) <= moc })?.id
    }

    func sendMessage(_ content: String) async {
        guard let threadId = thread?.id else { return }

        // Hiện ngay tin tạm rồi mới gọi máy chủ. Id âm để chắc chắn không đụng
        // id thật — bản cũ bốc số ngẫu nhiên trong 100000...999999, mà id thật
        // rơi vào đúng khoảng đó thì tin thật bị thay nhầm.
        let tempMessage = Message(
            id: -Int(Date().timeIntervalSince1970 * 1000) % 1_000_000_000,
            threadId: threadId,
            senderId: AppState.shared.currentUser?.id ?? 0,
            sender: AppState.shared.currentUser,
            content: content,
            mediaUrl: nil,
            mediaKind: nil,
            deleted: nil,
            recalled: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            attachments: nil,
            parentMessageId: nil,
            parentMessage: nil,
            hasAttachment: nil
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


// MARK: - Tách bớt cho trình biên dịch
//
// Thân `ChatView` từng dài tới mức `swiftc` bỏ cuộc: "unable to type-check this
// expression in reasonable time". Gộp chuỗi bộ điều chỉnh vào hai `ViewModifier`
// làm mỗi khối nhỏ lại đủ để suy kiểu.

private struct VongDoiChat: ViewModifier {
    let thread: MessageThread
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var realtime: RealtimeClient
    @Binding var messageText: String
    @Binding var thongBaoTat: String?

    func body(content: Content) -> some View {
        content
            .onAppear {
                viewModel.thread = thread
                AppState.shared.hoiThoaiDangMo = thread.id
                // Hội thoại vừa tạo chưa có trong danh sách máy chủ tự cho vào
                // lúc bắt tay, nên phải xin vào phòng.
                realtime.vaoPhong(threadId: thread.id)
                Task {
                    await viewModel.loadMessages()
                    // Mở hội thoại = đã đọc. Bản cũ có hàm `markAsRead()` nhưng
                    // KHÔNG chỗ nào gọi, nên huy hiệu chưa đọc không tắt.
                    await viewModel.markAsRead()
                    await viewModel.taiMocDoc()
                }
            }
            // Tin mới đẩy thẳng vào danh sách, không hỏi lại API.
            .onReceive(realtime.tinMoi) { su in
                guard su.threadId == thread.id else { return }
                viewModel.chenTinMoi(su.message)
                // Đang mở hội thoại mà tin tới thì coi như đọc luôn, không thì
                // huy hiệu chưa đọc nhảy lên ngay trước mắt người đang đọc.
                Task { await viewModel.markAsRead() }
            }
            // Người kia mở hội thoại → dời mốc "Đã xem" ngay.
            .onReceive(realtime.daDoc) { su in
                guard su.threadId == thread.id,
                      su.readerId != AppState.shared.currentUser?.id else { return }
                viewModel.capNhatMocDoc(su.readAt)
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
                Task { await viewModel.markAsRead() }
            }
            .alert("Hội thoại", isPresented: .constant(thongBaoTat != nil)) {
                Button("OK") { thongBaoTat = nil }
            } message: {
                Text(thongBaoTat ?? "")
            }
    }
}

private struct DinhKemChat: ViewModifier {
    @Binding var hienChonTep: Bool
    let guiTep: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $hienChonTep, allowedContentTypes: [.item]) { kq in
                guiTep(kq)
            }
    }
}
