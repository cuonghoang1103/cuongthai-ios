import Foundation

// MARK: - CTWAPI — hộp thư + cài đặt thông báo + hành động nhanh trên thông báo
//
// Tên hàm có tiền tố `tb` (thông báo) để không trùng hàm của mô-đun khác (Approvals…).

extension CTWAPI {
    /// `GET /me/notify-settings` ⇒ `{emailMode, quietStart, quietEnd}` (`services/work/notify.ts`).
    static func tbCaiDat() -> APIEndpoint { get("/me/notify-settings") }
    /// `{ emailMode?: INSTANT|DIGEST|OFF, quietStart?: 0–23|null, quietEnd?: 0–23|null }` — hai mốc giờ im lặng đi CÙNG nhau.
    static func tbLuuCaiDat(_ than: [String: Any]) -> APIEndpoint { goi("/me/notify-settings", "PUT", than) }
    /// Duyệt / từ chối một yêu cầu phê duyệt (`work.routes.ts` → `approvals.decideApproval`).
    static func tbPheDuyet(pid: Int, aid: Int, dongY: Bool, ghiChu: String? = nil) -> APIEndpoint {
        var b: [String: Any] = ["decision": dongY ? "APPROVE" : "REJECT"]
        if let ghiChu, !ghiChu.isEmpty { b["comment"] = ghiChu }
        return goi("/projects/\(pid)/approvals/\(aid)/decide", "POST", b)
    }
}
