import Foundation
import AVFoundation
import SwiftUI

// MARK: - Ghi voice note (web CT Work có voice note ⇒ app có)
//
// Quyền micro CHỈ xin khi người dùng chạm nút micro lần đầu (NSMicrophoneUsageDescription
// nói đúng việc này). Trước lần ghi ĐẦU TIÊN phải đồng ý rõ ràng (App Store 5.1.2(i)):
// máy chủ gửi âm thanh voice note cho Groq (dịch vụ chuyển giọng nói thành chữ bên thứ
// ba) để đồng đội đọc được — `chatFiles.service.ts → transcribeChatVoice`.
// Trần máy chủ: ≤ 3 phút, ≤ 8 MB, audio/mp4 (AAC .m4a) được nhận.

@MainActor
final class GhiAmCTW: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let tranGiay: TimeInterval = 180
    private static let khoaDongY = "com.cuongthai.ctwork.dongYPhienAmGiongNoi"

    static var daDongYPhienAm: Bool {
        get { UserDefaults.standard.bool(forKey: khoaDongY) }
        set { UserDefaults.standard.set(newValue, forKey: khoaDongY) }
    }

    enum TrangThai: Equatable { case nghi, dangGhi, biTuChoi }

    @Published private(set) var trangThai: TrangThai = .nghi
    @Published private(set) var giay: TimeInterval = 0
    @Published private(set) var muc: [CGFloat] = Array(repeating: 0.1, count: 24)

    private var recorder: AVAudioRecorder?
    private var dongHo: Timer?
    private var tep: URL?
    /// Ghi xong (tự dừng ở trần 3 phút) — màn soạn gửi luôn.
    var xongTuDong: ((Data, Int) -> Void)?

    /// Xin quyền micro (chỉ hỏi một lần; từ chối ⇒ `.biTuChoi`).
    func batDau() async {
        let duoc = await AVAudioApplication.requestRecordPermission()
        guard duoc else { trangThai = .biTuChoi; return }
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try s.setActive(true)
            let u = FileManager.default.temporaryDirectory.appendingPathComponent("ctw-voice-\(UUID().uuidString).m4a")
            let r = try AVAudioRecorder(url: u, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ])
            r.delegate = self
            r.isMeteringEnabled = true
            guard r.record(forDuration: Self.tranGiay) else { trangThai = .nghi; return }
            recorder = r
            tep = u
            giay = 0
            trangThai = .dangGhi
            CTWRung.chon()
            dongHo = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.nhip() }
            }
        } catch {
            trangThai = .nghi
        }
    }

    private func nhip() {
        guard let r = recorder, r.isRecording else { return }
        giay = r.currentTime
        r.updateMeters()
        let db = r.averagePower(forChannel: 0)
        let m = CGFloat(max(0.06, min(1, pow(10, db / 40))))
        muc.removeFirst()
        muc.append(m)
    }

    /// Dừng và trả dữ liệu (nil nếu quá ngắn < 0,5 giây).
    func dung() -> (Data, Int)? {
        guard let r = recorder else { return nil }
        let t = r.currentTime
        r.stop()
        donDep()
        guard t >= 0.5, let tep, let d = try? Data(contentsOf: tep) else { xoaTep(); return nil }
        xoaTep()
        return (d, Int(t * 1000))
    }

    func huy() {
        recorder?.stop()
        recorder?.deleteRecording()
        donDep()
        xoaTep()
    }

    private func donDep() {
        dongHo?.invalidate()
        dongHo = nil
        recorder = nil
        trangThai = .nghi
        muc = Array(repeating: 0.1, count: 24)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func xoaTep() {
        if let tep { try? FileManager.default.removeItem(at: tep) }
        tep = nil
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            // Tự dừng ở trần 3 phút ⇒ gửi luôn bản đã ghi.
            guard self.trangThai == .dangGhi, self.recorder === recorder else { return }
            if let kq = self.dung() { self.xongTuDong?(kq.0, kq.1) }
        }
    }
}

/// Câu công bố trước lần ghi đầu (5.1.2(i)) — dùng chung cho hộp đồng ý.
enum CongBoGiongNoiCTW {
    static var tieuDe: String { String(localized: "Voice notes are transcribed") }
    static var noiDung: String { String(localized: "When you send a voice note, CT Work stores the recording for people in this channel and sends the audio to Groq, a third-party speech-to-text service, to create a written transcript that appears under the voice note. Nothing is recorded until you tap the microphone.") }
}
