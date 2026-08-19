import Foundation
import Combine

// MARK: - App State
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var unreadMessages = 0
    @Published var selectedTab: AppTab = .home

    private let storage = StorageManager.shared

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

    private init() { checkAuth() }

    func checkAuth() {
        if storage.getAuthToken() != nil {
            isAuthenticated = true
            Task { await fetchProfile() }
        }
    }

    func login(token: String, refreshToken: String? = nil) {
        storage.saveAuthToken(token, refreshToken: refreshToken)
        isAuthenticated = true
        Task { await fetchProfile() }
    }

    func logout() {
        storage.clearAll()
        ModerationStore.shared.reset()
        isAuthenticated = false
        currentUser = nil
        unreadMessages = 0
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

    func fetchUnreadCounts() async {
        do {
            let count: Int = try await APIClient.shared.request(.getUnreadMessageCount)
            unreadMessages = count
        } catch { }
    }
}
