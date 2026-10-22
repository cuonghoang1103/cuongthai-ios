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
        // `khung…` = VỎ THẬT (MainView: thanh tab / thanh bên iPad) với Hôm nay
        // dữ liệu giả — để soi điều hướng mà không cần đăng nhập. Xem `KhungXemThu`.
        if ten.lowercased().hasPrefix("khung") {
            KhungXemThu(ten: ten.lowercased())
        } else {
            ManXemThu(ten: ten)
        }
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Main View (bố cục theo BỀ RỘNG, không theo hệ điều hành)
//
// 22/10/2026 — đợt "rút gọn": 5 điểm đến chính (Hôm nay · Bảng tin · Học ·
// Tin nhắn · Tôi) + MỘT danh mục "Tất cả tính năng" (`Shared/TatCa`). Tạo bài
// không còn là tab (nút "+" nổi ở Bảng tin), CT Work là app riêng.
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
            // Bảng trình bày từ GỐC: tìm kiếm ⌘K, thông báo, ghi chú, cài đặt,
            // soạn bài. Neo vào một view nền RIÊNG (không lên `boCuc`): màn con
            // nào cũng có `.sheet` của nó, chung một view là cái sau nuốt cái
            // trước (CLAUDE.md C5).
            .background(Color.clear.sheet(item: $appState.bangGoc) { b in
                ManBangGoc(bang: b)
            })
            // AI Chat mở từ danh mục / tìm kiếm.
            .moAIChat(dangMo: $appState.moAIChatGoc)
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

/// Nội dung của `AppState.bangGoc`.
struct ManBangGoc: View {
    let bang: BangGoc

    var body: some View {
        switch bang {
        case .timKiem: SearchView()
        case .thongBao: NotificationsView()
        case .notes: NotesView()
        case .caiDat: SettingsView()
        case .taoBai: CreatePostView(laBangTrinhBay: true)
        }
    }
}

// MARK: - iOS TabView (iPhone, và iPad ở cửa sổ hẹp)
#if os(iOS)
struct iOSTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ForEach(AppState.AppTab.allCases) { tab in
                ManCuaTab(tab: tab)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
                    .tag(tab)
                    .badge(tab == .tinNhan && appState.unreadMessages > 0 ? appState.unreadMessages : 0)
            }
        }
        .tint(AppColors.primary)
        .onAppear {
            // Vừa từ cột đôi (iPad) thu về hẹp (Slide Over/Split View) mà đang
            // xem một tính năng ở cột chi tiết ⇒ đưa nó sang Hôm nay thay vì
            // đánh rơi.
            switch appState.mucBenRieng {
            case .tinhNang(let f)? where f.cachMo == .day:
                appState.selectedTab = .homNay
                appState.duongHomNay = [.tinhNang(f)]
            case .tatCa?:
                appState.selectedTab = .homNay
                appState.duongHomNay = [.tatCa]
            case .some:
                appState.mucBenRieng = nil
            case nil:
                break
            }
            nhatTinhNang()
        }
        .onChange(of: appState.dichCanMo) { _, _ in nhatTinhNang() }
    }

    /// Tính năng kiểu `.day` mở trên iPhone = đẩy vào stack của Hôm nay. Không
    /// còn tấm phủ toàn màn riêng cho từng mảng (năm cờ `moTienNong…` cũ):
    /// đẩy thì có nút quay lại, có vuốt cạnh, và đúng một thanh tiêu đề.
    private func nhatTinhNang() {
        guard let d = appState.dichCanMo else { return }
        appState.dichCanMo = nil
        appState.selectedTab = .homNay
        appState.duongHomNay = [d]
    }
}
#endif

// MARK: - Bố cục cột đôi (iPad màn rộng + macOS)
//
// Thanh bên: ô tìm (⌘K) · năm điểm đến chính · "Công cụ" = các tính năng ĐÃ
// GHIM (thu gọn được) + "Tất cả tính năng…". Chọn một công cụ ⇒ nó hiện ở cột
// chi tiết, cùng chỗ với năm màn chính.
struct BoCucCotDoi: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var ghim = KhoGhim.shared
    @Environment(\.openWindow) private var moCuaSo
    @AppStorage("thanhBen.moCongCu") private var moCongCu = true

    /// `UIApplicationSupportsMultipleScenes` trong Info.plist. Đọc lúc chạy
    /// chứ không ghi cứng `#if os(iOS)`: iPhone cũng là iOS mà không mở được
    /// cửa sổ thứ hai.
    private var nhieuCuaSoDuoc: Bool {
        #if os(iOS)
        return UIApplication.shared.supportsMultipleScenes
        #else
        return true
        #endif
    }

    var body: some View {
        NavigationSplitView {
            // ⚠️ PHẢI là `NavigationLink(value:)`, KHÔNG phải `Label(...).tag(...)`.
            // Cách cũ (thừa hưởng từ bản macOS) chọn được trên macOS vì ở đó
            // hàng List là hàng bấm-để-chọn. Trên iOS/iPadOS thì KHÔNG: chọn
            // bằng `.tag` chỉ ăn khi List đang ở chế độ sửa, nên bấm vào mục
            // sidebar trên iPad KHÔNG có gì xảy ra — không lỗi, không hiệu ứng,
            // trông y như nút chết (người dùng báo 16/09/2026).
            List(selection: mucDangChon) {
                Section { oTim }

                Section {
                    ForEach(AppState.AppTab.allCases) { tab in
                        NavigationLink(value: MucBen.tab(tab)) {
                            Label(tab.title, systemImage: tab.icon)
                        }
                        .badge(tab == .tinNhan && appState.unreadMessages > 0
                               ? appState.unreadMessages : 0)
                        // Mở module ra cửa sổ RIÊNG để đặt cạnh cửa sổ chính —
                        // Vở bên trái, bài giảng bên phải. Chỉ iPad/Mac mới có
                        // nhiều cửa sổ; trên iPhone `openWindow` không làm gì
                        // nên giấu mục này đi cho khỏi thành nút chết.
                        .contextMenu { nutCuaSoMoi(.tab(tab)) }
                        .listRowBackground(nenChon(.tab(tab)))
                    }
                }

                Section(isExpanded: $moCongCu) {
                    ForEach(ghim.ds) { f in
                        hangCongCu(f).listRowBackground(nenChon(.tinhNang(f)))
                    }
                    NavigationLink(value: MucBen.tatCa) {
                        Label(T("Tất cả tính năng…"), systemImage: "square.grid.2x2")
                    }
                    .contextMenu { nutCuaSoMoi(.tatCa) }
                    .listRowBackground(nenChon(.tatCa))
                } header: {
                    Text(T("Công cụ"))
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("CuongThai")
            .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 340)
        } detail: {
            VStack(spacing: 0) {
                // Báo NGAY trên đầu mọi màn: đang xem bản đã tải. Hiện nội
                // dung cũ mà im lặng là để người dùng tin vào số liệu lỗi
                // thời — tệ hơn màn trắng, vì màn trắng thì họ biết là hỏng.
                DaiNgoaiTuyen()
                chiTiet
            }
        }
        // `.balanced` để iPad DỰNG ĐỨNG vẫn thấy cột trái. Kiểu mặc định
        // (`.automatic`) giấu nó sau một nút ở dọc, nên xoay máy một cái là
        // điều hướng biến mất — đúng cảm giác "app iPhone phóng to" mà cả
        // việc này sinh ra để tránh.
        .navigationSplitViewStyle(.balanced)
        .tint(AppColors.primary)
        .onAppear { nhatTinhNang() }
        .onChange(of: appState.dichCanMo) { _, _ in nhatTinhNang() }
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
    }

    /// Nền của mục ĐANG CHỌN — tự vẽ: đo trên iPadOS 26 (máy mô phỏng) thì
    /// thanh bên `List(selection:)` không tô mục chọn lúc mới mở, người dùng
    /// không biết mình đang ở đâu.
    @ViewBuilder
    private func nenChon(_ muc: MucBen) -> some View {
        if mucDangChon.wrappedValue == muc {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(AppColors.primary.opacity(0.14))
        } else {
            Color.clear
        }
    }

    /// Trông như ô tìm, bấm là mở bảng tìm toàn cục (cùng bảng với ⌘K).
    private var oTim: some View {
        Button { appState.bangGoc = .timKiem } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textTertiary)
                Text(T("Tìm kiếm"))
                    .foregroundColor(AppColors.textTertiary)
                Spacer(minLength: 0)
                Text("⌘K")
                    .font(.caption.monospaced())
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).strokeBorder(AppColors.border))
                    .accessibilityHidden(true)
            }
            .font(.bodyMedium)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(AppColors.backgroundTertiary))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
        .accessibilityLabel(T("Tìm kiếm"))
        .accessibilityHint(T("Tìm tính năng, người, bài viết, khoá học"))
    }

    @ViewBuilder
    private func hangCongCu(_ f: TinhNang) -> some View {
        let nhan = Label {
            Text(f.ten)
        } icon: {
            Image(systemName: f.bieuTuong).foregroundStyle(f.mau)
        }
        Group {
            if f.cachMo == .day {
                NavigationLink(value: MucBen.tinhNang(f)) { nhan }
            } else {
                // AI Chat, Ghi chú, Cài đặt… trình bày từ gốc; CT Work mở app
                // riêng — không phải một "trang" để chọn ở cột chi tiết.
                Button { appState.moTinhNang(f) } label: { nhan }
                    .foregroundColor(AppColors.textPrimary)
            }
        }
        .contextMenu {
            if f.cachMo == .day { nutCuaSoMoi(.tinhNang(f)) }
            Button(role: .destructive) { ghim.boGhim(f) } label: {
                Label(T("Bỏ ghim"), systemImage: "pin.slash")
            }
        }
    }

    @ViewBuilder
    private func nutCuaSoMoi(_ muc: MucBen) -> some View {
        if nhieuCuaSoDuoc {
            Button {
                moCuaSo(id: "cua-so-phu", value: muc)
            } label: {
                Label(T("Mở trong cửa sổ mới"), systemImage: "macwindow.badge.plus")
            }
        }
    }

    @ViewBuilder
    private var chiTiet: some View {
        switch appState.mucBenRieng {
        case .tinhNang(let f)?:
            NavigationStack { ManTinhNang(tinhNang: f) }
                .id(f)   // đổi công cụ ⇒ stack mới, không mang màn con của công cụ trước
        case .tatCa?:
            NavigationStack { TatCaView() }
        case .tab(let t)?:
            ManCuaTab(tab: t)
        case nil:
            ManCuaTab(tab: appState.selectedTab)
        }
    }

    private func nhatTinhNang() {
        guard let d = appState.dichCanMo else { return }
        appState.dichCanMo = nil
        switch d {
        case .tinhNang(let f): appState.mucBenRieng = .tinhNang(f)
        case .tatCa: appState.mucBenRieng = .tatCa
        }
    }

    /// ⚠️ Cột trái phải đọc/ghi THẲNG `appState`, không được giữ `@State`
    /// riêng. Thông báo đẩy (`ThongBaoDay.apDungDinhTuyen`) và màn Thông báo
    /// điều hướng bằng cách ĐẶT `appState.selectedTab`; một bản sao riêng nuốt
    /// trọn những lệnh đó — chạm thông báo thì không có gì xảy ra và không có
    /// lỗi nào để thấy. Bản macOS cũ đúng là đang dính lỗi này.
    private var mucDangChon: Binding<MucBen?> {
        Binding(get: { appState.mucBenRieng ?? .tab(appState.selectedTab) },
                set: { moi in
                    switch moi {
                    case .tab(let t)?: appState.selectedTab = t   // didSet xoá mục riêng
                    case .tinhNang(let f)?:
                        if f.cachMo == .day { appState.mucBenRieng = .tinhNang(f) }
                        else { appState.moTinhNang(f) }
                    case .tatCa?: appState.mucBenRieng = .tatCa
                    case nil: break
                    }
                })
    }
}

/// Màn của MỘT điểm đến chính. Mỗi màn TỰ mang `NavigationStack` của nó.
/// Tách khỏi `BoCucCotDoi` vì thanh tab iPhone và cửa sổ PHỤ cũng dựng đúng
/// những màn này — hai bản `switch` song song là kiểu thêm module mới rồi
/// quên một bên, và bên quên sẽ im lặng hiện màn trống.
struct ManCuaTab: View {
    let tab: AppState.AppTab
    /// Cửa sổ phụ: Hôm nay KHÔNG dùng stack chung `appState.duongHomNay`
    /// (không thì đẩy màn ở cửa sổ này, cửa sổ kia nhảy theo).
    var laCuaSoPhu = false

    @ViewBuilder
    var body: some View {
        switch tab {
        case .homNay:
            #if DEBUG
            if KhungXemThu.dangBat { ThuTongQuan(kieu: .day) } else { TongQuanView(dungDuongChung: !laCuaSoPhu) }
            #else
            TongQuanView(dungDuongChung: !laCuaSoPhu)
            #endif
        case .bangTin: HomeView()
        case .hoc: CoursesView()
        case .tinNhan:
            // MessagesView carries its own NavigationStack + NavigationLink,
            // so it drives push-to-chat inside the split-view detail column.
            MessagesView()
        case .toi: ProfileView()
        }
    }
}

/// Màn của cửa sổ PHỤ (`WindowGroup(id: "cua-so-phu")`).
///
/// ⚠️ Bản cũ bọc `NavigationStack { ManCuaTab(tab) }` — mà màn của tab nào
/// cũng tự mang stack ⇒ hai stack lồng nhau trong mọi cửa sổ phụ. Ở đây chỉ
/// TÍNH NĂNG (dạng nội dung) mới được bọc.
struct ManCuaSo: View {
    let muc: MucBen

    var body: some View {
        switch muc {
        case .tab(let t):
            ManCuaTab(tab: t, laCuaSoPhu: true)
        case .tinhNang(let f):
            NavigationStack { ManTinhNang(tinhNang: f) }
        case .tatCa:
            NavigationStack { TatCaView() }
        }
    }
}
