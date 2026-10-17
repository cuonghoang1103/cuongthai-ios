import SwiftUI

// MARK: - CT Work — model sổ tài sản & giấy phép (`assets.service.ts:164-189`)
// Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).
// `expiresAt` là NGÀY ("YYYY-MM-DD"), không phải ISO đầy đủ.

struct CTWTaiSan: Codable, Hashable, Identifiable {
    struct HetHan: Codable, Hashable {
        /// NONE | OK | EXPIRING | EXPIRED
        var state: String?
        var daysLeft: Int?
    }
    struct LienKet: Codable, Hashable {
        /// ISSUE | PAGE
        var kind: String?
        var number: Int?
        var key: String?
        var title: String?
    }
    var id: Int
    var number: Int?
    var key: String?
    var name: String
    var category: String?
    var licenseType: String?
    var licenseName: String?
    var licenseUrl: String?
    var source: String?
    var sourceUrl: String?
    var version: String?
    var owner: CTWUser?
    var status: String?
    var expiresAt: String?
    var remindDays: Int?
    var expiry: HetHan?
    var cost: Double?
    var currency: String?
    var billing: String?
    var seats: Int?
    var attributionRequired: Bool?
    var attribution: String?
    var notes: String?
    var createdAt: String?
    var updatedAt: String?
    var licenseLabel: String?
    var links: [LienKet]?
}

struct CTWDsTaiSan: Codable {
    struct TongKet: Codable, Hashable {
        var total: Int?
        var active: Int?
        var expiring: Int?
        var expired: Int?
        var needsAttribution: Int?
        var unknownLicense: Int?
        /// `{ "USD": 2040, "VND": 1200000 }`
        var annualCost: [String: Double]?
    }
    var items: [CTWTaiSan]?
    var summary: TongKet?
    var canEdit: Bool?
}

enum CTWTaiSanHienThi {
    static func bieuTuong(_ cat: String?) -> String {
        switch cat {
        case "SOFTWARE": return "app.badge"
        case "LICENSE": return "checkmark.seal"
        case "SERVICE": return "cloud"
        case "DEVICE": return "iphone.gen3"
        case "FONT": return "textformat"
        case "IMAGE": return "photo"
        case "AUDIO": return "waveform"
        case "VIDEO": return "film"
        case "MODEL_3D": return "cube"
        case "LIBRARY": return "shippingbox"
        case "DATASET": return "tablecells"
        default: return "archivebox"
        }
    }

    /// Nhãn hạn dùng: "Expires in 44 days", "Expires today", "Expired 3 days ago", "No expiry".
    static func nhanHan(_ e: CTWTaiSan.HetHan?) -> (chu: String, mau: Color) {
        guard let e, let st = e.state, st != "NONE" else { return ("No expiry", AppColors.textSecondary) }
        let n = e.daysLeft
        switch st {
        case "EXPIRED":
            if let n, n < 0 { return ("Expired \(-n) day\(n == -1 ? "" : "s") ago", AppColors.error) }
            return ("Expired", AppColors.error)
        case "EXPIRING":
            if n == 0 { return ("Expires today", AppColors.warning) }
            if let n { return ("Expires in \(n) day\(n == 1 ? "" : "s")", AppColors.warning) }
            return ("Expiring soon", AppColors.warning)
        default:
            if let n { return ("Expires in \(n) day\(n == 1 ? "" : "s")", AppColors.success) }
            return ("Valid", AppColors.success)
        }
    }

    static func nhanThanhToan(_ b: String?) -> String? {
        switch b {
        case "FREE": return "Free"
        case "ONE_TIME": return "One-time"
        case "MONTHLY": return "per month"
        case "YEARLY": return "per year"
        default: return nil
        }
    }
}
