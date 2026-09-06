import Foundation
import UserNotifications

/// Nhắc đi học bằng thông báo CỤC BỘ lặp hằng tuần.
///
/// Vì sao cục bộ chứ không đẩy từ máy chủ: thời khoá biểu là lịch CỐ ĐỊNH theo
/// tuần, biết trước hàng tháng. Đẩy từ máy chủ thì cần một cron chạy mỗi phút,
/// cần thẻ thiết bị còn sống, và mất mạng là mất lời nhắc — đúng lúc người
/// dùng đang trên đường tới trường. `UNCalendarNotificationTrigger` với
/// `repeats: true` do hệ điều hành giữ, không cần app chạy, không cần mạng.
enum NhacHoc {
    /// Tiền tố id để gỡ đúng nhóm của mình, không đụng thông báo khác của app.
    private static let tienTo = "buoihoc-"

    /// Đặt lại TOÀN BỘ lời nhắc theo danh sách buổi học hiện tại.
    ///
    /// Xoá hết rồi đặt lại, không cố sửa từng cái: buổi học đổi giờ, đổi thứ,
    /// bị xoá, hết kỳ — dò xem cái nào cần sửa thì phức tạp hơn và mỗi nhánh
    /// bỏ sót là một lời nhắc ma còn kêu sau khi môn đã hết.
    static func datLai(_ ds: [BuoiHoc]) async {
        let tt = UNUserNotificationCenter.current()
        let cho = await tt.pendingNotificationRequests()
        tt.removePendingNotificationRequests(withIdentifiers:
            cho.map(\.identifier).filter { $0.hasPrefix(tienTo) })

        let can = ds.filter { $0.remindMinutes > 0 && conTrongKy($0) }
        guard !can.isEmpty else { return }

        // Chỉ xin quyền khi THẬT SỰ có gì để nhắc. Hỏi lúc mở app lần đầu,
        // trước khi người dùng nhập buổi học nào, thì họ không hiểu vì sao và
        // bấm Từ chối — mà từ chối rồi thì chỉ có vào Cài đặt iOS mới bật lại.
        guard await xinQuyen() else { return }

        for b in can {
            guard let r = yeuCau(b) else { continue }
            try? await tt.add(r)
        }
    }

    static func xoaHet() async {
        let tt = UNUserNotificationCenter.current()
        let cho = await tt.pendingNotificationRequests()
        tt.removePendingNotificationRequests(withIdentifiers:
            cho.map(\.identifier).filter { $0.hasPrefix(tienTo) })
    }

    // MARK: Riêng

    private static func xinQuyen() async -> Bool {
        let tt = UNUserNotificationCenter.current()
        let ht = await tt.notificationSettings()
        switch ht.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default:
            return (try? await tt.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    /// Còn trong kỳ học không. Hết kỳ thì thôi nhắc — không cần ai nhớ đi xoá.
    private static func conTrongKy(_ b: BuoiHoc) -> Bool {
        let f = PhamViViec.dinhDang
        let homNay = f.string(from: Date())
        if let t = b.startDate, t.count >= 10, String(t.prefix(10)) > homNay { return false }
        if let d = b.endDate, d.count >= 10, String(d.prefix(10)) < homNay { return false }
        return true
    }

    private static func yeuCau(_ b: BuoiHoc) -> UNNotificationRequest? {
        let p = b.startTime.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return nil }

        // Trừ ngược số phút nhắc trước. Có thể lùi qua nửa đêm ⇒ lùi luôn THỨ.
        // Không xử lý chỗ này thì "nhắc trước 60 phút" cho buổi 00:30 sẽ đặt
        // vào -30 phút và hệ điều hành lặng lẽ bỏ qua yêu cầu.
        var tong = p[0] * 60 + p[1] - b.remindMinutes
        var thu = b.weekday
        while tong < 0 {
            tong += 24 * 60
            thu = thu == BuoiHoc.thuNho ? BuoiHoc.thuLon : thu - 1
        }

        var kh = DateComponents()
        // `DateComponents.weekday` là hệ 1 = Chủ nhật … 7 = thứ Bảy, KHÁC hệ
        // 2..8 của ta. Đây là chỗ DUY NHẤT đổi ngược lại.
        kh.weekday = thu == BuoiHoc.thuLon ? 1 : thu
        kh.hour = tong / 60
        kh.minute = tong % 60

        let nd = UNMutableNotificationContent()
        nd.title = b.remindMinutes > 0
            ? String(format: T("%@ — %d phút nữa"), b.subject, b.remindMinutes)
            : b.subject
        var dong: [String] = ["\(b.startTime)–\(b.endTime)"]
        if let r = b.room, !r.isEmpty { dong.append(r) }
        if let g = b.teacher, !g.isEmpty { dong.append(g) }
        nd.body = dong.joined(separator: " · ")
        nd.sound = .default
        nd.userInfo = ["loai": "buoi-hoc", "id": b.id]

        return UNNotificationRequest(
            identifier: "\(tienTo)\(b.id)",
            content: nd,
            trigger: UNCalendarNotificationTrigger(dateMatching: kh, repeats: true))
    }
}
