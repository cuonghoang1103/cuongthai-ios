import Foundation

// MARK: - CTWAPI — Sơ đồ (work.diagrams.routes.ts:62-145, ảnh: work.ctw8c.routes.ts:86-97)

extension CTWAPI {
    static func dsSoDo(pid: Int) -> APIEndpoint { get("/projects/\(pid)/diagrams") }
    static func soDo(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/diagrams/\(so)") }
    static func binhLuanSoDo(pid: Int, so: Int, chu: String, banSo: Int?) -> APIEndpoint {
        var b: [String: Any] = ["body": chu]
        if let banSo { b["versionNumber"] = banSo }
        return goi("/projects/\(pid)/diagrams/\(so)/comments", "POST", b)
    }
    static func xoaBinhLuanSoDo(pid: Int, so: Int, cid: Int) -> APIEndpoint {
        goi("/projects/\(pid)/diagrams/\(so)/comments/\(cid)", "DELETE", nil)
    }

    /// Ảnh PNG đã dựng — trả BYTE THÔ (không phải envelope JSON) ⇒ không đi qua
    /// `APIClient.request`; tải bằng `CTWAnhSoDo.tai` (gắn token).
    static func duongAnhSoDo(pid: Int, so: Int, ban: Int?) -> String {
        "/api/v1/work/projects/\(pid)/diagrams/\(so)/image.png" + (ban.map { "?version=\($0)" } ?? "")
    }
}
