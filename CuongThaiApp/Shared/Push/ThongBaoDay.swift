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
    /// App Store dùng PRODUCTION. Gửi nhầm máy chủ thì Apple im lặng không
    /// giao, và KHÔNG có lỗi nào ở bất kỳ đâu để thấy.
    ///
    /// ⚠️ TRƯỚC ĐÂY dùng `#if DEBUG` và nó SAI: `SWIFT_ACTIVE_COMPILATION_-
    /// CONDITIONS: DEBUG` bị khai trong settings GỐC của target nên áp cho cả
    /// Release — bản TestFlight vẫn báo `sandbox: true`, gửi vào máy chủ thử
    /// nghiệm, và người dùng TestFlight không nhận được thông báo nào.
    ///
    /// Nay đọc THẲNG `aps-environment` trong hồ sơ cấp phép nhúng trong gói.
    /// Đó chính là giá trị Apple dùng để quyết định máy chủ nào, nên nó không
    /// thể lệch với thực tế dù cờ biên dịch có sai thế nào.
    ///   • có `aps-environment = development`  → sandbox
    ///   • `production`, hoặc KHÔNG có hồ sơ (bản App Store) → production
    static let laBanThuNghiem: Bool = {
        guard let duong = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let tho = try? Data(contentsOf: URL(fileURLWithPath: duong)),
              // Hồ sơ là CMS ký, không phải plist thuần — nhưng phần plist nằm
              // dạng chữ bên trong nên đọc theo chuỗi là đủ và không cần thư
              // viện mã hoá nào.
              let chu = String(data: tho, encoding: .isoLatin1),
              let r = chu.range(of: "aps-environment")
        else {
            // Không có hồ sơ nhúng = bản tải từ App Store ⇒ production.
            print("[day] không thấy hồ sơ cấp phép — coi là production")
            return false
        }
        let sau = chu[r.upperBound...].prefix(200)
        let la = sau.contains("development")
        print("[day] môi trường đẩy: \(la ? "sandbox (development)" : "production")")
        return la
    }()

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
