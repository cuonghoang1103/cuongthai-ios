import SwiftUI

// MARK: - Thông báo
//
// Backend đã có sẵn ba đường (GET danh sách, PATCH đánh dấu đã đọc, GET đếm
// chưa đọc) từ lâu nhưng app chưa có màn nào đọc chúng — mọi lượt thích, bình
// luận, nhắc tên đều rơi vào hư không.

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var items: [AppNotification] = []
    @Published var dangTai = false
    @Published var dangTaiThem = false
    @Published var loi: String?

    private var cursor: Int?
    private var conNua = true

    func tai() async {
        dangTai = true
        loi = nil
        do {
            let res: NotificationsResponse = try await APIClient.shared.request(
                .getNotifications(cursor: nil, limit: 20)
            )
            items = res.items
            cursor = res.pagination.nextCursor
            conNua = res.pagination.hasNextPage
            AppState.shared.unreadNotifications = res.unreadCount
        } catch {
            loi = error.localizedDescription
        }
        dangTai = false
    }

    func taiThem() async {
        guard conNua, !dangTaiThem, let cursor else { return }
        dangTaiThem = true
        do {
            let res: NotificationsResponse = try await APIClient.shared.request(
                .getNotifications(cursor: cursor, limit: 20)
            )
            // Lọc trùng: một thông báo mới chen vào giữa hai lần gọi sẽ đẩy
            // trang sau lệch đi một dòng, và dòng đó hiện hai lần.
            let daCo = Set(items.map(\.id))
            items.append(contentsOf: res.items.filter { !daCo.contains($0.id) })
            self.cursor = res.pagination.nextCursor
            conNua = res.pagination.hasNextPage
        } catch {
            loi = error.localizedDescription
        }
        dangTaiThem = false
    }

    /// Đánh dấu đã đọc. Cập nhật ngay trên máy rồi mới gọi mạng — người dùng
    /// mở chuông là coi như đã thấy, không việc gì phải đợi máy chủ trả lời.
    func danhDauDaDoc(_ ids: [Int]? = nil) async {
        let truoc = items
        let truocSo = AppState.shared.unreadNotifications
        if let ids {
            let tap = Set(ids)
            items = items.map { $0.isRead || !tap.contains($0.id) ? $0 : $0.danhDauDoc() }
            AppState.shared.unreadNotifications = max(0, truocSo - tap.count)
            AppState.shared.dongBoHuyHieu()
        } else {
            items = items.map { $0.isRead ? $0 : $0.danhDauDoc() }
            AppState.shared.unreadNotifications = 0
            AppState.shared.dongBoHuyHieu()
        }
        do {
            try await APIClient.shared.send(.markNotificationsRead(ids: ids))
        } catch {
            items = truoc
            AppState.shared.unreadNotifications = truocSo
            AppState.shared.dongBoHuyHieu()
            loi = error.localizedDescription
        }
    }
}

extension AppNotification {
    /// Bản sao đã đọc — model là `let` hết nên không sửa tại chỗ được.
    func danhDauDoc() -> AppNotification {
        AppNotification(
            id: id, type: type, entityId: entityId, secondaryEntityId: secondaryEntityId,
            isRead: true, createdAt: createdAt, sender: sender, payload: payload,
        )
    }
}

struct NotificationsView: View {
    @StateObject private var vm = NotificationsViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var baiDangMo: SocialPost?
    @State private var nguoiDangMo: Int?
    @State private var dangMoBai: Int?

    var body: some View {
        NavigationStack {
            Group {
                if vm.dangTai && vm.items.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "Chưa có thông báo",
                        subtitle: "Khi có người thích hoặc bình luận bài của bạn, nó sẽ hiện ở đây."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    danhSach
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Thông báo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if appState.unreadNotifications > 0 {
                        Button("Đọc hết") {
                            Task { await vm.danhDauDaDoc() }
                        }
                        .font(.buttonSmall)
                    }
                }
            }
            .navigationDestination(item: $baiDangMo) { bai in
                PostDetailView(post: bai)
            }
            .navigationDestination(item: $nguoiDangMo) { userId in
                UserProfileView(userId: userId)
            }
            .alert("Lỗi", isPresented: .constant(vm.loi != nil)) {
                Button("OK") { vm.loi = nil }
            } message: {
                Text(vm.loi ?? "")
            }
            .task { await vm.tai() }
            .refreshable { await vm.tai() }
        }
    }

    private var danhSach: some View {
        List {
            ForEach(vm.items) { tb in
                Button {
                    Task { await moThongBao(tb) }
                } label: {
                    hang(tb)
                }
                .listRowBackground(tb.isRead ? AppColors.backgroundPrimary : AppColors.primary.opacity(0.08))
                .onAppear {
                    if tb.id == vm.items.last?.id {
                        Task { await vm.taiThem() }
                    }
                }
            }
            if vm.dangTaiThem {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(AppColors.backgroundPrimary)
            }
        }
        .listStyle(.plain)
    }

    private func hang(_ tb: AppNotification) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                UserAvatarView(url: tb.sender?.avatarUrl, size: 44)
                Image(systemName: tb.bieuTuong)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.onPrimary)
                    .padding(5)
                    .background(AppColors.primary)
                    .clipShape(Circle())
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                (Text(tb.sender?.name ?? "Ai đó").fontWeight(.semibold)
                    + Text(" " + tb.loiNhan))
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(TimeFormatter.formatTimeAgo(tb.createdAt))
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer(minLength: 0)

            if dangMoBai == tb.id {
                ProgressView().scaleEffect(0.8)
            } else if !tb.isRead {
                Circle().fill(AppColors.primary).frame(width: 8, height: 8).offset(y: 6)
            }
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
    }

    private func moThongBao(_ tb: AppNotification) async {
        if !tb.isRead { await vm.danhDauDaDoc([tb.id]) }

        switch tb.noiDen {
        case .tinNhan:
            dismiss()
            appState.selectedTab = .messages

        case .nguoiDung(let userId):
            nguoiDangMo = userId

        case .baiViet(let postId):
            guard dangMoBai == nil else { return }
            dangMoBai = tb.id
            defer { dangMoBai = nil }
            do {
                let bai: SocialPost = try await APIClient.shared.request(.getPost(id: postId))
                baiDangMo = bai
            } catch {
                vm.loi = "Không mở được bài viết — có thể nó đã bị xoá."
            }

        case .ctWork(let dich):
            // Đóng chuông TRƯỚC rồi mới mở CT Work: iPhone mở nó bằng tấm phủ
            // toàn màn, mà trình bày tấm phủ lúc sheet đang đóng dở thì iOS
            // bỏ qua im lặng.
            dismiss()
            try? await Task.sleep(nanoseconds: 450_000_000)
            appState.ctWorkDich = dich
            appState.selectedTab = .ctWork

        case .khongDauCa:
            // Ghi chú, tài liệu Hub, thông báo ban quản trị: app chưa có màn
            // tương ứng. Nói thẳng còn hơn bấm vào không có gì xảy ra.
            vm.loi = "Nội dung này hiện chỉ xem được trên website cuongthai.com."
        }
    }
}

#Preview {
    NotificationsView().environmentObject(AppState.shared)
}
