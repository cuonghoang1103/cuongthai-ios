import Foundation

// MARK: - Số tiền qua dây
//
// ⚠️ Prisma `Decimal` đi qua JSON dưới dạng **CHUỖI** ("1500000"), không phải
// số. Khai `Double` trần thì `JSONDecoder` ném `typeMismatch` và CẢ MÀN HÌNH
// trống — không có gì hiện ra để biết là vì sao. Nhưng vài chỗ backend đã
// `Number(...)` sẵn (bảng cố vấn AI chẳng hạn) nên nó lại về dạng số thật.
// Cùng một khái niệm, hai hình dạng: phải đọc được cả hai.
//
// Dùng `Double` chứ không `Decimal`: tiền Việt lên tới 10^12 vẫn nằm gọn
// trong 53 bit của Double (≈9·10^15), và mọi phép ở app chỉ là cộng để hiện,
// không phải sổ sách — sổ sách nằm ở máy chủ.
@propertyWrapper
struct TienSo: Codable, Hashable {
    var wrappedValue: Double

    init(wrappedValue: Double) { self.wrappedValue = wrappedValue }

    init(from decoder: Decoder) throws {
        let o = try decoder.singleValueContainer()
        if let d = try? o.decode(Double.self) { wrappedValue = d }
        else if let s = try? o.decode(String.self) { wrappedValue = Double(s) ?? 0 }
        else { wrappedValue = 0 }
    }

    func encode(to encoder: Encoder) throws {
        var o = encoder.singleValueContainer()
        try o.encode(wrappedValue)
    }
}

/// Bản có thể vắng mặt. `null` và trường thiếu đều thành `nil`.
@propertyWrapper
struct TienSoTuyChon: Codable, Hashable {
    var wrappedValue: Double?

    init(wrappedValue: Double?) { self.wrappedValue = wrappedValue }

    init(from decoder: Decoder) throws {
        let o = try decoder.singleValueContainer()
        if o.decodeNil() { wrappedValue = nil }
        else if let d = try? o.decode(Double.self) { wrappedValue = d }
        else if let s = try? o.decode(String.self) { wrappedValue = Double(s) }
        else { wrappedValue = nil }
    }

    func encode(to encoder: Encoder) throws {
        var o = encoder.singleValueContainer()
        if let v = wrappedValue { try o.encode(v) } else { try o.encodeNil() }
    }
}

extension KeyedDecodingContainer {
    // Trường vắng hẳn (không phải `null`) thì Swift KHÔNG gọi init của
    // propertyWrapper — nó đòi phải có, rồi ném. Hai hàm này cho phép vắng.
    func decode(_ type: TienSo.Type, forKey key: Key) throws -> TienSo {
        try decodeIfPresent(TienSo.self, forKey: key) ?? TienSo(wrappedValue: 0)
    }
    func decode(_ type: TienSoTuyChon.Type, forKey key: Key) throws -> TienSoTuyChon {
        try decodeIfPresent(TienSoTuyChon.self, forKey: key) ?? TienSoTuyChon(wrappedValue: nil)
    }
}

// MARK: - Định dạng tiền

enum DinhDangTien {
    /// `1500000` → `"1.500.000₫"`. USD thì `"$1,500"`.
    static func day(_ v: Double, _ tienTe: String = "VND") -> String {
        if tienTe == "USD" {
            return "$" + nguyen(v, dauPhan: ",")
        }
        return nguyen(v, dauPhan: ".") + "₫"
    }

    /// Bản NGẮN cho thẻ số liệu: `1500000` → `"1,5 tr"`, `2400000000` → `"2,4 tỷ"`.
    /// Thẻ "Tổng số dư" rộng 160pt không chứa nổi 13 chữ số — mà cắt bớt chữ
    /// số thì người dùng đọc nhầm đơn vị, tệ hơn là làm tròn.
    static func ngan(_ v: Double, _ tienTe: String = "VND") -> String {
        if tienTe == "USD" { return "$" + nguyen(v, dauPhan: ",") }
        let am = v < 0
        let a = abs(v)
        let chu: String
        if a >= 1_000_000_000 { chu = "\(motSo(a / 1_000_000_000)) tỷ" }
        else if a >= 1_000_000 { chu = "\(motSo(a / 1_000_000)) tr" }
        else if a >= 1_000 { chu = "\(motSo(a / 1_000)) k" }
        else { chu = nguyen(a, dauPhan: ".") + "₫" }
        return (am ? "−" : "") + chu
    }

    private static func motSo(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        if r == r.rounded() { return String(Int(r)) }
        return String(format: "%.1f", r).replacingOccurrences(of: ".", with: ",")
    }

    private static func nguyen(_ v: Double, dauPhan: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = dauPhan
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v.rounded())) ?? "0"
    }

    /// Đọc số người dùng gõ. Chấp cả `1.500.000`, `1500000`, `1,5tr`, `2 tỷ`.
    static func doc(_ chu: String) -> Double? {
        var s = chu.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "₫", with: "")
            .replacingOccurrences(of: "đ", with: "")
        var nhan: Double = 1
        for (hau, n) in [("tỷ", 1_000_000_000.0), ("ty", 1_000_000_000.0),
                         ("tr", 1_000_000.0), ("triệu", 1_000_000.0), ("trieu", 1_000_000.0),
                         ("k", 1_000.0), ("nghìn", 1_000.0), ("nghin", 1_000.0)] where s.hasSuffix(hau) {
            s = String(s.dropLast(hau.count)); nhan = n; break
        }
        // Có hậu tố (1,5tr) ⇒ dấu phẩy là phần THẬP PHÂN. Không có (1.500.000)
        // ⇒ cả chấm lẫn phẩy đều là dấu phân nhóm. Đoán sai chỗ này là lệch
        // một nghìn lần, im lặng.
        if nhan > 1 {
            s = s.replacingOccurrences(of: ",", with: ".")
        } else {
            s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
        }
        guard let v = Double(s) else { return nil }
        return v * nhan
    }
}

// MARK: - Bảng tổng quan

struct BangTien: Decodable {
    let month: String
    @TienSo var totalBalance: Double
    @TienSo var netWorth: Double
    @TienSo var totalRemainingDebt: Double
    @TienSo var totalSavings: Double
    @TienSo var totalAssetValue: Double
    @TienSo var incomeThisMonth: Double
    @TienSo var expenseThisMonth: Double
    @TienSo var savingsThisMonth: Double
    let spendingVsIncomePct: Double?
    let hasUnconvertedUsd: Bool?
    let wallets: [Vi]
    let budgets: [NganSachNhom]
    let cashflow: [DongTienNgay]
    let expenseByCategory: [ChiTheoNhom]
    let upcomingPayments: [KyNoSapToi]
}

struct DongTienNgay: Decodable, Identifiable {
    let date: String
    @TienSo var income: Double
    @TienSo var expense: Double
    var id: String { date }
}

struct ChiTheoNhom: Decodable, Identifiable {
    let category: NhomChi?
    @TienSo var total: Double
    var id: Int { category?.id ?? -1 }
}

struct NganSachNhom: Decodable, Identifiable {
    let category: NhomChi
    @TienSo var budget: Double
    @TienSo var used: Double
    let ratio: Double
    let status: String        // ok | warn | over
    var id: Int { category.id }
}

struct KyNoSapToi: Decodable, Identifiable {
    let id: Int
    let debtId: Int
    let lenderName: String
    let lenderType: String
    let currency: String
    let dueDate: String
    @TienSo var amountDue: Double
    let isOverdue: Bool
}

// MARK: - Ví

struct Vi: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let type: String          // CASH | BANK | EWALLET | OTHER
    let icon: String?
    let color: String?
    @TienSo var balance: Double
    let currency: String
    let isArchived: Bool
    let order: Int

    var bieuTuong: String {
        if let i = icon, !i.isEmpty { return i }
        switch type {
        case "CASH": return "💵"
        case "BANK": return "🏦"
        case "EWALLET": return "📱"
        default: return "👛"
        }
    }

    static let tenLoai: [(String, String)] = [
        ("CASH", "Tiền mặt"), ("BANK", "Ngân hàng"), ("EWALLET", "Ví điện tử"), ("OTHER", "Khác"),
    ]
}

// MARK: - Chi tiêu

struct NhomChi: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let icon: String?
    let color: String?
    @TienSoTuyChon var monthlyBudget: Double?
    var bieuTuong: String { (icon?.isEmpty == false ? icon! : "🏷️") }
}

struct KhoanChi: Decodable, Identifiable, Hashable {
    let id: Int
    let categoryId: Int
    let walletId: Int
    @TienSo var amount: Double
    let currency: String
    let date: String
    let description: String?
    let receiptUrl: String?
    let isRecurring: Bool?
    /// Backend `include` NHÓM nhưng KHÔNG include ví — đừng thêm `wallet` vào
    /// đây rồi hiển thị, nó sẽ luôn trống.
    let category: NhomChi?
}

struct TrangChi: Decodable {
    let items: [KhoanChi]
    let pagination: PhanTrang?
}

struct PhanTrang: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

// MARK: - Thu nhập

struct KhoanThu: Decodable, Identifiable, Hashable {
    let id: Int
    let sourceId: Int?
    let walletId: Int
    @TienSo var amount: Double
    let currency: String
    let date: String
    let type: String          // SALARY | BONUS | OT_PAYOUT | FREELANCE | OTHER
    let note: String?

    static let tenLoai: [(String, String)] = [
        ("SALARY", "Lương"), ("BONUS", "Thưởng"), ("OT_PAYOUT", "Tăng ca"),
        ("FREELANCE", "Freelance"), ("OTHER", "Khác"),
    ]
}

struct NguonThu: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let type: String
    let payType: String
    @TienSoTuyChon var baseSalary: Double?
    @TienSoTuyChon var hourlyRate: Double?
    let currency: String
    let isActive: Bool
    let note: String?
}

// MARK: - Nợ

struct No: Decodable, Identifiable, Hashable {
    let id: Int
    let lenderName: String
    let lenderType: String
    @TienSo var principal: Double
    let currency: String
    let interestType: String
    @TienSo var interestRate: Double
    let startDate: String
    let termMonths: Int?
    let paymentDay: Int?
    let status: String        // ACTIVE | PAID_OFF | OVERDUE
    let note: String?
    let schedule: [KyNo]?
    let computed: TinhNo?

    static let tenBenChoVay: [(String, String)] = [
        ("LOAN_APP", "App vay"), ("BANK", "Ngân hàng"), ("PERSON", "Cá nhân"),
        ("CREDIT_CARD", "Thẻ tín dụng"), ("OTHER", "Khác"),
    ]
    static let tenKieuLai: [(String, String)] = [
        ("FLAT_MONTHLY", "Lãi phẳng / tháng"),
        ("REDUCING_BALANCE", "Lãi giảm dần"),
        ("DAILY_PERCENT", "Lãi ngày (%/ngày)"),
        ("NO_INTEREST", "Không lãi"),
    ]
}

struct TinhNo: Decodable, Hashable {
    @TienSo var remaining: Double
    @TienSo var paidPrincipal: Double
    @TienSo var interestPaid: Double
    @TienSo var projectedInterest: Double
    let progressPct: Double
    let nextDueDate: String?
    @TienSoTuyChon var nextDueAmount: Double?
    @TienSoTuyChon var interestPerDay: Double?
}

struct KyNo: Decodable, Identifiable, Hashable {
    let id: Int
    let debtId: Int
    let installmentNo: Int
    let dueDate: String
    @TienSo var amountDue: Double
    @TienSo var principalPart: Double
    @TienSo var interestPart: Double
    let isPaid: Bool
    let paidAt: String?
}

// MARK: - Tiết kiệm & đầu tư

struct SoTietKiem: Decodable, Identifiable, Hashable {
    let id: Int
    let bankName: String
    @TienSo var amount: Double
    let currency: String
    @TienSo var interestRatePerYear: Double
    let termMonths: Int
    let startDate: String
    let maturityDate: String
    let autoRenew: Bool
    let status: String        // ACTIVE | MATURED | WITHDRAWN
    let note: String?
}

struct MucTieuTietKiem: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    @TienSo var targetAmount: Double
    @TienSo var currentAmount: Double
    let deadline: String?
    let icon: String?
    let status: String
    var tiLe: Double { targetAmount > 0 ? min(1, currentAmount / targetAmount) : 0 }
}

struct KhoanDauTu: Decodable, Identifiable, Hashable {
    let id: Int
    let type: String          // SELF | ASSET
    let name: String
    @TienSo var amount: Double
    let currency: String
    let date: String
    let expectedOutcome: String?
    @TienSoTuyChon var currentValue: Double?
    let status: String        // ACTIVE | COMPLETED | SOLD
    let outcomeNote: String?
    let note: String?

    /// Lãi/lỗ của tài sản. `nil` với đầu tư vào BẢN THÂN — quy kết quả một
    /// khoá học ra tiền là bịa, và một con số bịa trông y như số thật.
    var laiLo: Double? {
        guard type == "ASSET", let cv = currentValue else { return nil }
        return cv - amount
    }
}

// MARK: - Mục tiêu chi tiêu (ngày / tuần / tháng)

struct MucTieuChi: Decodable, Identifiable, Hashable {
    let id: Int
    let ky: String            // DAY | WEEK | MONTH
    let mucTieu: Double
    let daTieu: Double
    let conLai: Double
    let tiLe: Int
    let tuNgay: String
    let denNgay: String?

    var tenKy: String {
        switch ky {
        case "DAY": return T("Hôm nay")
        case "WEEK": return T("Tuần này")
        default: return T("Tháng này")
        }
    }
    var vuot: Bool { conLai < 0 }
}

struct GoiMucTieu: Decodable {
    let mucTieu: [MucTieuChi]
    let homNay: String
}

// MARK: - Cố vấn AI

struct SoLieuCoVan: Decodable {
    let thang: String
    let homNay: String
    let tongSoDu: Double
    let giaTriRong: Double
    let tongNoConLai: Double
    let thuThangNay: Double
    let chiThangNay: Double
    let deDanhThangNay: Double
    let tiLeChiTrenThu: Double?
}

struct TraLoiCoVan: Decodable {
    let nhanXet: String?
    let traLoi: String?
    let lyDo: String?
    let so: SoLieuCoVan?

    /// Phần chữ, dù backend gọi nó là `nhanXet` (tóm tắt) hay `traLoi` (hỏi).
    var chu: String? { traLoi ?? nhanXet }
    var thieuKhoaAI: Bool { lyDo == "ai_unavailable" }
}

// MARK: - Ngày tháng

enum NgayTien {
    static let mayChu: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Ngày hôm nay theo giờ Việt Nam — KHÔNG theo giờ máy.
    ///
    /// Máy chủ chốt "hôm nay" ở +07 (xem `ngayVN()` trong `nhacNhiem.service`).
    /// Máy để múi giờ khác mà app tự lấy ngày địa phương thì mục tiêu ngày
    /// trên app và trên máy chủ lệch nhau một ngày, và không có lỗi nào hiện.
    static func homNay() -> String { mayChu.string(from: Date()) }

    /// `"2026-09-18"` → `"18/09"`. Chuỗi lạ thì trả nguyên — thà xấu còn hơn trống.
    static func ngayGon(_ s: String) -> String {
        let p = s.prefix(10).split(separator: "-")
        guard p.count == 3 else { return s }
        return "\(p[2])/\(p[1])"
    }

    static func ngayDay(_ s: String) -> String {
        let p = s.prefix(10).split(separator: "-")
        guard p.count == 3 else { return s }
        return "\(p[2])/\(p[1])/\(p[0])"
    }

    /// Còn bao nhiêu ngày tới `s` (âm = đã qua). Tính theo lịch VN.
    static func conBaoNhieuNgay(_ s: String) -> Int? {
        guard let d = mayChu.date(from: String(s.prefix(10))),
              let h = mayChu.date(from: homNay()) else { return nil }
        return Int((d.timeIntervalSince(h) / 86400).rounded())
    }

    static func thangHienTai() -> String { String(homNay().prefix(7)) }

    /// `"2026-09"` → `"Tháng 9/2026"`.
    static func tenThang(_ s: String) -> String {
        let p = s.split(separator: "-")
        guard p.count >= 2, let m = Int(p[1]) else { return s }
        return "\(T("Tháng")) \(m)/\(p[0])"
    }

    /// Ngày đầu và ngày cuối của một tháng `"YYYY-MM"`, dạng `YYYY-MM-DD`.
    ///
    /// ⚠️ `GET /finance/expenses` KHÔNG nhận `month` — nó nhận `from`/`to`
    /// (xem `ExpenseFilter` trong `expense.service.ts`). Gửi `month` thì máy
    /// chủ LỜ ĐI, trả về MỌI khoản chi từ trước tới nay, và màn hình vẫn đề
    /// "Tháng 9/2026" ở trên đầu — sai mà không có lỗi nào.
    static func khungThang(_ thang: String) -> (tu: String, den: String) {
        let p = thang.split(separator: "-")
        guard p.count >= 2, let y = Int(p[0]), let m = Int(p[1]) else {
            return (thang + "-01", thang + "-31")
        }
        let soNgay = [31, (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28,
                      31, 30, 31, 30, 31, 31, 30, 31, 30, 31][max(0, min(11, m - 1))]
        return (String(format: "%04d-%02d-01", y, m), String(format: "%04d-%02d-%02d", y, m, soNgay))
    }

    static func doiThang(_ s: String, _ buoc: Int) -> String {
        let p = s.split(separator: "-")
        guard p.count >= 2, let y = Int(p[0]), let m = Int(p[1]) else { return s }
        var nam = y, thang = m + buoc
        while thang > 12 { thang -= 12; nam += 1 }
        while thang < 1 { thang += 12; nam -= 1 }
        return String(format: "%04d-%02d", nam, thang)
    }
}
