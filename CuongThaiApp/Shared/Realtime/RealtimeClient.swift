import Foundation
import Combine
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
    func vaoPhong(threadId: Int) {
        socket?.emit("thread:join", ["threadId": threadId])
    }

    // MARK: - Nghe

    private func dangKyLangNghe(_ socket: SocketIOClient) {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in self?.trangThai = .daNoi }
        }
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in self?.trangThai = .chuaNoi }
        }
        socket.on(clientEvent: .reconnect) { [weak self] _, _ in
            Task { @MainActor in self?.trangThai = .dangNoi }
        }
        socket.on(clientEvent: .error) { [weak self] _, _ in
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
