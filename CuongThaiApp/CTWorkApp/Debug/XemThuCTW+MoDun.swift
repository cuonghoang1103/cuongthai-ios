#if DEBUG
import Foundation

// MARK: - Xem thử MỌI mô-đun bằng máy chủ giả — `CT_XEM_MAN=mod:<id>[/<màn con>]`
//
//     SIMCTL_CHILD_CT_XEM_MAN=mod:approvals xcrun simctl launch <udid> com.cuongthai.ctwork
//     SIMCTL_CHILD_CT_XEM_MAN=mod:tests/run …   (màn con do mô-đun tự đọc `XemThuCTW.moDunXem?.con`)
//
// Vì sao một cú pháp chung: mỗi mô-đun mới không phải sửa `XemThuCTW.swift` (tệp
// mà nhiều phiên cùng sửa) — chỉ thêm dữ liệu mẫu vào tệp `XemThuCTW+<Mảng>.swift`
// của mình rồi nối MỘT dòng vào `DuLieuGiaMoDun.route` dưới đây.
// ⚠️ Cả tệp trong `#if DEBUG` (CLAUDE.md A6).

extension XemThuCTW {
    /// `mod:docs/edit` ⇒ ("docs", "edit").
    static var moDunXem: (id: String, con: String?)? {
        guard let m = man?.trimmingCharacters(in: .whitespaces), m.lowercased().hasPrefix("mod:") else { return nil }
        let phan = m.dropFirst(4).split(separator: "/", maxSplits: 1).map(String.init)
        guard let id = phan.first, !id.isEmpty else { return nil }
        return (id, phan.count > 1 ? phan[1] : nil)
    }

    /// Màn con đang xem thử của mô-đun `id` (nil nếu không xem thử mô-đun đó).
    static func conCua(_ id: String) -> String? {
        guard let m = moDunXem, m.id == id else { return nil }
        return m.con ?? ""
    }
}

/// Bộ định tuyến dữ liệu mẫu của các mô-đun — `DuLieuGia.route` hỏi đây TRƯỚC.
/// Trả `nil` = không phải đường của mô-đun nào ⇒ về bộ định tuyến lõi.
enum DuLieuGiaMoDun {
    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        guard p.hasPrefix("/work/") else { return nil }
        for f in boXuLy { if let r = f(m, p, b) { return r } }
        return nil
    }

    /// Mỗi mảng MỘT dòng.
    static let boXuLy: [(String, String, [String: Any]) -> Any?] = [
        DuLieuGiaDichVu.route,
        DuLieuGiaDocs.route,
        DuLieuGiaGovernance.route,
        DuLieuGiaTests.route,
        DuLieuGiaRequirements.route,
        DuLieuGiaB.route,
        DuLieuGiaToChuc.route,
        DuLieuGiaD.route,
    ]
}
#endif
