import SwiftUI
import UIKit

/// Thông báo đẩy BẮT BUỘC phải qua `UIApplicationDelegate` — SwiftUI thuần
/// không có chỗ nào nhận được thẻ thiết bị mà Apple trả về.
final class AppDelegate: NSObject, UIApplicationDelegate {
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
                    ThongBaoDay.shared.khoiDong()
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
