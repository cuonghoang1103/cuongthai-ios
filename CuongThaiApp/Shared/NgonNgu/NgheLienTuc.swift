import Foundation
import Speech
import AVFoundation

// ════════════════════════════════════════════════════════════════
// NGHE LIÊN TỤC — chuyển lời nói thành chữ, CHẠY TRÊN MÁY
//
// Không gửi tiếng lên máy chủ: `SFSpeechRecognizer` với
// `requiresOnDeviceRecognition = true` nhận được ja-JP / zh-CN / en-US ngay
// trên iPhone. Nhanh hơn nhiều, miễn phí, và tiếng nói của người dùng không
// rời khỏi máy.
//
// ⚠️ ĐIỂM CHẾT NGƯỜI: KHÔNG được nghe trong lúc AI đang nói. Micro sẽ thu
// chính giọng của AI, nhận ra thành chữ, rồi gửi lại cho AI — hai bên tự
// nói chuyện với nhau và người dùng chỉ ngồi nhìn. Bộ điều phối ở
// `TroChuyenAI` phải tắt nghe trước khi cho đọc.
// ════════════════════════════════════════════════════════════════

@MainActor
final class NgheLienTuc: ObservableObject {
    @Published private(set) var dangNghe = false
    @Published private(set) var chuTamThoi = ""
    @Published var loi: String?

    /// Gọi khi người dùng ngừng nói đủ lâu. Trả về câu đã nghe được.
    var khiXongCau: ((String) -> Void)?

    private let mayThu = AVAudioEngine()
    private var boNhan: SFSpeechRecognizer?
    private var yeuCau: SFSpeechAudioBufferRecognitionRequest?
    private var viec: SFSpeechRecognitionTask?
    private var dongHoLang: Timer?
    private var chuCuoi = ""

    /// Im bao lâu thì coi là nói xong.
    ///
    /// 1,4 giây: ngắn hơn thì cắt ngang lúc người ta ngập ngừng tìm từ —
    /// mà đang tập nói ngoại ngữ thì ngập ngừng là chuyện thường. Dài hơn
    /// thì cuộc nói chuyện lê thê.
    private let LANG_GIAY: TimeInterval = 1.4

    static func maNhan(_ code: String) -> String? {
        switch code {
        case "ja": return "ja-JP"
        case "zh": return "zh-CN"
        case "en": return "en-US"
        case "fr": return "fr-FR"
        case "ger": return "de-DE"
        case "rus": return "ru-RU"
        default: return nil
        }
    }

    static func nhanDuoc(_ code: String) -> Bool {
        guard let ma = maNhan(code) else { return false }
        return SFSpeechRecognizer(locale: Locale(identifier: ma))?.isAvailable ?? false
    }

    static func xinQuyen() async -> Bool {
        let nhan = await withCheckedContinuation { t in
            SFSpeechRecognizer.requestAuthorization { t.resume(returning: $0) }
        }
        guard nhan == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func batDau(code: String) {
        guard !dangNghe else { return }
        guard let ma = Self.maNhan(code),
              let bn = SFSpeechRecognizer(locale: Locale(identifier: ma)), bn.isAvailable else {
            NhatKy.noi.error("KHÔNG có bộ nhận cho \(code)")
            loi = "Máy chưa hỗ trợ nhận giọng nói cho ngôn ngữ này."
            return
        }
        boNhan = bn
        chuTamThoi = ""
        chuCuoi = ""

        let phien = AVAudioSession.sharedInstance()
        do {
            try phien.setCategory(.playAndRecord, mode: .measurement,
                                  options: [.duckOthers, .defaultToSpeaker])
            try phien.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            NhatKy.noi.error("phiên âm thanh HỎNG: \(error)")
            loi = "Không mở được micro."
            return
        }

        let yc = SFSpeechAudioBufferRecognitionRequest()
        yc.shouldReportPartialResults = true
        // Chạy trên máy khi máy làm được. Không làm được thì để Apple xử ở
        // máy chủ của họ — vẫn hơn là không nghe được gì.
        if bn.supportsOnDeviceRecognition { yc.requiresOnDeviceRecognition = true }
        yeuCau = yc

        let nut = mayThu.inputNode
        let dang = nut.outputFormat(forBus: 0)
        nut.removeTap(onBus: 0)
        nut.installTap(onBus: 0, bufferSize: 1024, format: dang) { [weak self] buf, _ in
            self?.yeuCau?.append(buf)
        }

        mayThu.prepare()
        do { try mayThu.start() } catch {
            NhatKy.noi.error("mayThu.start HỎNG: \(error)")
            loi = "Không khởi động được micro."
            return
        }
        dangNghe = true
        NhatKy.noi.info("NGHE bật · \(ma) · trên-máy=\(yc.requiresOnDeviceRecognition)")

        viec = bn.recognitionTask(with: yc) { [weak self] kq, _ in
            guard let self else { return }
            Task { @MainActor in
                if let kq {
                    let chu = kq.bestTranscription.formattedString
                    if chu != self.chuCuoi {
                        self.chuCuoi = chu
                        self.chuTamThoi = chu
                        self.hoanLang()   // còn nói thì hoãn mốc im lặng
                    }
                }
            }
        }
        hoanLang()
    }

    /// Đặt lại đồng hồ đếm im lặng.
    private func hoanLang() {
        dongHoLang?.invalidate()
        dongHoLang = Timer.scheduledTimer(withTimeInterval: LANG_GIAY, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.chotCau() }
        }
    }

    private func chotCau() {
        let chu = chuTamThoi.trimmingCharacters(in: .whitespacesAndNewlines)
        NhatKy.noi.info("im \(LANG_GIAY)s → chốt: '\(chu)'")
        dung()
        // Im lặng suốt mà không ra chữ nào thì không gửi gì cả — gửi chuỗi
        // rỗng lên AI là nó trả lời vu vơ và tự kéo cuộc nói chuyện đi.
        guard !chu.isEmpty else { return }
        khiXongCau?(chu)
    }

    func dung() {
        if dangNghe { NhatKy.noi.info("NGHE tắt") }
        dongHoLang?.invalidate(); dongHoLang = nil
        if mayThu.isRunning {
            mayThu.stop()
            mayThu.inputNode.removeTap(onBus: 0)
        }
        yeuCau?.endAudio()
        viec?.cancel()
        yeuCau = nil
        viec = nil
        dangNghe = false
    }

    /// Người dùng bấm gửi tay khi không muốn đợi hết 1,4 giây.
    func chotNgay() {
        guard dangNghe else { return }
        chotCau()
    }
}
