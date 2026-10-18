import Foundation

// MARK: - CTWAPI — cuộc họp (`work.governance.routes.ts` mục "Cuộc họp" + `work.ctwk2.routes.ts` phòng họp)

extension CTWAPI {
    /// Báo cáo ghi chú cuộc họp (1.2) — `POST /projects/:pid/meetings/:num/report {reason}` ⇒ `{reported, duplicate}`.
    static func baoCaoHop(pid: Int, so: Int, lyDo: String) -> APIEndpoint {
        goi("/projects/\(pid)/meetings/\(so)/report", "POST", ["reason": lyDo])
    }
    /// `scope`: upcoming | past | all
    static func dsHop(pid: Int, pham: String = "all") -> APIEndpoint { get("/projects/\(pid)/meetings", ["scope": pham]) }
    static func motHop(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/meetings/\(so)") }
    static func taoHop(pid: Int, _ than: [String: Any]) -> APIEndpoint { goi("/projects/\(pid)/meetings", "POST", than) }
    /// PATCH có `version` ⇒ máy chủ trả 409 nếu người khác vừa sửa.
    static func suaHop(pid: Int, so: Int, _ than: [String: Any]) -> APIEndpoint { goi("/projects/\(pid)/meetings/\(so)", "PATCH", than) }
    static func xoaHop(pid: Int, so: Int) -> APIEndpoint { goi("/projects/\(pid)/meetings/\(so)", "DELETE") }
    static func nguoiHop(pid: Int, so: Int, ids: [Int]) -> APIEndpoint { goi("/projects/\(pid)/meetings/\(so)/attendees", "PUT", ["userIds": ids]) }
    /// Thay CẢ danh sách việc: `[{id?, text, assigneeId?, dueDate?}]`.
    static func viecHop(pid: Int, so: Int, _ ds: [[String: Any]]) -> APIEndpoint { goi("/projects/\(pid)/meetings/\(so)/actions", "PUT", ["items": ds]) }
    /// Việc ⇒ thẻ (bỏ `actionIds` = mọi việc chưa có thẻ).
    static func theTuViecHop(pid: Int, so: Int, ids: [Int]) -> APIEndpoint {
        goi("/projects/\(pid)/meetings/\(so)/actions/issues", "POST", ids.isEmpty ? [:] : ["actionIds": ids])
    }
    static func nhanBanHop(pid: Int, so: Int, tuan: Int = 1) -> APIEndpoint { goi("/projects/\(pid)/meetings/\(so)/duplicate", "POST", ["weeks": tuan]) }

    // Phòng họp
    static func phongHop(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/meetings/\(so)/room") }
    /// `YES | NO | MAYBE`
    static func traLoiMoi(pid: Int, so: Int, rsvp: String, ghiChu: String? = nil) -> APIEndpoint {
        var b: [String: Any] = ["rsvp": rsvp]
        if let ghiChu, !ghiChu.isEmpty { b["note"] = ghiChu }
        return goi("/projects/\(pid)/meetings/\(so)/rsvp", "POST", b)
    }
    /// "Vào họp": ghi giờ vào + điểm danh tự động ⇒ `{url, attendance, room}`.
    static func vaoHop(pid: Int, so: Int) -> APIEndpoint { goi("/projects/\(pid)/meetings/\(so)/join", "POST") }
    static func chuongTrinhHop(pid: Int, so: Int, _ ds: [[String: Any]]) -> APIEndpoint {
        goi("/projects/\(pid)/meetings/\(so)/agenda-items", "PUT", ["items": ds])
    }
    static func banGhiLoiHop(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/meetings/\(so)/transcript") }
    /// Áp bản nháp biên bản AI ĐÃ CÓ (không gọi AI — chỉ chép đề xuất người dùng đã xem vào biên bản).
    static func apBanNhapAI(pid: Int, so: Int, did: Int) -> APIEndpoint {
        goi("/projects/\(pid)/meetings/\(so)/minutes-ai/\(did)/apply", "POST")
    }
    static func boBanNhapAI(pid: Int, so: Int, did: Int) -> APIEndpoint {
        goi("/projects/\(pid)/meetings/\(so)/minutes-ai/\(did)/dismiss", "POST")
    }
}
