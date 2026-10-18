import Foundation

// MARK: - CTWAPI — chat dự án (`work.ctwk3.routes.ts`)

extension CTWAPI {
    // MARK: Cấp người dùng

    static func chatChuaDoc() -> APIEndpoint { get("/chat/unread") }
    static func caiDatChat() -> APIEndpoint { get("/chat/prefs") }
    /// `{ mute?: 30m|1h|8h|tomorrow|forever|off, notify?: ALL|MENTIONS, sound?, desktop?, emailDigest? }`
    static func luuCaiDatChat(_ than: [String: Any]) -> APIEndpoint { goi("/chat/prefs", "PUT", than) }

    // MARK: Kênh

    static func dsKenh(pid: Int, coLuuTru: Bool = false) -> APIEndpoint {
        get("/projects/\(pid)/chat/channels", coLuuTru ? ["archived": "1"] : nil)
    }
    /// `kind`: PUBLIC | PRIVATE (nhóm riêng). `memberIds` chỉ áp cho PRIVATE.
    static func taoKenh(pid: Int, ten: String, chuDe: String?, kieu: String, thanhVien: [Int]) -> APIEndpoint {
        var b: [String: Any] = ["name": ten, "kind": kieu]
        if let chuDe, !chuDe.isEmpty { b["topic"] = chuDe }
        if kieu == "PRIVATE" { b["memberIds"] = thanhVien }
        return goi("/projects/\(pid)/chat/channels", "POST", b)
    }
    static func suaKenh(pid: Int, cid: Int, _ than: [String: Any]) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)", "PATCH", than)
    }
    /// Nhắn riêng 1-1 (18/10/2026) — trả kênh cũ nếu đã có. Một bên đã chặn ⇒ 403 `USER_BLOCKED`;
    /// khách cổng ⇒ `CLIENT_PORTAL_ONLY`; nhắn chính mình ⇒ 400.
    static func moDM(pid: Int, userId: Int) -> APIEndpoint { goi("/projects/\(pid)/chat/dm", "POST", ["userId": userId]) }
    static func thanhVienKenh(pid: Int, cid: Int) -> APIEndpoint { get("/projects/\(pid)/chat/channels/\(cid)/members") }
    static func doiThanhVienKenh(pid: Int, cid: Int, them: [Int], bot: [Int]) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)/members", "PUT", ["add": them, "remove": bot])
    }
    /// `{ mute?: 30m|1h|8h|tomorrow|forever|off, notify?: DEFAULT|ALL|MENTIONS }`
    static func baoKenh(pid: Int, cid: Int, _ than: [String: Any]) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)/notify", "PUT", than)
    }
    static func daDocKenh(pid: Int, cid: Int, toiTin: Int? = nil) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)/read", "POST", toiTin.map { ["messageId": $0] } ?? [:])
    }
    static func daDocTatCa(pid: Int) -> APIEndpoint { goi("/projects/\(pid)/chat/read-all", "POST") }
    static func tinGhim(pid: Int, cid: Int) -> APIEndpoint { get("/projects/\(pid)/chat/channels/\(cid)/pinned") }
    static func timTin(pid: Int, cid: Int, q: String) -> APIEndpoint {
        get("/projects/\(pid)/chat/channels/\(cid)/search", ["q": String(q.prefix(200))])
    }
    /// "Gọi nhóm": dùng lại cuộc gọi đang mở hoặc tạo phòng mới (máy chủ tự sinh).
    static func goiNhom(pid: Int, cid: Int) -> APIEndpoint { goi("/projects/\(pid)/chat/channels/\(cid)/call", "POST") }

    // MARK: Tin

    static func dsTin(pid: Int, cid: Int, truoc: Int? = nil, quanh: Int? = nil, limit: Int = 50) -> APIEndpoint {
        var q: [String: Any] = ["limit": limit]
        if let truoc { q["before"] = truoc }
        if let quanh { q["around"] = quanh }
        return get("/projects/\(pid)/chat/channels/\(cid)/messages", q)
    }
    static func motTin(pid: Int, cid: Int, mid: Int) -> APIEndpoint {
        get("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)")
    }
    static func chuoiTraLoi(pid: Int, cid: Int, mid: Int) -> APIEndpoint {
        get("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)/thread")
    }
    static func guiTin(pid: Int, cid: Int, chu: String, traLoi: Int?, khoa: String, tep: [Int] = []) -> APIEndpoint {
        var b: [String: Any] = ["body": chu, "clientKey": khoa]
        if let traLoi { b["parentId"] = traLoi }
        if !tep.isEmpty { b["fileIds"] = tep }
        return goi("/projects/\(pid)/chat/channels/\(cid)/messages", "POST", b)
    }
    static func suaTin(pid: Int, cid: Int, mid: Int, chu: String) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)", "PATCH", ["body": chu])
    }
    static func xoaTin(pid: Int, cid: Int, mid: Int) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)", "DELETE")
    }
    static func camXuc(pid: Int, cid: Int, mid: Int, emoji: String, bat: Bool) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)/reactions/\(doan(emoji))", "PUT", ["active": bat])
    }
    static func ghimTin(pid: Int, cid: Int, mid: Int, ghim: Bool) -> APIEndpoint {
        goi("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)/pin", "PUT", ["pinned": ghim])
    }
    static func theTuTin(pid: Int, cid: Int, mid: Int, loai: Int, tieuDe: String?) -> APIEndpoint {
        var b: [String: Any] = ["typeId": loai]
        if let tieuDe, !tieuDe.isEmpty { b["title"] = tieuDe }
        return goi("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)/issue", "POST", b)
    }
    static func chuyenTiep(pid: Int, cid: Int, mid: Int, toi: Int, ghiChu: String?) -> APIEndpoint {
        var b: [String: Any] = ["toChannelId": toi]
        if let ghiChu, !ghiChu.isEmpty { b["note"] = ghiChu }
        return goi("/projects/\(pid)/chat/channels/\(cid)/messages/\(mid)/forward", "POST", b)
    }

    // MARK: Tệp

    /// Url ký sẵn của tệp chat (`inline=1` ⇒ xem trong app).
    static func urlTepChat(pid: Int, fid: Int, xemTrongApp: Bool = true) -> APIEndpoint {
        get("/projects/\(pid)/chat/files/\(fid)/url", xemTrongApp ? ["inline": "1"] : nil)
    }
    /// Bỏ tệp nháp (đã tải lên nhưng chưa gửi).
    static func boTepNhap(pid: Int, fid: Int) -> APIEndpoint { goi("/projects/\(pid)/chat/files/\(fid)", "DELETE") }

    /// Đường tải lên (multipart — không đi qua `APIEndpoint`, xem `TaiTepChatCTW`).
    static func duongTaiTepChat(pid: Int, cid: Int, giongNoi: Bool) -> String {
        "/api/v1/work/projects/\(pid)/chat/channels/\(cid)/\(giongNoi ? "voice" : "files")"
    }
}
