import Foundation

// MARK: - CT Work — model Tài chính dự án (CHỈ XEM) — `finance.service.ts`
// Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4). Tiền là `Double`.
// App Store 3.1.1: app chỉ HIỂN THỊ số liệu; không nút trả tiền, không link thanh toán.

struct CTWTaiChinhCaiDat: Codable {
    struct QuyenTC: Codable, Hashable { var manage: Bool?; var ownTimesheet: Bool?; var review: String? }
    var currency: String?
    var contractValue: Double?
    var budgetTotal: Double?
    var alertLevel: Int?
    var access: QuyenTC?
    var notice: String?
}

struct CTWTaiChinhTongQuan: Codable {
    struct TomTat: Codable, Hashable {
        var bac: Double?
        var actual: Double?
        var laborCost: Double?
        var expenseCost: Double?
        var remaining: Double?
        var percentUsed: Double?
        var burnRatePerWeek: Double?
        /// 0…1
        var percentComplete: Double?
        var ev: Double?
        var cpi: Double?
        var eac: Double?
        /// CPI | BURN_RATE
        var eacMethod: String?
        var vac: Double?
        /// OVER | WARN | FORECAST_OVER
        var alerts: [String]?
        var alertLevel: Int?
    }
    struct Dong: Codable, Hashable {
        var id: Int?
        var label: String?
        var category: String?
        var status: String?
        var budget: Double?
        var actual: Double?
    }
    struct Nguoi: Codable, Hashable { var userId: Int?; var name: String?; var minutes: Int?; var cost: Double? }
    struct ThanhToan: Codable, Hashable { var planned: Double?; var due: Double?; var invoiced: Double?; var paid: Double? }
    var currency: String?
    var contractValue: Double?
    var budgetTotal: Double?
    var summary: TomTat?
    var approvedMinutes: Int?
    var pendingMinutes: Int?
    var pendingTimesheets: Int?
    var plannedEnd: String?
    var byStage: [Dong]?
    var byCategory: [Dong]?
    var byPerson: [Nguoi]?
    var payments: ThanhToan?
    var notice: String?
}

/// Mốc thanh toán — CHỈ hiển thị trạng thái, không có thao tác nào trên điện thoại.
struct CTWMocThanhToan: Codable, Hashable, Identifiable {
    struct Ten: Codable, Hashable { var id: Int?; var name: String?; var n: Int? }
    var id: Int
    var number: Int?
    var name: String
    var percent: Double?
    var amount: Double?
    /// MANUAL | UAT | STAGE_GATE
    var trigger: String?
    var dueDate: String?
    /// PLANNED | DUE | INVOICED | PAID
    var status: String?
    var paidAt: String?
    var invoicedAt: String?
    var version: Ten?
    var stage: Ten?
    var computedAmount: Double?
    var overdue: Bool?
}

struct CTWDsMocThanhToan: Codable {
    var currency: String?
    var contractValue: Double?
    var items: [CTWMocThanhToan]?
}

struct CTWChiPhi: Codable, Hashable, Identifiable {
    struct Ten: Codable, Hashable { var id: Int?; var name: String?; var n: Int? }
    var id: Int
    var spentOn: String?
    var category: String?
    var description: String?
    var vendor: String?
    var amount: Double?
    var budgetLine: Ten?
    var stage: Ten?
}

struct CTWBangCong: Codable, Hashable, Identifiable {
    var id: Int
    var userId: Int?
    var userName: String?
    var weekStart: String?
    var weekEnd: String?
    /// SUBMITTED | APPROVED | RETURNED | REOPENED
    var status: String?
    var totalMinutes: Int?
    var note: String?
    var returnReason: String?
    var approvedCost: Double?
}

struct CTWDsBangCong: Codable {
    var items: [CTWBangCong]?
}

// MARK: - Định dạng tiền / số

enum CTWTien {
    /// VND không có phần lẻ; tiền khác 2 số lẻ. Luôn kèm mã tiền tệ (không đoán ký hiệu).
    static func dinhDang(_ v: Double?, _ ma: String?) -> String {
        guard let v else { return "—" }
        let m = (ma ?? "").uppercased()
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        let khongLe = m == "VND" || m == "JPY" || m == "KRW"
        f.maximumFractionDigits = khongLe ? 0 : 2
        f.minimumFractionDigits = khongLe ? 0 : (v.rounded() == v ? 0 : 2)
        let s = f.string(from: NSNumber(value: v)) ?? "\(v)"
        return m.isEmpty ? s : "\(s) \(m)"
    }

    /// Rút gọn cho ô số: 471,698,113 VND → "471.7M VND".
    static func gon(_ v: Double?, _ ma: String?) -> String {
        guard let v else { return "—" }
        let a = abs(v)
        let (chia, hau): (Double, String) = a >= 1e9 ? (1e9, "B") : a >= 1e6 ? (1e6, "M") : a >= 1e4 ? (1e3, "K") : (1, "")
        if hau.isEmpty { return dinhDang(v, ma) }
        let so = v / chia
        let s = String(format: abs(so) >= 100 ? "%.0f" : "%.1f", so)
        return "\(s)\(hau)" + ((ma ?? "").isEmpty ? "" : " \(ma!.uppercased())")
    }

    static func phanTram(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: v.rounded() == v ? "%.0f%%" : "%.1f%%", v)
    }

    /// CPI: 0.848 → "0.85". <1 = đang vượt chi phí.
    static func cpi(_ v: Double?) -> String { v.map { String(format: "%.2f", $0) } ?? "—" }

    static func gio(_ phut: Int?) -> String {
        guard let phut else { return "—" }
        let h = Double(phut) / 60
        return h.rounded() == h ? "\(Int(h)) h" : String(format: "%.1f h", h)
    }

    static func nhanCanhBao(_ a: String) -> String {
        switch a {
        case "OVER": return "Over budget"
        case "WARN": return "Near budget limit"
        case "FORECAST_OVER": return "Forecast over budget"
        default: return CTWMauTrangThai.nhan(a)
        }
    }
}
