import Foundation
#if os(iOS)
import UIKit
import UserNotifications

/// Đăng ký thông báo đẩy và gửi thẻ thiết bị về máy chủ.
///
/// ⚠️ Chuỗi việc này có BỐN chỗ có thể đứt, và không chỗ nào báo lỗi ra màn
/// hình. Nếu thông báo không tới, soi log `[day]` để biết đứt ở đâu:
///   1. Người dùng chưa cho phép → không có thẻ
///   2. Thiếu entitlement `aps-environment` → gọi xong im lặng
///   3. App ID chưa bật Push Notifications ở Developer portal → Apple từ chối
///   4. Máy chủ chưa cắm khoá APNs → có thẻ nhưng không ai gửi
@MainActor
final class ThongBaoDay: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = ThongBaoDay()

    @Published private(set) var daChoPhep = false
    /// Thẻ nhận được nhưng CHƯA gửi được lên máy chủ (chưa đăng nhập chẳng
    /// hạn) — giữ lại để gửi sau, đừng vứt.
    private var theChoGui: String?

    private override init() { super.init() }

    func khoiDong() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Hỏi quyền rồi đăng ký. Gọi SAU khi đăng nhập, không phải lúc mở app lần
    /// đầu — hỏi quyền trước khi người dùng hiểu app làm gì thì đa số bấm
    /// "Không cho phép", và iOS KHÔNG cho hỏi lại lần hai.
    func xinQuyenVaDangKy() async {
        let tt = UNUserNotificationCenter.current()
        do {
            let ok = try await tt.requestAuthorization(options: [.alert, .sound, .badge])
            daChoPhep = ok
            guard ok else {
                print("[day] người dùng từ chối quyền thông báo")
                return
            }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            print("[day] xin quyền hỏng: \(error.localizedDescription)")
        }
    }

    /// Gọi từ `AppDelegate` khi Apple trả thẻ về.
    func nhanThe(_ data: Data) {
        let the = data.map { String(format: "%02x", $0) }.joined()
        print("[day] nhận thẻ \(the.prefix(12))…")
        theChoGui = the
        Task { await guiThe() }
    }

    /// Gọi lại sau khi đăng nhập — thẻ có thể đã về TRƯỚC lúc có token.
    func guiLaiNeuCan() {
        guard theChoGui != nil else { return }
        Task { await guiThe() }
    }

    private func guiThe() async {
        guard let the = theChoGui else { return }
        guard AppState.shared.currentUser != nil else {
            print("[day] chưa đăng nhập — giữ thẻ, gửi sau")
            return
        }
        do {
            let _: EmptyResponse = try await APIClient.shared
                .request(.dangKyThietBi(token: the, sandbox: Self.laBanThuNghiem))
            print("[day] đã gửi thẻ lên máy chủ")
            theChoGui = nil
        } catch {
            print("[day] gửi thẻ hỏng: \(error.localizedDescription)")
        }
    }

    /// Gỡ thẻ khi đăng xuất — không thì thông báo của người cũ vẫn tới máy.
    func goThe() async {
        guard let the = theChoGui else { return }
        _ = try? await APIClient.shared.send(.goThietBi(token: the))
    }

    /// Bản chạy thẳng từ Xcode dùng máy chủ push SANDBOX; bản TestFlight và
    /// App Store dùng PRODUCTION. Gửi nhầm máy chủ thì Apple trả
    /// `BadDeviceToken` và thông báo im lặng không tới nơi.
    ///
    /// Nhận biết bằng hồ sơ cấp phép: bản Debug có `embedded.mobileprovision`,
    /// bản App Store thì KHÔNG. TestFlight có, nhưng nó dùng production — nên
    /// phải loại trừ bằng biên dịch điều kiện.
    static var laBanThuNghiem: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: Người dùng chạm vào thông báo

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let loai = info["loai"] as? String else { return }
        await MainActor.run {
            switch loai {
            case "tin-nhan":
                AppState.shared.selectedTab = .messages
                if let tid = info["threadId"] as? Int {
                    AppState.shared.hoiThoaiCanMo = tid
                }
            default:
                break
            }
        }
    }

    /// Đang mở app mà có thông báo tới thì vẫn hiện banner — trừ khi người
    /// dùng đang ở ĐÚNG hội thoại đó, lúc ấy tin đã hiện trong khung chat rồi.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let info = notification.request.content.userInfo
        let tid = info["threadId"] as? Int
        let dangMo = await MainActor.run { AppState.shared.hoiThoaiDangMo }
        if let tid, tid == dangMo { return [] }
        return [.banner, .sound, .badge]
    }
}
#endif
