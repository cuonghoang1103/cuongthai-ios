import Foundation
import UserNotifications

/// Nhắc VIỆC bằng thông báo cục bộ.
///
/// ⚠️ TRƯỚC ĐÂY `remindAt` ĐƯỢC LƯU MÀ KHÔNG AI DÙNG. App cho người dùng đặt
/// giờ nhắc cho một việc, máy chủ lưu tử tế, và rồi **không có lời nhắc nào
/// từng kêu**. Không lỗi, không thông báo — chỉ là một lời hứa suông. Tìm ra
/// 10/09/2026 khi rà lại toàn bộ đường nhắc nhở.
///
/// Đi theo đúng khuôn `NhacHoc`: thông báo CỤC BỘ do hệ điều hành giữ, không
/// cần cron ở máy chủ, không cần thẻ thiết bị còn sống, và mất mạng vẫn kêu.
///
/// Khác `NhacHoc` ở một điểm: việc xảy ra ĐÚNG MỘT LẦN vào một ngày cụ thể,
/// nên `repeats: false` và hệ điều hành tự dọn sau khi nó kêu.
enum NhacViec {
    private static let tienTo = "viec-"

    /// Đặt lại TOÀN BỘ lời nhắc theo danh sách việc hiện tại.
    ///
    /// Xoá hết rồi đặt lại, không cố sửa từng cái — cùng lý do với `NhacHoc`:
    /// việc bị xoá, đổi giờ, hay vừa đánh dấu xong thì dò từng nhánh là mỗi
    /// nhánh bỏ sót một lời nhắc ma còn kêu sau khi việc đã xong.
    static func datLai(_ ds: [ViecTongQuan]) async {
        let tt = UNUserNotificationCenter.current()
        let cho = await tt.pendingNotificationRequests()
        tt.removePendingNotificationRequests(withIdentifiers:
            cho.map(\.identifier).filter { $0.hasPrefix(tienTo) })

        let bayGio = Date()
        let can = ds.compactMap { v -> (ViecTongQuan, Date)? in
            // Việc ĐÃ XONG thì không nhắc nữa — đây là nửa còn lại của lời
            // hứa: nhắc đúng lúc, và im khi không cần.
            guard !v.done, let s = v.remindAt, let luc = moc(s) else { return nil }
            // Mốc đã qua thì hệ điều hành lặng lẽ bỏ qua yêu cầu; lọc ở đây
            // để không tưởng là đã đặt được.
            guard luc > bayGio else { return nil }
            return (v, luc)
        }
        guard !can.isEmpty else { return }
        guard await xinQuyen() else { return }

        for (v, luc) in can {
            let nd = UNMutableNotificationContent()
            nd.title = T("Nhắc việc")
            nd.body = v.title
            nd.sound = .default
            nd.userInfo = ["loai": "viec", "id": v.id]
            let kh = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: luc)
            let r = UNNotificationRequest(
                identifier: "\(tienTo)\(v.id)",
                content: nd,
                trigger: UNCalendarNotificationTrigger(dateMatching: kh, repeats: false))
            try? await tt.add(r)
        }
    }

    /// Đọc mốc `remindAt` từ máy chủ.
    ///
    /// ⚠️ Máy chủ trả ISO-8601 có múi giờ (`...Z` hoặc `+07:00`). Cắt chuỗi
    /// rồi tự ghép ngày giờ là mời một lỗi lệch 7 tiếng vào đúng chỗ khó thấy
    /// nhất — dùng bộ đọc chuẩn và để nó lo múi giờ.
    static func moc(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    private static func xinQuyen() async -> Bool {
        let tt = UNUserNotificationCenter.current()
        let tt2 = await tt.notificationSettings()
        if tt2.authorizationStatus == .authorized || tt2.authorizationStatus == .provisional { return true }
        if tt2.authorizationStatus == .denied { return false }
        return (try? await tt.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
}
