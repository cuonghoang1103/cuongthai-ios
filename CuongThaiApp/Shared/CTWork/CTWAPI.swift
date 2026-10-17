import Foundation

// MARK: - CTWAPI — LÕI gọi API CT Work
//
// Mọi đường dẫn tương đối với `/api/v1/work` (`APIEndpoint.workGoi`). Mỗi mảng
// có tệp riêng `CTWAPI+<MoDun>.swift` (thêm tệp mới, đừng sửa tệp của mảng
// khác): `Shared/CTWork/CTWAPI+Issues.swift`, `CTWorkApp/Modules/Chat/CTWAPI+Chat.swift`…
// Nơi gọi KHÔNG gõ chuỗi đường dẫn — gọi hàm có kiểu ở đây.
//
// Lỗi: `APIClient` ném `APIError` (`.coMa(ma, thongDiep)` khi máy chủ trả mã
// như `MODULE_DISABLED`, `CONFLICT`, `WORK_AGENT_FORBIDDEN`) — hiện cho người
// dùng bằng `CTW.loi(error)`; xung đột phiên bản bằng `CTW.laXungDot(error)`.
// Phân trang: mỗi route một kiểu (cursor chuỗi `nextCursor`, `before`/`hasMoreBefore`
// của chat, `offset`/`hasMore` của tìm kiếm) — xem model của từng mảng.

enum CTWAPI {
    /// GET + query (giá trị nào cũng được, `APIClient` tự `"\(v)"`).
    static func get(_ duong: String, _ q: [String: Any]? = nil) -> APIEndpoint {
        .workGoi(duong: duong, phuongThuc: "GET", than: nil, query: q)
    }
    /// POST/PUT/PATCH/DELETE kèm thân JSON (`NSNull()` để gửi `null`).
    static func goi(_ duong: String, _ phuongThuc: String, _ than: [String: Any]? = [:]) -> APIEndpoint {
        .workGoi(duong: duong, phuongThuc: phuongThuc, than: than, query: nil)
    }
    /// Mã hoá MỘT đoạn đường dẫn (slug, mã dự án do người dùng đặt).
    static func doan(_ s: String) -> String { APIEndpoint.maHoaDoan(s) }
}
