import Foundation
import Combine

// MARK: - App State
@MainActor
final class AppState: ObservableObject {

    /// Biệt danh vừa đổi ở một hội thoại.
    ///
    /// Biệt danh là thứ **chỉ người xem thấy** — máy chủ không phát sự kiện
    /// socket nào cho nó, nên không có đường realtime sẵn để bám vào. Mà
    /// `MessagesViewModel` lại là `@StateObject` RIÊNG của màn danh sách:
    /// `ChatView` không với tới được nó.
    ///
    /// Thiếu kênh này thì đổi biệt danh xong, danh sách bên ngoài vẫn hiện
    /// tên cũ cho tới lượt tải lại kế tiếp — người dùng thấy là "app đơ".
    let bietDanhDoi = PassthroughSubject<(threadId: Int, ten: String), Never>()
    static let shared = AppState()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var unreadMessages = 0
    @Published var unreadNotifications = 0
    @Published var selectedTab: AppTab = .home

    private let storage = StorageManager.shared
    private var huyDangKy = Set<AnyCancellable>()
    /// Hội thoại đang mở — tin mới của chính nó KHÔNG cộng vào huy hiệu.
    var hoiThoaiDangMo: Int?
    /// Hội thoại cần mở sau khi người dùng chạm vào thông báo đẩy. Màn Tin
    /// nhắn đọc rồi xoá — không xoá thì lần sau vào tab đó nó tự mở lại.
    @Published var hoiThoaiCanMo: Int?
    /// Bật lên khi người dùng chạm một thông báo mạng xã hội — Trang chủ mở
    /// bảng chuông. Trang chủ tự hạ cờ sau khi mở.
    @Published var moChuongThongBao = false

    // Five tabs is the iPhone maximum before iOS collapses the rest into
    // "More". Search moved into the Home toolbar so the Learn tab (courses +
    // notes) can be a first-class destination — it is the substance the app is
    // reviewed on, not an extra.
    enum AppTab: Int, CaseIterable, Identifiable {
        case home = 0, learn = 1, create = 2, messages = 3, profile = 4
        /// Vở viết tay. CHỈ hiện ở thanh bên của màn rộng (iPad/Mac) —
        /// thanh tab của iPhone giữ đúng 5 mục, mục thứ sáu bị iOS dồn vào
        /// tab "More" và chôn cuốn vở sau hai lần chạm.
        case notebook = 5
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .home: return T("Trang chủ")
            case .learn: return T("Học")
            case .create: return T("Tạo")
            case .messages: return T("Tin nhắn")
            case .profile: return T("Cá nhân")
            case .notebook: return T("Vở")
            }
        }
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .learn: return "graduationcap.fill"
            case .create: return "plus.app.fill"
            case .messages: return "message.fill"
            case .profile: return "person.fill"
            case .notebook: return "book.closed.fill"
            }
        }
    }

    /// Mã lỗi Keychain nếu kho khoá không dùng được. Khác nil nghĩa là phiên
    /// đăng nhập KHÔNG lưu được — phải nói ra chứ không để người dùng đăng
    /// nhập xong, mở lại app thấy mình bị đăng xuất mà không hiểu vì sao.
    @Published var loiKeychain: OSStatus?

    private init() {
        loiKeychain = KeychainStore.tuKiem()
        checkAuth()
        // Tin mới về qua socket thì cộng huy hiệu ngay, không đợi lần làm mới
        // sau. Bỏ qua tin của chính mình và tin của hội thoại đang mở.
        RealtimeClient.shared.tinMoi
            .sink { [weak self] su in
                guard let self else { return }
                guard su.message.senderId != self.currentUser?.id else { return }
                guard su.threadId != self.hoiThoaiDangMo else { return }
                self.unreadMessages += 1
                self.dongBoHuyHieu()
            }
            .store(in: &huyDangKy)
    }

    func checkAuth() {
        if storage.getAuthToken() != nil {
            isAuthenticated = true
            RealtimeClient.shared.noi()
            Task { await fetchProfile() }
        }
    }

    func login(token: String, refreshToken: String? = nil) {
        storage.saveAuthToken(token, refreshToken: refreshToken)
        isAuthenticated = true
        // `noiLai` chứ không phải `noi`: token nằm trong header của kết nối,
        // nên đăng nhập tài khoản khác mà chỉ gọi `noi()` thì socket cũ vẫn
        // sống với token cũ và ta nhận tin của người dùng TRƯỚC.
        RealtimeClient.shared.noiLai()
        Task { await fetchProfile() }
    }

    func logout() {
        storage.clearAll()
        RealtimeClient.shared.ngat()
        ModerationStore.shared.reset()
        isAuthenticated = false
        currentUser = nil
        trangThaiHoSo = .chuaNap
        unreadMessages = 0
        unreadNotifications = 0
    }

    /// Hồ sơ nạp được chưa — để màn Hồ sơ biết vẽ gì.
    ///
    /// ⚠️ Trước 06/09/2026 hàm này nuốt MỌI lỗi không phải 401. `checkAuth()`
    /// bật `isAuthenticated = true` chỉ vì máy CÓ token (chưa hỏi máy chủ),
    /// nên một lần gọi hỏng lúc mở app — mạng chập, 500 thoáng qua, giải mã
    /// lệch — để lại trạng thái "đã đăng nhập mà không có người dùng"
    /// VĨNH VIỄN: không ai thử lại, không log, và ProfileView lấp chỗ trống
    /// bằng `?? "User"` nên người dùng thấy một hồ sơ giả "User / @username /
    /// 0 / 0 / 0". Nhìn y như app hỏng, và App Store đánh trượt vì đúng là
    /// nội dung giữ chỗ (Guideline 2.1).
    enum TrangThaiHoSo: Equatable { case chuaNap, dangNap, xong, loi(String) }
    @Published var trangThaiHoSo: TrangThaiHoSo = .chuaNap

    func fetchProfile() async {
        if case .dangNap = trangThaiHoSo { return }
        trangThaiHoSo = .dangNap
        // Thử lại có giãn cách: hỏng lúc mở app phần lớn là mạng chưa sẵn sàng.
        for lan in 0..<3 {
            do {
                let user: User = try await APIClient.shared.request(.getProfile)
                currentUser = user
                storage.saveCurrentUser(user)
                trangThaiHoSo = .xong
                await ModerationStore.shared.refreshBlocks()
                return
            } catch {
                if case APIError.unauthorized = error { logout(); return }
                if lan == 2 {
                    trangThaiHoSo = .loi(error.localizedDescription)
                    // Có bản lưu trong máy thì dùng tạm — thà hồ sơ cũ còn hơn
                    // hồ sơ giả.
                    if currentUser == nil, let luu = storage.getCurrentUser() {
                        currentUser = luu
                        trangThaiHoSo = .xong
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: UInt64(400_000_000) << lan)
            }
        }
    }

    /// Đếm chưa đọc cho cả tin nhắn lẫn thông báo.
    ///
    /// Bản cũ giải mã `/messages/unread-count` thẳng ra `Int`, nhưng backend
    /// trả `{ "count": 5 }` — một ĐỐI TƯỢNG. Lệnh giải mã luôn ném lỗi, lỗi
    /// bị `catch { }` nuốt, nên huy hiệu tin nhắn VĨNH VIỄN bằng 0 mà không
    /// một dòng log nào. Hỏng câm đúng nghĩa.
    /// Huy hiệu app = tin chưa đọc + thông báo chưa đọc.
    ///
    /// Backend chỉ gửi SỐ TIN trong gói đẩy, nhưng người dùng nhìn biểu tượng
    /// thì hiểu là "có bao nhiêu thứ đang chờ tôi" — nên cộng cả hai. Quan
    /// trọng hơn: hàm này là chỗ DUY NHẤT biết cách hạ số xuống.
    func dongBoHuyHieu() {
        ThongBaoDay.datHuyHieu(unreadMessages + unreadNotifications)
    }

    func fetchUnreadCounts() async {
        do {
            let tin: UnreadMessageCount = try await APIClient.shared.request(.getUnreadMessageCount)
            unreadMessages = tin.count
        } catch {
            // Mất mạng thì giữ nguyên số cũ, đừng xoá về 0 —
            // "0 tin chưa đọc" là một lời khẳng định, không phải "không biết".
        }
        do {
            let tb: UnreadNotificationCount = try await APIClient.shared.request(.getUnreadNotificationCount)
            unreadNotifications = tb.unreadCount
        } catch { }
        // Máy chủ là nguồn sự thật — đồng bộ huy hiệu theo nó, kể cả khi số
        // GIẢM. Đây là lượt duy nhất huy hiệu có thể tụt xuống.
        dongBoHuyHieu()
    }
}
