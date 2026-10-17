import Foundation
import UIKit
import UserNotifications

// MARK: - Thông báo đẩy của app CT Work
//
// Đăng ký thẻ APNs với `POST /api/v1/devices` — CÙNG đường của app chính,
// thân `{ token, sandbox, platform: 'ios', app: 'com.cuongthai.ctwork' }`.
// Trường `app` (danh sách trắng ở máy chủ, 17/10/2026) cho máy chủ biết thẻ
// này của app CT Work ⇒ gửi với `apns-topic` = bundle này, chỉ thông báo
// `WORK_*`; huy hiệu chỉ đếm `WORK_*` chưa đọc. Người chưa cài app này vẫn
// nhận thông báo CT Work ở app chính như cũ.
// Gói đẩy: `kieu` (WORK_ASSIGN…), `thongBaoId`, `duongDan` (/work/…), `maThe`
// (NW-12) ⇒ chạm vào mở đúng thẻ / kênh.

@MainActor
final class DayCTW: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = DayCTW()
    static let maApp = "com.cuongthai.ctwork"

    private var the: String?
    /// Đường dẫn chờ mở (chạm thông báo lúc app vừa được dựng dậy). Áp ở
    /// `apDung()` — đổi `@Published` ngay trong callback lúc scene chưa
    /// active là UIKit nổ assertion (bài học app chính 21/08/2026).
    private static var duongCho: String?

    func khoiDong() {
        UNUserNotificationCenter.current().delegate = self
        // Nút ngay trên thông báo (Reply / Mark as Read / Approve / Reject) — Modules/Inbox.
        NutThongBaoCTW.dangKy()
    }

    func xinQuyenVaDangKy() async {
        #if DEBUG
        if AppState.shared.cheDoXemThu { return }
        #endif
        let tt = await UNUserNotificationCenter.current().notificationSettings()
        if tt.authorizationStatus == .notDetermined {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        }
        let sau = await UNUserNotificationCenter.current().notificationSettings()
        guard sau.authorizationStatus == .authorized || sau.authorizationStatus == .provisional else { return }
        UIApplication.shared.registerForRemoteNotifications()
        if the != nil { await gui() }
    }

    func nhanThe(_ d: Data) {
        the = d.map { String(format: "%02x", $0) }.joined()
        Task { await gui() }
    }

    private func gui() async {
        guard let the, AppState.shared.isAuthenticated else { return }
        _ = try? await APIClient.shared.send(.tuyChinh(
            duong: "/api/v1/devices", phuongThuc: "POST",
            than: ["token": the, "platform": "ios", "sandbox": Self.laBanThuNghiem,
                   "app": Bundle.main.bundleIdentifier ?? Self.maApp]))
    }

    /// Đăng xuất ⇒ gỡ thẻ, không thì thông báo của người cũ vẫn tới máy này.
    func goTheKhiDangXuat() {
        guard let the else { return }
        Task { _ = try? await APIClient.shared.send(.goThietBi(token: the)) }
    }

    /// Đọc `aps-environment` trong hồ sơ nhúng — đúng giá trị Apple dùng để
    /// chọn máy chủ. Không có hồ sơ (bản App Store) ⇒ production.
    static let laBanThuNghiem: Bool = {
        guard let p = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let d = try? Data(contentsOf: URL(fileURLWithPath: p)),
              let s = String(data: d, encoding: .isoLatin1),
              let r = s.range(of: "aps-environment") else { return false }
        return s[r.upperBound...].prefix(200).contains("development")
    }()

    static func datHuyHieu(_ so: Int) {
        UNUserNotificationCenter.current().setBadgeCount(max(0, so))
    }

    // MARK: Chạm thông báo

    static func apDung() {
        guard let d = duongCho else { return }
        duongCho = nil
        DinhTuyenCTW.mo(duongDan: d)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
        Task { @MainActor in await AppState.shared.taiSoChuaDoc() }
    }

    /// ⚠️ Dạng COMPLETION HANDLER, không `async` (bài học app chính: dạng
    /// async chạy completion ngoài luồng chính khi app được dựng dậy ⇒ sập).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        // Nút hành động (trả lời / đã đọc / duyệt) chạy NỀN, không mở màn — xong mới báo hệ thống.
        if NutThongBaoCTW.laNutCuaCTW(response.actionIdentifier) {
            let nut = response.actionIdentifier
            let chu = (response as? UNTextInputNotificationResponse)?.userText
            let id = (info["thongBaoId"] as? Int) ?? Int("\(info["thongBaoId"] ?? "")")
            let duongDan = info["duongDan"] as? String
            let aid = info["approvalId"] as? Int
            DispatchQueue.main.async {
                NutThongBaoCTW.xuLy(nut: nut, thongBaoId: id, duongDan: duongDan, approvalId: aid, chu: chu, xong: completionHandler)
            }
            return
        }
        let duong = info["duongDan"] as? String
        let maThe = info["maThe"] as? String
        completionHandler()
        // Có `duongDan` thì theo nó (mở cả kênh chat); chỉ có `maThe` thì tìm thẻ theo mã.
        guard let duong = duong ?? maThe.map({ "ctwork://issue/" + $0 }) else { return }
        DispatchQueue.main.async {
            DayCTW.duongCho = duong
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { DayCTW.apDung() }
        }
    }
}
