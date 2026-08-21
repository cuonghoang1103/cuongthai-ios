import Foundation
import Combine
import os
import SocketIO

// MARK: - Kết nối thời gian thực
//
// Máy chủ: socket.io 4.8.3, đường `/socket.io/`, xác thực bằng JWT đọc từ
// header `Authorization: Bearer` (`extractToken` ưu tiên header trước cookie,
// nên native không cần cookie).
//
// Lúc bắt tay xong, máy chủ TỰ cho vào phòng `user:<id>` và mọi phòng
// `thread:<id>` mà mình là thành viên — không phải tự join từng cái. Chỉ khi
// mở một hội thoại chưa nằm trong danh sách nạp sẵn mới cần gửi `thread:join`.
//
// Sự kiện nghe:
//   thread:new-message  { threadId, threadType, participantIds, message }
//   thread:typing       { threadId, userId, isTyping }
//   thread:read         { threadId, readerId, readAt, … }
//   social:notification { id, type, entityId, receiverId, … }
//   presence:update     { userId, online }
// Sự kiện gửi:
//   thread:typing { threadId, isTyping }
//   thread:join   { threadId }

@MainActor
final class RealtimeClient: ObservableObject {
    static let shared = RealtimeClient()

    enum TrangThai: String {
        case chuaNoi, dangNoi, daNoi
        var moTa: String {
            switch self {
            case .chuaNoi: return "Ngoại tuyến"
            case .dangNoi: return "Đang kết nối…"
            case .daNoi: return "Trực tuyến"
            }
        }
    }

    @Published private(set) var trangThai: TrangThai = .chuaNoi
    /// id người đang gõ, theo từng hội thoại.
    @Published private(set) var dangGo: [Int: Set<Int>] = [:]
    /// Người đang trực tuyến (từ `presence:update`).
    @Published private(set) var truyenTuyen: Set<Int> = []

    /// Tin mới về từ máy chủ. ChatView nghe cái này thay vì hỏi lại API.
    let tinMoi = PassthroughSubject<(threadId: Int, message: Message), Never>()
    /// `thread:read` — người kia vừa mở hội thoại, dùng để dời mốc "Đã xem".
    let daDoc = PassthroughSubject<(threadId: Int, readerId: Int, readAt: Date), Never>()

    // ── Gọi thoại ────────────────────────────────────────────────
    //
    // Chỉ chuyển hộ lời chào (SDP) và đường đi mạng (ICE). Tiếng nói KHÔNG đi
    // qua socket — nó đi thẳng máy-tới-máy, hoặc vòng qua TURN khi không nối
    // thẳng được.
    /// Máy chủ báo mã cuộc gọi NGAY khi bắt đầu đổ chuông. Người gọi cần nó
    /// để gửi ứng viên ICE, vốn bay ra trước lúc bên kia bắt máy nhiều giây.
    let goiDoChuong = PassthroughSubject<String, Never>()
    let goiToi = PassthroughSubject<(callId: String, threadId: Int, tuUserId: Int,
                                     sdp: [String: Any], ten: String, anh: String?), Never>()
    let goiDuocNhan = PassthroughSubject<(callId: String, sdp: [String: Any]), Never>()
    let goiIce = PassthroughSubject<[String: Any], Never>()
    let goiKetThuc = PassthroughSubject<(lyDo: String, giay: Int), Never>()
    let goiBan = PassthroughSubject<String, Never>()
    /// `message:updated` — thả cảm xúc, thu hồi, xoá một tin đã gửi.
    let tinDoi = PassthroughSubject<(threadId: Int, messageId: Int,
                                     reactions: [MessageReaction]?,
                                     thuHoi: Bool?, daXoa: Bool?), Never>()

    private static let log = Logger(subsystem: "com.cuongthai.app", category: "realtime")

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var hetGoTask: [Int: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Vòng đời

    func noi() {
        guard socket == nil, let token = StorageManager.shared.getAuthToken() else { return }
        guard let url = URL(string: "https://cuongthai.com") else { return }

        trangThai = .dangNoi
        let manager = SocketManager(
            socketURL: url,
            config: [
                .log(false),
                .compress,
                // Header thay vì cookie: bản native không giữ cookie, và
                // `extractToken` đọc header TRƯỚC cookie nên đường này chắc.
                .extraHeaders(["Authorization": "Bearer \(token)"]),
                // Ép websocket, bỏ chặng polling: chặng polling gửi token
                // trong mọi lượt hỏi và tốn thêm một vòng bắt tay.
                .forceWebsockets(true),
                .reconnects(true),
                .reconnectWait(2),
                .reconnectWaitMax(30),
            ],
        )
        let socket = manager.defaultSocket
        self.manager = manager
        self.socket = socket

        dangKyLangNghe(socket)
        socket.connect()
    }

    func ngat() {
        socket?.removeAllHandlers()
        socket?.disconnect()
        socket = nil
        manager = nil
        trangThai = .chuaNoi
        dangGo = [:]
        truyenTuyen = []
        hetGoTask.values.forEach { $0.cancel() }
        hetGoTask = [:]
    }

    /// Gọi lại sau khi đăng nhập bằng tài khoản khác — token cũ đã nằm trong
    /// header của kết nối cũ, không tự đổi được.
    func noiLai() {
        ngat()
        noi()
    }

    // MARK: - Gửi

    func baoDangGo(threadId: Int, dangGo: Bool) {
        socket?.emit("thread:typing", ["threadId": threadId, "isTyping": dangGo])
    }

    /// Chỉ cần khi mở hội thoại KHÔNG nằm trong danh sách máy chủ tự cho vào
    /// lúc bắt tay (ví dụ hội thoại vừa tạo xong).
    // ── Gửi tín hiệu cuộc gọi ────────────────────────────────────
    func guiGoi(threadId: Int, toUserId: Int, sdp: [String: Any]) {
        socket?.emit("call:offer", ["threadId": threadId, "toUserId": toUserId, "sdp": sdp])
    }

    func guiNhanGoi(callId: String, sdp: [String: Any]) {
        socket?.emit("call:answer", ["callId": callId, "sdp": sdp])
    }

    func guiIce(callId: String, candidate: [String: Any]) {
        socket?.emit("call:ice", ["callId": callId, "candidate": candidate])
    }

    func guiTuChoi(callId: String) {
        socket?.emit("call:reject", ["callId": callId])
    }

    func guiCupMay(callId: String) {
        socket?.emit("call:end", ["callId": callId])
    }

    func vaoPhong(threadId: Int) {
        socket?.emit("thread:join", ["threadId": threadId])
    }

    // MARK: - Nghe

    private func dangKyLangNghe(_ socket: SocketIOClient) {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            Self.log.notice("socket ĐÃ NỐI")
            Task { @MainActor in
                NhatKy.socket.info("SOCKET ĐÃ NỐI")
                self?.trangThai = .daNoi
            }
        }
        socket.on(clientEvent: .disconnect) { [weak self] data, _ in
            Self.log.notice("socket NGẮT: \(String(describing: data), privacy: .public)")
            Task { @MainActor in self?.trangThai = .chuaNoi }
        }
        socket.on(clientEvent: .reconnect) { [weak self] _, _ in
            Task { @MainActor in self?.trangThai = .dangNoi }
        }
        socket.on(clientEvent: .error) { [weak self] data, _ in
            Self.log.error("socket LỖI: \(String(describing: data), privacy: .public)")
            // Token hết hạn cũng rơi vào đây. Không thử lại vô hạn với token
            // hỏng — REST sẽ làm mới token, lần `noi()` sau dùng token mới.
            Task { @MainActor in self?.trangThai = .chuaNoi }
        }

        socket.on("thread:new-message") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let threadId = dict["threadId"] as? Int,
                  let raw = dict["message"],
                  let tin = Self.giaiMa(Message.self, tu: raw)
            else { return }
            Task { @MainActor in
                self?.tinMoi.send((threadId: threadId, message: tin))
                // Tin mới thì người đó thôi gõ.
                self?.datDangGo(threadId: threadId, userId: tin.senderId, dangGo: false)
            }
        }

        socket.on("message:updated") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let threadId = dict["threadId"] as? Int,
                  let messageId = dict["messageId"] as? Int
            else { return }
            let doi = dict["changes"] as? [String: Any] ?? [:]
            // `changes` chỉ chứa những khoá THỰC SỰ đổi — thả cảm xúc thì không
            // có `recalled`. Đọc thiếu khoá thành `false` sẽ "bỏ thu hồi" một
            // tin đã thu hồi, nên phải giữ nil khi khoá vắng mặt.
            var camXuc: [MessageReaction]?
            if let raw = doi["reactions"] {
                camXuc = Self.giaiMa([MessageReaction].self, tu: raw)
            }
            Task { @MainActor in
                self?.tinDoi.send((threadId: threadId, messageId: messageId,
                                   reactions: camXuc,
                                   thuHoi: doi["recalled"] as? Bool,
                                   daXoa: doi["deleted"] as? Bool))
            }
        }

        // ── Sự kiện cuộc gọi ─────────────────────────────────────
        socket.on("call:ringing") { [weak self] data, _ in
            guard let d = data.first as? [String: Any],
                  let id = d["callId"] as? String else { return }
            Task { @MainActor in self?.goiDoChuong.send(id) }
        }

        socket.on("call:incoming") { [weak self] data, _ in
            guard let d = data.first as? [String: Any],
                  let id = d["callId"] as? String,
                  let tid = d["threadId"] as? Int,
                  let tu = d["fromUserId"] as? Int,
                  let sdp = d["sdp"] as? [String: Any] else { return }
            let ten = d["tenNguoiGoi"] as? String ?? "Người dùng"
            let anh = d["anhNguoiGoi"] as? String
            Task { @MainActor in
                self?.goiToi.send((callId: id, threadId: tid, tuUserId: tu,
                                   sdp: sdp, ten: ten, anh: anh))
            }
        }

        socket.on("call:answered") { [weak self] data, _ in
            guard let d = data.first as? [String: Any],
                  let id = d["callId"] as? String,
                  let sdp = d["sdp"] as? [String: Any] else { return }
            Task { @MainActor in self?.goiDuocNhan.send((callId: id, sdp: sdp)) }
        }

        socket.on("call:ice") { [weak self] data, _ in
            guard let d = data.first as? [String: Any],
                  let c = d["candidate"] as? [String: Any] else { return }
            Task { @MainActor in self?.goiIce.send(c) }
        }

        socket.on("call:end") { [weak self] data, _ in
            guard let d = data.first as? [String: Any] else { return }
            let lyDo = d["lyDo"] as? String ?? "cup-may"
            let giay = d["giay"] as? Int ?? 0
            Task { @MainActor in self?.goiKetThuc.send((lyDo: lyDo, giay: giay)) }
        }

        socket.on("call:busy") { [weak self] data, _ in
            let ai = (data.first as? [String: Any])?["ai"] as? String ?? "ho"
            Task { @MainActor in self?.goiBan.send(ai) }
        }

        socket.on("thread:read") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let threadId = dict["threadId"] as? Int,
                  let readerId = dict["readerId"] as? Int
            else { return }
            // Socket.IO giao `readAt` khi thì chuỗi ISO, khi thì số mili giây,
            // tuỳ cách bên phát serialize — nhận cả hai, đừng đoán một kiểu.
            let moc: Date?
            if let chuoi = dict["readAt"] as? String {
                moc = Date.tuChuoiISO(chuoi)
            } else if let ms = dict["readAt"] as? Double {
                moc = Date(timeIntervalSince1970: ms / 1000)
            } else {
                moc = nil
            }
            guard let readAt = moc else { return }
            Task { @MainActor in
                self?.daDoc.send((threadId: threadId, readerId: readerId, readAt: readAt))
            }
        }

        socket.on("thread:typing") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let threadId = dict["threadId"] as? Int,
                  let userId = dict["userId"] as? Int
            else { return }
            let go = dict["isTyping"] as? Bool ?? false
            Task { @MainActor in self?.datDangGo(threadId: threadId, userId: userId, dangGo: go) }
        }

        socket.on("presence:update") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let userId = dict["userId"] as? Int
            else { return }
            let online = (dict["online"] as? Bool) ?? (dict["status"] as? String == "online")
            Task { @MainActor in
                if online { self?.truyenTuyen.insert(userId) } else { self?.truyenTuyen.remove(userId) }
            }
        }

        socket.on("social:notification") { _, _ in
            Task { @MainActor in
                AppState.shared.unreadNotifications += 1
            }
        }
    }

    // MARK: - Nội bộ

    private func datDangGo(threadId: Int, userId: Int, dangGo go: Bool) {
        var tap = dangGo[threadId] ?? []
        if go { tap.insert(userId) } else { tap.remove(userId) }
        dangGo[threadId] = tap.isEmpty ? nil : tap

        hetGoTask[threadId]?.cancel()
        guard go else { return }
        // Lưới đỡ: máy chủ chỉ phát "đang gõ", KHÔNG bảo đảm phát "thôi gõ"
        // (người kia đóng app giữa chừng là mất hẳn tín hiệu tắt). Thiếu cái
        // này thì dòng "đang gõ…" đứng nguyên trên màn hình mãi mãi.
        hetGoTask[threadId] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.datDangGo(threadId: threadId, userId: userId, dangGo: false) }
        }
    }

    private static func giaiMa<T: Decodable>(_ kieu: T.Type, tu raw: Any) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: raw) else { return nil }
        return try? JSONDecoder().decode(kieu, from: data)
    }
}
