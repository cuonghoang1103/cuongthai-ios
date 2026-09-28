import Foundation

// MARK: - Mô hình cho các API PHÂN TÍCH (28/09/2026)
//
// `GET /finance/phan-tich`, `GET /finance/debts/chien-luoc`,
// `GET /finance/debts/:id` (khối `phanTich`), `GET /finance/debts/:id/tat-toan`.
//
// Quy ước ở đây (CLAUDE.md C3/C4):
//  • Mọi trường là `var` và OPTIONAL — backend thêm/bớt một trường không được
//    làm hỏng cả lượt giải mã, vì lỗi giải mã ở app này bị nuốt im lặng và
//    hiện ra thành "màn trống".
//  • Ngày là `String` ("2026-09-28"), không bao giờ `Date`.
//  • Tiền và phần trăm dùng `@TienSoTuyChon`: backend gửi Decimal dạng CHUỖI
//    ("168859760.54") ở chỗ này, số thật ở chỗ khác — đọc được cả hai.
//  • Chỉ số NGUYÊN (số kỳ, số ngày) mới khai `Int?`.
//
// ⚠️ App CHỈ HIỂN THỊ. Mọi con số do máy chủ tính (`phanTich.service.ts`,
// `phanTichNo.ts`). Đừng cộng/nhân lại ở đây: chép công thức lần hai là để
// hai bản trôi khỏi nhau, và bản sai sẽ là bản người dùng nhìn.

// MARK: Gói phân tích tổng

struct GoiPhanTich: Decodable {
    var homNay: String?
    var thang: String?
    var coUsdChuaQuyDoi: Bool?
    var no: PhanTichNoTong?
    var dongTien: DongTienPT?
    var chiTieu: ChiTieuPT?
    var chiSo: ChiSoPT?
    var quyKhanCap: QuyKhanCapPT?
    var dauTu: DauTuPT?
    var soTietKiem: [SoTietKiemPT]?
    var thuTheoNguon: [ThuTheoNguonPT]?
    var canhBao: [CanhBaoTien]?
    var thieuDuLieu: [String]?
}

// MARK: Cảnh báo

struct CanhBaoTien: Decodable, Hashable, Identifiable {
    /// `nguy` (đỏ) · `canh` (cam) · `tin` (trung tính).
    var muc: String?
    var ma: String?
    var tieuDe: String?
    var chiTiet: String?
    /// Đường của WEB (`/finance/debts/1`, `/finance/expenses`) — app tự dịch
    /// sang màn tương ứng, xem `DichLienKetTien`.
    var lienKet: String?

    var id: String { "\(ma ?? "")|\(tieuDe ?? "")|\(lienKet ?? "")" }
}

// MARK: Nợ — tổng hợp

struct PhanTichNoTong: Decodable {
    var tong: TongNoPT?
    var thangNay: NoThangNayPT?
    var lichTheoThang: [LichThangPT]?
    var quaHan: [KyCanhBaoPT]?
    var sapDenHan: [KyCanhBaoPT]?
    var tatToanHomNay: [TatToanNhanhPT]?
    var cacKhoan: [PhanTichKhoanNo]?
    var khoanChuaKhaiPhi: [String]?
}

struct TongNoPT: Decodable {
    @TienSoTuyChon var gocBanDau: Double?
    @TienSoTuyChon var gocConLai: Double?
    @TienSoTuyChon var laiConPhaiTra: Double?
    @TienSoTuyChon var tongConPhaiTra: Double?
    @TienSoTuyChon var laiDaTra: Double?
    @TienSoTuyChon var tongLaiCaKhoan: Double?
    var soKhoanDangNo: Int?
    var ngayHetNo: String?
}

struct NoThangNayPT: Decodable {
    @TienSoTuyChon var conPhaiTra: Double?
    @TienSoTuyChon var laiTrongDo: Double?
    @TienSoTuyChon var daTra: Double?
    @TienSoTuyChon var tongNghiaVu: Double?
    var quaHanThangTruoc: QuaHanThangTruocPT?
}

struct QuaHanThangTruocPT: Decodable {
    var soKy: Int?
    @TienSoTuyChon var tong: Double?
    @TienSoTuyChon var goc: Double?
    @TienSoTuyChon var lai: Double?
}

struct LichThangPT: Decodable, Identifiable {
    var thang: String?
    @TienSoTuyChon var goc: Double?
    @TienSoTuyChon var lai: Double?
    @TienSoTuyChon var tong: Double?
    var soKy: Int?
    @TienSoTuyChon var daTraTrongThang: Double?
    var id: String { thang ?? UUID().uuidString }
}

/// Một kỳ quá hạn / sắp đến hạn trong gói tổng.
struct KyCanhBaoPT: Decodable, Identifiable {
    var debtId: Int?
    var ten: String?
    var tienTe: String?
    var ky: Int?
    var ngay: String?
    @TienSoTuyChon var soTien: Double?
    @TienSoTuyChon var soTienVnd: Double?
    var soNgayQuaHan: Int?
    var conNgay: Int?
    var kyId: Int?
    var id: String { "\(debtId ?? -1)-\(kyId ?? -1)-\(ky ?? -1)" }
}

/// "Nếu tất toán HÔM NAY" — một dòng cho mỗi khoản đang nợ.
struct TatToanNhanhPT: Decodable, Identifiable {
    var debtId: Int?
    var ten: String?
    var tienTe: String?
    @TienSoTuyChon var chiPhiTatToan: Double?
    @TienSoTuyChon var tietKiem: Double?
    @TienSoTuyChon var kyDenHanPhaiTra: Double?
    @TienSoTuyChon var chiPhiTatToanVnd: Double?
    @TienSoTuyChon var tietKiemVnd: Double?
    var chuaKhaiPhi: Bool?
    var soKyBoQua: Int?
    var id: Int { debtId ?? -1 }
}

// MARK: Nợ — một khoản

/// Khối `phanTich` của `GET /debts/:id`, và cũng là phần tử `no.cacKhoan[]`.
struct PhanTichKhoanNo: Decodable, Hashable {
    var id: Int?
    var ten: String?
    var loaiChoVay: String?
    var kieuLai: String?
    var tienTe: String?
    var trangThai: String?
    var daTatToan: Bool?
    @TienSoTuyChon var gocBanDau: Double?
    @TienSoTuyChon var gocDaTra: Double?
    @TienSoTuyChon var gocConLai: Double?
    @TienSoTuyChon var laiDaTra: Double?
    @TienSoTuyChon var laiConPhaiTra: Double?
    @TienSoTuyChon var tongConPhaiTra: Double?
    @TienSoTuyChon var tongLaiCaKhoan: Double?
    @TienSoTuyChon var tongPhaiTraCaKhoan: Double?
    @TienSoTuyChon var daTraThucTe: Double?
    @TienSoTuyChon var chenhLechThucTra: Double?
    var soKy: Int?
    var soKyDaTra: Int?
    var soKyConLai: Int?
    var kyToi: KyLichPT?
    var ngayTatToanDuKien: String?
    var quaHan: QuaHanKhoanPT?
    var sapDenHan: [KyLichPT]?
    var laiSuat: LaiSuatPT?
    @TienSoTuyChon var laiMoiNgay: Double?
    @TienSoTuyChon var phiTraTruocPct: Double?
    var lich: [KyLichPT]?
    var thieuDuLieu: [String]?
}

struct QuaHanKhoanPT: Decodable, Hashable {
    var soKy: Int?
    @TienSoTuyChon var soTien: Double?
    @TienSoTuyChon var goc: Double?
    @TienSoTuyChon var lai: Double?
    var lauNhatNgay: Int?
}

struct LaiSuatPT: Decodable, Hashable {
    /// Phần trăm (0.9 = 0,9%).
    @TienSoTuyChon var danhNghiaThang: Double?
    @TienSoTuyChon var danhNghiaNam: Double?
    /// Lãi suất THỰC (IRR) — với lãi phẳng nó cao gần gấp đôi danh nghĩa.
    @TienSoTuyChon var thucThang: Double?
    @TienSoTuyChon var thucNam: Double?
    /// `DAY` | `MONTH` | `YEAR` — đơn vị người dùng đã khai.
    var donVi: String?
}

/// Một kỳ trong lịch có dư nợ trước/sau và trạng thái do máy chủ chốt.
struct KyLichPT: Decodable, Hashable {
    var id: Int?
    var ky: Int?
    var ngay: String?
    @TienSoTuyChon var goc: Double?
    @TienSoTuyChon var lai: Double?
    @TienSoTuyChon var tong: Double?
    @TienSoTuyChon var duNoTruoc: Double?
    @TienSoTuyChon var duNoSau: Double?
    /// `DA_TRA` | `QUA_HAN` | `HOM_NAY` | `CHUA_DEN`.
    var trangThai: String?
    /// Dương = đã quá bao nhiêu ngày; âm = còn bao nhiêu ngày.
    var soNgayQuaHan: Int?

    var ma: String { "\(id ?? -1)-\(ky ?? -1)" }
}

// MARK: Tất toán sớm (mô phỏng)

struct MoPhongTatToan: Decodable {
    var debtId: Int?
    var tienTe: String?
    var ngay: String?
    var kyDenHanPhaiTra: KyDenHanPT?
    @TienSoTuyChon var gocTatToan: Double?
    @TienSoTuyChon var laiDonKyDangChay: Double?
    var soNgayDaQuaTrongKy: Int?
    var soNgayCuaKy: Int?
    @TienSoTuyChon var phiTraTruoc: Double?
    var chuaKhaiPhi: Bool?
    @TienSoTuyChon var chiPhiTatToan: Double?
    @TienSoTuyChon var tongCanChi: Double?
    @TienSoTuyChon var neuTraTheoLich: Double?
    @TienSoTuyChon var laiTranhDuoc: Double?
    @TienSoTuyChon var tietKiem: Double?
    var soKyBoQua: Int?
    var giaDinh: [String]?
}

struct KyDenHanPT: Decodable {
    var soKy: Int?
    @TienSoTuyChon var soTien: Double?
}

// MARK: Chiến lược trả nợ

struct ChienLuocNo: Decodable {
    var thang: String?
    var soSanh: SoSanhChienLuoc?
    var traMotLan: TraMotLanPT?
    var khoanChuaKhaiPhi: [String]?
    var thieuDuLieu: [String]?
}

struct SoSanhChienLuoc: Decodable {
    @TienSoTuyChon var traThemMoiThang: Double?
    var theoLich: PhuongAnTraNo?
    var toiUu: PhuongAnTraNo?
    var avalanche: PhuongAnTraNo?
    var snowball: PhuongAnTraNo?
    /// `TOI_UU` hoặc `nil` (không phương án nào hơn theo lịch).
    var deXuat: String?
    var giaDinh: [String]?
}

struct PhuongAnTraNo: Decodable {
    var chienLuoc: String?
    var thuTu: [TenKhoanPT]?
    var soThang: Int?
    var thangHetNo: String?
    @TienSoTuyChon var tongLai: Double?
    @TienSoTuyChon var tongPhi: Double?
    @TienSoTuyChon var tongTra: Double?
    @TienSoTuyChon var tietKiemSoVoiLich: Double?
    var somHonThang: Int?
    var tungKhoan: [TungKhoanPT]?
}

struct TenKhoanPT: Decodable, Identifiable {
    var id: Int?
    var ten: String?
}

struct TungKhoanPT: Decodable {
    var id: Int?
    var ten: String?
    var thangTatToan: String?
    @TienSoTuyChon var lai: Double?
    @TienSoTuyChon var phi: Double?
}

struct TraMotLanPT: Decodable {
    @TienSoTuyChon var soTien: Double?
    var xepHang: [XepHangMotLanPT]?
}

struct XepHangMotLanPT: Decodable {
    var id: Int?
    var ten: String?
    @TienSoTuyChon var tienDungDuoc: Double?
    @TienSoTuyChon var tietKiem: Double?
    var dongKhoanLuon: Bool?
    var thangTatToanMoi: String?
    var thangTatToanCu: String?
}

// MARK: Dòng tiền · chi tiêu · chỉ số

struct DongTienPT: Decodable {
    var thangNay: DongTienThangPT?
    var thangTruoc: DongTienThangPT?
    var xuHuong: [DongTienThangPT]?
}

struct DongTienThangPT: Decodable, Identifiable {
    var thang: String?
    @TienSoTuyChon var thu: Double?
    @TienSoTuyChon var chi: Double?
    @TienSoTuyChon var traNo: Double?
    /// thu − chi − trả nợ, máy chủ tính.
    @TienSoTuyChon var rong: Double?
    var coDuLieu: Bool?
    var id: String { thang ?? "?" }
}

struct ChiTieuPT: Decodable {
    @TienSoTuyChon var thangNay: Double?
    @TienSoTuyChon var thangTruoc: Double?
    @TienSoTuyChon var cungKyThangTruoc: Double?
    @TienSoTuyChon var soVoiCungKyPct: Double?
    var ngayTrongThang: Int?
    var soNgayThang: Int?
    @TienSoTuyChon var duBaoCuoiThang: Double?
    var nhom: [NhomChiPT]?
}

struct NhomChiPT: Decodable, Identifiable {
    var nhomId: Int?
    var ten: String?
    var icon: String?
    @TienSoTuyChon var thangNay: Double?
    @TienSoTuyChon var thangTruoc: Double?
    @TienSoTuyChon var cungKyThangTruoc: Double?
    @TienSoTuyChon var chenh: Double?
    @TienSoTuyChon var chenhCungKyPct: Double?
    @TienSoTuyChon var nganSach: Double?
    @TienSoTuyChon var tiLeNganSach: Double?
    @TienSoTuyChon var tiTrong: Double?
    var id: String { "\(nhomId ?? -1)|\(ten ?? "")" }
}

struct ChiSoPT: Decodable {
    @TienSoTuyChon var thuBinhQuan3Thang: Double?
    @TienSoTuyChon var chiBinhQuan3Thang: Double?
    @TienSoTuyChon var traNoBinhQuan3Thang: Double?
    var soThangLamBinhQuan: Int?
    @TienSoTuyChon var nghiaVuNoThangNay: Double?
    /// Phần trăm, vd 47.7.
    @TienSoTuyChon var tyLeNoTrenThu: Double?
    @TienSoTuyChon var tyLeTietKiemThangTruoc: Double?
    @TienSoTuyChon var tyLeChiTrenThuThangNay: Double?
}

struct QuyKhanCapPT: Decodable {
    @TienSoTuyChon var tienMat: Double?
    @TienSoTuyChon var tietKiemGui: Double?
    @TienSoTuyChon var chiMoiThang: Double?
    @TienSoTuyChon var soThang: Double?
    @TienSoTuyChon var soThangKeCaTietKiem: Double?
    var coSo: String?
}

struct DauTuPT: Decodable {
    var tong: TongDauTuPT?
    var cacKhoan: [KhoanDauTuPT]?
}

struct TongDauTuPT: Decodable {
    @TienSoTuyChon var vonDangGiu: Double?
    @TienSoTuyChon var giaTriDangGiu: Double?
    @TienSoTuyChon var laiLoTamTinh: Double?
    @TienSoTuyChon var tySuatTamTinh: Double?
    @TienSoTuyChon var laiLoDaChot: Double?
    @TienSoTuyChon var dauTuBanThan: Double?
}

/// Số tiền ở đây ĐÃ quy ra VND (máy chủ quy), kể cả khoản khai bằng USD.
struct KhoanDauTuPT: Decodable, Identifiable {
    var id: Int?
    var ten: String?
    var loai: String?
    var trangThai: String?
    var tienTe: String?
    var ngay: String?
    @TienSoTuyChon var von: Double?
    @TienSoTuyChon var giaTri: Double?
    @TienSoTuyChon var laiLo: Double?
    @TienSoTuyChon var tySuat: Double?
    var daChot: Bool?
    var chuaCapNhatGia: Bool?
}

struct SoTietKiemPT: Decodable, Identifiable {
    var id: Int?
    var nganHang: String?
    var tienTe: String?
    @TienSoTuyChon var soTien: Double?
    @TienSoTuyChon var laiSuatNam: Double?
    var kyHanThang: Int?
    var ngayDaoHan: String?
    var conNgay: Int?
    @TienSoTuyChon var laiKhiDaoHan: Double?
}

struct ThuTheoNguonPT: Decodable, Identifiable {
    var ten: String?
    var loai: String?
    @TienSoTuyChon var tong: Double?
    var id: String { "\(ten ?? "")|\(loai ?? "")" }
}

// MARK: - Cố vấn AI: phần mới

struct KiemSoAI: Decodable {
    var hopLe: Bool?
    var soKhongKhop: [String]?
    var soDaKiem: Int?
}

// MARK: - Hiển thị dùng chung

enum HienThiPhanTich {
    /// `47.7` → `"47,7%"`. Bỏ phần thập phân khi tròn.
    static func phanTram(_ v: Double?, soLe: Int = 1) -> String {
        guard let v else { return "—" }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = soLe
        return (f.string(from: NSNumber(value: v)) ?? "\(v)") + "%"
    }

    /// Phần trăm có dấu (+35,8% / −8%).
    static func phanTramCoDau(_ v: Double?) -> String {
        guard let v else { return "—" }
        return (v > 0 ? "+" : (v < 0 ? "−" : "")) + phanTram(abs(v))
    }

    /// `"2027-10"` → `"10/2027"`.
    static func thangGon(_ s: String?) -> String {
        guard let s else { return "—" }
        let p = s.split(separator: "-")
        guard p.count >= 2 else { return s }
        return "\(p[1])/\(p[0])"
    }

    /// Số tháng dạng `2,3`.
    static func soThang(_ v: Double?) -> String {
        guard let v else { return "—" }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    static func tenKieuLai(_ m: String?) -> String {
        No.tenKieuLai.first { $0.0 == m }.map { T($0.1) } ?? (m ?? "—")
    }
}

/// Đường của web trong `canhBao[].lienKet` → màn nào ở app.
enum DichLienKetTien {
    case no(id: Int)
    case dsNo
    case chiTieu
    case thuNhap
    case tietKiem
    case dauTu

    static func dich(_ s: String?) -> DichLienKetTien? {
        guard let s, s.hasPrefix("/finance") else { return nil }
        let p = s.split(separator: "?").first.map(String.init) ?? s
        let phan = p.split(separator: "/").map(String.init)   // ["finance", "debts", "1"]
        guard phan.count >= 2 else { return nil }
        switch phan[1] {
        case "debts":
            if phan.count >= 3, let id = Int(phan[2]) { return .no(id: id) }
            return .dsNo
        case "expenses": return .chiTieu
        case "income": return .thuNhap
        case "savings": return .tietKiem
        case "investments": return .dauTu
        default: return nil
        }
    }
}
