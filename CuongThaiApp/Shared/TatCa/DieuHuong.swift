import Foundation

// ════════════════════════════════════════════════════════════════
// ĐIỀU HƯỚNG CHUNG — kiểu dữ liệu + hàm THUẦN (không đụng SwiftUI/UIKit) để
// kiểm thử được: mục thanh bên iPad / cửa sổ phụ, bảng trình bày từ gốc, đọc
// link `cuongthai://`, phân loại thông báo đẩy. Phần ÁP vào trạng thái nằm ở
// `AppState` (moTinhNang / apDung).
// ════════════════════════════════════════════════════════════════

/// Một mục của thanh bên iPad — cũng là GIÁ TRỊ của cửa sổ phụ (`cua-so-phu`),
/// nên phải `Codable` và giải mã được giá trị CŨ.
///
/// ⚠️ Trước 22/10/2026 cửa sổ phụ khoá bằng `AppTab` số nguyên 0…10 (gồm cả
/// Vở/Tiền nong/CT Work). iPadOS khôi phục cửa sổ đã mở bằng chính dữ liệu đã
/// mã hoá đó, nên bản mới vẫn phải đọc được một số trần — không thì cửa sổ
/// khôi phục rơi về mặc định hoặc trắng. `tuTabCu` là bảng đổi.
enum MucBen: Hashable, Codable {
    case tab(AppState.AppTab)
    case tinhNang(TinhNang)
    case tatCa

    /// `AppState.AppTab` cũ (Int) ⇒ mục mới. Số lạ ⇒ Hôm nay (đừng bao giờ ra màn trống).
    static func tuTabCu(_ so: Int) -> MucBen {
        switch so {
        case 0: return .tab(.homNay)
        case 1: return .tab(.hoc)
        case 2: return .tab(.bangTin)        // tab "Tạo" cũ — soạn bài nay ở Bảng tin
        case 3: return .tab(.tinNhan)
        case 4: return .tab(.toi)
        case 5: return .tinhNang(.vo)
        case 6: return .tinhNang(.tienNong)
        case 7: return .tinhNang(.ielts)
        case 8: return .tinhNang(.xuongVe)
        case 9: return .tinhNang(.xuongBa)
        case 10: return .tinhNang(.ctWork)
        default: return .tab(.homNay)
        }
    }

    private enum CodingKeys: String, CodingKey { case loai, ma }

    init(from decoder: Decoder) throws {
        // Giá trị cũ: một số trần.
        if let c = try? decoder.singleValueContainer(), let so = try? c.decode(Int.self) {
            self = Self.tuTabCu(so)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let loai = try c.decode(String.self, forKey: .loai)
        let ma = try c.decodeIfPresent(String.self, forKey: .ma) ?? ""
        switch loai {
        case "tab": self = .tab(AppState.AppTab(rawValue: ma) ?? .homNay)
        case "tinhNang":
            if let f = TinhNang(rawValue: ma) { self = .tinhNang(f) } else { self = .tab(.homNay) }
        case "tatCa": self = .tatCa
        default: self = .tab(.homNay)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .tab(let t): try c.encode("tab", forKey: .loai); try c.encode(t.rawValue, forKey: .ma)
        case .tinhNang(let f): try c.encode("tinhNang", forKey: .loai); try c.encode(f.rawValue, forKey: .ma)
        case .tatCa: try c.encode("tatCa", forKey: .loai)
        }
    }
}

/// Một màn đẩy vào stack của Hôm nay (iPhone) / hiện ở cột chi tiết (iPad).
enum DichHomNay: Hashable {
    case tinhNang(TinhNang)
    case tatCa
}

/// Bảng trình bày từ GỐC (`MainView`) — MỘT `.sheet(item:)` cho tất cả (hai
/// `.sheet` trên cùng view thì chỉ cái cuối chạy — CLAUDE.md C5).
enum BangGoc: String, Identifiable {
    case timKiem, thongBao, notes, caiDat, taoBai
    var id: String { rawValue }
}

/// Đọc link `cuongthai://…` (widget, Share Extension, link ngoài).
enum HanhDongURL: Equatable {
    case tinhNang(TinhNang)
    case tab(AppState.AppTab)
    case nhatVideo
    case timKiem

    /// - `cuongthai://tien` — widget Tiền nong (giữ nguyên từ bản cũ)
    /// - `cuongthai://them-video` — Share Extension
    /// - `cuongthai://tinh-nang/<rawValue>` — mọi tính năng trong danh mục
    /// - `cuongthai://tab/<rawValue>` — năm điểm đến chính
    /// - `cuongthai://tim` — ô tìm kiếm
    static func doc(_ url: URL) -> HanhDongURL? {
        guard url.scheme?.lowercased() == "cuongthai" else { return nil }
        let host = (url.host ?? "").lowercased()
        let doan = url.pathComponents.filter { $0 != "/" }.first ?? ""
        switch host {
        case "tien": return .tinhNang(.tienNong)
        case "them-video": return .nhatVideo
        case "tim": return .timKiem
        case "tinh-nang": return TinhNang(rawValue: doan).map(HanhDongURL.tinhNang)
        case "tab": return AppState.AppTab(rawValue: doan).map(HanhDongURL.tab)
        default: return nil
        }
    }
}

/// Chạm một thông báo đẩy thì đi đâu. Thuần dữ liệu — `ThongBaoDay` CẤT nó lúc
/// chạm, `AppState.apDung` ÁP lúc scene đã active (xem chú thích "cất rồi áp
/// sau" ở `ThongBaoDay`).
enum DinhTuyenDay: Equatable {
    /// CT Work (`kieu` = WORK_*): mở app CT Work riêng (đúng thẻ nếu có đường dẫn).
    case ctWork(duongDan: String?)
    /// Tiền nong (`man` = finance…): mở màn Tiền nong, có thể mở ngay ô ghi chi.
    case tienNong(ghiChiNgay: Bool)
    /// Mạng xã hội (`loai` = xa-hoi): Bảng tin + MỞ bảng thông báo.
    case chuong
    /// Tin nhắn: tab Tin nhắn, mở đúng hội thoại nếu biết.
    case tinNhan(threadId: Int?)

    static func phanLoai(_ info: [AnyHashable: Any]) -> DinhTuyenDay? {
        // `threadId` có thể về dạng Int, NSNumber hoặc chuỗi tuỳ đường đi.
        let tid = (info["threadId"] as? Int)
            ?? (info["threadId"] as? NSNumber)?.intValue
            ?? Int((info["threadId"] as? String) ?? "")
        let loai = info["loai"] as? String
        let kieu = info["kieu"] as? String
        let man = info["man"] as? String
        if kieu?.hasPrefix("WORK_") == true {
            // Thông báo CT Work cũng mang `loai: "xa-hoi"` — phải bắt TRƯỚC
            // nhánh chuông, không thì nó chỉ mở chuông.
            return .ctWork(duongDan: info["duongDan"] as? String)
        }
        if man?.hasPrefix("finance") == true {
            let ghi = (info["hoiChiTieu"] as? Bool) == true
                || (info["hoiChiTieu"] as? NSNumber)?.boolValue == true
            return .tienNong(ghiChiNgay: ghi)
        }
        if loai == "xa-hoi" { return .chuong }
        if loai == "tin-nhan" || tid != nil { return .tinNhan(threadId: tid) }
        return nil
    }
}

extension Notification.Name {
    /// Vừa đăng một bài viết (bảng soạn trình bày từ gốc) — Bảng tin tải lại.
    static let baiVietVuaDang = Notification.Name("ct.baiVietVuaDang")
}
