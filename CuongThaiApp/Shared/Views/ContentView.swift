import SwiftUI

// MARK: - Root Content View
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var hasAcceptedTerms = StorageManager.shared.hasAcceptedTerms

    var body: some View {
        Group {
            // Cửa xem màn hình cho việc soi giao diện — xem `ManXemThu`.
            // ⚠️ `#if DEBUG` KHÔNG cắt ngang được chuỗi `if / else if` của
            // Swift (nó là một câu lệnh, không phải mấy khối rời), nên phần
            // điều kiện phải tách ra ngoài như dưới đây.
            if let man = manXemThu {
                cuaXemThu(man)
            } else if !hasAcceptedTerms {
                // App Store Guideline 1.2: the community rules must be agreed
                // to before any user-generated content is shown.
                TermsConsentView { hasAcceptedTerms = true }
            } else if appState.isAuthenticated {
                MainView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
    }

    /// Tên màn cần xem, chỉ đọc được ở bản DEBUG.
    private var manXemThu: String? {
        #if DEBUG
        let v = ProcessInfo.processInfo.environment["CT_XEM_MAN"] ?? ""
        return v.isEmpty ? nil : v
        #else
        return nil
        #endif
    }

    @ViewBuilder
    private func cuaXemThu(_ ten: String) -> some View {
        #if DEBUG
        ManXemThu(ten: ten)
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Main View (Platform Adaptive)
struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        #if os(iOS)
        iOSTabView()
        #else
        macOSNavigationView()
        #endif
    }
}

// MARK: - iOS TabView
#if os(iOS)
struct iOSTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // Trang chủ = BẢNG ĐIỀU KHIỂN việc + lịch học, không còn là bảng
            // tin. `HomeView` (bảng tin) vẫn sống, vào từ nút trên thanh tiêu
            // đề của Tổng quan và một thẻ trong "Đi nhanh" — gỡ hẳn thì mọi
            // màn liên quan (chi tiết bài, bình luận, cảm xúc) thành mã chết.
            TongQuanView()
                .tabItem {
                    Label(AppState.AppTab.home.title, systemImage: AppState.AppTab.home.icon)
                }
                .tag(AppState.AppTab.home)

            CoursesView()
                .tabItem {
                    Label(AppState.AppTab.learn.title, systemImage: AppState.AppTab.learn.icon)
                }
                .tag(AppState.AppTab.learn)

            CreatePostView()
                .tabItem {
                    Label(AppState.AppTab.create.title, systemImage: AppState.AppTab.create.icon)
                }
                .tag(AppState.AppTab.create)

            MessagesView()
                .tabItem {
                    Label(AppState.AppTab.messages.title, systemImage: AppState.AppTab.messages.icon)
                }
                .tag(AppState.AppTab.messages)
                .badge(appState.unreadMessages > 0 ? appState.unreadMessages : 0)

            ProfileView()
                .tabItem {
                    Label(AppState.AppTab.profile.title, systemImage: AppState.AppTab.profile.icon)
                }
                .tag(AppState.AppTab.profile)
        }
        .tint(AppColors.primary)
        // Không có socket nên đây là lúc DUY NHẤT số chưa đọc được làm mới:
        // mở app, và mỗi lần app quay lại tiền cảnh. Trước đây
        // `fetchUnreadCounts()` không được gọi từ bất cứ đâu, nên huy hiệu
        // vĩnh viễn bằng 0 dù hàm vẫn nằm đó.
        .task {
            // Mở NGUỘI từ cú chạm thông báo: didReceive đã cất đường đi từ
            // trước khi view này tồn tại — áp lại ở đây.
            ThongBaoDay.apDungDinhTuyen()
            await appState.fetchUnreadCounts()
        }
        .onChange(of: scenePhase) { _, moi in
            if moi == .active {
                // App từ nền quay lại sau cú chạm thông báo.
                ThongBaoDay.apDungDinhTuyen()
                Task { await appState.fetchUnreadCounts() }
            }
        }
    }
}
#endif

// MARK: - macOS NavigationSplitView
#if os(macOS)
struct macOSNavigationView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppState.AppTab? = .home

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(AppState.AppTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            if let tab = selectedTab {
                detailView(for: tab)
            } else {
                Text(T("Chọn một mục"))
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    private func detailView(for tab: AppState.AppTab) -> some View {
        switch tab {
        case .home: TongQuanView()
        case .learn: CoursesView()
        case .create: CreatePostView()
        case .messages:
            // MessagesView carries its own NavigationStack + NavigationLink,
            // so it drives push-to-chat inside the split-view detail column.
            MessagesView()
        case .profile: ProfileView()
        }
    }
}
#endif
