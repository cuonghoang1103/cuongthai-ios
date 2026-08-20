import Foundation
import Combine

// MARK: - App State
@MainActor
final class AppState: ObservableObject {
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

    // Five tabs is the iPhone maximum before iOS collapses the rest into
    // "More". Search moved into the Home toolbar so the Learn tab (courses +
    // notes) can be a first-class destination — it is the substance the app is
    // reviewed on, not an extra.
    enum AppTab: Int, CaseIterable, Identifiable {
        case home = 0, learn = 1, create = 2, messages = 3, profile = 4
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .home: return "Trang chủ"
            case .learn: return "Học"
            case .create: return "Tạo"
            case .messages: return "Tin nhắn"
            case .profile: return "Cá nhân"
            }
        }
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .learn: return "graduationcap.fill"
            case .create: return "plus.app.fill"
            case .messages: return "message.fill"
            case .profile: return "person.fill"
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
        unreadMessages = 0
        unreadNotifications = 0
    }

    func fetchProfile() async {
        do {
            let user: User = try await APIClient.shared.request(.getProfile)
            currentUser = user
            storage.saveCurrentUser(user)
            await ModerationStore.shared.refreshBlocks()
        } catch {
            if case APIError.unauthorized = error { logout() }
        }
    }

    /// Đếm chưa đọc cho cả tin nhắn lẫn thông báo.
    ///
    /// Bản cũ giải mã `/messages/unread-count` thẳng ra `Int`, nhưng backend
    /// trả `{ "count": 5 }` — một ĐỐI TƯỢNG. Lệnh giải mã luôn ném lỗi, lỗi
    /// bị `catch { }` nuốt, nên huy hiệu tin nhắn VĨNH VIỄN bằng 0 mà không
    /// một dòng log nào. Hỏng câm đúng nghĩa.
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
    }
}
