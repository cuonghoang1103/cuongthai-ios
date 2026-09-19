import SwiftData
import SwiftUI
import UIKit

/// Thông báo đẩy BẮT BUỘC phải qua `UIApplicationDelegate` — SwiftUI thuần
/// không có chỗ nào nhận được thẻ thiết bị mà Apple trả về.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// ⚠️⚠️ DELEGATE THÔNG BÁO PHẢI ĐẶT Ở ĐÂY, KHÔNG PHẢI TRONG `.task` CỦA VIEW.
    ///
    /// Chạm một thông báo lúc app đang tắt thì iOS giao cú chạm đó NGAY trong
    /// lúc khởi động — trước khi SwiftUI kịp dựng view, nên trước cả `.task`.
    /// Chưa có delegate ở thời điểm ấy thì iOS VỨT LUÔN cú chạm, không giữ lại
    /// và cũng không báo lỗi gì.
    ///
    /// Triệu chứng đúng như người dùng gặp: chạm thông báo tin nhắn thì app mở
    /// ra ở Trang chủ, không vào đoạn chat. Đo thật 21/08/2026: dòng nhật ký
    /// "CHẠM thông báo" KHÔNG hề xuất hiện — hàm xử lý chưa từng chạy, chứ
    /// không phải chạy rồi định tuyến sai.
    /// ⚠️ Chữ ký phải khớp CHÍNH XÁC `application:didFinishLaunchingWithOptions:`.
    /// Bản trước tôi viết `= nil` cho tham số — Swift sinh thêm một hàm nạp
    /// chồng và selector không còn khớp cái iOS gọi, nên app không khởi động
    /// theo đường thông báo nữa. KHÔNG đặt giá trị mặc định ở đây.
    @MainActor
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NhatKy.thongBao.info("didFinishLaunching — đặt delegate thông báo")
        ThongBaoDay.shared.khoiDong()
        return true
    }

    func application(_ app: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        Task { @MainActor in ThongBaoDay.shared.nhanThe(token) }
    }

    func application(_ app: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Hay gặp nhất: chạy trên MÁY MÔ PHỎNG (không có APNs), hoặc App ID
        // chưa bật Push Notifications ở Developer portal.
        print("[day] đăng ký thất bại: \(error.localizedDescription)")
    }
}

@main
struct CuongThaiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var appState = AppState.shared
    @StateObject private var giaoDien = QuanLyGiaoDien.shared
    @StateObject private var ngonNgu = QuanLyNgonNguApp.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NhatKy.xoaCu()
        // ⚠️ Phải nghe `Transaction.updates` từ lúc app mở, KHÔNG đợi người
        // dùng vào màn mua. Đó là đường Apple giao những giao dịch xảy ra
        // ngoài app: mua lúc app đang tắt, "Hỏi để mua" được phụ huynh duyệt
        // sau, gia hạn, và lượt mua lần trước chưa `finish()` vì mất mạng.
        // Nghe muộn thì những giao dịch đó nằm lại hàng đợi — người dùng đã
        // trả tiền mà không thấy Pro đâu.
        KhoPro.shared.batDauNghe()
    }

    /// Bọc chuỗi link thành `Identifiable` để dùng với `.sheet(item:)`.
    private struct LienChiaSe: Identifiable {
        let lien: String
        var id: String { lien }
        init(_ l: String) { lien = l }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                // Kho Vở (SwiftData). Gắn ở gốc để mọi màn con — kể cả màn
                // viết mở bằng `fullScreenCover` — đều thấy cùng một kho.
                .modelContainer(KhoSwiftData.chung)
                // Bảng "Thêm video" mở từ GỐC, không từ màn Học bằng video:
                // người dùng bấm chia sẻ khi đang ở bất kỳ tab nào, và bắt họ
                // tự đi tìm đúng màn thì coi như tính năng không có.
                .sheet(item: Binding(
                    get: { appState.videoChoThem.map(LienChiaSe.init) },
                    set: { appState.videoChoThem = $0?.lien })
                ) { l in
                    ThemVideoView(lienSan: l.lien) { }
                }
                // Cuộc gọi tới phải reo dù người dùng đang ở màn nào.
                .lopPhuCuocGoi()
                // `nil` = để iOS quyết định. Màu của app vốn đã thích ứng nên
                // chỉ cần một dòng này là cả app đổi theo.
                .preferredColorScheme(giaoDien.mauSac)
                // ⚠️ `.id(...)` dựng lại TOÀN BỘ cây khi đổi ngôn ngữ.
                //
                // `T(...)` là hàm thường, không phải `@Published`, nên
                // SwiftUI không có cách nào biết chữ vừa đổi — thiếu dòng này
                // thì bấm sang English xong màn hình vẫn y nguyên tiếng Việt
                // cho tới khi vô tình chuyển màn. Cái giá: trạng thái tạm của
                // màn đang mở bị dựng lại. Đổi ngôn ngữ là việc hiếm, và dựng
                // lại còn ĐÚNG hơn là để nửa màn hai thứ tiếng.
                .id(ngonNgu.ngonNgu)
                .onChange(of: scenePhase) { _, moi in
                    // Máy ngủ qua mốc 6h/18h thì `Timer` không chạy — tính lại
                    // khi quay lại, không thì mở app buổi tối vẫn thấy nền sáng.
                    if moi == .active { giaoDien.lamMoiKhiTroLai() }

                    // Báo "tôi đang dùng app" cho máy chủ, và NGỪNG khi xuống
                    // nền. Thiếu nửa đầu thì với mọi người khác mình luôn
                    // ngoại tuyến; thiếu nửa sau thì mình hiện "đang hoạt
                    // động" suốt đêm trong khi máy nằm trong túi.
                    if moi == .active { BaoHoatDong.shared.batDau() }
                    else { BaoHoatDong.shared.dungLai() }

                    // Chia sẻ từ app khác: `openURL` của extension có thể bị
                    // hệ thống từ chối, nên nhặt lại mỗi lần quay lại app.
                    if moi == .active { appState.nhatVideoDuocChiaSe() }
                }
                // Google trả người dùng về app qua URL scheme riêng. Thiếu
                // dòng này thì luồng đăng nhập mở ra được, người dùng chọn
                // xong tài khoản, rồi app KHÔNG bao giờ nhận lại kết quả.
                .onOpenURL { url in
                    // `cuongthai://tien` — widget Tiền nong mở về đúng màn đó.
                    //
                    // ⚠️ Phải xử lý TRƯỚC khi chuyển cho Google: `nhanURL`
                    // nhận mọi URL rồi tự quyết, và một ngày nào đó nó nuốt
                    // nhầm thì widget chết câm mà không ai nghĩ tới đây.
                    if url.scheme == "cuongthai" {
                        if url.host == "tien" { appState.selectedTab = .finance }
                        // Share Extension đã ghi link vào nhóm ứng dụng rồi
                        // mới mở app — ở đây chỉ việc nhặt lên.
                        if url.host == "them-video" { appState.nhatVideoDuocChiaSe() }
                        return
                    }
                    _ = GoogleSignInService.nhanURL(url)
                }
                .task {
                    // `khoiDong()` đã chạy ở `didFinishLaunchingWithOptions` —
                    // xem ghi chú ở AppDelegate. Ở đây chỉ còn việc xin quyền.
                    // Chỉ xin quyền khi ĐÃ đăng nhập: hỏi lúc mở app lần đầu
                    // thì đa số bấm "Không cho phép", và iOS KHÔNG cho hỏi
                    // lại lần hai — mất luôn cơ hội.
                    if appState.currentUser != nil {
                        await ThongBaoDay.shared.xinQuyenVaDangKy()
                    }
                }
                .onChange(of: appState.currentUser?.id) { _, moi in
                    guard moi != nil else { return }
                    Task {
                        await ThongBaoDay.shared.xinQuyenVaDangKy()
                        ThongBaoDay.shared.guiLaiNeuCan()
                    }
                }
        }
        // Phím tắt ⌘1…⌘0 — xem `LenhDieuHuong`.
        .commands { LenhDieuHuong(appState: appState) }

        // CỬA SỔ PHỤ — một module tách ra cửa sổ riêng, để đặt cạnh cửa sổ
        // chính trong Stage Manager / Split View.
        //
        // ⚠️ Nó KHÔNG đọc `appState.selectedTab`. Dùng chung biến đó thì hai
        // cửa sổ luôn hiện cùng một màn, và đổi bên này là bên kia nhảy theo
        // — tức là mất sạch lý do mở cửa sổ thứ hai. Module hiện ở đây đi
        // theo GIÁ TRỊ mà `openWindow` truyền vào.
        WindowGroup(id: "cua-so-phu", for: AppState.AppTab.self) { $tab in
            NavigationStack { ManCuaTab(tab: tab ?? .notebook) }
                .environmentObject(appState)
                .modelContainer(KhoSwiftData.chung)
                .lopPhuCuocGoi()
                .preferredColorScheme(giaoDien.mauSac)
                .id(ngonNgu.ngonNgu)
        }
    }
}
