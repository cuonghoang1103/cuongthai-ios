import SwiftUI

// ════════════════════════════════════════════════════════════════
// CHỦ ĐỀ 4 MÙA (23/10/2026) — bảng màu + bảng màu trang trí của từng chủ đề.
//
// Kiến trúc (thêm chủ đề mới = 4 bước, đều trong thư mục này):
//   1. thêm một `case` vào `Mua` (hoặc `ChuDe` nếu không phải một mùa),
//   2. khai `BangMauChuDe` của nó trong `BangMauChuDe.cua(_:)` — đủ sáng + tối, chạy `ChuDeTests` đo WCAG,
//   3. khai `BoMauTrangTri` (màu hạt, nền loang) trong `BoMauTrangTri.cua(_:)`,
//   4. vẽ hạt + trang trí góc trong `NenMua.swift` (`veHat`, `veGoc…`).
// Mọi màn dùng `AppColors.x` tự theo — `Theme.swift` đọc `KhoBangMau.shared.bang`, `QuanLyChuDe` ghi vào đó.
// ════════════════════════════════════════════════════════════════

/// Lựa chọn của người dùng trong Cài đặt → Giao diện.
enum ChuDe: String, CaseIterable, Identifiable {
    case tuDong, macDinh, xuan, ha, thu, dong
    var id: String { rawValue }

    /// Mùa mà chủ đề này vẽ ra tại thời điểm `ngay`. `nil` = Mặc định (giao diện tím quen thuộc, không trang trí).
    func mua(_ ngay: Date = Date()) -> Mua? {
        switch self {
        case .macDinh: return nil
        case .tuDong: return Mua.theoNgay(ngay)
        case .xuan: return .xuan
        case .ha: return .ha
        case .thu: return .thu
        case .dong: return .dong
        }
    }

    var ten: String {
        switch self {
        case .tuDong: return T("Tự động theo mùa")
        case .macDinh: return T("Mặc định")
        case .xuan: return T("Xuân · Tết")
        case .ha: return T("Hạ · Biển")
        case .thu: return T("Thu · Lá rơi")
        case .dong: return T("Đông · Noel")
        }
    }

    var moTa: String {
        switch self {
        case .tuDong: return T("Đổi theo tháng ở Việt Nam")
        case .macDinh: return T("Tím CuongThai quen thuộc")
        case .xuan: return T("Hoa đào, hoa mai, đèn lồng, pháo hoa")
        case .ha: return T("Nắng, sóng biển, mây trôi, hải âu")
        case .thu: return T("Lá phong, hoa anh đào, trăng rằm")
        case .dong: return T("Tuyết rơi, cây thông, chim cánh cụt")
        }
    }

    var bieuTuong: String {
        switch self {
        case .tuDong: return "calendar.circle.fill"
        case .macDinh: return "paintpalette.fill"
        case .xuan: return Mua.xuan.bieuTuong
        case .ha: return Mua.ha.bieuTuong
        case .thu: return Mua.thu.bieuTuong
        case .dong: return Mua.dong.bieuTuong
        }
    }
}

enum Mua: String, CaseIterable, Identifiable {
    case xuan, ha, thu, dong
    var id: String { rawValue }

    /// ⭐ MỘT chỗ quyết tháng nào là mùa nào (theo cảm giác ở Việt Nam, không theo thiên văn):
    /// Xuân 1–3 (Tết) · Hạ 4–7 · Thu 8–10 · Đông 11–12 (Noel). Muốn dời mốc thì sửa đúng hàm này.
    static func theoThang(_ thang: Int) -> Mua {
        switch thang {
        case 1...3: return .xuan
        case 4...7: return .ha
        case 8...10: return .thu
        default: return .dong
        }
    }

    static func theoNgay(_ ngay: Date) -> Mua {
        #if DEBUG
        // `CT_THANG=1…12` — ép tháng khi chụp màn "Tự động theo mùa".
        if let s = ProcessInfo.processInfo.environment["CT_THANG"], let t = Int(s), (1...12).contains(t) {
            return theoThang(t)
        }
        #endif
        return theoThang(Calendar.current.component(.month, from: ngay))
    }

    var ten: String {
        switch self {
        case .xuan: return T("Xuân")
        case .ha: return T("Hạ")
        case .thu: return T("Thu")
        case .dong: return T("Đông")
        }
    }

    var bieuTuong: String {
        switch self {
        case .xuan: return "camera.macro"
        case .ha: return "sun.max.fill"
        case .thu: return "leaf.fill"
        case .dong: return "snowflake"
        }
    }
}

// MARK: - Bảng màu token

extension BangMauChuDe {
    private static func m(_ sang: UInt32, _ toi: UInt32) -> Color {
        .theoCheDo(sang: Color(hex: sang), toi: Color(hex: toi))
    }

    /// Bảng của chủ đề — `nil` = Mặc định.
    ///
    /// Số tương phản (WCAG 2.1, đo bằng `ChuDeTests`): chữ (text1/2/3) và primary-làm-chữ ≥ 4,5:1 trên CẢ BỐN nền
    /// (primary/secondary/tertiary/card); chữ trắng trên nút primary ≥ 4,5:1 ở nền sáng, ≥ 3:1 ở nền tối (chữ nút đậm —
    /// cùng mức xanh hệ thống của iOS ở chế độ tối).
    static func cua(_ mua: Mua?) -> BangMauChuDe {
        switch mua {
        case nil: return macDinh
        case .xuan?: return xuan
        case .ha?: return ha
        case .thu?: return thu
        case .dong?: return dong
        }
    }

    /// Mặc định — giữ tím CuongThai. Chế độ TỐI y nguyên bảng gốc (trừ primary đậm lên một nấc cho chữ tím trên thẻ
    /// đạt 4,6:1 thay vì 4,0:1); chế độ SÁNG bớt "trắng phẳng": nền ngả tím lavender rất nhạt để thẻ trắng nổi lên.
    static let macDinh = BangMauChuDe(
        primary: m(0x7A45E8, 0x9A6BF2),
        primaryDark: m(0x6535D0, 0x7340DB),
        primaryLight: m(0x9B6BFF, 0xA673FF),
        secondary: m(0x0E7F92, 0x21D4ED),
        accent: m(0xB45309, 0xFF9933),
        backgroundPrimary: m(0xF3F0FA, 0x0A0A14),
        backgroundSecondary: m(0xFFFFFF, 0x141420),
        backgroundTertiary: m(0xECE8F6, 0x1A1A24),
        backgroundCard: m(0xFFFFFF, 0x1A1A24),
        textPrimary: m(0x16141F, 0xFFFFFF),
        textSecondary: m(0x4F4B5E, 0x9999A6),
        textTertiary: m(0x625D73, 0x8E8E9C),
        divider: .theoCheDo(sang: Color(hex: 0x3B2A6B).opacity(0.11), toi: Color.white.opacity(0.12)),
        border: .theoCheDo(sang: Color(hex: 0x3B2A6B).opacity(0.10), toi: Color.white.opacity(0.10)),
        brandPink: m(0xDB2777, 0xF472B6))

    /// Xuân — đỏ Tết, vàng mai, hồng đào trên nền kem ấm.
    static let xuan = BangMauChuDe(
        primary: m(0xC0262D, 0xEF5350),
        primaryDark: m(0x9E1C22, 0xD43F3C),
        primaryLight: m(0xE0484C, 0xFF7B73),
        secondary: m(0x8A5A00, 0xF2C14E),
        accent: m(0xB4460F, 0xFF8A5B),
        backgroundPrimary: m(0xFDF1EA, 0x170B0A),
        backgroundSecondary: m(0xFFFBF8, 0x211110),
        backgroundTertiary: m(0xF8E2D8, 0x2C1715),
        backgroundCard: m(0xFFFCFA, 0x2A1614),
        textPrimary: m(0x2A1512, 0xFFF4EF),
        textSecondary: m(0x5C3D36, 0xD9B9AF),
        textTertiary: m(0x75544B, 0xB69389),
        divider: .theoCheDo(sang: Color(hex: 0x7A2A1A).opacity(0.13), toi: Color(hex: 0xFFD8C8).opacity(0.12)),
        border: .theoCheDo(sang: Color(hex: 0x7A2A1A).opacity(0.12), toi: Color(hex: 0xFFD8C8).opacity(0.11)),
        brandPink: m(0xD81B60, 0xF48FB1))

    /// Hạ — xanh biển, ngọc lam, vàng cát.
    static let ha = BangMauChuDe(
        primary: m(0x0A6A9E, 0x3393D0),
        primaryDark: m(0x075580, 0x2478B0),
        primaryLight: m(0x2E8FC6, 0x5DB2E6),
        secondary: m(0x0B7A70, 0x3CCFC0),
        accent: m(0xA85A00, 0xF5B547),
        backgroundPrimary: m(0xEEF6FA, 0x051320),
        backgroundSecondary: m(0xFFFFFF, 0x0A1C2B),
        backgroundTertiary: m(0xDDEDF5, 0x0F2537),
        backgroundCard: m(0xFFFFFF, 0x0E2233),
        textPrimary: m(0x0D1F2B, 0xF0F8FF),
        textSecondary: m(0x384F5E, 0xA9C3D3),
        textTertiary: m(0x4D6575, 0x8BA7B9),
        divider: .theoCheDo(sang: Color(hex: 0x0B3A55).opacity(0.12), toi: Color(hex: 0xBFE6FF).opacity(0.12)),
        border: .theoCheDo(sang: Color(hex: 0x0B3A55).opacity(0.11), toi: Color(hex: 0xBFE6FF).opacity(0.11)),
        brandPink: m(0xD94F4F, 0xFF8A80))

    /// Thu — cam lá phong, hồng anh đào, vàng trăng trên nền giấy ấm.
    static let thu = BangMauChuDe(
        primary: m(0xB0441A, 0xDD6F35),
        primaryDark: m(0x8F3410, 0xC25A24),
        primaryLight: m(0xD3612F, 0xF0915C),
        secondary: m(0xB03565, 0xF48FB1),
        accent: m(0x8F5B00, 0xE6B85C),
        backgroundPrimary: m(0xFAF1E7, 0x160E09),
        backgroundSecondary: m(0xFFFCF8, 0x201610),
        backgroundTertiary: m(0xF3E6D8, 0x2A1D15),
        backgroundCard: m(0xFFFCF8, 0x271B13),
        textPrimary: m(0x2A1C13, 0xFFF5EC),
        textSecondary: m(0x584334, 0xD8BFAB),
        textTertiary: m(0x6E5848, 0xB59C88),
        divider: .theoCheDo(sang: Color(hex: 0x6B3A1A).opacity(0.13), toi: Color(hex: 0xFFE0C2).opacity(0.12)),
        border: .theoCheDo(sang: Color(hex: 0x6B3A1A).opacity(0.12), toi: Color(hex: 0xFFE0C2).opacity(0.11)),
        brandPink: m(0xC93A75, 0xF48FB1))

    /// Đông — xanh băng, trắng tuyết, đỏ Noel, xanh lá thông.
    static let dong = BangMauChuDe(
        primary: m(0x1E5AA8, 0x4D8FE3),
        primaryDark: m(0x17488A, 0x3A78CC),
        primaryLight: m(0x3D7BC9, 0x7BAEF0),
        secondary: m(0x17704A, 0x4CC38A),
        accent: m(0xB82828, 0xF2645A),
        backgroundPrimary: m(0xEEF4FA, 0x07101C),
        backgroundSecondary: m(0xFFFFFF, 0x0C1726),
        backgroundTertiary: m(0xDFE9F4, 0x122034),
        backgroundCard: m(0xFFFFFF, 0x101D2F),
        textPrimary: m(0x0E1A29, 0xF2F7FF),
        textSecondary: m(0x3A4A5F, 0xAFC0D6),
        textTertiary: m(0x4F6075, 0x8FA3BC),
        divider: .theoCheDo(sang: Color(hex: 0x123257).opacity(0.12), toi: Color(hex: 0xCFE3FF).opacity(0.12)),
        border: .theoCheDo(sang: Color(hex: 0x123257).opacity(0.11), toi: Color(hex: 0xCFE3FF).opacity(0.11)),
        brandPink: m(0xC62828, 0xF2645A))
}

// MARK: - Màu trang trí (nền loang, hạt) — không phải token chữ nên không cần đạt 4,5:1

struct BoMauTrangTri {
    /// Ba điểm của lớp nền loang: góc trên, giữa, đáy. Rất nhạt ở chế độ sáng — chỉ để nền có "chiều sâu".
    let nenTren: Color, nenGiua: Color, nenDuoi: Color
    /// Quầng sáng (mặt trời, trăng, đèn) ở góc trên.
    let quang: Color
    /// Màu hạt rơi — chọn xoay vòng theo chỉ số hạt.
    let hat: [Color]

    private static func m(_ sang: UInt32, _ toi: UInt32, _ a: Double = 1, _ aToi: Double? = nil) -> Color {
        .theoCheDo(sang: Color(hex: sang).opacity(a), toi: Color(hex: toi).opacity(aToi ?? a))
    }

    static func cua(_ mua: Mua?) -> BoMauTrangTri {
        switch mua {
        case nil:
            return BoMauTrangTri(
                nenTren: m(0xE4DAFB, 0x1B1236), nenGiua: m(0xF3F0FA, 0x0A0A14), nenDuoi: m(0xF7E6F3, 0x120A1C),
                quang: m(0xC9B2FF, 0x6D45D8, 0.55, 0.35), hat: [m(0xB79CFF, 0x8C5AF0)])
        case .xuan?:
            return BoMauTrangTri(
                nenTren: m(0xFFE0D6, 0x3A1210), nenGiua: m(0xFDF1EA, 0x170B0A), nenDuoi: m(0xFFF0D2, 0x241307),
                quang: m(0xFFC98A, 0xFF7043, 0.55, 0.30),
                hat: [m(0xF7A8C0, 0xF48FB1), m(0xF9C1D3, 0xF8BBD0), m(0xF5C542, 0xFFD54F), m(0xF3B0C8, 0xF06292)])
        case .ha?:
            return BoMauTrangTri(
                nenTren: m(0xCFEAFB, 0x0B3350), nenGiua: m(0xEEF6FA, 0x051320), nenDuoi: m(0xFBEFD6, 0x14232A),
                quang: m(0xFFE08A, 0xFFC94A, 0.70, 0.35),
                hat: [m(0x6FB8DE, 0xBFE9FF), m(0x8CCDEB, 0x7FD3F5), m(0xE9B53C, 0xFFE08A)])
        case .thu?:
            return BoMauTrangTri(
                nenTren: m(0xFBDDC4, 0x351A0C), nenGiua: m(0xFAF1E7, 0x160E09), nenDuoi: m(0xF8E1E6, 0x23110F),
                quang: m(0xFFE2A8, 0xFFE7B0, 0.65, 0.30),
                hat: [m(0xE0662A, 0xF0864A), m(0xC94A2C, 0xE0603C), m(0xE8A33A, 0xF2B655), m(0xF2A9BE, 0xF6B3C8)])
        case .dong?:
            return BoMauTrangTri(
                nenTren: m(0xD6E6F7, 0x0F2445), nenGiua: m(0xEEF4FA, 0x07101C), nenDuoi: m(0xF6F9FC, 0x0D1A2B),
                quang: m(0xCFE4FF, 0x9CC7FF, 0.60, 0.22),
                hat: [m(0x9DBDE3, 0xFFFFFF), m(0xB4CDEA, 0xDDEBFF)])
        }
    }
}

// MARK: - Ngày lễ (đếm ngược nhỏ ở Hôm nay)

enum NgayLe {
    /// Mùng 1 Tết âm lịch (giờ Việt Nam). Bảng tay vì lịch âm VN (UTC+7) có năm lệch lịch Trung Quốc (UTC+8) —
    /// `Calendar(.chinese)` chỉ dùng làm đường lùi cho năm ngoài bảng.
    static let mungMotTet: [Int: (thang: Int, ngay: Int)] = [
        2026: (2, 17), 2027: (2, 6), 2028: (1, 26), 2029: (2, 13), 2030: (2, 3),
        2031: (1, 23), 2032: (2, 11), 2033: (1, 31), 2034: (2, 19), 2035: (2, 8),
    ]

    static func tet(nam: Int) -> Date? {
        let l = Calendar.current
        if let d = mungMotTet[nam] {
            return l.date(from: DateComponents(year: nam, month: d.thang, day: d.ngay))
        }
        // Đường lùi: tìm mùng 1 tháng Giêng âm lịch rơi vào năm dương `nam`.
        let am = Calendar(identifier: .chinese)
        guard let giua = l.date(from: DateComponents(year: nam, month: 3, day: 1)) else { return nil }
        let nhuan = am.dateComponents([.era, .year], from: giua)
        guard let d = am.date(from: DateComponents(era: nhuan.era, year: nhuan.year, month: 1, day: 1)) else { return nil }
        return l.startOfDay(for: d)
    }

    /// "Bính Ngọ", "Đinh Mùi"… của năm âm lịch bắt đầu trong năm dương `nam`.
    static func canChi(_ nam: Int) -> String {
        let can = ["Canh", "Tân", "Nhâm", "Quý", "Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ"]
        let chi = ["Thân", "Dậu", "Tuất", "Hợi", "Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi"]
        return "\(can[((nam % 10) + 10) % 10]) \(chi[((nam % 12) + 12) % 12])"
    }

    /// Một dòng chào theo mùa cho đầu trang Hôm nay. `nil` = không nói gì (chủ đề Mặc định).
    static func loiMua(_ mua: Mua?, _ bayGio: Date = Date()) -> (bieuTuong: String, chu: String)? {
        guard let mua else { return nil }
        let l = Calendar.current
        let homNay = l.startOfDay(for: bayGio)
        let nam = l.component(.year, from: bayGio)
        func soNgay(_ toi: Date) -> Int { l.dateComponents([.day], from: homNay, to: l.startOfDay(for: toi)).day ?? 0 }

        // Tết gần nhất phía trước (năm nay nếu chưa qua, không thì năm sau).
        let tetToi: (Date, Int)? = {
            if let t = tet(nam: nam), soNgay(t) >= 0 { return (t, nam) }
            if let t = tet(nam: nam + 1) { return (t, nam + 1) }
            return nil
        }()

        switch mua {
        case .dong:
            if let noel = l.date(from: DateComponents(year: nam, month: 12, day: 25)) {
                let n = soNgay(noel)
                if n > 0 { return ("gift.fill", String(format: T("Còn %d ngày nữa là Giáng sinh"), n)) }
                if n == 0 { return ("gift.fill", T("Giáng sinh an lành!")) }
            }
            if let (t, namTet) = tetToi {
                return ("sparkles", String(format: T("Còn %d ngày nữa là Tết %@"), soNgay(t), canChi(namTet)))
            }
            return ("snowflake", T("Mùa đông ấm áp nhé"))
        case .xuan:
            if let (t, namTet) = tetToi {
                let n = soNgay(t)
                if n == 0 { return ("sparkles", String(format: T("Chúc mừng năm mới %@!"), canChi(namTet))) }
                if n <= 60 { return ("sparkles", String(format: T("Còn %d ngày nữa là Tết %@"), n, canChi(namTet))) }
            }
            // Đã qua Tết của năm nay: chúc xuân.
            if let t = tet(nam: nam), soNgay(t) < 0, soNgay(t) > -15 {
                return ("sparkles", String(format: T("Xuân %@ — học hành tấn tới!"), canChi(nam)))
            }
            return ("camera.macro", T("Xuân về — một ngày học thật tươi"))
        case .ha:
            return ("sun.max.fill", T("Mùa hè rực rỡ — giữ nhịp học nhé"))
        case .thu:
            return ("leaf.fill", T("Thu sang, lá rơi — học thôi"))
        }
    }
}
