import Foundation

// MARK: - CTWAPI — Sprint (`work.routes.ts:790-874`)
//
// Ghi (tạo/sửa/bắt đầu/hoàn tất/xoá) cần quyền `sprint.manage` (ADMIN; MEMBER khi dự án bật
// `membersManageSprints`) — app chỉ hiện nút khi `permissions.manageSprints == true`, máy chủ vẫn kiểm.

extension CTWAPI {
    static func dsSprint(pid: Int, coDaDong: Bool = true) -> APIEndpoint {
        get("/projects/\(pid)/sprints", coDaDong ? ["includeClosed": "true"] : nil)
    }

    static func taoSprint(pid: Int, ten: String?, mucTieu: String?) -> APIEndpoint {
        var t: [String: Any] = [:]
        if let ten, !ten.trimmingCharacters(in: .whitespaces).isEmpty { t["name"] = String(ten.prefix(100)) }
        if let mucTieu { t["goal"] = mucTieu.isEmpty ? NSNull() : String(mucTieu.prefix(5000)) }
        return goi("/projects/\(pid)/sprints", "POST", t)
    }

    /// PATCH: chỉ gửi trường đổi. Ngày gửi ISO đầy đủ (máy chủ nhận mọi chuỗi `Date.parse` được).
    static func suaSprint(pid: Int, sid: Int, ten: String?, mucTieu: String?, batDau: Date?, ketThuc: Date?) -> APIEndpoint {
        var t: [String: Any] = [:]
        if let ten { t["name"] = String(ten.prefix(100)) }
        if let mucTieu { t["goal"] = mucTieu.isEmpty ? NSNull() : String(mucTieu.prefix(5000)) }
        if let batDau { t["startAt"] = isoSprint(batDau) }
        if let ketThuc { t["endAt"] = isoSprint(ketThuc) }
        return goi("/projects/\(pid)/sprints/\(sid)", "PATCH", t)
    }

    static func batDauSprint(pid: Int, sid: Int, ten: String?, mucTieu: String?, batDau: Date, ketThuc: Date) -> APIEndpoint {
        var t: [String: Any] = ["startAt": isoSprint(batDau), "endAt": isoSprint(ketThuc)]
        if let ten, !ten.isEmpty { t["name"] = String(ten.prefix(100)) }
        if let mucTieu { t["goal"] = mucTieu.isEmpty ? NSNull() : String(mucTieu.prefix(5000)) }
        return goi("/projects/\(pid)/sprints/\(sid)/start", "POST", t)
    }

    /// `moveTo`: "backlog" | "new" | id sprint PLANNED khác.
    static func hoanTatSprint(pid: Int, sid: Int, chuyenDen: DichChuyenSprintCTW) -> APIEndpoint {
        let v: Any
        switch chuyenDen {
        case .backlog: v = "backlog"
        case .sprintMoi: v = "new"
        case .sprint(let id): v = id
        }
        return goi("/projects/\(pid)/sprints/\(sid)/complete", "POST", ["moveTo": v])
    }

    static func xoaSprint(pid: Int, sid: Int) -> APIEndpoint { goi("/projects/\(pid)/sprints/\(sid)", "DELETE") }

    static func burndown(pid: Int, sid: Int) -> APIEndpoint { get("/projects/\(pid)/reports/burndown", ["sprintId": sid]) }
    static func baoCaoSprint(pid: Int, sid: Int) -> APIEndpoint { get("/projects/\(pid)/reports/sprint", ["sprintId": sid]) }

    /// Mốc ngày người dùng chọn ⇒ nửa đêm theo giờ VN (khớp cách web lưu sprint: 00:00 giờ VN).
    static func isoSprint(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        let goc = NgayCTW.lichVN.date(from: DateComponents(year: c.year, month: c.month, day: c.day)) ?? d
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: goc)
    }
}

enum DichChuyenSprintCTW: Hashable {
    case backlog, sprintMoi
    case sprint(Int)
}
