import SwiftUI
import Combine

// MARK: - Home View Model
@MainActor
class HomeViewModel: ObservableObject {
    @Published var posts: [SocialPost] = []

    /// Bỏ một bài khỏi danh sách đang hiện — gọi sau khi xoá bài trên máy chủ.
    func boBaiKhoiDanhSach(_ id: Int) {
        posts.removeAll { $0.id == id }
    }
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    /// Số bài mỗi tab, để hiện lên chip. Đã trừ bài của các loạt — cùng cờ với
    /// lúc gọi bảng tin, không thì chip ghi 145 mà cuộn ra 10 bài là hết.
    @Published var soBai: [String: Int] = [:]
    private var cursor: Int?
    private var hasMore = true

    /// Bảng tin chung KHÔNG chứa bài của ba loạt 100 ngày — chúng có mục Học tập
    /// riêng. Đo 20/08/2026: 135 trong 145 bài là bài loạt, để nguyên thì mở
    /// bảng tin ra gần như chỉ thấy bài học.
    private let boQuaLoat = true

    func loadFeed(type: String? = nil) async {
        isLoading = true
        error = nil
        do {
            let res: (items: [SocialPost], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(
                    .getFeed(cursor: nil, limit: 20, type: type, videoCategoryId: nil,
                             hashtag: nil, excludeSeries: boQuaLoat)
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
            let res: (items: [SocialPost], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(
                    .getFeed(cursor: cursor, limit: 20, type: type, videoCategoryId: nil,
                             hashtag: nil, excludeSeries: boQuaLoat)
                )
            // Lọc trùng: bài mới chen vào giữa hai lần gọi đẩy trang sau lệch
            // một dòng, và dòng đó hiện hai lần.
            let daCo = Set(posts.map(\.id))
            posts.append(contentsOf: res.items.filter { !daCo.contains($0.id) })
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

    /// Số đếm hỏng thì chip chỉ mất con số, bảng tin vẫn chạy — nên nuốt lỗi ở
    /// đây thay vì để nó che cả màn hình.
    func taiSoBai() async {
        guard let d: [String: Int] = try? await APIClient.shared
            .request(.getPostCounts(excludeSeries: boQuaLoat)) else { return }
        soBai = d
    }
}

// MARK: - Home View
struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @ObservedObject private var moderation = ModerationStore.shared
    @EnvironmentObject private var appState: AppState
    @State private var quickSheet: QuickSheet?
    /// Bấm "Bình luận" mở đúng bài đó — dùng đích điều hướng riêng thay vì
    /// lồng NavigationLink trong NavigationLink.
    @State private var baiMoBinhLuan: SocialPost?

    // One `.sheet(item:)` rather than two `.sheet(isPresented:)` — SwiftUI
    // only honours the last presentation modifier attached to a view.
    enum QuickSheet: String, Identifiable {
        case search, notes, notifications, ai
        var id: String { rawValue }
    }
    @State private var tabDangChon: TabTrangChu = .tatCa

    /// Năm mục của Trang chủ. "Học tập" KHÔNG phải một bộ lọc của bảng tin —
    /// nó là một màn khác hẳn, nên để chung một enum thay vì một `String?` type
    /// cộng thêm cờ; kiểu cũ đã có lúc để lọt trạng thái "type=nil mà đang ở
    /// Học tập" và hiện nhầm bảng tin.
    enum TabTrangChu: String, CaseIterable, Identifiable {
        case tatCa, hocTap, baiViet, video, file
        var id: String { rawValue }

        var ten: String {
            switch self {
            case .tatCa: return "Tất cả"
            case .hocTap: return "Học tập"
            case .baiViet: return "Bài viết"
            case .video: return "Video"
            case .file: return "File"
            }
        }

        var bieuTuong: String {
            switch self {
            case .tatCa: return "square.stack"
            case .hocTap: return "graduationcap.fill"
            case .baiViet: return "doc.text"
            case .video: return "play.rectangle"
            case .file: return "paperclip"
            }
        }

        /// `type` gửi lên API. `nil` = mọi loại. Học tập không gọi bảng tin.
        var loaiAPI: String? {
            switch self {
            case .baiViet: return "POST"
            case .video: return "VIDEO"
            case .file: return "FILE"
            case .tatCa, .hocTap: return nil
            }
        }

        /// Khoá trong `soBai` trả về từ `/posts/counts`.
        var khoaDem: String? {
            switch self {
            case .tatCa: return "all"
            case .baiViet: return "post"
            case .video: return "video"
            case .file: return "file"
            case .hocTap: return nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    filterBar
                    if tabDangChon == .hocTap {
                        HocTapView()
                    } else {
                        feedContent
                    }
                }
            }
            // ⚠️ Tiêu đề để TRỐNG. Trước đây vừa đặt `navigationTitle`
            // ("CuongThai" hiện ở GIỮA) vừa có chữ "CuongThai" ở bên TRÁI —
            // hai cái cùng tên, và cái bên trái bị tiêu đề giữa cộng ba nút
            // bên phải ép hết chỗ nên cắt thành "C…". Facebook cũng chỉ có
            // MỘT chữ, nằm bên trái.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("CuongThai")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        // Dùng CHUNG `brandGradient` thay vì tự khai — không
                        // thì đổi màu thương hiệu phải nhớ sửa từng màn.
                        .foregroundStyle(AppColors.brandGradient)
                        // Không cho hệ thống cắt chữ thương hiệu — thà đẩy
                        // nút bên phải hẹp lại còn hơn hiện "C…".
                        .fixedSize()
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
                        Button { quickSheet = .ai } label: {
                            Image(systemName: "sparkles")
                                .foregroundStyle(AppColors.brandGradient)
                        }
                        Button { quickSheet = .notes } label: {
                            Image(systemName: "note.text")
                        }
                    }
                    .foregroundColor(AppColors.textPrimary)
                }
            }
            // PHẢI nằm TRONG `NavigationStack`. Trước đây nó gắn ở ngoài, mà
            // HomeView nằm thẳng trong TabView chứ không có stack cha nào —
            // nên cái đích này không thuộc stack nào cả và bấm "Bình luận"
            // không đẩy được màn nào.
            .navigationDestination(item: $baiMoBinhLuan) { bai in
                PostDetailView(post: bai)
            }
        }
        .sheet(item: $quickSheet) { sheet in
            switch sheet {
            case .search: SearchView()
            case .notes: NotesView()
            case .notifications: NotificationsView()
            case .ai: AIChatView()
            }
        }
        // Chạm thông báo mạng xã hội từ ngoài app ⇒ mở thẳng bảng chuông.
        .onChange(of: appState.moChuongThongBao) { _, bat in
            guard bat else { return }
            quickSheet = .notifications
            appState.moChuongThongBao = false
        }
        .task {
            // Cờ có thể đã bật TRƯỚC khi màn này dựng (mở nguội từ thông báo)
            // — `onChange` không bắt được, phải kiểm một lượt.
            if appState.moChuongThongBao {
                quickSheet = .notifications
                appState.moChuongThongBao = false
            }
        }
        .task {
            await vm.loadFeed(type: tabDangChon.loaiAPI)
            await vm.taiSoBai()
        }
    }

    private var filterBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(TabTrangChu.allCases) { tab in
                        FilterPill(
                            title: tab.ten,
                            bieuTuong: tab.bieuTuong,
                            soLuong: tab.khoaDem.flatMap { vm.soBai[$0] },
                            isSelected: tabDangChon == tab
                        ) {
                            guard tabDangChon != tab else { return }
                            Haptics.cham()
                            tabDangChon = tab
                            // Học tập tự tải mục lục của nó; gọi bảng tin ở đây
                            // chỉ tốn một vòng mạng cho thứ không ai nhìn.
                            if tab != .hocTap {
                                Task { await vm.loadFeed(type: tab.loaiAPI) }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            Divider().opacity(0.5)
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
                    Task { await vm.loadFeed(type: tabDangChon.loaiAPI) }
                }
                Spacer()
            } else if moderation.filter(vm.posts).isEmpty {
                Spacer()
                VStack(spacing: Spacing.md) {
                    EmptyStateView(
                        icon: "newspaper",
                        title: "Chưa có bài viết",
                        subtitle: "Hãy là người đầu tiên chia sẻ!"
                    )
                    // Bài của ba loạt 100 ngày đã bị lọc khỏi bảng tin, nên tab
                    // này rỗng KHÔNG có nghĩa là web không có nội dung — chỉ ra
                    // chỗ chúng nằm, đừng để người dùng tưởng app hỏng.
                    Button {
                        Haptics.cham()
                        tabDangChon = .hocTap
                    } label: {
                        Label("Xem loạt bài 100 ngày", systemImage: "graduationcap.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.onPrimary)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(AppColors.primary))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            } else {
                ScrollViewReader { cuon in
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        NeoDauTrang()
                        // Blocked authors and hidden posts never reach the screen.
                        ForEach(moderation.filter(vm.posts)) { post in
                            ZStack(alignment: .topTrailing) {
                                NavigationLink(destination: PostDetailView(post: post)) {
                                    PostCard(post: post) { baiMoBinhLuan = post }
                                }
                                .buttonStyle(.plain)

                                PostModerationMenu(post: post) {
                                    // Bỏ khỏi danh sách NGAY. Đợi tải lại thì
                                    // bài vừa xoá vẫn nằm đó vài giây, người
                                    // dùng tưởng xoá không ăn và bấm lại.
                                    withAnimation { vm.boBaiKhoiDanhSach(post.id) }
                                }
                                    .padding(.top, Spacing.md)
                                    .padding(.trailing, Spacing.md)
                            }
                            .onAppear {
                                if post.id == vm.posts.last?.id {
                                    Task { await vm.loadMore(type: tabDangChon.loaiAPI) }
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
                    await vm.refresh(type: tabDangChon.loaiAPI)
                }
                // Hàng thẻ lọc GHIM phía trên (`filterBar` nằm ngoài
                // `ScrollView`), nên đổi tab lúc đang cuộn sâu là bảng tin
                // mới mở ra ngay giữa chừng. Khác Code Lab / Phòng thi: ở đó
                // thẻ lọc nằm TRONG vùng cuộn nên tự trôi mất.
                .onChange(of: tabDangChon) { _, _ in cuon.veDauTrang() }
                }
            }
        }
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    var bieuTuong: String? = nil
    /// Số bài của tab. `nil` = không có số để hiện (tab Học tập, hoặc số chưa
    /// tải xong) — khi đó KHÔNG vẽ chỗ trống, vì một viên thuốc rộng hơn hẳn
    /// mấy viên kia rồi lại co lại lúc số về trông như giao diện giật.
    var soLuong: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let bieuTuong {
                    Image(systemName: bieuTuong)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                if let soLuong {
                    Text("\(soLuong)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(isSelected
                                           ? Color.white.opacity(0.25)
                                           : AppColors.textTertiary.opacity(0.18))
                        )
                }
            }
            .foregroundColor(isSelected ? AppColors.onPrimary : AppColors.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(isSelected ? AppColors.primary : AppColors.backgroundCard)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
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
