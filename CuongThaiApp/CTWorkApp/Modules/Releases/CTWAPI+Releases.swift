import Foundation

// MARK: - CTWAPI — Releases (`work.routes.ts:1245-1274`, `work.uxb.routes.ts:59-62`)

extension CTWAPI {
    static func dsPhienBan(pid: Int) -> APIEndpoint { get("/projects/\(pid)/versions") }
    static func phienBan(pid: Int, id: Int) -> APIEndpoint { get("/projects/\(pid)/versions/\(id)") }
    /// `by`: `count` (số thẻ) | `estimate` (điểm/giờ).
    static func burnupPhatHanh(pid: Int, id: Int, theoSoThe: Bool) -> APIEndpoint {
        get("/projects/\(pid)/reports/release-burnup", ["versionId": id, "by": theoSoThe ? "count" : "estimate"])
    }
    /// Tạo phiên bản — cần quyền `sprint.manage`. Ngày YMD.
    static func taoPhienBan(pid: Int, ten: String, moTa: String?, batDau: String?, phatHanh: String?) -> APIEndpoint {
        goi("/projects/\(pid)/versions", "POST", [
            "name": String(ten.prefix(60)),
            "description": moTa.map { String($0.prefix(5000)) } ?? NSNull(),
            "startDate": batDau ?? NSNull(),
            "releaseDate": phatHanh ?? NSNull(),
        ])
    }
    /// PATCH tự do (chỉ gửi khoá có trong `than`): name, description, startDate, releaseDate,
    /// status (`UNRELEASED` | `ARCHIVED`), releaseNotes (≤ 50 000 ký tự).
    static func suaPhienBan(pid: Int, id: Int, than: [String: Any]) -> APIEndpoint {
        goi("/projects/\(pid)/versions/\(id)", "PATCH", than)
    }
    /// Phát hành. `chuyenSang` = id phiên bản UNRELEASED khác, hoặc nil = gỡ thẻ chưa xong khỏi phiên bản.
    static func phatHanh(pid: Int, id: Int, chuyenSang: Int?, ngay: String?) -> APIEndpoint {
        var t: [String: Any] = ["moveUnresolvedTo": chuyenSang ?? NSNull()]
        if let ngay { t["releaseDate"] = ngay }
        return goi("/projects/\(pid)/versions/\(id)/release", "POST", t)
    }
}
