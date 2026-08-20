import SwiftUI
import Combine

// MARK: - Messages View
struct MessagesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = MessagesViewModel()
    @State private var searchQuery = ""
    @State private var hoiThoaiMoTuThongBao: MessageThread?
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
            // ⚠️ Mọi thao tác vuốt (ghim/lưu trữ/chưa đọc/tắt báo) đều hoàn
            // tác thay đổi rồi đặt `viewModel.error` khi hỏng — mà TRƯỚC BẢN
            // NÀY không chỗ nào hiện nó ra. Hàng bật về như cũ, không một chữ
            // giải thích, nên người dùng thấy đúng là "nút không hoạt động".
            .alert("Không thực hiện được",
                   isPresented: Binding(get: { viewModel.error != nil },
                                        set: { if !$0 { viewModel.error = nil } })) {
                Button("OK") { viewModel.error = nil }
            } message: { Text(viewModel.error ?? "") }
            .onAppear {
                Task {
                    await viewModel.loadThreads()
                    // ⚠️ `onChange` bên dưới CHỈ bắt thay đổi. Chạm thông báo
                    // lúc app đang tắt thì `hoiThoaiCanMo` đã được đặt TRƯỚC
                    // khi màn này kịp dựng — không có "thay đổi" nào để bắt,
                    // nên app chỉ mở tab Tin nhắn rồi đứng đó. Phải kiểm lại
                    // một lần ngay khi xuất hiện.
                    moHoiThoaiDangCho()
                }
            }
            .modifier(LamMoiKhiCanThiet(viewModel: viewModel, moHoiThoai: moHoiThoaiDangCho))
            // Chạm vào thông báo đẩy → mở thẳng hội thoại đó. Không có đoạn
            // này thì chạm xong chỉ nhảy vào tab Tin nhắn rồi đứng ở danh
            // sách, người dùng phải tự đi tìm.
            .onChange(of: AppState.shared.hoiThoaiCanMo) { _, id in
                guard let id else { return }
                Task {
                    if viewModel.threads.isEmpty { await viewModel.loadThreads() }
                    hoiThoaiMoTuThongBao = viewModel.threads.first { $0.id == id }
                    // Xoá NGAY sau khi dùng — không xoá thì lần sau vào tab
                    // này nó tự mở lại hội thoại cũ.
                    AppState.shared.hoiThoaiCanMo = nil
                }
            }
            .navigationDestination(item: $hoiThoaiMoTuThongBao) { t in
                ChatView(thread: t)
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
        VStack(spacing: 0) {
            // Hàng tin ở TRÊN danh sách, ngoài List — để trong List thì nó cuộn
            // ngang bên trong một hàng và dính luôn cả thao tác vuốt của hàng đó.
            HangTinView()
            Divider().background(AppColors.divider)
            noiDungDanhSach
        }
    }

    private var noiDungDanhSach: some View {
        Group {
            if viewModel.isLoading && viewModel.threads.isEmpty {
                loadingView
            } else if viewModel.filteredThreads(searchQuery: searchQuery).isEmpty {
                emptyStateView
            } else {
                // Phải là `List` chứ không phải `LazyVStack`: `.swipeActions`
                // chỉ có tác dụng trong List. Bỏ hết trang trí mặc định của
                // List để nhìn y như danh sách cũ.
                List {
                    ForEach(viewModel.filteredThreads(searchQuery: searchQuery)) { thread in
                        ZStack {
                            NavigationLink(destination: ChatView(thread: thread)) {
                                EmptyView()
                            }
                            .opacity(0)

                            ThreadRow(thread: thread)
                        }
                        .listRowInsets(EdgeInsets())
                        // Vạch ngăn dùng của List, thụt vào cho thẳng mép chữ.
                        // Tự thêm `Divider()` vào ForEach là sai: trong List nó
                        // thành MỘT HÀNG riêng, ăn nguyên chiều cao một hàng.
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(AppColors.divider)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 76 }
                        .listRowBackground(AppColors.backgroundPrimary)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Haptics.cham()
                                Task { await viewModel.doiGhim(thread) }
                            } label: {
                                Label(thread.daGhim ? "Bỏ ghim" : "Ghim",
                                      systemImage: thread.daGhim ? "pin.slash.fill" : "pin.fill")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                Haptics.cham()
                                Task { await viewModel.doiLuuTru(thread) }
                            } label: {
                                Label(thread.daLuuTru ? "Bỏ lưu trữ" : "Lưu trữ",
                                      systemImage: thread.daLuuTru ? "tray.and.arrow.up" : "archivebox.fill")
                            }
                            .tint(.purple)

                            Button {
                                Haptics.cham()
                                Task { await viewModel.danhDauChuaDoc(thread) }
                            } label: {
                                Label("Chưa đọc", systemImage: "envelope.badge.fill")
                            }
                            .tint(AppColors.primary)

                            Button {
                                Haptics.cham()
                                Task { await viewModel.doiTatThongBao(thread, phut: thread.daTatThongBao ? nil : 60 * 8) }
                            } label: {
                                Label(thread.daTatThongBao ? "Bật báo" : "Tắt báo",
                                      systemImage: thread.daTatThongBao ? "bell.fill" : "bell.slash.fill")
                            }
                            .tint(.gray)
                        }
                    }

                    if viewModel.hasMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .listRowSeparator(.hidden)
                            .listRowBackground(AppColors.backgroundPrimary)
                            .onAppear {
                                Task { await viewModel.loadMoreThreads() }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppColors.backgroundPrimary)
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

    /// Mở hội thoại mà thông báo đẩy đã chỉ định, nếu có.
    private func moHoiThoaiDangCho() {
        guard let id = AppState.shared.hoiThoaiCanMo else { return }
        hoiThoaiMoTuThongBao = viewModel.threads.first { $0.id == id }
        // Chỉ xoá khi ĐÃ tìm thấy — xoá sớm thì lần tải sau không còn gì để mở.
        if hoiThoaiMoTuThongBao != nil { AppState.shared.hoiThoaiCanMo = nil }
    }
}

// MARK: - Message Filter
enum MessageFilter: String, CaseIterable {
    case all = "Tất cả"
    case unread = "Chưa đọc"
    case pinned = "Đã ghim"
    case personal = "Cá nhân"
    case support = "Hỗ trợ"
    case archived = "Lưu trữ"

    var icon: String {
        switch self {
        case .all: return "tray"
        case .unread: return "envelope.badge"
        case .pinned: return "pin.fill"
        case .support: return "lifepreserver"
        case .archived: return "archivebox"
        case .personal: return "person"
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

                if thread.laNhanRieng && isOnline {
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
                HStack(spacing: 5) {
                    // Ghim / tắt báo / lưu trữ phải THẤY ĐƯỢC trên hàng. Vuốt
                    // xong mà hàng không đổi gì thì người dùng tưởng nút không
                    // ăn và vuốt lại lần nữa — tức bật rồi tắt.
                    if thread.daGhim {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    Text(thread.displayName)
                        .font(.titleSmall)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    if thread.daTatThongBao {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    if thread.daLuuTru {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                    }

                    Spacer(minLength: 4)

                    if let lastMessage = thread.lastMessage {
                        Text(TimeFormatter.formatTimeAgo(lastMessage.createdAt))
                            .font(.caption)
                            .foregroundColor(thread.chuaDoc ? AppColors.primary : AppColors.textTertiary)
                    }
                }

                HStack {
                    if let lastMessage = thread.lastMessage {
                        Text(lastMessage.xemTruoc)
                            .font(.bodyMedium)
                            .foregroundColor(thread.chuaDoc ? AppColors.textPrimary : AppColors.textSecondary)
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
                    } else if thread.chuaDoc {
                        // Tự đánh dấu chưa đọc: không có số nào để hiện, nhưng
                        // vẫn phải có chấm, không thì thao tác đó vô hình.
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(thread.chuaDoc ? AppColors.primary.opacity(0.05) : Color.clear)
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
    private var huyDangKy = Set<AnyCancellable>()

    init() { ngheSocket() }

    /// Nghe tin mới và cập nhật NGAY hàng tương ứng.
    ///
    /// ⚠️ Trước bản này danh sách chỉ tải lại ở `onAppear` và khi kéo xuống,
    /// nên đang đứng sẵn ở màn này thì KHÔNG gì làm mới nó: bạn bè nhắn tới,
    /// khung chat bên trong hiện ngay (nó tự nghe socket) còn hàng ngoài này
    /// vẫn là tin cũ tới khi rời tab rồi quay lại. `AppState` cũng nghe cùng
    /// sự kiện đó nhưng chỉ để CỘNG HUY HIỆU — nên tab hiện số mới ngay trong
    /// khi dòng chữ bên dưới vẫn cũ, đúng thứ người dùng thấy.
    private func ngheSocket() {
        RealtimeClient.shared.tinMoi
            .receive(on: DispatchQueue.main)
            .sink { [weak self] su in self?.apTinMoi(su.threadId, su.message) }
            .store(in: &huyDangKy)

        // Đọc ở máy khác thì dấu chưa đọc ở đây phải tắt theo.
        RealtimeClient.shared.daDoc
            .receive(on: DispatchQueue.main)
            .sink { [weak self] su in
                guard let self,
                      su.readerId == AppState.shared.currentUser?.id,
                      let i = self.threads.firstIndex(where: { $0.id == su.threadId })
                else { return }
                self.threads[i] = self.threads[i].daDocHet()
            }
            .store(in: &huyDangKy)
    }

    private func apTinMoi(_ threadId: Int, _ tin: Message) {
        guard let i = threads.firstIndex(where: { $0.id == threadId }) else {
            // Hội thoại CHƯA có trong danh sách — người lạ nhắn lần đầu. Chỉ
            // lúc này mới cần gọi mạng; cập nhật tại chỗ lo hết phần còn lại.
            Task { await loadThreads() }
            return
        }
        let cuaMinh = tin.senderId == AppState.shared.currentUser?.id
        let dangMo = AppState.shared.hoiThoaiDangMo == threadId
        let hang = threads[i].voiTinMoi(tin, tangChuaDoc: !cuaMinh && !dangMo)
        threads.remove(at: i)
        // Đưa lên đầu, nhưng KHÔNG vượt mấy hàng đã ghim — ghim mà bị tin mới
        // đẩy xuống thì cái ghim vô nghĩa.
        threads.insert(hang, at: viTriChen(daGhimTheoThuTu: threads.map(\.daGhim),
                                          hangDuocGhim: hang.daGhim))
    }

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

        // ⚠️ Máy chủ KHÔNG tự giấu hội thoại đã lưu trữ: `listThreadsForUser`
        // chỉ lọc theo `deletedAt`, còn `archivedAt` thì vẫn trả về. Nên mọi
        // tab TRỪ "Lưu trữ" phải tự bỏ chúng ra, không thì lưu trữ xong nó
        // vẫn nằm nguyên chỗ cũ và người dùng tưởng nút không ăn.
        if selectedFilter != .archived {
            filtered = filtered.filter { !$0.daLuuTru }
        }

        switch selectedFilter {
        case .all:
            break
        case .unread:
            filtered = filtered.filter { $0.chuaDoc }
        case .pinned:
            filtered = filtered.filter { $0.daGhim }
        case .personal:
            // `USER` / `ADMIN` — KHÔNG phải "direct"/"group". Bản cũ lọc bằng
            // hai chuỗi không tồn tại nên cả hai tab luôn RỖNG. Và máy chủ
            // không có hội thoại nhóm nào cả, nên chip "Nhóm" đã bỏ.
            filtered = filtered.filter { $0.laNhanRieng }
        case .support:
            filtered = filtered.filter { $0.laHoTro }
        case .archived:
            filtered = filtered.filter { $0.daLuuTru }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            filtered = filtered.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
                ($0.lastMessage?.xemTruoc.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }

        // Hội thoại đã ghim luôn nổi lên đầu, giữ nguyên thứ tự thời gian
        // trong từng nhóm — `sorted` của Swift ổn định nên chỉ cần một khoá.
        return filtered.sorted { a, b in
            a.daGhim && !b.daGhim
        }
    }

    // MARK: Ghim / lưu trữ / đánh dấu chưa đọc

    /// Đổi tại chỗ TRƯỚC rồi mới gọi mạng: vuốt xong mà hàng đứng im nửa giây
    /// thì người dùng vuốt lại lần nữa và bật-tắt hai lần.
    private func capNhat(_ threadId: Int, _ moi: ThreadPreferences?) {
        guard let i = threads.firstIndex(where: { $0.id == threadId }) else { return }
        threads[i] = threads[i].doiTuyChon(moi)
    }

    func doiGhim(_ t: MessageThread) async {
        let cu = t.preferences
        let moc = t.daGhim ? nil : ISO8601DateFormatter().string(from: Date())
        capNhat(t.id, (cu ?? ThreadPreferences()).dat(\.pinnedAt, moc))
        do {
            let _: TuyChonBoc = try await APIClient.shared
                .request(.datTuyChonHoiThoai(threadId: t.id, slot: "pinnedAt", value: moc))
        } catch {
            capNhat(t.id, cu)
            self.error = error.localizedDescription
        }
    }

    func doiLuuTru(_ t: MessageThread) async {
        let cu = t.preferences
        let dangLuu = t.daLuuTru
        let moc = dangLuu ? nil : ISO8601DateFormatter().string(from: Date())
        capNhat(t.id, (cu ?? ThreadPreferences()).dat(\.archivedAt, moc))
        do {
            if dangLuu {
                // Bỏ lưu trữ có route RIÊNG vì nó còn xoá cả `deletedAt` —
                // đặt `archivedAt = null` qua /preference thì hội thoại từng
                // bị "xoá cho riêng tôi" vẫn không quay lại hộp thư.
                let _: EmptyResponse = try await APIClient.shared.request(.boLuuTruHoiThoai(threadId: t.id))
            } else {
                let _: TuyChonBoc = try await APIClient.shared
                    .request(.datTuyChonHoiThoai(threadId: t.id, slot: "archivedAt", value: moc))
            }
        } catch {
            capNhat(t.id, cu)
            self.error = error.localizedDescription
        }
    }

    func danhDauChuaDoc(_ t: MessageThread) async {
        let cu = t.preferences
        capNhat(t.id, (cu ?? ThreadPreferences())
            .dat(\.markedUnreadAt, ISO8601DateFormatter().string(from: Date())))
        do {
            let _: EmptyResponse = try await APIClient.shared.request(.danhDauChuaDoc(threadId: t.id))
        } catch {
            capNhat(t.id, cu)
            self.error = error.localizedDescription
        }
    }

    func doiTatThongBao(_ t: MessageThread, phut: Int?) async {
        let cu = t.preferences
        let moc = phut.map { ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double($0) * 60)) }
        capNhat(t.id, (cu ?? ThreadPreferences()).dat(\.mutedUntil, moc))
        do {
            let _: TuyChonBoc = try await APIClient.shared
                .request(.datTuyChonHoiThoai(threadId: t.id, slot: "mutedUntil", value: moc))
        } catch {
            capNhat(t.id, cu)
            self.error = error.localizedDescription
        }
    }
}

/// `PATCH /threads/:id/preference` trả `{ preferences: {...} }`, không trả
/// thẳng bộ tuỳ chọn — phải bóc một lớp.
struct TuyChonBoc: Decodable {
    let preferences: ThreadPreferences?
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


/// Ba lưới đỡ cho danh sách hội thoại, gom lại một chỗ.
///
/// Tách khỏi `body` vì gộp thẳng vào đó làm trình biên dịch bỏ cuộc
/// ("unable to type-check this expression in reasonable time") — `body` của
/// màn này vốn đã dài.
///
/// Cập nhật tại chỗ qua socket vẫn là đường CHÍNH; ba cái dưới đây chỉ lo
/// những khoảng mà socket không thể phủ:
///   • socket vừa nối lại  → mọi sự kiện lúc đứt đã mất hẳn
///   • app quay lại từ nền → lúc ở nền socket đóng, tin tới qua push
struct LamMoiKhiCanThiet: ViewModifier {
    @ObservedObject var viewModel: MessagesViewModel
    let moHoiThoai: () -> Void
    @ObservedObject private var realtime = RealtimeClient.shared
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: realtime.trangThai) { cu, moi in
                guard cu != .daNoi, moi == .daNoi else { return }
                Task { await viewModel.loadThreads() }
            }
            .onChange(of: scenePhase) { _, giaiDoan in
                guard giaiDoan == .active else { return }
                Task {
                    await viewModel.loadThreads()
                    moHoiThoai()
                }
            }
    }
}
