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
    /// Thả nút mà không nghe ra chữ nào. Màn hình phải nói điều đó ra.
    var khiRong: (() -> Void)?

    private let mayThu = AVAudioEngine()
    private var boNhan: SFSpeechRecognizer?
    private var yeuCau: SFSpeechAudioBufferRecognitionRequest?
    private var viec: SFSpeechRecognitionTask?
    private var chuCuoi = ""
    /// Đếm khối âm thanh micro đưa vào. Tách được hai ca trông GIỐNG HỆT
    /// nhau: micro không thu được gì (số này = 0) hay micro thu tốt mà bộ
    /// nhận không ra chữ (số này lớn mà chữ vẫn rỗng).
    private var soKhoi = 0

    // ⚠️ ĐÃ BỎ đồng hồ tự cắt theo im lặng (21/08).
    //
    // Bản trước đếm 1,4 giây im lặng rồi tự gửi — nhưng đồng hồ chạy NGAY
    // TỪ LÚC BẬT MIC, không phải từ lúc người ta bắt đầu nói. Nghĩa là
    // người dùng có đúng 1,4 giây để kịp nhận ra mic đã bật và mở miệng.
    // Không ai kịp. Nhật ký thật: bật 20:55:35.333 → chốt 20:55:36.734,
    // chuỗi rỗng, `No speech detected` — lượt nào cũng vậy.
    //
    // Nay theo cách người dùng yêu cầu: GIỮ nút thì nghe, THẢ thì gửi.
    // Không đoán khi nào người ta nói xong nữa — chính họ nói ra điều đó.

    /// Bật khi bản nhận trên máy tỏ ra câm. Giữ ở mức kiểu để cả phiên dùng
    /// chung — dò lại mỗi lượt là mỗi lượt mất một lần thử.
    private static var epNhanQuaMang = false

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
        soKhoi = 0

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
        // Nhận trên máy nhanh và riêng tư, NHƯNG `supportsOnDeviceRecognition`
        // chỉ nói "máy này làm được", không nói "gói tiếng đã tải về chưa".
        // Chưa tải thì nó chạy và KHÔNG ra chữ nào, không lỗi rõ ràng.
        // `epNhanQuaMang` là đường lùi sau lần đầu câm.
        if bn.supportsOnDeviceRecognition && !Self.epNhanQuaMang {
            yc.requiresOnDeviceRecognition = true
        }
        yeuCau = yc

        let nut = mayThu.inputNode
        // ⚠️ `inputFormat` chứ KHÔNG phải `outputFormat`. Với nút VÀO,
        // `outputFormat(forBus:)` có lúc trả về định dạng 0 kênh / 0 Hz khi
        // phiên âm thanh vừa đổi chế độ — `installTap` vẫn nhận, vẫn chạy,
        // và im lặng không đẩy được mẫu nào vào bộ nhận.
        var dang = nut.inputFormat(forBus: 0)
        if dang.channelCount == 0 || dang.sampleRate == 0 {
            dang = nut.outputFormat(forBus: 0)
        }
        NhatKy.noi.info("định dạng micro: \(dang.sampleRate)Hz \(dang.channelCount) kênh")
        guard dang.channelCount > 0, dang.sampleRate > 0 else {
            NhatKy.noi.error("micro trả định dạng RỖNG — không thu được")
            loi = "Không đọc được micro. Thử đóng app khác đang dùng micro rồi vào lại."
            return
        }
        nut.removeTap(onBus: 0)
        nut.installTap(onBus: 0, bufferSize: 1024, format: dang) { [weak self] buf, _ in
            self?.yeuCau?.append(buf)
            self?.soKhoi += 1
        }

        mayThu.prepare()
        do { try mayThu.start() } catch {
            NhatKy.noi.error("mayThu.start HỎNG: \(error)")
            loi = "Không khởi động được micro."
            return
        }
        dangNghe = true
        NhatKy.noi.info("NGHE bật · \(ma) · trên-máy=\(yc.requiresOnDeviceRecognition)")

        viec = bn.recognitionTask(with: yc) { [weak self] kq, err in
            guard let self else { return }
            Task { @MainActor in
                // ⚠️ Bản trước tôi bỏ qua tham số lỗi này. Kết quả: bộ nhận
                // im lặng hoàn toàn mà nhật ký không có một dòng nào nói vì
                // sao — đúng thứ đã làm mất một vòng gỡ lỗi.
                if let err {
                    NhatKy.noi.error("bộ nhận: \(err.localizedDescription)")
                }
                if let kq {
                    let chu = kq.bestTranscription.formattedString
                    if chu != self.chuCuoi {
                        self.chuCuoi = chu
                        self.chuTamThoi = chu
                    }
                }
            }
        }
    }

    private func chotCau() {
        let chu = chuTamThoi.trimmingCharacters(in: .whitespacesAndNewlines)
        NhatKy.noi.info("thả nút → chốt: '\(chu)' · \(soKhoi) khối tiếng")
        dung()
        // Im lặng suốt mà không ra chữ nào thì không gửi gì cả — gửi chuỗi
        // rỗng lên AI là nó trả lời vu vơ và tự kéo cuộc nói chuyện đi.
        guard !chu.isEmpty else {
            // Có tiếng vào mà KHÔNG ra chữ ⇒ bản nhận trên máy câm. Chuyển
            // hẳn sang đường máy chủ của Apple cho các lượt sau.
            if soKhoi > 20 && !Self.epNhanQuaMang {
                Self.epNhanQuaMang = true
                NhatKy.noi.error("trên-máy CÂM (\(soKhoi) khối, 0 chữ) → chuyển sang nhận qua mạng")
            }
            khiRong?()
            return
        }
        khiXongCau?(chu)
    }

    func dung() {
        if dangNghe { NhatKy.noi.info("NGHE tắt") }
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

    /// Thả nút — gửi câu vừa nói.
    func chotNgay() {
        guard dangNghe else { return }
        chotCau()
    }
}
