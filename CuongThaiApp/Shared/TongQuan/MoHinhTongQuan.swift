import Foundation

// MARK: - Phạm vi việc

/// Năm phạm vi, khớp `TASK_SCOPES` của máy chủ. Chuỗi thô chính là giá trị gửi
/// đi — tách nhãn hiển thị ra `ten` để đổi chữ không làm hỏng dữ liệu.
enum PhamViViec: String, CaseIterable, Identifiable, Codable {
    case today, week, month, quarter, year
    var id: String { rawValue }

    var ten: String {
        switch self {
        case .today:   return T("Hôm nay")
        case .week:    return T("Tuần này")
        case .month:   return T("Tháng này")
        case .quarter: return T("Quý này")
        case .year:    return T("Năm nay")
        }
    }

    var bieuTuong: String {
        switch self {
        case .today:   return "sun.max"
        case .week:    return "calendar"
        case .month:   return "calendar.badge.clock"
        case .quarter: return "chart.bar"
        case .year:    return "flag"
        }
    }

    /// Câu mời khi phạm vi này chưa có việc nào — nói rõ phạm vi để người dùng
    /// không tưởng mình mất dữ liệu khi đổi tab.
    var loiMoi: String {
        switch self {
        case .today:   return T("Chưa có việc nào cho hôm nay.")
        case .week:    return T("Chưa có việc nào cho tuần này.")
        case .month:   return T("Chưa có việc nào cho tháng này.")
        case .quarter: return T("Chưa có việc nào cho quý này.")
        case .year:    return T("Chưa có việc nào cho năm nay.")
        }
    }

    /// ⛔⛔ MỐC NGÀY TÍNH THEO GIỜ MÁY, KHÔNG PHẢI UTC.
    ///
    /// Máy chủ tính mốc bằng UTC (`scopeDate` trong `utils/dashboard.ts`). Ở
    /// UTC+7, từ 00:00 tới 07:00 thì "hôm nay" của máy chủ vẫn là HÔM QUA ⇒
    /// việc tạo lúc 2 giờ sáng bị gắn ngày hôm qua và **biến mất ngay sau khi
    /// thêm**. Không lỗi, không dấu vết. App desktop đã trúng lỗi này thật.
    ///
    /// Cách chữa giống desktop: app tự tính mốc theo giờ máy rồi GỬI KÈM —
    /// `date` khi tạo việc, `homNay` khi đọc.
    func moc(_ homNay: Date = Date()) -> String {
        var l = Calendar(identifier: .gregorian)
        l.firstWeekday = 2                      // tuần bắt đầu THỨ HAI, không phải Chủ nhật
        l.timeZone = .current
        let d: Date
        switch self {
        case .today:   d = homNay
        case .week:    d = l.dateInterval(of: .weekOfYear, for: homNay)?.start ?? homNay
        case .month:   d = l.dateInterval(of: .month, for: homNay)?.start ?? homNay
        case .quarter:
            let th = l.component(.month, from: homNay)
            let dauQuy = ((th - 1) / 3) * 3 + 1
            d = l.date(from: DateComponents(year: l.component(.year, from: homNay), month: dauQuy, day: 1)) ?? homNay
        case .year:
            d = l.date(from: DateComponents(year: l.component(.year, from: homNay), month: 1, day: 1)) ?? homNay
        }
        return PhamViViec.dinhDang.string(from: d)
    }

    static let dinhDang: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")   // không để lịch Phật/Hồi làm lệch năm
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Việc

struct ViecTongQuan: Codable, Identifiable, Equatable {
    let id: Int
    var scope: String
    var date: String
    var title: String
    var done: Bool
    var exp: Int
    var note: String?
    var dueAt: String?
    var remindAt: String?
    var priority: Int
    var repeatMode: String
    var parentId: Int?
    var sortOrder: Int?

    // `repeat` là từ khoá của Swift nên phải đổi tên và ánh xạ lại.
    enum CodingKeys: String, CodingKey {
        case id, scope, date, title, done, exp, note, dueAt, remindAt, priority, parentId, sortOrder
        case repeatMode = "repeat"
    }

    var pham: PhamViViec { PhamViViec(rawValue: scope) ?? .today }

    /// 0 = không đặt · 1 = thấp · 2 = vừa · 3 = cao
    var nhanUuTien: String? {
        switch priority {
        case 3: return T("Cao")
        case 2: return T("Vừa")
        case 1: return T("Thấp")
        default: return nil
        }
    }
}

// MARK: - Trạng thái (cấp độ / EXP)

struct TrangThaiTongQuan: Codable, Equatable {
    var level: Int
    var exp: Int
    var totalExp: Int

    /// EXP cần cho mỗi cấp. Máy chủ dùng 100; để hằng số ở đây chứ không rải
    /// số 100 khắp giao diện.
    static let expMoiCap = 100
    var phanTram: Double { min(1, Double(exp) / Double(Self.expMoiCap)) }
}

struct GoiTongQuan: Codable {
    var state: TrangThaiTongQuan?
    var tasks: [ViecTongQuan]
}

// MARK: - Buổi học

struct BuoiHoc: Codable, Identifiable, Equatable {
    let id: Int
    var subject: String
    var classCode: String?
    var teacher: String?
    var room: String?
    /// 2 = thứ Hai … 8 = Chủ nhật (lối gọi Việt, khớp máy chủ).
    var weekday: Int
    var startTime: String
    var endTime: String
    var color: String?
    var note: String?
    var remindMinutes: Int
    var startDate: String?
    var endDate: String?

    static let thuNho = 2
    static let thuLon = 8

    static func tenThu(_ t: Int) -> String {
        switch t {
        case 2: return T("Thứ 2")
        case 3: return T("Thứ 3")
        case 4: return T("Thứ 4")
        case 5: return T("Thứ 5")
        case 6: return T("Thứ 6")
        case 7: return T("Thứ 7")
        case 8: return T("Chủ nhật")
        default: return "?"
        }
    }

    /// Đổi `Calendar.component(.weekday)` (1 = Chủ nhật … 7 = thứ Bảy) sang
    /// lối gọi Việt 2..8. Đây là CHỖ DUY NHẤT được phép đổi hệ — làm rải rác
    /// là mời lỗi lệch-một.
    static func thuViet(tuLich w: Int) -> Int { w == 1 ? 8 : w }

    var phutBatDau: Int {
        let p = startTime.split(separator: ":").compactMap { Int($0) }
        return p.count == 2 ? p[0] * 60 + p[1] : 0
    }
}
