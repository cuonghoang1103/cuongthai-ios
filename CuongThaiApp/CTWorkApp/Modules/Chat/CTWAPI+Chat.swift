import Foundation

// MARK: - CTWAPI — chat dự án (`work.ctwk3.routes.ts`)

extension CTWAPI {
    // MARK: Chat

    static func chatChuaDoc() -> APIEndpoint { get("/chat/unread") }
    static func dsKenh(pid: Int) -> APIEndpoint { get("/projects/\(pid)/chat/channels") }
    static func dsTin(pid: Int, cid: Int, truoc: Int? = nil, limit: Int = 50) -> APIEndpoint {
        var q: [String: Any] = ["limit": limit]
        if let truoc { q["before"] = truoc }
        return get("/projects/\(pid)/chat/channels/\(cid)/messages", q)
    }
    static func motTin(pid: Int, cid: Int, mid: Int) -> APIEndpoint {
        get("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)")
    }
    static func chuoiTraLoi(pid: Int, cid: Int, mid: Int) -> APIEndpoint {
        get("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)/thread")
    }
    static func guiTin(pid: Int, cid: Int, chu: String, traLoi: Int?, khoa: String) -> APIEndpoint {
        var b: [String: Any] = ["body": chu, "clientKey": khoa]
        if let traLoi { b["parentId"] = traLoi }
        return goi("/projects/\(pid)/chat/channels/\(cid)/messages", "POST", b)
    }
    static func suaTin(pid: Int, cid: Int, mid: Int, chu: String) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)", "PATCH", ["body": chu])
    }
    static func xoaTin(pid: Int, cid: Int, mid: Int) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)", "DELETE")
    }
    static func daDocKenh(pid: Int, cid: Int) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)/read", "POST")
    }
}
