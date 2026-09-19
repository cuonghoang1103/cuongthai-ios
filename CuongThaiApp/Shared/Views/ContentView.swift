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

// MARK: - Main View (bố cục theo BỀ RỘNG, không theo hệ điều hành)
struct MainView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    // Đây là bề rộng CỬA SỔ, không phải loại máy — và đó mới là thứ cần hỏi.
    // iPad trong Slide Over hẹp trả `.compact`, nên nó tự rơi về thanh tab của
    // iPhone thay vì cố nhét hai cột vào ~320pt. Ngược lại iPhone Pro Max nằm
    // ngang vẫn `.compact`, nên nó KHÔNG bị đẩy sang cột đôi.
    @Environment(\.horizontalSizeClass) private var beRongNgang
    #endif

    var body: some View {
        boCuc
            // ⚠️ Vòng đời phiên nằm ở ĐÂY, không nằm trong từng bố cục. Trước
            // 16/09/2026 cả ba việc dưới đây gắn vào `iOSTabView`; để nguyên
            // thế thì iPad màn rộng (đi đường cột đôi) mất sạch cả ba, và cả
            // ba đều hỏng CÂM: huy hiệu chưa đọc đứng yên ở 0, chạm thông báo
            // đẩy không mở đúng chỗ, vương miện Pro vẫn sáng sau khi hết hạn.
            .task {
                #if os(iOS)
                // Mở NGUỘI từ cú chạm thông báo: didReceive đã cất đường đi từ
                // trước khi view này tồn tại — áp lại ở đây.
                ThongBaoDay.apDungDinhTuyen()
                #endif
                await appState.fetchUnreadCounts()
            }
            .onChange(of: scenePhase) { _, moi in
                guard moi == .active else { return }
                #if os(iOS)
                // App từ nền quay lại sau cú chạm thông báo.
                ThongBaoDay.apDungDinhTuyen()
                #endif
                Task { await appState.fetchUnreadCounts() }
                // ⚠️ Hồ sơ cũng phải nạp lại, không chỉ số chưa đọc. `isPro`
                // và hạn Pro do MÁY CHỦ tính; trước đây chúng chỉ được lấy lúc
                // mở app và sau khi đăng nhập. Ai để app chạy nền vài ngày thì
                // vương miện Pro vẫn sáng sau khi gói đã hết hạn, cho tới lúc
                // bấm trúng một tính năng và ăn 403 — người dùng đọc ra là
                // "app hỏng", không phải "gói đã hết".
                //
                // Chiều ngược lại còn quan trọng hơn: vừa mua Pro trên web ở
                // một tab khác, quay sang app là thấy ngay, không phải thoát
                // ra đăng nhập lại.
                Task { await appState.fetchProfile() }
            }
    }

    @ViewBuilder
    private var boCuc: some View {
        #if os(iOS)
        if beRongNgang == .regular {
            BoCucCotDoi()
        } else {
            iOSTabView()
        }
        #else
        BoCucCotDoi()
        #endif
    }
}

// MARK: - iOS TabView (iPhone, và iPad ở cửa sổ hẹp)
#if os(iOS)
struct iOSTabView: View {
    @EnvironmentObject var appState: AppState

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
        // ⚠️ Thanh tab này KHÔNG có mục `.notebook`. Người dùng đang ở Vở
        // trên iPad rồi kéo app vào Slide Over là rơi xuống đúng đây, và
        // `TabView` gặp một `tag` không tồn tại thì hiện MÀN TRỐNG — không
        // lỗi, không tab nào sáng, trông y như app chết. Kéo về Trang chủ.
        .onAppear { neuLacTab() }
        .onChange(of: appState.selectedTab) { _, _ in neuLacTab() }
        .fullScreenCover(isPresented: $appState.moTienNong) { TienView(coNutDong: true) }
        .fullScreenCover(isPresented: $appState.moIelts) { IeltsView(coNutDong: true) }
    }

    private func neuLacTab() {
        // Hai tab KHÔNG có mặt trên thanh này. `.notebook` thì cố ý (Vở chỉ
        // dành cho iPad màn rộng); `.finance` thì có mặt ở đây dưới dạng một
        // TẤM PHỦ toàn màn, vì thanh tab đã đủ 5 mục và mục thứ sáu bị iOS
        // dồn vào "More" — chôn cả một mảng xuống hai lần chạm.
        if appState.selectedTab == .finance {
            appState.selectedTab = .home
            appState.moTienNong = true
            return
        }
        if appState.selectedTab == .ielts {
            appState.selectedTab = .home
            appState.moIelts = true
            return
        }
        if appState.selectedTab == .notebook { appState.selectedTab = .home }
    }
}
#endif

// MARK: - Bố cục cột đôi (iPad màn rộng + macOS)
//
// Một bố cục cho CẢ HAI. Trước 16/09/2026 đây là `macOSNavigationView` khoá
// sau `#if os(macOS)`; mở khoá rẻ hơn viết bố cục iPad thứ hai, và mọi sửa
// chữa từ nay áp cho cả hai cùng lúc thay vì phải nhớ làm hai lần.
struct BoCucCotDoi: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            // ⚠️ PHẢI là `NavigationLink(value:)`, KHÔNG phải `Label(...).tag(...)`.
            // Cách cũ (thừa hưởng từ bản macOS) chọn được trên macOS vì ở đó
            // hàng List là hàng bấm-để-chọn. Trên iOS/iPadOS thì KHÔNG: chọn
            // bằng `.tag` chỉ ăn khi List đang ở chế độ sửa, nên bấm vào mục
            // sidebar trên iPad KHÔNG có gì xảy ra — không lỗi, không hiệu ứng,
            // trông y như nút chết (người dùng báo 16/09/2026).
            List(selection: mucDangChon) {
                ForEach(AppState.AppTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .badge(tab == .messages && appState.unreadMessages > 0
                           ? appState.unreadMessages : 0)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            manChiTiet(appState.selectedTab)
        }
        // `.balanced` để iPad DỰNG ĐỨNG vẫn thấy cột trái. Kiểu mặc định
        // (`.automatic`) giấu nó sau một nút ở dọc, nên xoay máy một cái là
        // điều hướng biến mất — đúng cảm giác "app iPhone phóng to" mà cả
        // việc này sinh ra để tránh.
        .navigationSplitViewStyle(.balanced)
        .tint(AppColors.primary)
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
    }

    /// ⚠️ Cột trái phải đọc/ghi THẲNG `appState.selectedTab`, không được giữ
    /// `@State` riêng. Thông báo đẩy (`ThongBaoDay.apDungDinhTuyen`) và màn
    /// Thông báo điều hướng bằng cách ĐẶT `appState.selectedTab`; một bản sao
    /// riêng nuốt trọn những lệnh đó — chạm thông báo thì không có gì xảy ra
    /// và không có lỗi nào để thấy. Bản macOS cũ đúng là đang dính lỗi này.
    private var mucDangChon: Binding<AppState.AppTab?> {
        Binding(get: { appState.selectedTab },
                set: { moi in if let moi { appState.selectedTab = moi } })
    }

    @ViewBuilder
    private func manChiTiet(_ tab: AppState.AppTab) -> some View {
        switch tab {
        case .home: TongQuanView()
        case .learn: CoursesView()
        case .create: CreatePostView()
        case .messages:
            // MessagesView carries its own NavigationStack + NavigationLink,
            // so it drives push-to-chat inside the split-view detail column.
            MessagesView()
        case .profile: ProfileView()
        case .notebook: VoView()
        case .finance: TienView()
        case .ielts: IeltsView()
        }
    }
}
