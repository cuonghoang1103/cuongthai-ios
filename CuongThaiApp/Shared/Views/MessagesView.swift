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
            // Đổi biệt danh trong khung chat phải hiện NGAY ở danh sách.
            // Máy chủ không phát sự kiện nào cho biệt danh (nó chỉ người xem
            // thấy), nên đường duy nhất là kênh nội bộ này.
            .onReceive(AppState.shared.bietDanhDoi) { su in
                guard let i = viewModel.threads.firstIndex(where: { $0.id == su.threadId })
                else { return }
                viewModel.threads[i] = viewModel.threads[i].doiBietDanh(su.ten)
            }
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
                        // ⚠️ Ép LÀM MỚI Ô: dữ liệu đã tươi và body đã chạy
                        // lại (nhật ký VẼ ghi rõ "mày" lúc 04:11:04.901) mà
                        // điểm ảnh trên máy vẫn là tin cũ (ảnh người dùng chụp
                        // sau đó vài giây còn "ok"). Trói danh tính ô vào đúng
                        // những gì mắt phải thấy — tin cuối, số chưa đọc, ghim,
                        // chuông — để ô BẮT BUỘC dựng lại khi chúng đổi.
                        .id("\(thread.id)-\(thread.lastMessage?.id ?? 0)-\(thread.unreadCount)-\(thread.daGhim ? 1 : 0)-\(thread.daTatThongBao ? 1 : 0)")
                        .listRowInsets(EdgeInsets())
                        // Vạch ngăn dùng của List, thụt vào cho thẳng mép chữ.
                        // Tự thêm `Divider()` vào ForEach là sai: trong List nó
                        // thành MỘT HÀNG riêng, ăn nguyên chiều cao một hàng.
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(AppColors.divider)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 76 }
                        .listRowBackground(AppColors.backgroundPrimary)
                        // Nhấn giữ kiểu Messenger: nền mờ + XEM TRƯỚC cuộc trò
                        // chuyện + menu. `.contextMenu(menuItems:preview:)` cho
                        // đúng hiệu ứng đó bằng đường của hệ thống — dựng tay
                        // thì phải tự lo nền mờ, hoạt ảnh và cử chỉ, mà kết quả
                        // vẫn khác iOS thật.
                        .contextMenu {
                            Button {
                                Task { await viewModel.danhDauChuaDoc(thread) }
                            } label: {
                                Label("Đánh dấu là chưa đọc", systemImage: "envelope.badge")
                            }
                            Button {
                                Task { await viewModel.doiGhim(thread) }
                            } label: {
                                Label(thread.daGhim ? "Bỏ ghim" : "Ghim",
                                      systemImage: thread.daGhim ? "pin.slash" : "pin")
                            }
                            Button {
                                Task { await viewModel.doiTatThongBao(thread, phut: thread.daTatThongBao ? nil : 60 * 8) }
                            } label: {
                                Label(thread.daTatThongBao ? "Bật thông báo" : "Tắt thông báo",
                                      systemImage: thread.daTatThongBao ? "bell" : "bell.slash")
                            }
                            Button {
                                Task { await viewModel.doiLuuTru(thread) }
                            } label: {
                                Label(thread.daLuuTru ? "Bỏ lưu trữ" : "Lưu trữ",
                                      systemImage: thread.daLuuTru ? "tray.and.arrow.up" : "archivebox")
                            }
                            Divider()
                            Button(role: .destructive) {
                                Task { await viewModel.xoaHoiThoai(thread) }
                            } label: {
                                Label("Xoá", systemImage: "trash")
                            }
                        } preview: {
                            XemTruocHoiThoai(thread: thread)
                        }
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
        NhatKy.thongBao.info("cần mở hội thoại \(id) — có trong danh sách: \(viewModel.threads.contains { $0.id == id })")
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
    /// ⚠️ Trước 17/09/2026 chỗ này là `@State private var isOnline = false` —
    /// khai ra, đọc đúng một lần ở dưới, và KHÔNG CHỖ NÀO GÁN. Chấm xanh vì
    /// thế chưa từng hiện một lần nào kể từ khi viết. Dữ liệu thật vẫn về đều
    /// qua `RealtimeClient.truyenTuyen`, chỉ là không ai đọc.
    @ObservedObject private var realtime = RealtimeClient.shared

    /// Socket lo phần REALTIME, `lastActiveAt` lo phần VỪA MỞ APP — lúc đó
    /// chưa có `presence:update` nào bay tới nên socket còn rỗng.
    private var trangThai: TrangThaiHoatDong.KetQua {
        let id = thread.peer?.id
        return TrangThaiHoatDong.tinh(
            mocHoatDong: TrangThaiHoatDong.docMoc(thread.peer?.lastActiveAt),
            socketBaoOnline: id.map { realtime.truyenTuyen.contains($0) } ?? false)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                UserAvatarView(url: thread.avatarUrl, size: 56)

                if thread.laNhanRieng && trangThai.trucTuyen {
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

    /// Danh tính để đối chiếu: bản nghe socket có PHẢI bản đang vẽ không.
    /// Kết quả lọc gần nhất — chỉ để nhật ký đọc được thứ ĐÃ vẽ.
    private var ketQuaCuoi: [MessageThread] = []

    var maSo: String { String(UInt(bitPattern: ObjectIdentifier(self).hashValue) % 10000) }

    init() {
        ngheSocket()
        NhatKy.tinNhan.info("TẠO ViewModel #\(maSo)")
    }

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
            .sink { [weak self] su in
                NhatKy.tinNhan.info("socket giao tin mới cho hội thoại \(su.threadId)")
                self?.apTinMoi(su.threadId, su.message)
            }
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
        NhatKy.tinNhan.info("apTinMoi ở VM #\(maSo): \(self.threads.count) hàng")
        guard let i = threads.firstIndex(where: { $0.id == threadId }) else {
            NhatKy.tinNhan.info("  → KHÔNG thấy hội thoại \(threadId) trong danh sách, tải lại")
            // Hội thoại CHƯA có trong danh sách — người lạ nhắn lần đầu. Chỉ
            // lúc này mới cần gọi mạng; cập nhật tại chỗ lo hết phần còn lại.
            Task { await loadThreads() }
            return
        }
        // Máy chủ phát MỖI TIN HAI LẦN (đo thật trong nhật ký: mọi tin đều về
        // đúng 2 lượt cách nhau 12-25ms — phòng thread + phòng user). Không
        // chặn thì unreadCount cộng ĐÔI và mỗi tin gây HAI lượt remove/insert
        // sát nhau — đúng loại nhiễu làm bộ diff của List bỏ qua cập nhật.
        if threads[i].lastMessage?.id == tin.id {
            NhatKy.tinNhan.info("tin \(tin.id) lặp lần 2 — bỏ")
            return
        }
        let cuaMinh = tin.senderId == AppState.shared.currentUser?.id
        let dangMo = AppState.shared.hoiThoaiDangMo == threadId
        let hang = threads[i].voiTinMoi(tin, tangChuaDoc: !cuaMinh && !dangMo)
        NhatKy.tinNhan.info("  → cập nhật hàng \(i): \(hang.lastMessage?.content ?? "(rỗng)")")
        threads.remove(at: i)
        // Đưa lên đầu, nhưng KHÔNG vượt mấy hàng đã ghim — ghim mà bị tin mới
        // đẩy xuống thì cái ghim vô nghĩa.
        threads.insert(hang, at: viTriChen(daGhimTheoThuTu: threads.map(\.daGhim),
                                          hangDuocGhim: hang.daGhim))
    }

    func loadThreads() async {
        NhatKy.tinNhan.info("loadThreads() gọi mạng…")
        isLoading = true
        error = nil
        cursor = nil

        do {
            let response: (items: [MessageThread], nextCursor: Int?, hasMore: Bool) = try await APIClient.shared.requestList(
                .getThreads(cursor: nil, limit: 20)
            )
            threads = response.items
            NhatKy.tinNhan.info("loadThreads xong: \(response.items.count) hàng · đầu = \(response.items.first?.lastMessage?.content ?? "(rỗng)")")
            cursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            NhatKy.tinNhan.error("thao tác HỎNG: \(error.localizedDescription)")
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
            NhatKy.tinNhan.error("thao tác HỎNG: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    func filteredThreads(searchQuery: String) -> [MessageThread] {
        defer {
            // In ĐÚNG thứ sắp hiện lên màn hình. Nếu dòng này nói "hả" mà mắt
            // vẫn thấy tin cũ, thì lỗi nằm ở tầng vẽ chứ không ở dữ liệu.
            let dau = ketQuaCuoi.first
            NhatKy.tinNhan.info("VẼ #\(maSo): \(ketQuaCuoi.count) hàng · đầu = \(dau?.displayName ?? "—") / \(dau?.lastMessage?.content ?? "(rỗng)")")
        }
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
        ketQuaCuoi = filtered
        return filtered.sorted { a, b in
            a.daGhim && !b.daGhim
        }
    }

    // MARK: Ghim / lưu trữ / đánh dấu chưa đọc

    /// Đổi tại chỗ TRƯỚC rồi mới gọi mạng: vuốt xong mà hàng đứng im nửa giây
    /// thì người dùng vuốt lại lần nữa và bật-tắt hai lần.
    /// Xoá hội thoại cho riêng mình. Bỏ khỏi màn hình NGAY rồi mới gọi mạng —
    /// chờ mạng xong mới xoá thì hàng nằm đó vài trăm ms và người dùng bấm lần nữa.
    func xoaHoiThoai(_ t: MessageThread) async {
        let luu = threads
        threads.removeAll { $0.id == t.id }
        do {
            try await APIClient.shared.send(.xoaHoiThoai(threadId: t.id))
        } catch {
            threads = luu
            self.error = "Không xoá được: \(error.localizedDescription)"
        }
    }

    private func capNhat(_ threadId: Int, _ moi: ThreadPreferences?) {
        guard let i = threads.firstIndex(where: { $0.id == threadId }) else { return }
        threads[i] = threads[i].doiTuyChon(moi)
    }

    func doiGhim(_ t: MessageThread) async {
        NhatKy.tinNhan.info("BẤM doiGhim — hội thoại \(t.id)")
        let cu = t.preferences
        let moc = t.daGhim ? nil : ISO8601DateFormatter().string(from: Date())
        capNhat(t.id, (cu ?? ThreadPreferences()).dat(\.pinnedAt, moc))
        do {
            let _: TuyChonBoc = try await APIClient.shared
                .request(.datTuyChonHoiThoai(threadId: t.id, slot: "pinnedAt", value: moc))
        } catch {
            capNhat(t.id, cu)
            NhatKy.tinNhan.error("thao tác HỎNG: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    func doiLuuTru(_ t: MessageThread) async {
        NhatKy.tinNhan.info("BẤM doiLuuTru — hội thoại \(t.id)")
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
            NhatKy.tinNhan.error("thao tác HỎNG: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    func danhDauChuaDoc(_ t: MessageThread) async {
        NhatKy.tinNhan.info("BẤM danhDauChuaDoc — hội thoại \(t.id)")
        let cu = t.preferences
        capNhat(t.id, (cu ?? ThreadPreferences())
            .dat(\.markedUnreadAt, ISO8601DateFormatter().string(from: Date())))
        do {
            let _: EmptyResponse = try await APIClient.shared.request(.danhDauChuaDoc(threadId: t.id))
        } catch {
            capNhat(t.id, cu)
            NhatKy.tinNhan.error("thao tác HỎNG: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    func doiTatThongBao(_ t: MessageThread, phut: Int?) async {
        NhatKy.tinNhan.info("BẤM doiTatThongBao — hội thoại \(t.id)")
        let cu = t.preferences
        let moc = phut.map { ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double($0) * 60)) }
        capNhat(t.id, (cu ?? ThreadPreferences()).dat(\.mutedUntil, moc))
        do {
            let _: TuyChonBoc = try await APIClient.shared
                .request(.datTuyChonHoiThoai(threadId: t.id, slot: "mutedUntil", value: moc))
        } catch {
            capNhat(t.id, cu)
            NhatKy.tinNhan.error("thao tác HỎNG: \(error.localizedDescription)")
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
                                    Text(user.ten)
                                        .font(.titleSmall)
                                        .foregroundColor(AppColors.textPrimary)

                                    Text("@\(user.username ?? "")")
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
    private func moHoiThoai(voi user: NguoiTK) async {
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
    @Published var users: [NguoiTK] = []
    /// Lỗi khi tìm người. Bản cũ nuốt im lặng nên hỏng mà không ai biết.
    @Published var loiTim: String?
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
                // ⚠️ `/users/search` trả về MẢNG PHẲNG (`MentionSuggestion[]`),
                // KHÔNG phải `{users: […]}`. Bản cũ giải mã sai hình dạng nên
                // luôn ném lỗi — và ngay bên dưới lại nuốt lỗi im lặng, nên ô
                // tìm người để nhắn tin CHƯA TỪNG trả về ai, mà không có dấu
                // hiệu gì. Sửa 09/09/2026 cùng lúc với màn Tìm kiếm.
                let ds: [NguoiTK] = try await APIClient.shared.request(
                    .searchUsers(q: searchQuery)
                )
                guard !Task.isCancelled else { return }
                users = ds
            } catch {
                guard !Task.isCancelled else { return }
                users = []
                loiTim = (error as NSError).localizedDescription
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
                NhatKy.socket.info("trạng thái socket: \(cu.rawValue) → \(moi.rawValue)")
                guard cu != .daNoi, moi == .daNoi else { return }
                NhatKy.tinNhan.info("socket nối lại ⇒ tải lại danh sách")
                Task { await viewModel.loadThreads() }
            }
            .onChange(of: scenePhase) { _, giaiDoan in
                NhatKy.tinNhan.info("app chuyển sang: \(String(describing: giaiDoan))")
                guard giaiDoan == .active else { return }
                Task {
                    await viewModel.loadThreads()
                    moHoiThoai()
                }
            }
    }
}


/// Xem trước cuộc trò chuyện khi nhấn giữ — phần nội dung của
/// `.contextMenu(preview:)`.
///
/// Cố ý KHÔNG gọi mạng: xem trước phải hiện ngay lập tức, mà dữ liệu đã có sẵn
/// trong hàng rồi (người kia, tin cuối, thời điểm). Tải thêm chỉ để lấp đầy
/// khung thì người dùng nhìn thấy ô trống trong lúc chờ.
struct XemTruocHoiThoai: View {
    let thread: MessageThread

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                UserAvatarView(url: thread.peer?.avatarUrl, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    if thread.daTatThongBao {
                        Label("Đã tắt thông báo", systemImage: "bell.slash.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                Spacer(minLength: 0)
                if thread.daGhim {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColors.backgroundSecondary)

            Divider()

            if let tin = thread.lastMessage {
                // `Message` không có sẵn cờ "của tôi" — so người gửi, đúng cách
                // các màn khác trong app đang làm.
                let cuaToi = tin.senderId == AppState.shared.currentUser?.id
                HStack(alignment: .bottom, spacing: 8) {
                    if !cuaToi { UserAvatarView(url: thread.peer?.avatarUrl, size: 26) }
                    Text(tin.xemTruoc)
                        .font(.system(size: 14.5))
                        .foregroundColor(cuaToi ? AppColors.onPrimary : AppColors.textPrimary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(cuaToi ? AppColors.primary : AppColors.backgroundTertiary)
                        )
                        .frame(maxWidth: 230, alignment: cuaToi ? .trailing : .leading)
                    if cuaToi { Spacer(minLength: 0) } 
                }
                .frame(maxWidth: .infinity, alignment: cuaToi ? .trailing : .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            } else {
                Text("Chưa có tin nhắn")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.vertical, 24)
            }
        }
        .frame(width: 300)
        .background(AppColors.backgroundPrimary)
    }
}
