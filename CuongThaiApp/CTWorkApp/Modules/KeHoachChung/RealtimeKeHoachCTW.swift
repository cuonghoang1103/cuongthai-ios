import Foundation
import Combine
import SocketIO

// MARK: - Realtime cho mảng Kế hoạch (Poker · Retro · OKR · đồng hồ bấm giờ)
//
// Đối chiếu backend `src/socket/work.socket.ts` + `services/work/agileCommon.ts`:
//   · client → server: `work:join <projectId>` (có ack `{ok, role?, error?}`), `work:leave <projectId>`;
//     tối đa 20 phòng/socket; phải vào lại sau mỗi lần nối lại.
//   · server → client: `work:agile {projectId, kind:'okr'|'poker'|'retro', id, action, at}` trong phòng
//     `work:project:<pid>` — KHÔNG mang nội dung ⇒ nhận được thì tải lại qua REST.
//   · `work:timer {at}` vào phòng `user:<id>` (tự vào khi kết nối) — đồng hồ đổi ở thiết bị khác.
//
// Vì sao một socket RIÊNG thay vì sửa `App/RealtimeCTW.swift`: tệp đó do mảng Chat sở hữu và
// đang sửa song song; socket này chỉ mở khi có màn kế hoạch cần nghe (đếm người nghe), đóng khi
// không còn ai — không tốn pin lúc người dùng ở màn khác.

struct SuKienAgileCTW: Equatable {
    var projectId: Int
    /// okr | poker | retro
    var kind: String
    /// id phiên poker / retro / objective
    var id: Int
    /// poker: created · items · started · voted · revealed · timer · estimated · skipped · closed · deleted
    /// retro: created · updated · deleted · card · vote · action · summary
    var action: String
}

@MainActor
final class RealtimeKeHoachCTW: ObservableObject {
    static let shared = RealtimeKeHoachCTW()

    let suKienAgile = PassthroughSubject<SuKienAgileCTW, Never>()
    /// Đồng hồ bấm giờ đổi (bắt đầu/dừng/tạm dừng ở web/desktop) ⇒ tải lại `GET /me/timer`.
    let suKienDongHo = PassthroughSubject<Void, Never>()
    @Published private(set) var daNoi = false

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    /// Đếm người nghe theo dự án (nhiều màn cùng nghe một dự án). Khoá 0 = chỉ cần phòng user (đồng hồ).
    private var nguoiNghe: [Int: Int] = [:]

    private init() {}

    /// Bắt đầu nghe dự án `pid` (0 = chỉ nghe sự kiện cá nhân như đồng hồ). Gọi `boNghe` khi rời màn.
    func nghe(pid: Int) {
        nguoiNghe[pid, default: 0] += 1
        noiNeuCan()
        if pid > 0, nguoiNghe[pid] == 1 { vao(pid) }
    }

    func boNghe(pid: Int) {
        guard let n = nguoiNghe[pid] else { return }
        if n <= 1 {
            nguoiNghe[pid] = nil
            if pid > 0, let socket, socket.status == .connected { socket.emit("work:leave", pid) }
        } else {
            nguoiNghe[pid] = n - 1
        }
        if nguoiNghe.isEmpty { ngat() }
    }

    private func noiNeuCan() {
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
                for pid in self.nguoiNghe.keys where pid > 0 { self.vao(pid) }
            }
        }
        s.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in self?.daNoi = false }
        }
        s.on("work:agile") { [weak self] data, _ in
            guard let d = data.first as? [String: Any], let pid = d["projectId"] as? Int,
                  let kind = d["kind"] as? String, let id = d["id"] as? Int else { return }
            let sk = SuKienAgileCTW(projectId: pid, kind: kind, id: id, action: d["action"] as? String ?? "")
            Task { @MainActor in self?.suKienAgile.send(sk) }
        }
        s.on("work:timer") { [weak self] _, _ in
            Task { @MainActor in self?.suKienDongHo.send(()) }
        }
        s.connect(withPayload: ["token": token])
    }

    private func vao(_ pid: Int) {
        guard let socket, socket.status == .connected else { return }
        socket.emitWithAck("work:join", pid).timingOut(after: 8) { _ in }
    }

    private func ngat() {
        socket?.removeAllHandlers()
        socket?.disconnect()
        socket = nil
        manager = nil
        daNoi = false
    }
}
