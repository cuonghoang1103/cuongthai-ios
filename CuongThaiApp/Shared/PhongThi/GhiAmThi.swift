import Foundation
#if os(iOS)
import AVFoundation

// ════════════════════════════════════════════════════════════════
// THU ÂM CHO ĐỀ NÓI (PE SPEAK)
//
// Mỗi câu hỏi phụ một tệp `.m4a` (AAC 44,1kHz mono) trong thư mục tạm. Web
// thu `audio/webm` bằng MediaRecorder; máy chủ không quan tâm định dạng — nó
// chuyển thẳng cho Whisper (Groq), và Whisper nhận m4a.
//
// ⚠️ Micro cần `NSMicrophoneUsageDescription` (đã có trong Info.plist, câu
// mục đích nhắc cả "làm đề thi nói"). Bị từ chối thì báo rõ cách bật lại,
// KHÔNG gọi `record()` — gọi khi chưa có quyền là thu ra tệp câm.
// ════════════════════════════════════════════════════════════════

@MainActor
final class GhiAmThi: NSObject, ObservableObject, AVAudioPlayerDelegate {
    /// Câu nào đang thu (chỉ số câu hỏi phụ).
    @Published private(set) var dangThu: Int?
    /// Câu nào đang phát lại.
    @Published private(set) var dangPhat: Int?
    @Published private(set) var giayDaThu: Int = 0
    @Published private(set) var muc: Float = 0
    /// Tệp đã thu theo chỉ số câu.
    @Published private(set) var tep: [Int: URL] = [:]
    @Published var loi: String?

    /// Trần mỗi câu trả lời — câu nói bình thường 30–90 giây; 3 phút là dư
    /// mà vẫn dưới trần 20MB/tệp của máy chủ rất xa (~1,5MB).
    static let tranGiay = 180

    private var mayThu: AVAudioRecorder?
    private var mayPhat: AVAudioPlayer?
    private var dongHo: Timer?
    private let thuMuc: URL

    init(khoa: String) {
        thuMuc = FileManager.default.temporaryDirectory
            .appendingPathComponent("phong-thi-noi", isDirectory: true)
            .appendingPathComponent(khoa, isDirectory: true)
        super.init()
        try? FileManager.default.createDirectory(at: thuMuc, withIntermediateDirectories: true)
    }

    func batDau(_ i: Int) async {
        dung()
        loi = nil
        guard await xinQuyen() else {
            loi = T("Chưa có quyền dùng micro. Bật trong Cài đặt → CuongThai → Micro rồi thử lại.")
            return
        }
        let phien = AVAudioSession.sharedInstance()
        do {
            try phien.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try phien.setActive(true)
        } catch {
            loi = T("Không mở được micro: ") + error.localizedDescription
            return
        }
        let url = thuMuc.appendingPathComponent("cau-\(i + 1).m4a")
        try? FileManager.default.removeItem(at: url)
        let cauHinh: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            let r = try AVAudioRecorder(url: url, settings: cauHinh)
            r.isMeteringEnabled = true
            guard r.record(forDuration: TimeInterval(Self.tranGiay)) else {
                loi = T("Không bắt đầu thu được. Thử lại nhé.")
                return
            }
            mayThu = r
            dangThu = i
            giayDaThu = 0
            Haptics.cham()
            dongHo = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.nhip() }
            }
        } catch {
            loi = T("Không bắt đầu thu được: ") + error.localizedDescription
        }
    }

    private func nhip() {
        guard let r = mayThu else { return }
        if !r.isRecording { ketThucThu(); return }
        r.updateMeters()
        // dB (-160…0) → 0…1 cho thanh mức âm.
        let db = r.averagePower(forChannel: 0)
        muc = max(0, min(1, (db + 55) / 55))
        giayDaThu = Int(r.currentTime)
    }

    func dungThu() { ketThucThu() }

    private func ketThucThu() {
        guard let r = mayThu, let i = dangThu else { return }
        r.stop()
        dongHo?.invalidate(); dongHo = nil
        // Bản thu dưới nửa giây là bấm nhầm — không giữ, không gửi lên chấm.
        let dai = (try? AVAudioPlayer(contentsOf: r.url))?.duration ?? 0
        if dai >= 0.5 { tep[i] = r.url } else { try? FileManager.default.removeItem(at: r.url) }
        mayThu = nil
        dangThu = nil
        muc = 0
        Haptics.xong()
    }

    func phat(_ i: Int) {
        if dangPhat == i { mayPhat?.stop(); dangPhat = nil; return }
        guard let u = tep[i] else { return }
        dungThu()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: u)
            p.delegate = self
            p.play()
            mayPhat = p
            dangPhat = i
        } catch { loi = error.localizedDescription }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.dangPhat = nil }
    }

    func xoa(_ i: Int) {
        if let u = tep[i] { try? FileManager.default.removeItem(at: u) }
        tep[i] = nil
    }

    /// Dừng mọi thứ (rời màn, nộp bài).
    func dung() {
        if mayThu != nil { ketThucThu() }
        mayPhat?.stop(); mayPhat = nil; dangPhat = nil
    }

    /// Các tệp theo THỨ TỰ câu — đúng như web gửi (chỉ câu đã thu).
    func tepTheoThuTu(soCau: Int) -> [URL] {
        (0..<soCau).compactMap { tep[$0] }
    }

    func donSach() {
        dung()
        try? FileManager.default.removeItem(at: thuMuc)
        tep = [:]
    }

    private func xinQuyen() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default:
            return await AVAudioApplication.requestRecordPermission()
        }
    }
}
#endif
