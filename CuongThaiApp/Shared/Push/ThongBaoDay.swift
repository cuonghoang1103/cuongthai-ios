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

    // MARK: Định tuyến chờ từ cú chạm thông báo

    /// ⚠️⚠️ VÌ SAO PHẢI "CẤT RỒI ÁP SAU" — ĐỌC TRƯỚC KHI SỬA LẠI THÀNH GỌI THẲNG
    ///
    /// Bản cũ đổi `AppState.shared.selectedTab` NGAY trong callback
    /// `didReceive`. Biến đó là `@Published` → SwiftUI đổi tab → UIKit chụp
    /// snapshot — trong khi scene CHƯA active (app vừa được cú chạm dựng dậy).
    /// UIKit nổ NSAssertion và app SẬP. Biên bản 21/08/2026, 9 lần từ 01:46
    /// tới 03:41, vết ném nào cũng một khuôn:
    ///
    ///   @objc closure #1 in ThongBaoDay.userNotificationCenter(_:didReceive:)
    ///     → _updateStateRestorationArchiveForBackgroundEvent…
    ///     → NSAssertionHandler → abort
    ///
    /// Người dùng thấy "chạm thông báo thì app không mở, vào lại bằng icon
    /// thì đứng ở Trang chủ" — vì app chết trước khi kịp vẽ gì.
    ///
    /// Luật: trong callback CHỈ ghi hai biến thường dưới đây (không ai quan
    /// sát ⇒ không SwiftUI ⇒ không UIKit). Việc đổi tab dời sang
    /// `apDungDinhTuyen()`, gọi từ ba chỗ đều đã an toàn:
    ///   • `.task` của iOSTabView        — mở nguội từ thông báo
    ///   • `scenePhase == .active`       — app từ nền quay lại
    ///   • Task trễ 150ms trong callback — chạm banner khi app ĐANG mở
    ///     (không có chuyển scene nào sắp xảy ra nên hai móc trên im lặng)
    @MainActor private static var canVaoTabTinNhan = false
    @MainActor private static var hoiThoaiCho: Int?

    @MainActor static func catDinhTuyen(threadId: Int?) {
        canVaoTabTinNhan = true
        hoiThoaiCho = threadId
        NhatKy.thongBao.info("cất định tuyến — hội thoại \(threadId.map(String.init) ?? "(không rõ)")")
    }

    /// Idempotent: áp xong tự xoá, ba móc có gọi chồng cũng chỉ áp một lần.
    @MainActor static func apDungDinhTuyen() {
        guard canVaoTabTinNhan else { return }
        canVaoTabTinNhan = false
        let tid = hoiThoaiCho
        hoiThoaiCho = nil
        NhatKy.thongBao.info("ÁP định tuyến — mở tab Tin nhắn, hội thoại \(tid.map(String.init) ?? "(không)")")
        AppState.shared.selectedTab = .messages
        if let tid { AppState.shared.hoiThoaiCanMo = tid }
    }

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

    /// ⚠️⚠️ PHẢI là dạng COMPLETION HANDLER, KHÔNG được đổi về dạng `async`.
    ///
    /// Dạng `nonisolated ... async` chạy trên executor NỀN, nên đoạn mã trình
    /// biên dịch tự sinh để gọi completion của UIKit cũng chạy NGOÀI luồng
    /// chính. Khi app được cú chạm dựng dậy từ trạng thái TẮT HẲN, UIKit chạy
    /// máy snapshot ngay trong completion (`_updateStateRestorationArchiveFor
    /// BackgroundEvent…`), đòi luồng chính, không được là nổ NSAssertion —
    /// app sập TRƯỚC khi kịp vẽ gì. 12+ biên bản ngày 21/08/2026.
    ///
    /// Bản 14 đã chứng minh bằng phép loại trừ: thân hàm chỉ ghi hai biến
    /// thường mà vẫn sập y hệt ⇒ lỗi nằm ở CÁCH KHAI, không ở thân hàm.
    /// Chạm lúc app còn ở NỀN thì không sập (đường snapshot đó không chạy) —
    /// vì thế lỗi này trông như "lúc được lúc không" nếu không đọc biên bản.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        // `threadId` có thể về dạng Int, NSNumber hoặc chuỗi tuỳ đường đi.
        let tid = (info["threadId"] as? Int)
            ?? (info["threadId"] as? NSNumber)?.intValue
            ?? Int((info["threadId"] as? String) ?? "")
        let loai = info["loai"] as? String
        // Về luồng CHÍNH rồi mới làm gì và mới gọi completion — đây là toàn
        // bộ bản vá. `main.async` chứ không gọi thẳng: tách hẳn khỏi lượt
        // giao dịch CATransaction mà UIKit đang giữ khi gọi mình.
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                NhatKy.thongBao.info("didReceive CHẠY — loai=\(loai ?? "(không có)") · threadId=\(tid.map(String.init) ?? "(không đọc được)")")
                if loai == "tin-nhan" || tid != nil {
                    // CHỈ CẤT — đổi tab dời sang `apDungDinhTuyen`, chạy khi
                    // scene đã active.
                    Self.catDinhTuyen(threadId: tid)
                    #if canImport(UIKit)
                    // Chạm banner khi app ĐANG mở: scene không đổi trạng thái
                    // nên các móc kia im lặng — tự áp sau khi mọi thứ đã yên.
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        if UIApplication.shared.applicationState == .active {
                            Self.apDungDinhTuyen()
                        }
                    }
                    #endif
                }
                completionHandler()
            }
        }
    }

    /// Đang mở app mà có thông báo tới thì vẫn hiện banner — trừ khi người
    /// dùng đang ở ĐÚNG hội thoại đó, lúc ấy tin đã hiện trong khung chat rồi.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Cùng bệnh với `didReceive`: dạng async trả completion NGOÀI luồng
        // chính ⇒ UIKit sập. Banner lúc app đang mở đi qua hàm này.
        let info = notification.request.content.userInfo
        let tid = (info["threadId"] as? Int)
            ?? (info["threadId"] as? NSNumber)?.intValue
            ?? Int((info["threadId"] as? String) ?? "")
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                // Đang đứng ĐÚNG hội thoại đó thì tin đã hiện trong khung chat
                // — banner chỉ thừa. Còn lại vẫn báo đầy đủ.
                if let tid, tid == AppState.shared.hoiThoaiDangMo {
                    completionHandler([])
                } else {
                    completionHandler([.banner, .sound, .badge])
                }
            }
        }
    }
}
#endif
