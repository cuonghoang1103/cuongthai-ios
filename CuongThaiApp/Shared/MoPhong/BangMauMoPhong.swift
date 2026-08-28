import SwiftUI

// ════════════════════════════════════════════════════════════════
// BẢNG MÀU SÂN KHẤU — chép từ `components/simulation/theme.ts`
//
// ⚠️ Web KHÔNG dùng 3D (không three.js, `getContext('2d')`). Thứ làm nó đẹp
// là hệ MÀU HAI LỚP: mỗi luồng có màu LÕI và màu QUẦNG (sáng hơn), cộng
// gradient nền, lưới kỹ thuật, bụi sao và bóng đổ. Bản đầu của tôi vẽ phẳng
// một màu nên nhìn "đúng mà nhạt".
//
// Trang này DARK-ONLY có chủ đích: nó là bề mặt quay video bài giảng, nền
// phải cố định để mọi bản ghi trông giống nhau. Vì thế KHÔNG dùng màu theo
// chủ đề của app ở đây.
// ════════════════════════════════════════════════════════════════

struct KieuLuong {
    let loi: Color
    let quang: Color
}

enum MauSanKhau {
    static let nenTrong = Color(hex: 0x141B2E)
    static let nenNgoai = Color(hex: 0x080B16)
    static let luoi = Color(hex: 0x1B2438)
    static let luoiChinh = Color(hex: 0x24314A)

    /// 13 loại luồng — màu lõi + màu quầng, lấy nguyên `FLOW_STYLES`.
    static func luong(_ k: String?) -> KieuLuong {
        switch (k ?? "").uppercased() {
        case "GET":        return .init(loi: Color(hex: 0x10B981), quang: Color(hex: 0x6EE7B7))
        case "POST":       return .init(loi: Color(hex: 0x22D3EE), quang: Color(hex: 0xA5F3FC))
        case "PUT":        return .init(loi: Color(hex: 0xF59E0B), quang: Color(hex: 0xFCD34D))
        case "DELETE":     return .init(loi: Color(hex: 0xF43F5E), quang: Color(hex: 0xFDA4AF))
        case "RESPONSE":   return .init(loi: Color(hex: 0x34D399), quang: Color(hex: 0xA7F3D0))
        case "ERROR":      return .init(loi: Color(hex: 0xEF4444), quang: Color(hex: 0xFCA5A5))
        case "CACHE_HIT":  return .init(loi: Color(hex: 0xA855F7), quang: Color(hex: 0xE9D5FF))
        // Cache MISS cố tình "buồn" hơn HIT — giữ đúng dụng ý của web.
        case "CACHE_MISS": return .init(loi: Color(hex: 0xB08968), quang: Color(hex: 0xD6C3AE))
        case "EVENT":      return .init(loi: Color(hex: 0xE879F9), quang: Color(hex: 0xF5D0FE))
        case "TOKEN":      return .init(loi: Color(hex: 0xFACC15), quang: Color(hex: 0xFEF08A))
        case "QUERY":      return .init(loi: Color(hex: 0x60A5FA), quang: Color(hex: 0xBFDBFE))
        case "ACK":        return .init(loi: Color(hex: 0x94A3B8), quang: Color(hex: 0xCBD5E1))
        default:           return .init(loi: Color(hex: 0x64748B), quang: Color(hex: 0x94A3B8))
        }
    }

    /// 13 loại nút — `NODE_STYLES`. Nhãn loại hiện dưới tên, đúng như web:
    /// nhận ra "đây là CACHE" bằng MÀU trước khi kịp đọc chữ.
    static func nut(_ k: String?) -> (Color, String) {
        switch (k ?? "").lowercased() {
        case "client":  return (Color(hex: 0x38BDF8), "CLIENT")
        case "edge":    return (Color(hex: 0xF97316), "EDGE")
        case "gateway": return (Color(hex: 0x818CF8), "GATEWAY")
        case "server":  return (Color(hex: 0x22D3EE), "SERVICE")
        case "cache":   return (Color(hex: 0xA855F7), "CACHE")
        case "db":      return (Color(hex: 0x60A5FA), "DATABASE")
        case "queue":   return (Color(hex: 0xFB923C), "BROKER")
        case "worker":  return (Color(hex: 0x4ADE80), "WORKER")
        case "auth":    return (Color(hex: 0xFACC15), "AUTH")
        case "socket":  return (Color(hex: 0xE879F9), "REALTIME")
        case "storage": return (Color(hex: 0xF59E0B), "STORAGE")
        case "ci":      return (Color(hex: 0xC084FC), "PIPELINE")
        case "index":   return (Color(hex: 0x2DD4BF), "INDEX")
        default:        return (Color(hex: 0x64748B), "NODE")
        }
    }

    /// Màu theo TRẠNG THÁI nút, đè lên màu loại khi nút đang hoạt động.
    static func trangThai(_ s: String?, mac: Color) -> Color {
        switch (s ?? "idle") {
        case "error": return Color(hex: 0xEF4444)
        case "success": return Color(hex: 0x34D399)
        case "waiting": return Color(hex: 0xFBBF24)
        case "processing", "active": return mac
        default: return mac
        }
    }
}

/// Băm số nguyên → [0,1). Thay `Math.random()` ở mọi chỗ cần "nhiễu".
///
/// ⚠️ TẤT ĐỊNH là điều kiện sống còn: cùng một bước phải vẽ ra cùng một hình,
/// nếu không thì tua đi tua lại thấy bụi sao nhảy loạn.
func bam01(_ n: Int) -> Double {
    var h = UInt32(truncatingIfNeeded: n) ^ 0x9E3779B9
    h = (h ^ (h >> 15)) &* 0x85EBCA6B
    h = (h ^ (h >> 13)) &* 0xC2B2AE35
    return Double((h ^ (h >> 16))) / 4294967296.0
}
