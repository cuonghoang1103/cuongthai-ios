import Foundation
import Combine
import SocketIO

// MARK: - Realtime cho app CT Work (Socket.IO, namespace mặc định)
//
// Đối chiếu backend `src/socket/work.socket.ts` + `services/work/chat.service.ts`:
//   · xác thực: `auth.token` (JWT) — gửi bằng `connect(withPayload:)`; header
//     Authorization kèm thêm cho chắc.
//   · vào phòng kênh: emit `work:chat:join {projectId, channelId}` (có ack);
//     tối đa 30 phòng / socket. Mất kết nối ⇒ phải vào lại.
//   · nhận: `work:chat:event {projectId, channelId, type, messageId, …}` trong
//     phòng kênh; `work:chat:notify` + `social:notification` vào phòng `user:<id>`
//     (tự vào khi kết nối) ⇒ cập nhật huy hiệu.

struct SuKienChatCTW {
    var projectId: Int
    var channelId: Int
    /// message | update | delete | reaction | pin | channel
    var type: String
    var messageId: Int?
    var parentId: Int?
    var message: CTWChatMessage?
}

/// `work:feed:event` của Bảng tin (hợp đồng api-backend `docs/ctw-feed-hop-dong-api.md` §8) — KHÔNG mang nội dung, chỉ id +
/// bộ đếm; màn tải lại qua REST (REST lọc quyền).
struct SuKienBangTinCTW: Equatable {
    /// post.created | post.updated | post.deleted | comment.created | comment.updated | comment.deleted | reaction | poll
    var type: String
    var postId: Int
    var workspaceId: Int?
    var projectId: Int?
    var actorId: Int?
    var commentId: Int?
    var parentId: Int?
    var commentCount: Int?
    var reactionCount: Int?

    static func tu(_ d: [String: Any]) -> SuKienBangTinCTW? {
        guard let t = d["type"] as? String, let pid = d["postId"] as? Int else { return nil }
        return SuKienBangTinCTW(type: t, postId: pid, workspaceId: d["workspaceId"] as? Int, projectId: d["projectId"] as? Int,
                                actorId: d["actorId"] as? Int, commentId: d["commentId"] as? Int, parentId: d["parentId"] as? Int,
                                commentCount: d["commentCount"] as? Int, reactionCount: d["reactionCount"] as? Int)
    }
}

/// `message:updated` của tin nhắn riêng — chỉ khoá THỰC SỰ đổi (nil = không đổi).
struct SuKienTinNhanDoiCTW {
    var threadId: Int
    var messageId: Int
    var camXuc: [MessageReaction]?
    var thuHoi: Bool?
    var daXoa: Bool?
}

@MainActor
final class RealtimeCTW: ObservableObject {
    static let shared = RealtimeCTW()

    let suKienChat = PassthroughSubject<SuKienChatCTW, Never>()
    /// "Đang gõ…" trong kênh đã vào (`work:chat:typing`) — mô-đun Chat.
    let suKienGo = PassthroughSubject<SuKienGoCTW, Never>()
    @Published private(set) var daNoi = false
    /// Tin nhắn riêng (Messenger chung với web — `messaging.socket.ts`), 21/10/2026: máy chủ tự cho socket vào phòng
    /// mọi hội thoại của mình lúc bắt tay. Kho `KhoTinNhanCTW` nghe các luồng này.
    let tinNhanMoi = PassthroughSubject<(threadId: Int, tin: Message), Never>()
    let tinNhanDoi = PassthroughSubject<SuKienTinNhanDoiCTW, Never>()
    let tinNhanDaDoc = PassthroughSubject<(threadId: Int, readerId: Int, readAt: Date), Never>()
    let tinNhanDangGo = PassthroughSubject<(threadId: Int, userId: Int, dangGo: Bool), Never>()
    /// `presence:update` — chỉ phát cho bạn bè ∪ người đã có hội thoại, và KHÔNG phát cho người tắt trạng thái.
    let hienDien = PassthroughSubject<(userId: Int, online: Bool), Never>()
    /// Bảng tin (21/10/2026): `work:feed:event` — viên "N bài mới", bộ đếm bình luận/cảm xúc.
    let suKienBangTin = PassthroughSubject<SuKienBangTinCTW, Never>()

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    /// Các phòng đang muốn ở — vào lại sau mỗi lần nối lại.
    private var phong: Set<[Int]> = []

    private init() {}

    func noi() {
        #if DEBUG
        if AppState.shared.cheDoXemThu { return }
        #endif
        guard socket == nil, let token = StorageManager.shared.getAuthToken(),
              let url = URL(string: APIClient.diaChiGoc) else { return }
        let m = SocketManager(socketURL: url, config: [
            .log(false), .compress,
            .extraHeaders(["Authorization": "Bearer \(token)", "X-Client-Platform": APIClient.nenTang]),
            .forceWebsockets(true), .reconnects(true), .reconnectWait(2), .reconnectWaitMax(30),
        ])
        let s = m.defaultSocket
        manager = m
        socket = s
        s.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.daNoi = true
                for p in self.phong { self.vaoPhong(pid: p[0], cid: p[1]) }
                // Bảng tin: xin vào phòng mọi phạm vi đọc được — PHẢI gửi lại sau mỗi lần nối lại (hợp đồng §8).
                // Máy chủ cũ không biết sự kiện này ⇒ bỏ qua, vô hại.
                self.dangKyBangTin()
                // Nối lại ⇒ gửi các tin đang chờ trong hàng chờ ngoại tuyến.
                await HangChoGuiCTW.shared.xa()
            }
        }
        s.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in self?.daNoi = false }
        }
        s.on("work:chat:event") { [weak self] data, _ in
            guard let d = data.first as? [String: Any],
                  let pid = d["projectId"] as? Int, let cid = d["channelId"] as? Int,
                  let type = d["type"] as? String else { return }
            var msg: CTWChatMessage?
            if let m = d["message"], let j = try? JSONSerialization.data(withJSONObject: m) {
                msg = try? JSONDecoder().decode(CTWChatMessage.self, from: j)
            }
            let sk = SuKienChatCTW(projectId: pid, channelId: cid, type: type,
                                   messageId: d["messageId"] as? Int, parentId: d["parentId"] as? Int, message: msg)
            Task { @MainActor in self?.suKienChat.send(sk) }
        }
        s.on("work:chat:typing") { [weak self] data, _ in
            guard let d = data.first as? [String: Any],
                  let pid = d["projectId"] as? Int, let cid = d["channelId"] as? Int else { return }
            var u: CTWUser?
            if let x = d["user"], let j = try? JSONSerialization.data(withJSONObject: x) {
                u = try? JSONDecoder().decode(CTWUser.self, from: j)
            }
            let sk = SuKienGoCTW(projectId: pid, channelId: cid, threadId: d["threadId"] as? Int,
                                 dangGo: (d["typing"] as? Bool) ?? true, user: u)
            Task { @MainActor in self?.suKienGo.send(sk) }
        }
        s.on("work:chat:notify") { _, _ in
            Task { @MainActor in await AppState.shared.taiSoChuaDoc() }
        }
        // Đã đọc ở thiết bị khác (web/desktop) ⇒ huy hiệu theo kịp.
        s.on("work:chat:read") { _, _ in
            Task { @MainActor in await AppState.shared.taiSoChuaDoc() }
        }
        s.on("social:notification") { _, _ in
            Task { @MainActor in await AppState.shared.taiSoChuaDoc() }
        }
        s.on("work:feed:event") { [weak self] data, _ in
            guard let d = data.first as? [String: Any], let e = SuKienBangTinCTW.tu(d) else { return }
            Task { @MainActor in self?.suKienBangTin.send(e) }
        }
        ngheTinNhan(s)
        s.connect(withPayload: ["token": token])
    }

    func ngat() {
        socket?.removeAllHandlers()
        socket?.disconnect()
        socket = nil
        manager = nil
        daNoi = false
        phong = []
    }

    func noiLai() { ngat(); noi() }

    func vaoKenh(pid: Int, cid: Int) {
        phong.insert([pid, cid])
        vaoPhong(pid: pid, cid: cid)
    }

    func roiKenh(pid: Int, cid: Int) {
        phong.remove([pid, cid])
        socket?.emit("work:chat:leave", ["projectId": pid, "channelId": cid])
    }

    /// `work:feed:subscribe` (không tham số) — chỉ khi máy chủ có bảng tin (hoặc chưa biết).
    func dangKyBangTin() {
        guard let socket, socket.status == .connected, KhoBangTinCTW.shared.hoTro != false else { return }
        socket.emitWithAck("work:feed:subscribe").timingOut(after: 8) { _ in }
    }

    /// Báo "đang gõ" (máy chủ chỉ phát lại trong phòng kênh socket đã vào; có trần nhịp).
    func baoDangGo(pid: Int, cid: Int, chuoi: Int?, dangGo: Bool) {
        guard let socket, socket.status == .connected else { return }
        var d: [String: Any] = ["projectId": pid, "channelId": cid, "typing": dangGo]
        if let chuoi { d["threadId"] = chuoi }
        socket.emit("work:chat:typing", d)
    }

    /// "Đang gõ…" trong tin nhắn riêng (`thread:typing`; máy chủ chỉ chuyển trong phòng hội thoại mình thuộc).
    func baoDangGoTinNhan(threadId: Int, dangGo: Bool) {
        guard let socket, socket.status == .connected else { return }
        socket.emit("thread:typing", ["threadId": threadId, "isTyping": dangGo])
    }

    /// Hội thoại vừa tạo SAU lúc bắt tay ⇒ xin vào phòng (máy chủ kiểm mình có trong hội thoại).
    func vaoHoiThoai(_ threadId: Int) {
        guard let socket, socket.status == .connected else { return }
        socket.emit("thread:join", ["threadId": threadId])
    }

    private func ngheTinNhan(_ s: SocketIOClient) {
        s.on("thread:new-message") { [weak self] data, _ in
            guard let d = data.first as? [String: Any], let tid = d["threadId"] as? Int, let raw = d["message"],
                  let j = try? JSONSerialization.data(withJSONObject: raw),
                  let tin = try? JSONDecoder().decode(Message.self, from: j) else { return }
            Task { @MainActor in self?.tinNhanMoi.send((threadId: tid, tin: tin)) }
        }
        s.on("message:updated") { [weak self] data, _ in
            guard let d = data.first as? [String: Any], let tid = d["threadId"] as? Int, let mid = d["messageId"] as? Int else { return }
            let doi = d["changes"] as? [String: Any] ?? [:]
            var camXuc: [MessageReaction]?
            if let r = doi["reactions"], let j = try? JSONSerialization.data(withJSONObject: r) {
                camXuc = try? JSONDecoder().decode([MessageReaction].self, from: j)
            }
            // Khoá vắng mặt giữ nil — thả cảm xúc không có `recalled`, đọc thiếu thành false là "bỏ thu hồi" nhầm.
            let sk = SuKienTinNhanDoiCTW(threadId: tid, messageId: mid, camXuc: camXuc,
                                         thuHoi: doi["recalled"] as? Bool, daXoa: doi["deleted"] as? Bool)
            Task { @MainActor in self?.tinNhanDoi.send(sk) }
        }
        s.on("thread:read") { [weak self] data, _ in
            guard let d = data.first as? [String: Any], let tid = d["threadId"] as? Int, let ai = d["readerId"] as? Int else { return }
            // `readAt` khi là chuỗi ISO, khi là số mili giây — nhận cả hai.
            let moc: Date? = (d["readAt"] as? String).flatMap(Date.tuChuoiISO)
                ?? (d["readAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
            guard let moc else { return }
            Task { @MainActor in self?.tinNhanDaDoc.send((threadId: tid, readerId: ai, readAt: moc)) }
        }
        s.on("thread:typing") { [weak self] data, _ in
            guard let d = data.first as? [String: Any], let tid = d["threadId"] as? Int, let ai = d["userId"] as? Int else { return }
            let go = d["isTyping"] as? Bool ?? false
            Task { @MainActor in self?.tinNhanDangGo.send((threadId: tid, userId: ai, dangGo: go)) }
        }
        s.on("presence:update") { [weak self] data, _ in
            guard let d = data.first as? [String: Any], let ai = d["userId"] as? Int else { return }
            let online = (d["online"] as? Bool) ?? false
            Task { @MainActor in self?.hienDien.send((userId: ai, online: online)) }
        }
        s.on("thread:created") { _, _ in
            Task { @MainActor in await KhoTinNhanCTW.shared.taiHoiThoai() }
        }
    }

    private func vaoPhong(pid: Int, cid: Int) {
        guard let socket, socket.status == .connected else { return }
        socket.emitWithAck("work:chat:join", ["projectId": pid, "channelId": cid]).timingOut(after: 8) { _ in }
    }
}
