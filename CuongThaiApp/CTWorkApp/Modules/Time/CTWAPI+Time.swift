import Foundation

// MARK: - CTWAPI — chấm công (timer · worklog · báo cáo giờ). Route: `work.ctw7a.routes.ts:125-136`,
// `work.routes.ts:1305-1324`, `work.ctw4.routes.ts:168-170`, `work.s4.routes.ts:92`.

extension CTWAPI {
    // MARK: Đồng hồ (một người một đồng hồ)
    static func dongHo() -> APIEndpoint { get("/me/timer") }
    static func suaDongHo(activity: String?, note: String?) -> APIEndpoint {
        var t: [String: Any] = [:]
        t["activity"] = activity ?? NSNull()
        t["note"] = note.map { String($0.prefix(1000)) } ?? NSNull()
        return goi("/me/timer", "PATCH", t)
    }
    /// Bắt đầu đồng hồ trên thẻ. `chuyen = true` ⇒ dừng (và ghi) đồng hồ đang chạy ở thẻ khác.
    static func batDauDongHo(pid: Int, so: Int, activity: String?, note: String?, chuyen: Bool) -> APIEndpoint {
        var t: [String: Any] = [:]
        if let activity { t["activity"] = activity }
        if let note, !note.isEmpty { t["note"] = String(note.prefix(1000)) }
        if chuyen { t["switch"] = true }
        return goi("/projects/\(pid)/issues/\(so)/timer", "POST", t)
    }
    static func dongHoCuaThe(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/issues/\(so)/timer") }
    static func tamDungDongHo() -> APIEndpoint { goi("/me/timer/pause", "POST") }
    static func tiepTucDongHo() -> APIEndpoint { goi("/me/timer/resume", "POST") }
    /// Dừng + ghi worklog. `phut` ghi đè số phút tính được.
    static func dungDongHo(phut: Int?, note: String?, activity: String?) -> APIEndpoint {
        var t: [String: Any] = [:]
        if let phut { t["minutes"] = min(max(phut, 1), 1440) }
        if let note, !note.isEmpty { t["note"] = String(note.prefix(1000)) }
        if let activity { t["activity"] = activity }
        return goi("/me/timer/stop", "POST", t)
    }
    static func huyDongHo() -> APIEndpoint { goi("/me/timer/discard", "POST") }

    // MARK: Worklog
    static func dsWorklog(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/issues/\(so)/worklogs") }
    static func ghiGio(pid: Int, so: Int, phut: Int, batDau: Date, note: String?, activity: String?) -> APIEndpoint {
        let f = ISO8601DateFormatter()
        var t: [String: Any] = ["minutes": min(max(phut, 1), 1440), "startedAt": f.string(from: batDau)]
        if let note, !note.isEmpty { t["note"] = String(note.prefix(1000)) }
        if let activity { t["activity"] = activity }
        return goi("/projects/\(pid)/issues/\(so)/worklogs", "POST", t)
    }
    static func xoaWorklog(pid: Int, so: Int, id: Int) -> APIEndpoint {
        goi("/projects/\(pid)/issues/\(so)/worklogs/\(id)", "DELETE")
    }
    static func worklogMacDinh(pid: Int, so: Int) -> APIEndpoint { get("/projects/\(pid)/issues/\(so)/worklog-defaults") }

    // MARK: Bảng giờ
    /// Giờ theo người trong khoảng ngày (VN, "YYYY-MM-DD"), tối đa 92 ngày.
    static func baoCaoGio(pid: Int, tu: String, den: String, userId: Int?) -> APIEndpoint {
        var q: [String: Any] = ["from": tu, "to": den, "principal": "ALL"]
        if let userId { q["userId"] = userId }
        return get("/projects/\(pid)/reports/time", q)
    }
    static func bangGioTuan(pid: Int, tuan: String) -> APIEndpoint { get("/projects/\(pid)/finance/timesheet", ["week": tuan]) }
}
