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

@MainActor
final class RealtimeCTW: ObservableObject {
    static let shared = RealtimeCTW()

    let suKienChat = PassthroughSubject<SuKienChatCTW, Never>()
    @Published private(set) var daNoi = false

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
        s.on("work:chat:notify") { _, _ in
            Task { @MainActor in await AppState.shared.taiSoChuaDoc() }
        }
        s.on("social:notification") { _, _ in
            Task { @MainActor in await AppState.shared.taiSoChuaDoc() }
        }
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

    private func vaoPhong(pid: Int, cid: Int) {
        guard let socket, socket.status == .connected else { return }
        socket.emitWithAck("work:chat:join", ["projectId": pid, "channelId": cid]).timingOut(after: 8) { _ in }
    }
}
