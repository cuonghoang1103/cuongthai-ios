import SwiftUI

// MARK: - Hộp thư (thông báo CT Work)
//
// `GET /api/v1/social/notifications` trả MỌI loại thông báo của tài khoản
// (cả mạng xã hội của app chính) và CHƯA có bộ lọc theo loại ⇒ app giữ lại
// đúng loại `WORK_*` và tự tải thêm trang cho tới khi đủ một màn. Đề xuất
// backend: `?surface=work` (payload WORK_* đã có `surface: 'work'`).

@MainActor
final class HopThuVM: ObservableObject {
    @Published var ds: [AppNotification] = []
    @Published var loi: String?
    @Published var dangTai = false
    @Published var daTai = false
    private var conTro: Int?
    private var conNua = true

    func tai() async {
        conTro = nil
        conNua = true
        ds = []
        await taiThem(toiThieu: 20)
        daTai = true
    }

    /// Tải tới khi có thêm ≥ `toiThieu` thông báo CT Work (tối đa 6 trang/lượt).
    func taiThem(toiThieu: Int = 15) async {
        guard conNua, !dangTai else { return }
        dangTai = true
        defer { dangTai = false }
        var them = 0
        var lan = 0
        do {
            while conNua && them < toiThieu && lan < 6 {
                lan += 1
                let r: NotificationsResponse = try await APIClient.shared.request(.getNotifications(cursor: conTro, limit: 50))
                let co = Set(ds.map(\.id))
                let moi = r.items.filter { $0.type.hasPrefix("WORK_") && !co.contains($0.id) }
                ds += moi
                them += moi.count
                conTro = r.pagination.nextCursor
                conNua = r.pagination.hasNextPage && conTro != nil
            }
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
        AppState.shared.hopThuChuaDoc = ds.filter { !$0.isRead }.count
    }

    func danhDauDaDoc(_ ids: [Int]) async {
        guard !ids.isEmpty else { return }
        do {
            try await APIClient.shared.send(.markNotificationsRead(ids: ids))
            ds = ds.map { n in
                guard ids.contains(n.id) else { return n }
                return AppNotification(id: n.id, type: n.type, entityId: n.entityId, secondaryEntityId: n.secondaryEntityId,
                                       isRead: true, createdAt: n.createdAt, sender: n.sender, payload: n.payload)
            }
            AppState.shared.hopThuChuaDoc = ds.filter { !$0.isRead }.count
            await AppState.shared.taiSoChuaDoc()
        } catch { loi = CTW.loi(error) }
    }
}

struct HopThuCTW: View {
    @StateObject private var vm = HopThuVM()
    @ObservedObject private var kd = ModerationStore.shared
    @State private var chiChuaDoc = false

    var body: some View {
        // Khung (`CotCTW`) đã bọc NavigationStack.
        Group {
            List {
                if let loi = vm.loi { CTWErrorBanner(text: loi).listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
                let ds = vm.ds.filter { n in
                    if chiChuaDoc && n.isRead { return false }
                    if let s = n.sender?.id, kd.blockedUserIds.contains(s) { return false }
                    // 3.1.1: máy chủ CHƯA lọc lời mời mua trong payload thông báo (sâu 4 cấp) — ẩn ở app.
                    if CTW.coLoiMoiMua(n.loiNhan) { return false }
                    return true
                }
                if vm.daTai && ds.isEmpty {
                    CTWOTrong(bieuTuong: "bell.slash", tieuDe: chiChuaDoc ? "You're all caught up" : "No notifications yet",
                              moTa: "Assignments, mentions, comments and alerts from your projects appear here.")
                    .listRowBackground(Color.clear)
                }
                ForEach(ds) { n in
                    Button { mo(n) } label: { hang(n) }
                        .buttonStyle(.plain)
                        .onAppear { if n.id == ds.last?.id { Task { await vm.taiThem() } } }
                }
                if vm.dangTai && !vm.ds.isEmpty {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .overlay { if vm.dangTai && vm.ds.isEmpty { CTWKhungTai() } }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Show", selection: $chiChuaDoc) {
                            Text("All").tag(false)
                            Text("Unread").tag(true)
                        }
                    } label: { Image(systemName: chiChuaDoc ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") }
                    .accessibilityLabel("Filter")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Read all") {
                        Task { await vm.danhDauDaDoc(vm.ds.filter { !$0.isRead }.map(\.id)) }
                    }
                    .disabled(!vm.ds.contains { !$0.isRead })
                }
            }
            .refreshable { await vm.tai() }
            .task { if !vm.daTai { await vm.tai() } }
        }
    }

    private func hang(_ n: AppNotification) -> some View {
        let ai = n.sender == nil
        return HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let u = n.sender {
                    CTWAvatar(user: CTWUser(id: u.id, username: u.username, fullName: u.fullName,
                                            displayName: u.displayName, avatarUrl: u.avatarUrl), size: 40)
                } else {
                    // Thông báo hệ thống (cảnh báo hạn, tự động hoá) — không có người gửi.
                    Image("LogoCTWork").resizable().scaledToFit().frame(width: 40, height: 40)
                        .accessibilityLabel("CT Work")
                }
                Image(systemName: n.bieuTuong).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    .frame(width: 20, height: 20).background(Circle().fill(mau(n)))
                    .overlay(Circle().strokeBorder(AppColors.backgroundPrimary, lineWidth: 1.5))
                    .offset(x: 4, y: 4)
            }
            VStack(alignment: .leading, spacing: 4) {
                (Text(ai ? "CT Work" : (n.sender?.displayName ?? n.sender?.fullName ?? n.sender?.username ?? "Someone")).bold()
                 + Text(" ") + Text(n.loiNhan))
                    .font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let t = n.payload?.title, n.type != "WORK_ASSIGN" {
                    Text(t).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
                Text(CTWChatThoiGian.gio(n.createdAt)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
            if !n.isRead {
                Circle().fill(AppColors.primary).frame(width: 9, height: 9).padding(.top, 6)
                    .accessibilityLabel("Unread")
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func mau(_ n: AppNotification) -> Color {
        switch n.type {
        case "WORK_ALERT": return AppColors.error
        case "WORK_MENTION": return AppColors.accent
        case "WORK_ASSIGN": return AppColors.success
        default: return AppColors.primary
        }
    }

    private func mo(_ n: AppNotification) {
        if !n.isRead { Task { await vm.danhDauDaDoc([n.id]) } }
        if let u = n.payload?.url { DinhTuyenCTW.mo(duongDan: u) }
    }
}
