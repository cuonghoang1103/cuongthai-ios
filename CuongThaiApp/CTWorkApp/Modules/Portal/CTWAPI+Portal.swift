import Foundation

// MARK: - CTWAPI — Cổng khách (`work.routes.ts` 1977–2063). `xemThu = true` ⇒ `?as=client`
// (đội dự án xem đúng thứ khách thấy; máy chủ chặn mọi thao tác ghi ở chế độ này).
// ⛔ KHÔNG gọi `/portal/payments` — app iOS không có màn tiền nong (3.1.1).

extension CTWAPI {
    private static func pq(_ xemThu: Bool, _ t: [String: Any] = [:]) -> [String: Any]? {
        var q = t
        if xemThu { q["as"] = "client" }
        return q.isEmpty ? nil : q
    }
    static func portalTongQuan(pid: Int, xemThu: Bool) -> APIEndpoint { get("/projects/\(pid)/portal/overview", pq(xemThu)) }
    static func portalYeuCau(pid: Int, loc: String, xemThu: Bool) -> APIEndpoint {
        get("/projects/\(pid)/portal/requests", pq(xemThu, ["filter": loc]))
    }
    static func portalYeuCauCT(pid: Int, so: Int, xemThu: Bool) -> APIEndpoint { get("/projects/\(pid)/portal/requests/\(so)", pq(xemThu)) }
    static func portalTaoYeuCau(pid: Int, loai: String, tieuDe: String, moTa: String, uuTien: Int) -> APIEndpoint {
        var t: [String: Any] = ["kind": loai, "title": tieuDe, "priority": uuTien]
        if !moTa.isEmpty { t["description"] = moTa }
        return goi("/projects/\(pid)/portal/requests", "POST", t)
    }
    static func portalDuyet(pid: Int, xemThu: Bool) -> APIEndpoint { get("/projects/\(pid)/portal/approvals", pq(xemThu)) }
    static func portalTaiLieu(pid: Int, xemThu: Bool) -> APIEndpoint { get("/projects/\(pid)/portal/documents", pq(xemThu)) }
    static func portalTrang(pid: Int, so: Int, xemThu: Bool) -> APIEndpoint { get("/projects/\(pid)/portal/documents/\(so)", pq(xemThu)) }
    /// Duyệt: UAT có route riêng của cổng; loại khác đi route phê duyệt chung (có trong danh sách cho phép của khách).
    static func portalQuyet(pid: Int, d: CTWPortalDuyet, dongY: Bool, yKien: String) -> APIEndpoint {
        var t: [String: Any] = ["decision": dongY ? "APPROVE" : "REJECT"]
        if !yKien.isEmpty { t["comment"] = yKien }
        if d.targetType == "UAT" { return goi("/projects/\(pid)/portal/uat/\(d.id)/decide", "POST", t) }
        return goi("/projects/\(pid)/approvals/\(d.id)/decide", "POST", t)
    }
}
