import Foundation

// MARK: - CTWAPI — Planning Poker (`work.ctw7a.routes.ts:78-98`)

extension CTWAPI {
    static func dsPoker(pid: Int) -> APIEndpoint { get("/projects/\(pid)/poker") }
    static func taoPoker(pid: Int, ten: String, boBai: String, sprintId: Int?) -> APIEndpoint {
        var t: [String: Any] = ["title": String(ten.prefix(120)), "deck": boBai]
        if let sprintId { t["sprintId"] = sprintId }
        return goi("/projects/\(pid)/poker", "POST", t)
    }
    static func phongPoker(pid: Int, sid: Int) -> APIEndpoint { get("/projects/\(pid)/poker/\(sid)") }
    static func dongPoker(pid: Int, sid: Int) -> APIEndpoint { goi("/projects/\(pid)/poker/\(sid)/close", "POST") }
    static func henGioPoker(pid: Int, sid: Int, giay: Int) -> APIEndpoint {
        goi("/projects/\(pid)/poker/\(sid)/timer", "POST", ["seconds": giay])
    }
    /// start · reveal · revote · skip (không thân).
    static func lenhMucPoker(pid: Int, sid: Int, iid: Int, lenh: String) -> APIEndpoint {
        goi("/projects/\(pid)/poker/\(sid)/items/\(iid)/\(lenh)", "POST")
    }
    /// `nil` = rút phiếu.
    static func boPhieuPoker(pid: Int, sid: Int, iid: Int, giaTri: String?) -> APIEndpoint {
        goi("/projects/\(pid)/poker/\(sid)/items/\(iid)/vote", "POST", ["value": giaTri ?? NSNull()])
    }
    static func chotPoker(pid: Int, sid: Int, iid: Int, giaTri: String) -> APIEndpoint {
        goi("/projects/\(pid)/poker/\(sid)/items/\(iid)/finalize", "POST", ["value": giaTri])
    }
}
