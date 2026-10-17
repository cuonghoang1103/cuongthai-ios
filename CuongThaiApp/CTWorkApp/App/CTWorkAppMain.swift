import SwiftUI
import UIKit

/// Thông báo đẩy BẮT BUỘC qua `UIApplicationDelegate`. Delegate thông báo đặt
/// NGAY ở `didFinishLaunching` — chạm thông báo lúc app tắt thì iOS giao cú
/// chạm trong lúc khởi động, trước khi SwiftUI dựng view (bài học app chính).
final class AppDelegateCTW: NSObject, UIApplicationDelegate {
    @MainActor
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        DayCTW.shared.khoiDong()
        return true
    }

    func application(_ app: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        Task { @MainActor in DayCTW.shared.nhanThe(token) }
    }

    func application(_ app: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("[ctw-day] đăng ký thất bại: \(error.localizedDescription)")
        #endif
    }
}

@main
struct CTWorkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegateCTW.self) private var delegate
    @StateObject private var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        XemThuCTW.batNeuCan()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            GocCTW()
                .environmentObject(appState)
                .tint(AppColors.primary)
                .onOpenURL { DinhTuyenCTW.mo(url: $0) }
                // Universal Link https://cuongthai.com/work/... (cần AASA ở máy chủ).
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { act in
                    if let u = act.webpageURL { DinhTuyenCTW.mo(url: u) }
                }
                .onChange(of: scenePhase) { _, moi in
                    guard moi == .active, appState.isAuthenticated else { return }
                    DayCTW.apDung()
                    Task { await appState.taiSoChuaDoc() }
                }
        }
    }
}
