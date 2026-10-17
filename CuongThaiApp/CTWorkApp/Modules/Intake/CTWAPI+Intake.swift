import Foundation

// MARK: - CTWAPI — Intake (`work.ctw7b.routes.ts`)

extension CTWAPI {
    static func deXuat(pid: Int, trangThai: String) -> APIEndpoint {
        get("/projects/\(pid)/intake/proposals", ["status": trangThai])
    }
    /// `decision`: ACCEPT | REJECT. Nhận ⇒ tạo thẻ (có thể đổi tiêu đề/loại/người làm/ưu tiên).
    static func quyetDeXuat(pid: Int, id: Int, nhan: Bool, tieuDe: String? = nil, loai: String? = nil,
                            nguoi: Int? = nil, uuTien: Int? = nil, ghiChu: String? = nil) -> APIEndpoint {
        var t: [String: Any] = ["decision": nhan ? "ACCEPT" : "REJECT"]
        if let tieuDe, !tieuDe.isEmpty { t["title"] = tieuDe }
        if let loai { t["typeKey"] = loai }
        if let nguoi { t["assigneeId"] = nguoi }
        if let uuTien { t["priority"] = uuTien }
        if let ghiChu, !ghiChu.isEmpty { t["note"] = String(ghiChu.prefix(300)) }
        return goi("/projects/\(pid)/intake/proposals/\(id)/decide", "POST", t)
    }
}
