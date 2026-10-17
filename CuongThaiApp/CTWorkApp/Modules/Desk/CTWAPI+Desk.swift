import Foundation

// MARK: - CTWAPI — Service desk (`work.desk.routes.ts`) + bình luận/trạng thái thẻ (`work.routes.ts`)

extension CTWAPI {
    static func deskHang(pid: Int, cheDo: String, q: String, sapXep: String) -> APIEndpoint {
        var t: [String: Any] = ["view": cheDo, "sort": sapXep]
        let s = q.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { t["q"] = String(s.prefix(200)) }
        return get("/projects/\(pid)/desk/queue", t)
    }
    static func deskTicket(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/issues/\(so)/desk") }
    /// `{requestType?, impact?, urgency?, priority?}` — đổi ưu tiên ⇒ máy chủ tính lại SLA từ lúc tạo.
    static func deskSua(pid: Int, so: Int, than: [String: Any]) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/desk", "PATCH", than)
    }
    static func deskCho(pid: Int, so: Int, cho: Bool) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/desk/waiting", "POST", ["waiting": cho])
    }

    // Thẻ dưới ticket
    static func dvThe(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/issues/\(so)") }
    static func dvChuyen(pid: Int, so: Int, trangThai: Int, phienBan: Int?) -> APIEndpoint {
        var t: [String: Any] = ["statusId": trangThai]
        if let phienBan { t["version"] = phienBan }
        return goi("/projects/\(pid)/issues/\(so)/move", "POST", t)
    }
    static func dvGiao(pid: Int, so: Int, nguoi: Int?, phienBan: Int?) -> APIEndpoint {
        var t: [String: Any] = ["assigneeId": nguoi.map { $0 as Any } ?? NSNull()]
        if let phienBan { t["version"] = phienBan }
        return goi("/projects/\(pid)/issues/\(so)", "PATCH", t)
    }
    static func dvBinhLuan(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/issues/\(so)/comments") }
    /// `visibility`: PUBLIC (trả lời khách) | INTERNAL (ghi chú nội bộ). Máy chủ tự ép theo vai trò.
    static func dvGuiBinhLuan(pid: Int, so: Int, chu: String, congKhai: Bool?) -> APIEndpoint {
        var t: [String: Any] = ["bodyJson": CTWNode.docTuChu(chu)]
        if let congKhai { t["visibility"] = congKhai ? "PUBLIC" : "INTERNAL" }
        return goi("/projects/\(pid)/issues/\(so)/comments", "POST", t)
    }
    static func dvChiaSeKhach(pid: Int, so: Int) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/client-visible", "PUT", ["visible": true])
    }
}
