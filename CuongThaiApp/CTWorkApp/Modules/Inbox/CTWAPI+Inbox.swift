import Foundation

// MARK: - CTWAPI — hộp thư + cài đặt thông báo + hành động nhanh trên thông báo
//
// Tên hàm có tiền tố `tb` (thông báo) để không trùng hàm của mô-đun khác (Approvals…).

extension CTWAPI {
    /// `GET /me/notify-settings` ⇒ `{emailMode, quietStart, quietEnd, push:{assign,comment,mention,alert,approval,chatAll}, timezone}`
    /// (`services/work/notify.ts → getNotifySettings`; `push` thiếu khoá = bật, `timezone` null = Asia/Ho_Chi_Minh).
    static func tbCaiDat() -> APIEndpoint { get("/me/notify-settings") }
    /// `{ emailMode?, quietStart?: 0–23|null, quietEnd?: 0–23|null, push?: {khoá: Bool} (gửi MỘT PHẦN được), timezone?: IANA|null }`
    /// — hai mốc giờ im lặng đi CÙNG nhau (lệch ⇒ 400 `WORK_BAD_QUIET`); múi giờ lạ ⇒ 400 `WORK_BAD_TIMEZONE`.
    static func tbLuuCaiDat(_ than: [String: Any]) -> APIEndpoint { goi("/me/notify-settings", "PUT", than) }

    // MARK: Hộp thư — lọc theo BỀ MẶT ở máy chủ (`?surface=work`, 18/10/2026)
    //
    // Đường nằm NGOÀI `/api/v1/work` ⇒ dùng `.tuyChinh`; query gắn thẳng vào chuỗi đường dẫn
    // (`APIClient` chỉ ghi đè query khi endpoint có tham số riêng — `.tuyChinh` không có).

    /// `GET /social/notifications?surface=work` — CHỈ `WORK_*`, `unreadCount` đi kèm cũng theo bề mặt.
    static func tbDanhSach(cursor: Int? = nil, limit: Int = 50) -> APIEndpoint {
        var d = "/api/v1/social/notifications?surface=work&limit=\(limit)"
        if let cursor { d += "&cursor=\(cursor)" }
        return .tuyChinh(duong: d, phuongThuc: "GET", than: nil)
    }
    /// `GET /social/notifications/unread-count?surface=work` ⇒ `{unreadCount}` — đúng con số huy hiệu.
    static func tbSoChuaDoc() -> APIEndpoint {
        .tuyChinh(duong: "/api/v1/social/notifications/unread-count?surface=work", phuongThuc: "GET", than: nil)
    }
    /// `PATCH /social/notifications {all:true, surface:'work'}` — chỉ đánh dấu đọc thông báo CT Work
    /// (thông báo mạng xã hội của app chính giữ nguyên).
    static func tbDocHet() -> APIEndpoint {
        .tuyChinh(duong: "/api/v1/social/notifications", phuongThuc: "PATCH", than: ["all": true, "surface": "work"])
    }
    /// Duyệt / từ chối một yêu cầu phê duyệt (`work.routes.ts` → `approvals.decideApproval`).
    static func tbPheDuyet(pid: Int, aid: Int, dongY: Bool, ghiChu: String? = nil) -> APIEndpoint {
        var b: [String: Any] = ["decision": dongY ? "APPROVE" : "REJECT"]
        if let ghiChu, !ghiChu.isEmpty { b["comment"] = ghiChu }
        return goi("/projects/\(pid)/approvals/\(aid)/decide", "POST", b)
    }
}
