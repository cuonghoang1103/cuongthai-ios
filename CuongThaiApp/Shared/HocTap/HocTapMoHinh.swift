import SwiftUI

/// Huấn luyện học kỳ (/hoc-tap) — mô hình khớp `src/services/hocTap/*` của backend.
/// Tỷ lệ trượt do MÁY CHỦ tính; app chỉ hiển thị, không tự tính lại.

struct RuiRoHT: Decodable, Hashable {
    let tyLe: Int
    let mucDo: String
    let tienDo: Int
    let kyVong: Int
    let quaHan: Int
    let nopTre: Int
    let diemLuyenTB: Double?
    let lyDo: [String]
}

struct ViecGonHT: Decodable, Identifiable, Hashable {
    let id: Int
    let monId: Int
    let maMon: String
    let mau: String?
    let tieuDe: String
    let loai: String
    let hanChot: String
    let thoiLuongPhut: Int
    let trangThai: String
    let batDauLuc: String?
    let diem: Double?
    let tuan: Int
}

struct MonHT: Decodable, Identifiable, Hashable {
    struct KeTiep: Decodable, Hashable { let id: Int; let tieuDe: String; let hanChot: String; let thoiLuongPhut: Int; let loai: String }
    struct Thi: Decodable, Hashable { let loai: String; let ngay: String; let batDau: String; let conNgay: Int }
    let id: Int
    let maMon: String
    let ten: String
    let mau: String?
    let courseSlug: String?
    let ruiRo: RuiRoHT
    let tongViec: Int
    let datViec: Int
    let choCham: Int
    let viecKeTiep: KeTiep?
    let thiSapToi: Thi?
}

struct TongQuanHT: Decodable {
    struct Ky: Decodable { let id: Int; let ten: String; let soTuan: Int; let tuanThi: Int }
    struct RuiRoKy: Decodable { let tyLe: Int; let mucDo: String }
    let hocKy: Ky?
    let tuan: Int
    let mon: [MonHT]
    let ruiRoKy: RuiRoKy
    let tienDoKy: Int?
    let homNay: [ViecGonHT]
    let quaHan: [ViecGonHT]
    let choCham: [ViecGonHT]
}

struct BangChungHT: Decodable, Identifiable, Hashable {
    struct Tep: Decodable, Hashable { let url: String; let ten: String?; let loai: String? }
    let id: Int
    let lanNop: Int
    let noiDung: String?
    let lienKet: [String]?
    let tep: [Tep]?
    let diem: Double?
    let dat: Bool?
    let nguoiCham: String?
    let chamLuc: String?
    let nopTre: Bool
    let createdAt: String
}

struct ViecHT: Decodable, Identifiable {
    struct Loi: Decodable { let loi: [String]?; let canCaiThien: [String]?; let diemManh: [String]? }
    struct Mon: Decodable { let maMon: String; let ten: String; let mau: String? }
    let id: Int
    let monId: Int
    let tuan: Int
    let loai: String
    let tieuDe: String
    let huongDan: String?
    let yeuCauBangChung: String?
    let lienKet: String?
    let thoiLuongPhut: Int
    let hanChot: String
    let trongSo: Int
    let trangThai: String
    let batDauLuc: String?
    let diem: Double?
    let nhanXet: String?
    let loiCanSua: Loi?
    let nguoiCham: String?
    let chamLuc: String?
    let nguon: String
    let bangChung: [BangChungHT]
    let mon: Mon?
}

struct ChiTietMonHT: Decodable {
    struct Mon: Decodable { let id: Int; let maMon: String; let ten: String; let mau: String?; let trinhDo: String?; let mucTieu: String? }
    struct ViecMon: Decodable, Identifiable {
        let id: Int; let tuan: Int; let loai: String; let tieuDe: String; let hanChot: String
        let thoiLuongPhut: Int; let trangThai: String; let batDauLuc: String?; let diem: Double?
    }
    let mon: Mon
    let viec: [ViecMon]
    let ruiRo: RuiRoHT
    let tuan: Int
}

struct NhanXetHT: Decodable { let loi: String }

enum HT {
    static func mau(_ mucDo: String) -> Color {
        switch mucDo {
        case "xanh": return AppColors.success
        case "vang": return AppColors.warning
        case "cam": return Color(hex: 0xF97316)
        default: return AppColors.error
        }
    }
    static func nhanMuc(_ mucDo: String) -> String {
        switch mucDo {
        case "xanh": return T("An toàn")
        case "vang": return T("Cần cố gắng")
        case "cam": return T("Nguy hiểm")
        default: return T("BÁO ĐỘNG ĐỎ")
        }
    }
    static func mauMon(_ hex: String?) -> Color {
        guard let hex, hex.hasPrefix("#"), let v = UInt32(hex.dropFirst(), radix: 16) else { return AppColors.primary }
        return Color(hex: v)
    }
    static func bieuTuong(_ loai: String) -> String {
        ["NEN_TANG": "🧱", "BAI_HOC": "📖", "BAI_TAP": "✍️", "LAB": "🧪", "QUIZ": "❓",
         "PE": "💻", "FE": "📝", "ON_TAP": "🔁", "GHI_CHU": "📒"][loai] ?? "•"
    }
    static func tenTrangThai(_ t: String) -> (String, Color) {
        switch t {
        case "DAT": return (T("Đạt"), AppColors.success)
        case "CHO_CHAM": return (T("Đang chấm"), Color(hex: 0xA855F7))
        case "CHUA_DAT": return (T("Chưa đạt — nộp lại"), Color(hex: 0xF97316))
        case "DANG_LAM": return (T("Đang làm"), AppColors.secondary)
        default: return (T("Chưa làm"), AppColors.textTertiary)
        }
    }
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    static func ngay(_ s: String?) -> Date? {
        guard let s else { return nil }
        return iso.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
    static func conLai(_ han: String) -> (String, Bool) {
        guard let d = ngay(han) else { return ("", false) }
        let giay = d.timeIntervalSinceNow
        let tre = giay < 0
        let a = abs(giay)
        let ngay = Int(a / 86_400), gio = Int(a.truncatingRemainder(dividingBy: 86_400) / 3600)
        let phut = Int(a.truncatingRemainder(dividingBy: 3600) / 60)
        let chu = ngay > 0 ? "\(ngay)d \(gio)h" : gio > 0 ? "\(gio)h \(phut)′" : "\(phut)′"
        return (tre ? String(format: T("trễ %@"), chu) : String(format: T("còn %@"), chu), tre)
    }
}
