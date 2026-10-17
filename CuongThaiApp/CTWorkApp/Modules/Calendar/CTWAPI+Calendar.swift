import Foundation

// MARK: - CTWAPI — Lịch (`work.governance.routes.ts:215`, `work.routes.ts:1570-1580`)
// Tên hàm riêng của mô-đun Calendar (mô-đun Meetings của mảng khác có `dsHop` riêng).

extension CTWAPI {
    /// Họp sắp tới của dự án — 403 `MODULE_DISABLED` / `WORK_INTERNAL_ONLY` khi không dùng được.
    static func hopSapToi(pid: Int) -> APIEndpoint { get("/projects/\(pid)/meetings", ["scope": "upcoming"]) }
    static func linkLich() -> APIEndpoint { get("/me/calendar-link") }
    /// Tạo link .ics MỚI — link cũ bị thu hồi.
    static func taoLinkLich() -> APIEndpoint { goi("/me/calendar-link", "POST") }
}
