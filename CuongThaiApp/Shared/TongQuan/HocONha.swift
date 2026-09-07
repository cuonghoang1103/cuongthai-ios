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
    /// Các mục ĐÃ TỪNG sinh, dạng "ngày|tên việc".
    ///
    /// ⛔⛔ Trước đây đây là MỘT chuỗi ngày ("hôm nay đã sinh rồi"), và nó đẻ ra
    /// đúng lỗi người dùng gặp 07/09/2026: sáng mở app lúc 07:19 → chưa buổi
    /// nào tan nên không có việc ôn, nhưng "Xem trước mai" thì sinh được → cờ
    /// bật → chiều hai lớp tan (12:20 và 15:10), tối mở lại thì hàm thoát ngay
    /// dòng đầu ⇒ "Ôn SWR302"/"Ôn LAB211" KHÔNG BAO GIỜ hiện ra. Người dùng
    /// thấy đúng thế: "sao trong kế hoạch chỉ có hai môn của ngày mai?".
    ///
    /// Ghi theo TỪNG MỤC thì việc của buổi tan lúc 15:10 vẫn sinh được lúc
    /// 20:00, mà thứ người dùng cố ý xoá vẫn không mọc lại — đó là lý do cái
    /// cờ tồn tại ngay từ đầu.
    private static let K_DA_SINH = "hoconha.dasinh.muc"
    private static let K_BAI_TAP = "hoconha.baitap"

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

    /// Kèm việc "Làm bài tập <môn>" cho mỗi buổi đã tan.
    ///
    /// Ôn KHÁC làm bài. Ôn là đọc lại cho khỏi quên; bài tập là thứ BỊ TÍNH
    /// ĐIỂM và là thứ dồn lại thành "không theo kịp". Tách hai dòng chứ không
    /// gộp: gộp thì tick một cái là coi như xong cả hai, mà thực tế người ta
    /// chỉ làm một.
    static var lamBaiTap: Bool {
        get { UserDefaults.standard.object(forKey: K_BAI_TAP) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: K_BAI_TAP) }
    }

    private static var daSinh: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: K_DA_SINH) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: K_DA_SINH) }
    }

    static let PHUT_ON = 20
    /// Ôn LẠI ngắn hơn lần đầu — đọc lại thứ đã tóm tắt, không dựng lại từ đầu.
    static let PHUT_ON_LAI = 10

    /// Ôn lặp ngắt quãng: sau buổi học thì ôn lại sau BAO NHIÊU ngày.
    ///
    /// ⚠️ Cố ý THƯA hơn thang chuẩn (1-3-7-14). Ba lý do:
    ///
    /// 1. Buổi học đã LẶP HẰNG TUẦN. Mốc 7 ngày trùng đúng buổi kế tiếp của
    ///    chính môn đó, nên nó không thêm lần chạm nào — chỉ thêm một dòng
    ///    trong danh sách.
    /// 2. Người dùng đang học 0 giờ/tuần. Thang 1-3-7 với 10 buổi/tuần ra ~40
    ///    việc/tuần; đó không phải kế hoạch, đó là một danh sách để bỏ.
    /// 3. Mốc "cùng ngày" đã có (việc "Ôn <môn> — 20 phút"), tức lần chạm đầu
    ///    và quan trọng nhất không nằm ở đây.
    ///
    /// Còn đúng MỘT mốc: 3 ngày. Cùng với buổi học tuần sau, mỗi môn được
    /// chạm 3 lần/tuần ở khoảng cách tăng dần — đủ để chống quên mà vẫn ~35
    /// phút/ngày. Thêm mốc chỉ nên làm khi người dùng đã giữ được nhịp này.
    static let MOC_ON_LAI = [3]
    private static let tienTo = "hoconha-"

    // MARK: A — sinh việc sau buổi học

    /// Sinh việc ôn cho các buổi ĐÃ HỌC XONG hôm nay.
    ///
    /// Trả về số việc đã tạo. Gọi mỗi lần mở Tổng quan; chỉ chạy MỘT LẦN mỗi
    /// ngày nhờ cờ trong máy — không có cờ thì việc người dùng cố ý xoá sẽ
    /// mọc lại ở lần mở app kế tiếp, và đó là kiểu app mà người ta gỡ.
    /// Sinh việc cho hôm nay: ôn + làm bài của các buổi ĐÃ TAN, việc ôn lại
    /// ngắt quãng, và một việc xem trước cho ngày mai.
    ///
    /// Trả về số việc đã tạo. Gọi mỗi lần mở Tổng quan — chạy được NHIỀU LẦN
    /// trong ngày, vì các buổi tan vào những giờ khác nhau. Chống mọc lại
    /// bằng danh sách mục đã sinh, xem `K_DA_SINH`.
    @MainActor
    static func sinhViecHomNay(_ buoi: [BuoiHoc], daCo: [ViecTongQuan]) async -> Int {
        guard bat else { return 0 }
        let homNay = PhamViViec.today.moc()
        let l = Calendar.current
        let bayGio = l.component(.hour, from: Date()) * 60 + l.component(.minute, from: Date())
        let thu = BuoiHoc.thuViet(tuLich: l.component(.weekday, from: Date()))
        let f = PhamViViec.dinhDang

        // Việc đã có trên máy chủ — người dùng có thể tự thêm trùng tên.
        let daCoTen = Set(daCo.map { "\($0.date)|\($0.title)" })
        var da = daSinh
        var soTao = 0

        func tao(_ ngay: String, _ ten: String, exp: Int, ghiChu: String? = nil) async {
            let khoa = "\(ngay)|\(ten)"
            if da.contains(khoa) || daCoTen.contains(khoa) { return }
            var p: [String: Any] = ["scope": "today", "date": ngay, "title": ten, "exp": exp]
            if let g = ghiChu, !g.isEmpty { p["note"] = g }
            do {
                try await APIClient.shared.send(.themViec(p))
                da.insert(khoa)
                soTao += 1
            } catch { /* mạng hỏng thì lần mở sau sinh tiếp */ }
        }

        // ── A. Buổi ĐÃ TAN hôm nay ──
        // Chỉ buổi đã kết thúc: sinh việc ôn cho buổi chiều lúc 8 giờ sáng là
        // bảo người ta ôn thứ chưa học.
        let xong = buoi
            .filter { $0.weekday == thu && conTrongKy($0) && phut($0.endTime) <= bayGio }
            .sorted { $0.phutBatDau < $1.phutBatDau }
        for b in xong {
            await tao(homNay, String(format: T("Ôn %@ — %d phút"), b.subject, PHUT_ON), exp: 25)
            if lamBaiTap {
                await tao(homNay, String(format: T("Làm bài tập %@"), b.subject),
                          exp: 25, ghiChu: ghiChuBaiTap(b))
            }
            // Ôn lặp: đặt SẴN vào ngày tương lai, không đợi tới hôm đó mới
            // sinh — app có thể không được mở hôm đó.
            for cach in MOC_ON_LAI {
                guard let d = l.date(byAdding: .day, value: cach, to: Date()) else { continue }
                await tao(f.string(from: d),
                          String(format: T("Ôn lại %@ (%d ngày) — %d phút"), b.subject, cach, PHUT_ON_LAI),
                          exp: 15)
            }
        }

        // ── B. Xem trước ngày mai ──
        // ĐỘC LẬP với A. Trước đây khối này nằm sau `guard !xong.isEmpty`, nên
        // ngày nào mở app trước giờ tan lớp thì cũng không có gì được sinh.
        let thuMai = thu == BuoiHoc.thuLon ? BuoiHoc.thuNho : thu + 1
        let mai = buoi.filter { $0.weekday == thuMai && conTrongKy($0) }
        if !mai.isEmpty {
            let ds = Array(Set(mai.map(\.subject))).sorted().joined(separator: ", ")
            await tao(homNay, String(format: T("Xem trước mai: %@"), ds), exp: 25)
        }

        if soTao > 0 { daSinh = donCu(da, homNay: homNay) }
        return soTao
    }

    /// Ghi chú cho việc làm bài tập: chỗ lấy đề. Không có thì để trống — một
    /// ghi chú rỗng tốt hơn một câu chung chung ("nhớ làm bài nhé").
    private static func ghiChuBaiTap(_ b: BuoiHoc) -> String? {
        var d: [String] = []
        if let m = b.materialsUrl, !m.isEmpty { d.append(m) }
        if let n = b.note, !n.isEmpty { d.append(n) }
        return d.isEmpty ? nil : d.joined(separator: "\n")
    }

    /// Bỏ mục cũ hơn 45 ngày — danh sách này chỉ để chống mọc lại, giữ mãi thì
    /// nó phình vô hạn trong `UserDefaults`.
    private static func donCu(_ tap: Set<String>, homNay: String) -> Set<String> {
        let f = PhamViViec.dinhDang
        guard let m = f.date(from: homNay),
              let cat = Calendar.current.date(byAdding: .day, value: -45, to: m)
        else { return tap }
        let moc = f.string(from: cat)
        return tap.filter { ($0.split(separator: "|").first.map(String.init) ?? "") >= moc }
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
