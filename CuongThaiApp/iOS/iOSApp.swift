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

    init() { NhatKy.xoaCu() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                // Google trả người dùng về app qua URL scheme riêng. Thiếu
                // dòng này thì luồng đăng nhập mở ra được, người dùng chọn
                // xong tài khoản, rồi app KHÔNG bao giờ nhận lại kết quả.
                .onOpenURL { url in
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
    }
}
