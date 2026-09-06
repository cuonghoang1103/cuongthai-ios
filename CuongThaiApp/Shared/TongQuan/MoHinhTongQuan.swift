import Foundation
import SwiftUI

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

    var slot: Int?
    var meetUrl: String?
    var materialsUrl: String?

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


// MARK: - Slot của FAP

/// Khung giờ slot theo lối FPT. Đây là BẢNG TRA để nhập nhanh, không phải
/// nguồn sự thật: giờ thật vẫn nằm ở `startTime`/`endTime` của từng buổi, vì
/// trường có thể đổi khung giờ giữa kỳ mà lịch đã nhập phải kêu đúng giờ cũ.
enum SlotFAP {
    static let khung: [Int: (String, String)] = [
        1: ("07:30", "09:50"),
        2: ("10:00", "12:20"),
        3: ("12:50", "15:10"),
        4: ("15:20", "17:40"),
        5: ("17:50", "20:10"),
    ]
    /// Slot có khung giờ, xếp theo thứ tự.
    static var coKhung: [Int] { khung.keys.sorted() }

    static func ten(_ n: Int) -> String {
        if let k = khung[n] { return String(format: T("Slot %d · %@–%@"), n, k.0, k.1) }
        return String(format: T("Slot %d"), n)
    }

    /// Dò slot từ giờ bắt đầu — để lịch nhập trước khi có cột `slot` vẫn xếp
    /// đúng hàng trong bảng tuần.
    static func doTuGio(_ batDau: String) -> Int? {
        khung.first { $0.value.0 == batDau }?.key
    }
}

// MARK: - Điểm danh

/// Khớp `ClassAttendance` do phiên khác dựng: 'co' | 'vang' | 'phep'.
/// Không có bản ghi = CHƯA chấm (FAP hiện "(Not yet)").
enum TrangThaiDiemDanh: String, CaseIterable, Identifiable, Codable {
    case co, vang, phep
    var id: String { rawValue }

    var ten: String {
        switch self {
        case .co:   return T("Có mặt")
        case .vang: return T("Vắng")
        case .phep: return T("Có phép")
        }
    }
    var bieuTuong: String {
        switch self {
        case .co:   return "checkmark.circle.fill"
        case .vang: return "xmark.circle.fill"
        case .phep: return "hand.raised.circle.fill"
        }
    }
}

struct DiemDanh: Codable, Identifiable, Equatable {
    let id: Int
    var scheduleId: Int
    /// Máy chủ trả ISO đầy đủ ("2026-09-07T00:00:00.000Z") vì cột là `@db.Date`
    /// nhưng Prisma vẫn tuần tự hoá thành DateTime. Cắt 10 ký tự đầu để so.
    var date: String
    var status: String
    var note: String?

    var ngay: String { String(date.prefix(10)) }
    var trangThai: TrangThaiDiemDanh? { TrangThaiDiemDanh(rawValue: status) }
}

// MARK: - Kỳ học & lịch thi

struct HocKy: Codable, Identifiable, Equatable {
    let id: Int
    var ten: String
    var batDau: String
    var soTuan: Int
    var tuanThi: Int
    var dangHoc: Bool

    var ngayBatDau: Date? { PhamViViec.dinhDang.date(from: String(batDau.prefix(10))) }

    /// Tuần thứ mấy của kỳ, tính theo GIỜ MÁY. `nil` khi ngày nằm ngoài kỳ.
    func tuan(_ ngay: Date = Date()) -> Int? {
        guard let goc = ngayBatDau else { return nil }
        var l = Calendar(identifier: .gregorian)
        l.firstWeekday = 2
        l.timeZone = .current
        let d = l.dateComponents([.day], from: l.startOfDay(for: goc), to: l.startOfDay(for: ngay)).day ?? 0
        guard d >= 0 else { return nil }
        let t = d / 7 + 1
        return t <= soTuan ? t : nil
    }
}

enum LoaiThi: String, CaseIterable, Identifiable, Codable {
    case PE, FE, PT, ME, NOI, NGHE, VIET, KHAC
    var id: String { rawValue }

    var ten: String {
        switch self {
        case .PE:   return T("PE — Thi thực hành")
        case .FE:   return T("FE — Thi cuối kỳ")
        case .PT:   return T("PT — Kiểm tra tiến độ")
        case .ME:   return T("ME — Thi giữa kỳ")
        case .NOI:  return T("Thi nói")
        case .NGHE: return T("Thi nghe")
        case .VIET: return T("Thi viết")
        case .KHAC: return T("Khác")
        }
    }
    var nhan: String {
        switch self {
        case .NOI:  return T("NÓI")
        case .NGHE: return T("NGHE")
        case .VIET: return T("VIẾT")
        case .KHAC: return T("KHÁC")
        default:    return rawValue
        }
    }
    /// Mỗi loại một màu — nhìn bảng là biết ngay hôm đó thi kiểu gì.
    var mau: Color {
        switch self {
        case .PE:   return AppColors.primary
        case .FE:   return AppColors.error
        case .PT:   return AppColors.warning
        case .ME:   return AppColors.accent
        case .NOI:  return AppColors.secondary
        case .NGHE: return AppColors.success
        case .VIET: return AppColors.primaryLight
        case .KHAC: return AppColors.textSecondary
        }
    }
}

struct BuoiThi: Codable, Identifiable, Equatable {
    let id: Int
    var monHoc: String
    var maMon: String?
    var loai: String
    var ngay: String
    var batDau: String
    var ketThuc: String
    var phong: String?
    var soBaoDanh: String?
    var ghiChu: String?
    var nhacTruoc: Int
    var hocKyId: Int?

    var ngayGon: String { String(ngay.prefix(10)) }
    var kieu: LoaiThi { LoaiThi(rawValue: loai) ?? .KHAC }
}
