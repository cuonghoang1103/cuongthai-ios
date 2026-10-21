import SwiftUI
import UIKit
import CoreSpotlight

/// Thông báo đẩy BẮT BUỘC qua `UIApplicationDelegate`. Delegate thông báo đặt
/// NGAY ở `didFinishLaunching` — chạm thông báo lúc app tắt thì iOS giao cú
/// chạm trong lúc khởi động, trước khi SwiftUI dựng view (bài học app chính).
final class AppDelegateCTW: NSObject, UIApplicationDelegate {
    @MainActor
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        DayCTW.shared.khoiDong()
        // Mảng D: Live Activity + widget đồng hồ nghe `DongHoCTW`; nút trên Live Activity chạy ở đây.
        LiveActivityDongHoCTW.khoiDong()
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
        // Ngôn ngữ (Account › Language): tráo Bundle.main + locale hiển thị TRƯỚC khi dựng view nào.
        NgonNguApCTW.khoiDong()
        #if DEBUG
        XemThuCTW.batNeuCan()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            GocCTW()
                .environmentObject(appState)
                // Khoá Face ID (tuỳ chọn, mặc định TẮT — Account → Security).
                .overlay { KhoaAppCTW() }
                .tint(AppColors.primary)
                .onOpenURL { DinhTuyenCTW.mo(url: $0) }
                // Universal Link https://cuongthai.com/work/... (cần AASA ở máy chủ).
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { act in
                    if let u = act.webpageURL { DinhTuyenCTW.mo(url: u) }
                }
                // Spotlight: chạm một thẻ đã xem gần đây.
                .onContinueUserActivity(CSSearchableItemActionType) { act in
                    if let id = act.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                       let d = CTWChiaSeNhom.duongDanTuSpotlight(id) { DinhTuyenCTW.mo(duongDan: d) }
                }
                .onChange(of: scenePhase) { _, moi in
                    KhoaAppCTW.doiPha(moi)
                    guard appState.isAuthenticated else { return }
                    if moi == .background { CTWChiaSeNhom.dongBoToken(); NhipHoatDongCTW.shared.dungLai() }
                    guard moi == .active else { return }
                    NhipHoatDongCTW.shared.batDau()   // "Đang hoạt động" cho đồng nghiệp (Thành viên) — POST /users/status
                    DayCTW.apDung()
                    CTWChiaSeNhom.dongBoToken()
                    Task {
                        await appState.taiSoChuaDoc()
                        await DongHoCTW.shared.taiLai()
                        await CTWChiaSeNhom.lamMoiViecHomNay()
                    }
                }
        }
    }
}
