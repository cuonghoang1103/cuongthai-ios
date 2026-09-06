import Foundation
import UserNotifications

/// Học ở nhà — hai thứ đánh vào đúng thói quen "về nhà là không học":
///
/// **A. Việc tự sinh sau buổi học.** Buổi nào ĐÃ KẾT THÚC hôm nay thì sinh một
/// việc "Ôn <môn> — 20 phút". Người dùng không phải nghĩ hôm nay cần ôn gì;
/// mở app ra là thấy sẵn.
///
/// **B. Một lời nhắc buổi tối** vào giờ tự chọn, nội dung NÓI RÕ hôm nay học
/// môn gì — không phải câu chung chung "đến giờ học rồi".
///
/// ⚠️ Vì sao 20 phút mà không phải 2 tiếng: người đang học 0 giờ mà bị giao 2
/// tiếng thì bỏ trong ba ngày. Phần lớn lượng quên xảy ra trong 24 giờ đầu, nên
/// 20 phút ôn NGAY trong ngày là phút có giá trị cao nhất — bắt đầu từ đó.
enum HocONha {
    // MARK: Cài đặt (giữ trong máy — đây là thói quen của từng người, không
    // phải dữ liệu tài khoản; đồng bộ lên máy chủ chỉ thêm một vòng mạng)

    private static let K_BAT = "hoconha.bat"
    private static let K_GIO = "hoconha.gio"      // phút từ 00:00
    private static let K_DA_SINH = "hoconha.dasinh"   // ngày đã sinh việc

    static var bat: Bool {
        get { UserDefaults.standard.object(forKey: K_BAT) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: K_BAT) }
    }
    /// Mặc định 20:00 — sau bữa tối, trước lúc điện thoại thắng.
    static var phutNhac: Int {
        get { UserDefaults.standard.object(forKey: K_GIO) as? Int ?? 20 * 60 }
        set { UserDefaults.standard.set(newValue, forKey: K_GIO) }
    }
    static var gioNhacChu: String {
        String(format: "%02d:%02d", phutNhac / 60, phutNhac % 60)
    }

    static let PHUT_ON = 20
    private static let tienTo = "hoconha-"

    // MARK: A — sinh việc sau buổi học

    /// Sinh việc ôn cho các buổi ĐÃ HỌC XONG hôm nay.
    ///
    /// Trả về số việc đã tạo. Gọi mỗi lần mở Tổng quan; chỉ chạy MỘT LẦN mỗi
    /// ngày nhờ cờ trong máy — không có cờ thì việc người dùng cố ý xoá sẽ
    /// mọc lại ở lần mở app kế tiếp, và đó là kiểu app mà người ta gỡ.
    @MainActor
    static func sinhViecHomNay(_ buoi: [BuoiHoc], daCo: [ViecTongQuan]) async -> Int {
        guard bat else { return 0 }
        let homNay = PhamViViec.today.moc()
        if UserDefaults.standard.string(forKey: K_DA_SINH) == homNay { return 0 }

        let l = Calendar.current
        let bayGio = l.component(.hour, from: Date()) * 60 + l.component(.minute, from: Date())
        let thu = BuoiHoc.thuViet(tuLich: l.component(.weekday, from: Date()))

        // Chỉ buổi ĐÃ KẾT THÚC. Sinh việc ôn cho buổi chiều lúc 8 giờ sáng là
        // bảo người ta ôn thứ chưa học.
        let xong = buoi.filter { b in
            b.weekday == thu && conTrongKy(b) && phut(b.endTime) <= bayGio
        }
        guard !xong.isEmpty else { return 0 }

        // Không tạo trùng: người dùng có thể đã tự thêm việc tên y hệt.
        let tenDaCo = Set(daCo.filter { $0.date == homNay }.map { $0.title })
        var soTao = 0
        for b in xong {
            let ten = String(format: T("Ôn %@ — %d phút"), b.subject, PHUT_ON)
            if tenDaCo.contains(ten) { continue }
            do {
                try await APIClient.shared.send(.themViec([
                    "scope": "today", "date": homNay, "title": ten, "exp": 25,
                ]))
                soTao += 1
            } catch { /* mạng hỏng thì thôi, mai mở lại sinh tiếp */ }
        }

        // Một việc xem trước cho ngày mai, nếu mai có lớp.
        let thuMai = thu == BuoiHoc.thuLon ? BuoiHoc.thuNho : thu + 1
        let mai = buoi.filter { $0.weekday == thuMai && conTrongKy($0) }
            .sorted { $0.phutBatDau < $1.phutBatDau }
        if !mai.isEmpty {
            let ds = Array(Set(mai.map(\.subject))).sorted().joined(separator: ", ")
            let ten = String(format: T("Xem trước mai: %@"), ds)
            if !tenDaCo.contains(ten) {
                try? await APIClient.shared.send(.themViec([
                    "scope": "today", "date": homNay, "title": ten, "exp": 25,
                ]))
                soTao += 1
            }
        }

        if soTao > 0 { UserDefaults.standard.set(homNay, forKey: K_DA_SINH) }
        return soTao
    }

    // MARK: B — lời nhắc buổi tối

    /// Đặt lại lời nhắc học ở nhà: MỘT thông báo cho mỗi thứ, lặp hằng tuần.
    ///
    /// ⚠️ Vì sao 7 thông báo chứ không 1: nội dung của thông báo cục bộ được
    /// chốt LÚC ĐẶT, không đổi được về sau. Muốn câu nhắc nói đúng "hôm nay
    /// bạn học SWR302 và LAB211" thì phải có một bản riêng cho từng thứ.
    static func datLaiNhacToi(_ buoi: [BuoiHoc]) async {
        let tt = UNUserNotificationCenter.current()
        let cho = await tt.pendingNotificationRequests()
        tt.removePendingNotificationRequests(withIdentifiers:
            cho.map(\.identifier).filter { $0.hasPrefix(tienTo) })

        guard bat else { return }
        let con = buoi.filter(conTrongKy)
        guard !con.isEmpty else { return }
        guard await xinQuyen() else { return }

        for thu in BuoiHoc.thuNho...BuoiHoc.thuLon {
            let mon = Array(Set(con.filter { $0.weekday == thu }.map(\.subject))).sorted()
            // Ngày không có lớp thì KHÔNG nhắc. Nhắc "ôn bài" vào Chủ nhật
            // trống là kiểu thông báo người ta tắt hẳn sau ba lần.
            guard !mon.isEmpty else { continue }

            let nd = UNMutableNotificationContent()
            nd.title = T("Giờ học ở nhà")
            nd.body = String(format: T("Hôm nay bạn học %@. Ôn %d phút mỗi môn là đủ."),
                             mon.joined(separator: ", "), PHUT_ON)
            nd.sound = .default
            nd.userInfo = ["loai": "hoc-o-nha"]

            var kh = DateComponents()
            kh.weekday = thu == BuoiHoc.thuLon ? 1 : thu   // 1 = Chủ nhật
            kh.hour = phutNhac / 60
            kh.minute = phutNhac % 60

            try? await tt.add(UNNotificationRequest(
                identifier: "\(tienTo)\(thu)", content: nd,
                trigger: UNCalendarNotificationTrigger(dateMatching: kh, repeats: true)))
        }
    }

    static func xoaNhacToi() async {
        let tt = UNUserNotificationCenter.current()
        let cho = await tt.pendingNotificationRequests()
        tt.removePendingNotificationRequests(withIdentifiers:
            cho.map(\.identifier).filter { $0.hasPrefix(tienTo) })
    }

    static func demNhacToi() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(tienTo) }.count
    }

    // MARK: Riêng

    private static func phut(_ hhmm: String) -> Int {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        return p.count == 2 ? p[0] * 60 + p[1] : 0
    }

    private static func conTrongKy(_ b: BuoiHoc) -> Bool {
        let homNay = PhamViViec.today.moc()
        if let t = b.startDate, t.count >= 10, String(t.prefix(10)) > homNay { return false }
        if let d = b.endDate, d.count >= 10, String(d.prefix(10)) < homNay { return false }
        return true
    }

    private static func xinQuyen() async -> Bool {
        let tt = UNUserNotificationCenter.current()
        let ht = await tt.notificationSettings()
        switch ht.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await tt.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }
}
