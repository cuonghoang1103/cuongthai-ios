import Foundation
// `@preconcurrency` vì WebRTC là module Objective-C cũ, không có chú thích
// `Sendable`. Bản thân `RTCPeerConnection` an toàn khi gọi từ nhiều luồng —
// chỉ là trình biên dịch Swift không có cách nào biết điều đó.
@preconcurrency import WebRTC
import AVFoundation

// ════════════════════════════════════════════════════════════════
// GỌI THOẠI 1-1 — bản iOS
//
// Cùng luật với web và desktop, nhưng API khác hẳn: WebRTC của Swift dùng
// hàm gọi ngược kiểu Objective-C chứ không phải `Promise`, và mọi thứ phải
// tự đẩy về đúng luồng.
//
// ⚠️ BA BẢN NÀY LÀ ANH EM — sửa một chỗ phải xem hai chỗ kia:
//   frontend/src/lib/webrtc/cuocGoi.ts
//   desktop/src/renderer/realtime/cuocGoi.ts
// Người dùng gọi GIỮA iOS và desktop, nên một bên xử ca hỏng khác là hỏng
// đúng lúc hai bên không cùng loại máy.
// ════════════════════════════════════════════════════════════════

enum TrangThaiGoi: Equatable {
    case roi, dangGoi, doChuong, dangNoi
}

@MainActor
final class CuocGoi: NSObject, ObservableObject {
    @Published private(set) var trangThai: TrangThaiGoi = .roi
    @Published var loi: String?
    @Published private(set) var tenBenKia = ""
    @Published private(set) var giay = 0

    private var pc: RTCPeerConnection?
    private var luongCuaToi: RTCAudioTrack?
    private var callId: String?
    private var sdpCho: RTCSessionDescription?
    private var daDon = false
    private var dongHo: Timer?

    /// Ứng viên ICE của CHÍNH MÌNH, chờ có `callId` mới gửi được.
    ///
    /// ⚠️ Máy chủ sinh `callId` và báo về bằng `call:ringing`, nhưng ICE bắt
    /// đầu bay ra ngay sau `createOffer` — sớm hơn vài trăm mili giây. Vứt
    /// chúng đi thì báo hiệu xong xuôi mà hai bên KHÔNG BAO GIỜ nghe được
    /// nhau. Đây đúng là lỗi đã gặp trên web ngày 21/08/2026.
    private var iceGuiCho: [RTCIceCandidate] = []
    /// Ứng viên của BÊN KIA, chờ `setRemoteDescription` xong.
    private var iceChoXuLy: [RTCIceCandidate] = []
    private var daCoMoTaXa = false
    private var thuNoiLai = false

    /// Một nhà máy cho cả vòng đời app. Dựng lại mỗi cuộc gọi thì rò bộ nhớ
    /// và có lúc âm thanh câm không rõ lý do.
    private static let nhaMay: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory(),
        )
    }()

    private let realtime = RealtimeClient.shared

    // ── Phiên âm thanh ──────────────────────────────────────────
    //
    // ⚠️ PHẢI đi qua `RTCAudioSession`, KHÔNG được gọi thẳng `AVAudioSession`.
    // WebRTC có bộ quản phiên âm thanh riêng và tự cấu hình lại lúc bắt đầu
    // truyền tiếng; chỉnh thẳng `AVAudioSession` là hai bên giành nhau, và
    // phần thua thường là mình — ra đúng cái cảnh "hai máy báo đang nói mà
    // không ai nghe thấy gì", không lỗi, không log.
    // `lockForConfiguration()` là cách báo cho WebRTC biết mình đang đổi.
    //
    // `.voiceChat` bật khử vọng và tự chỉnh mức. Thiếu nó thì hai bên nghe
    // tiếng chính mình vọng lại và tưởng máy hỏng.
    private func batAmThanh() {
        let phien = RTCAudioSession.sharedInstance()
        phien.lockForConfiguration()
        defer { phien.unlockForConfiguration() }
        do {
            try phien.setCategory(.playAndRecord, mode: .voiceChat,
                                  options: [.allowBluetoothHFP, .defaultToSpeaker])
            try phien.setActive(true)
        } catch {
            print("[gọi] không đặt được phiên âm thanh: \(error)")
        }
    }

    private func tatAmThanh() {
        let phien = RTCAudioSession.sharedInstance()
        phien.lockForConfiguration()
        defer { phien.unlockForConfiguration() }
        try? phien.setActive(false)
    }

    // ── Dựng kết nối ────────────────────────────────────────────
    private func dungPeer(_ iceServers: [RTCIceServer]) -> RTCPeerConnection? {
        let cauHinh = RTCConfiguration()
        cauHinh.iceServers = iceServers
        // `unifiedPlan` là chuẩn hiện hành; trình duyệt chỉ nói được nó, nên
        // để `planB` là iOS và web không hiểu nhau.
        cauHinh.sdpSemantics = .unifiedPlan
        cauHinh.continualGatheringPolicy = .gatherContinually

        let rangBuoc = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let pc = Self.nhaMay.peerConnection(with: cauHinh, constraints: rangBuoc, delegate: self)
        else { return nil }

        let nguon = Self.nhaMay.audioSource(with: RTCMediaConstraints(
            mandatoryConstraints: [
                "googEchoCancellation": "true",
                "googNoiseSuppression": "true",
                "googAutoGainControl": "true",
            ],
            optionalConstraints: nil,
        ))
        let track = Self.nhaMay.audioTrack(with: nguon, trackId: "audio0")
        pc.add(track, streamIds: ["luong0"])
        luongCuaToi = track
        self.pc = pc
        return pc
    }

    private func rangBuocThoai() -> RTCMediaConstraints {
        RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "false"],
            optionalConstraints: nil,
        )
    }

    // ── Gọi đi ──────────────────────────────────────────────────
    func goi(threadId: Int, toUserId: Int, ten: String) async {
        guard await xinMicro() else {
            loi = "Bạn chưa cho phép dùng micro. Bật lại trong Cài đặt → CuongThai → Micro."
            return
        }
        daDon = false
        tenBenKia = ten
        loi = nil
        batAmThanh()

        // Vào lại phòng trước khi gọi.
        //
        // ⚠️ Máy chủ chỉ nhận `call:offer` khi socket ĐANG ở trong phòng
        // `thread:{id}` (call.socket.ts:132) và **im lặng bỏ qua** nếu không —
        // không báo lỗi gì. Socket.IO thì mất sạch phòng mỗi lần nối lại, nên
        // một lần rớt sóng giữa chừng là nút gọi chết câm cho tới khi người
        // dùng thoát ra vào lại hội thoại.
        // 300ms là để phần kiểm quyền bằng database ở máy chủ kịp xong; đường
        // nhanh (đã ở trong phòng) không tốn gì cả.
        realtime.vaoPhong(threadId: threadId)
        try? await Task.sleep(for: .milliseconds(300))

        guard let pc = dungPeer(await layIceServers()) else {
            loi = "Không dựng được kết nối."
            return
        }
        trangThai = .dangGoi

        pc.offer(for: rangBuocThoai()) { [weak self] sdp, _ in
            guard let self, let sdp else { return }
            pc.setLocalDescription(sdp) { _ in
                Task { @MainActor in
                    self.realtime.guiGoi(threadId: threadId, toUserId: toUserId,
                                         sdp: ["type": "offer", "sdp": sdp.sdp])
                }
            }
        }
    }

    // ── Có người gọi tới ────────────────────────────────────────
    func chuanBiNhan(callId: String, sdp: [String: Any], ten: String) {
        self.callId = callId
        self.tenBenKia = ten
        self.daDon = false
        self.loi = nil
        if let chu = sdp["sdp"] as? String {
            sdpCho = RTCSessionDescription(type: .offer, sdp: chu)
        }
        trangThai = .doChuong
    }

    func nhan() async {
        guard let sdpCho, let callId else { return }
        guard await xinMicro() else {
            loi = "Bạn chưa cho phép dùng micro."
            tuChoi()
            return
        }
        batAmThanh()
        guard let pc = dungPeer(await layIceServers()) else { tuChoi(); return }

        pc.setRemoteDescription(sdpCho) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.daCoMoTaXa = true
                self.doIceDangCho()
                pc.answer(for: self.rangBuocThoai()) { sdp, _ in
                    guard let sdp else { return }
                    pc.setLocalDescription(sdp) { _ in
                        Task { @MainActor in
                            self.realtime.guiNhanGoi(callId: callId,
                                                     sdp: ["type": "answer", "sdp": sdp.sdp])
                            // KHÔNG đặt `.dangNoi` ở đây — gửi lời đáp xong
                            // không nghĩa là đã nghe được nhau. Đợi ICE bắt
                            // cặp; `didChange newState` mới là chỗ biết thật.
                        }
                    }
                }
            }
        }
    }

    // ── Bên kia bắt máy ─────────────────────────────────────────
    func benKiaDaNhan(sdp: [String: Any]) {
        guard let pc, let chu = sdp["sdp"] as? String else { return }
        pc.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: chu)) { [weak self] _ in
            Task { @MainActor in
                self?.daCoMoTaXa = true
                self?.doIceDangCho()
            }
        }
    }

    func themIce(_ c: [String: Any]) {
        guard let chu = c["candidate"] as? String else { return }
        let ung = RTCIceCandidate(sdp: chu,
                                  sdpMLineIndex: Int32(c["sdpMLineIndex"] as? Int ?? 0),
                                  sdpMid: c["sdpMid"] as? String)
        guard let pc, daCoMoTaXa else { iceChoXuLy.append(ung); return }
        pc.add(ung) { _ in }
    }

    private func doIceDangCho() {
        let ds = iceChoXuLy
        iceChoXuLy = []
        for c in ds { pc?.add(c) { _ in } }
    }

    /// Máy chủ vừa cho biết mã — đổ hết ứng viên đang xếp hàng đi.
    func datCallId(_ id: String) {
        callId = id
        let ds = iceGuiCho
        iceGuiCho = []
        for c in ds { realtime.guiIce(callId: id, candidate: moTaIce(c)) }
    }

    private func moTaIce(_ c: RTCIceCandidate) -> [String: Any] {
        var d: [String: Any] = ["candidate": c.sdp, "sdpMLineIndex": Int(c.sdpMLineIndex)]
        if let mid = c.sdpMid { d["sdpMid"] = mid }
        return d
    }

    // ── Kết thúc ────────────────────────────────────────────────
    func tuChoi() {
        if let callId { realtime.guiTuChoi(callId: callId) }
        don()
    }

    func cupMay() {
        if let callId { realtime.guiCupMay(callId: callId) }
        don()
    }

    /// Dọn tài nguyên. Gọi được nhiều lần — bốn đường kết thúc đều qua đây,
    /// và quên tắt phiên âm thanh là micro của máy sáng đèn mãi.
    func don() {
        if daDon { return }
        daDon = true
        dongHo?.invalidate(); dongHo = nil
        giay = 0
        luongCuaToi = nil
        pc?.close()
        pc = nil
        callId = nil
        sdpCho = nil
        iceGuiCho = []
        iceChoXuLy = []
        daCoMoTaXa = false
        thuNoiLai = false
        tatAmThanh()
        trangThai = .roi
    }

    func tatMicro(_ tat: Bool) {
        luongCuaToi?.isEnabled = !tat
    }

    /// Chuyển giữa loa ngoài và loa nghe áp tai.
    ///
    /// Mặc định là loa NGOÀI (`defaultToSpeaker` lúc dựng phiên): gọi thoại
    /// trong app này gần như luôn là vừa nói vừa nhìn màn hình, chứ không phải
    /// áp máy vào tai như gọi điện thoại thường.
    func doiLoa(_ ngoai: Bool) {
        let phien = RTCAudioSession.sharedInstance()
        phien.lockForConfiguration()
        defer { phien.unlockForConfiguration() }
        try? phien.overrideOutputAudioPort(ngoai ? .speaker : .none)
    }

    // ── Phụ trợ ─────────────────────────────────────────────────
    private func xinMicro() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    private func layIceServers() async -> [RTCIceServer] {
        struct Vo: Decodable {
            let iceServers: [May]
            let turn: Bool
            struct May: Decodable {
                let urls: [String]
                let username: String?
                let credential: String?
                // `urls` có thể là chuỗi ĐƠN hoặc mảng — máy chủ trả cả hai
                // dạng tuỳ mục. Khai cứng một kiểu là hỏng cả mảng.
                private enum CodingKeys: String, CodingKey { case urls, username, credential }
                init(from d: Decoder) throws {
                    let c = try d.container(keyedBy: CodingKeys.self)
                    if let mot = try? c.decode(String.self, forKey: .urls) { urls = [mot] }
                    else { urls = (try? c.decode([String].self, forKey: .urls)) ?? [] }
                    username = try? c.decode(String.self, forKey: .username)
                    credential = try? c.decode(String.self, forKey: .credential)
                }
            }
        }
        do {
            let v: Vo = try await APIClient.shared.request(.mayChuIce)
            if !v.turn {
                print("[gọi] TURN chưa cấu hình — gọi qua 4G nhiều khả năng hỏng")
            }
            return v.iceServers.map {
                if let u = $0.username, let c = $0.credential {
                    return RTCIceServer(urlStrings: $0.urls, username: u, credential: c)
                }
                return RTCIceServer(urlStrings: $0.urls)
            }
        } catch {
            // Mất mạng lúc hỏi thì vẫn thử bằng STUN công khai — còn hơn
            // không gọi được.
            return [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        }
    }

    fileprivate func batDauDemGio() {
        guard dongHo == nil else { return }
        giay = 0
        dongHo = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.giay += 1 }
        }
    }
}

// ── Đại diện của WebRTC ─────────────────────────────────────────
//
// Mọi hàm ở đây chạy trên luồng NỀN của WebRTC, nên phải đẩy về luồng chính
// trước khi đụng vào `@Published` — không thì SwiftUI đổi giao diện ngoài
// luồng chính và app sập, đúng họ với vụ thông báo đẩy hôm 21/08.
extension CuocGoi: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let id = self.callId else { self.iceGuiCho.append(candidate); return }
            self.realtime.guiIce(callId: id, candidate: self.moTaIce(candidate))
        }
    }

    nonisolated func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch newState {
            case .connected, .completed:
                self.thuNoiLai = false
                if self.trangThai != .dangNoi {
                    self.trangThai = .dangNoi
                    self.batDauDemGio()
                }
            case .failed:
                // Thử nối lại MỘT lần: chuyển Wi-Fi↔4G hay sóng chập một nhịp
                // là chuyện thường, cúp ngay là quá vội.
                if !self.thuNoiLai {
                    self.thuNoiLai = true
                    pc.restartIce()
                    return
                }
                self.loi = "Mất kết nối với người kia."
                self.cupMay()
            default:
                break
            }
        }
    }

    nonisolated func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
