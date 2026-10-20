import Foundation

// MARK: - CTWAPI — sửa thẻ đầy đủ (20/10/2026)
//
// Đường dẫn đối chiếu `work.routes.ts`, `work.resources.routes.ts`, `work.ctw4.routes.ts` (chỉ đọc —
// không sửa backend). Thẻ: PATCH `/issues/:num` kèm `version` (409 khi có người sửa chen).

extension CTWAPI {
    // MARK: Thẻ

    static func suaThe(pid: Int, so: Int, _ than: [String: Any]) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)", "PATCH", than)
    }
    static func taoThe(pid: Int, _ than: [String: Any]) -> APIEndpoint { goi("/projects/\(pid)/issues", "POST", than) }
    static func nhanBanThe(pid: Int, so: Int) -> APIEndpoint { goi("/projects/\(pid)/issues/\(so)/clone", "POST") }
    static func xoaThe(pid: Int, so: Int) -> APIEndpoint { goi("/projects/\(pid)/issues/\(so)", "DELETE") }
    static func chuyenDuAn(pid: Int, so: Int, dich: Int, version: Int?) -> APIEndpoint {
        var b: [String: Any] = ["targetProjectId": dich]
        if let version { b["version"] = version }
        return goi("/projects/\(pid)/issues/\(so)/move-project", "POST", b)
    }
    /// Thẻ con / thẻ cha có thể chọn (`parent`, `type`, `includeDone`).
    static func dsTheLoc(pid: Int, loai: [Int] = [], cha: Int? = nil, q: String = "", gomXong: Bool = false, limit: Int = 200) -> APIEndpoint {
        var p: [String: Any] = ["limit": limit, "includeDone": gomXong ? "true" : "false"]
        if !loai.isEmpty { p["type"] = loai.map(String.init).joined(separator: ",") }
        if let cha { p["parent"] = cha }
        let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { p["q"] = String(t.prefix(200)) }
        return get("/projects/\(pid)/issues", p)
    }

    // MARK: Cờ "Blocked"

    static func camCo(pid: Int, so: Int, lyDo: String) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/flag", "PUT", ["reason": String(lyDo.prefix(450))])
    }
    static func goCo(pid: Int, so: Int) -> APIEndpoint { goi("/projects/\(pid)/issues/\(so)/flag", "DELETE") }

    // MARK: Liên kết thẻ

    static func themLienKet(pid: Int, so: Int, kieu: String, maDich: String) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/links", "POST", ["type": kieu, "targetKey": maDich])
    }
    static func xoaLienKet(pid: Int, so: Int, lid: Int) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/links/\(lid)", "DELETE")
    }

    // MARK: Trường tuỳ chỉnh

    static func giaTriTruong(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/issues/\(so)/custom-values") }
    static func luuGiaTriTruong(pid: Int, so: Int, truong: Int, _ v: CTWGiaTriTruong?) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/custom-values", "PUT", CTWGiaTriTruong.than(truong: truong, v))
    }

    // MARK: Nhật ký giờ

    static func nhatKyGio(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/issues/\(so)/worklogs") }
    static func xoaNhatKyGio(pid: Int, so: Int, id: Int) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/worklogs/\(id)", "DELETE")
    }

    // MARK: Bộ phận · giai đoạn

    static func boPhan(wsId: Int) -> APIEndpoint { get("/workspaces/\(wsId)/teams") }
    static func giaiDoan(pid: Int) -> APIEndpoint { get("/projects/\(pid)/stages") }

    // MARK: Liên kết web · tài liệu

    static func lienKetWeb(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/issues/\(so)/web-links") }
    static func themLienKetWeb(pid: Int, so: Int, url: String, tieuDe: String?) -> APIEndpoint {
        var b: [String: Any] = ["url": String(url.prefix(2100))]
        if let tieuDe, !tieuDe.isEmpty { b["title"] = String(tieuDe.prefix(300)) }
        return goi("/projects/\(pid)/issues/\(so)/web-links", "POST", b)
    }
    static func xoaLienKetWeb(pid: Int, so: Int, lid: Int) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/web-links/\(lid)", "DELETE")
    }
    static func trangCuaThe(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/issues/\(so)/pages") }
    static func dsTrangNgan(pid: Int) -> APIEndpoint { get("/projects/\(pid)/pages") }
    static func ganTrang(pid: Int, trang: Int, so: Int) -> APIEndpoint {
        goi("/projects/\(pid)/pages/\(trang)/issues", "POST", ["issueNumber": so])
    }
    static func goTrang(pid: Int, trang: Int, so: Int) -> APIEndpoint {
        goi("/projects/\(pid)/pages/\(trang)/issues/\(so)", "DELETE")
    }

    // MARK: Tạo thẻ

    static func mauMoTa(pid: Int) -> APIEndpoint { get("/projects/\(pid)/issue-templates") }
    static func theTuongTu(pid: Int, tieuDe: String) -> APIEndpoint { get("/projects/\(pid)/similar", ["title": String(tieuDe.prefix(255))]) }

    // MARK: Chia sẻ vào kênh · chuyển dự án

    static func kenhChiaSe(pid: Int) -> APIEndpoint { get("/projects/\(pid)/chat/channels") }
    static func chiaSeVaoKenh(pid: Int, cid: Int, chu: String) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)/messages", "POST", ["body": chu, "clientKey": UUID().uuidString])
    }
    static func duAnTrongKhongGian(slug: String) -> APIEndpoint { get("/workspaces/by-slug/\(doan(slug))") }
}

extension CTWAPI {
    /// Giải mã phong bì `{success, data, message, code}` từ dữ liệu THÔ (`APIClient.requestRaw`) — dùng khi
    /// cần đọc MỘT phản hồi bằng hai model (vd `CTWIssueDetail` lõi + `CTWIssueThem`), cùng luật lỗi với `request`.
    static func giaiMa<T: Decodable>(_ kieu: T.Type, _ d: Data) throws -> T {
        let r: APIResponse<T>
        do { r = try JSONDecoder().decode(APIResponse<T>.self, from: d) } catch { throw APIError.decodingError(error) }
        guard r.success, let v = r.data else {
            let m = r.message ?? "Máy chủ không trả về dữ liệu"
            if let ma = r.code, !ma.isEmpty { throw APIError.coMa(ma: ma, thongDiep: m) }
            throw APIError.serverError(m)
        }
        return v
    }
}
