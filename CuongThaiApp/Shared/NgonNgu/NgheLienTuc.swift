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
    /// Bộ nhận đã trả kết quả CUỐI chưa. Thả nút xong phải đợi cờ này, không
    /// thì mất từ cuối — xem `chotCau()`.
    private var daCoKetQuaCuoi = false

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

    /// `supportsOnDeviceRecognition` phải hỏi hệ thống xem gói tiếng đã tải
    /// chưa — đo 09/09/2026 đó là phần lớn 274ms còn sót lại giữa "phiên sẵn
    /// sàng" và "định dạng micro". Trả lời không đổi trong một phiên chạy,
    /// nên hỏi một lần rồi nhớ.
    private static var nhoTrenMay: [String: Bool] = [:]

    private static func chayTrenMay(_ bn: SFSpeechRecognizer, ma: String) -> Bool {
        if let d = nhoTrenMay[ma] { return d }
        let d = bn.supportsOnDeviceRecognition
        nhoTrenMay[ma] = d
        return d
    }

    static func maNhan(_ code: String) -> String? {
        switch code {
        // Tiếng Việt KHÔNG phải ngôn ngữ học ở mục Ngoại ngữ — nó ở đây cho
        // chế độ nói chuyện với AI Chat. Thêm một nhánh không đổi hành vi cũ.
        case "vi": return "vi-VN"
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

    /// Cấu hình phiên âm thanh TRƯỚC, khi màn hình vừa mở.
    ///
    /// ⚠️ Đây là chỗ tốn thời gian thật. `setCategory(.playAndRecord)` +
    /// `setActive(true)` bắt hệ thống đổi tuyến âm thanh và đánh thức phần
    /// cứng micro — trên máy thật mất hàng trăm mili giây tới hơn một giây,
    /// và nó xảy ra NGAY LÚC NGÓN TAY VỪA CHẠM. Đo trên iPhone 16 Pro Max
    /// 09/09/2026: một lượt giữ chỉ thu được 21ms tiếng vì phần lớn thời
    /// gian giữ đã tiêu vào đây.
    ///
    /// Mở sẵn lúc vào màn thì lúc bấm chỉ còn gắn tap và chạy bộ nhận.
    ///
    /// Dùng `.default` chứ KHÔNG `.measurement`: chế độ đo tắt hết xử lý
    /// tiếng của hệ thống, mà màn nói chuyện còn phải PHÁT tiếng AI qua cùng
    /// một phiên. Đổi qua đổi lại giữa hai chế độ mỗi lượt là mỗi lượt thêm
    /// một lần đổi tuyến.
    static func moPhienTruoc() {
        let phien = AVAudioSession.sharedInstance()
        do {
            try phien.setCategory(.playAndRecord, mode: .default,
                                  options: [.defaultToSpeaker, .allowBluetooth,
                                            .allowBluetoothA2DP])
            try phien.setActive(true, options: .notifyOthersOnDeactivation)
            NhatKy.noi.info("phiên âm thanh MỞ SẴN xong")
        } catch {
            NhatKy.noi.error("mở sẵn phiên âm thanh HỎNG: \(error)")
        }
    }

    /// Đánh thức nốt bộ máy thu và bộ nhận.
    ///
    /// ⚠️ Vá phiên âm thanh xong vẫn còn **405ms** nữa, đo trên máy ảo
    /// 09/09/2026 — nó nằm LỌT GIỮA hai dòng nhật ký nên lần đầu không thấy:
    ///
    ///     41.314  phiên âm thanh sẵn sàng sau 2ms (đã mở sẵn)
    ///     41.719  định dạng micro: 48000.0Hz 1 kênh      ← 405ms ở đây
    ///
    /// Thủ phạm là lần ĐẦU chạm vào `mayThu.inputNode`: đó là lúc hệ thống
    /// dựng audio unit cho micro. Chạm sẵn ở đây thì lúc bấm nó đã có.
    func moSanMay(code: String) {
        _ = mayThu.inputNode.inputFormat(forBus: 0)
        mayThu.prepare()
        if let ma = Self.maNhan(code) {
            let bn = SFSpeechRecognizer(locale: Locale(identifier: ma))
            boNhan = bn
            if let bn { _ = Self.chayTrenMay(bn, ma: ma) }
        }
        NhatKy.noi.info("bộ máy thu đã đánh thức")
    }

    /// `daMoPhien` = phiên âm thanh đã được `moPhienTruoc()` bật rồi, đừng
    /// đụng lại. Mục Ngoại ngữ không truyền gì nên giữ nguyên hành vi cũ.
    func batDau(code: String, daMoPhien: Bool = false) {
        let batDauLuc = Date()
        guard !dangNghe else { return }
        // ⚠️ Dùng lại bộ nhận đã dựng sẵn CHỈ KHI nó đúng ngôn ngữ đang cần.
        // Mục Ngoại ngữ đổi qua lại ja → en → zh trong cùng một phiên chạy;
        // dùng lại mù thì bộ nhận tiếng Nhật đi nghe tiếng Anh.
        guard let ma = Self.maNhan(code),
              let bn = (boNhan?.locale.identifier == ma ? boNhan : nil)
                       ?? SFSpeechRecognizer(locale: Locale(identifier: ma)),
              bn.isAvailable else {
            NhatKy.noi.error("KHÔNG có bộ nhận cho \(code)")
            loi = "Máy chưa hỗ trợ nhận giọng nói cho ngôn ngữ này."
            return
        }
        boNhan = bn
        chuTamThoi = ""
        chuCuoi = ""
        soKhoi = 0
        daCoKetQuaCuoi = false

        if !daMoPhien {
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
        }
        NhatKy.noi.info("phiên âm thanh sẵn sàng sau \(Int(Date().timeIntervalSince(batDauLuc) * 1000))ms"
                        + (daMoPhien ? " (đã mở sẵn)" : " (mở TẠI CHỖ)"))

        let yc = SFSpeechAudioBufferRecognitionRequest()
        yc.shouldReportPartialResults = true
        // Chạy trên máy khi máy làm được. Không làm được thì để Apple xử ở
        // máy chủ của họ — vẫn hơn là không nghe được gì.
        // Nhận trên máy nhanh và riêng tư, NHƯNG `supportsOnDeviceRecognition`
        // chỉ nói "máy này làm được", không nói "gói tiếng đã tải về chưa".
        // Chưa tải thì nó chạy và KHÔNG ra chữ nào, không lỗi rõ ràng.
        // `epNhanQuaMang` là đường lùi sau lần đầu câm.
        if Self.chayTrenMay(bn, ma: ma) && !Self.epNhanQuaMang {
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
                if let err { self.daCoKetQuaCuoi = true; _ = err }
                if let kq {
                    let chu = kq.bestTranscription.formattedString
                    if chu != self.chuCuoi {
                        self.chuCuoi = chu
                        self.chuTamThoi = chu
                    }
                    // Kết quả CUỐI mới có từ vừa nói xong. Bản trước không
                    // đọc cờ này nên cắt ngay ở kết quả TẠM.
                    if kq.isFinal { self.daCoKetQuaCuoi = true }
                }
            }
        }
    }

    /// Chốt câu SAU KHI đợi bộ nhận trả kết quả cuối.
    ///
    /// ⚠️ BẢN CŨ CẮT NGAY LÚC THẢ TAY và mất đúng từ cuối cùng. Đo thật trên
    /// iPhone của người dùng 09/09/2026: nói "Hôm nay là thứ mấy?", giữ
    /// 1.445ms, thu 14 khối tiếng, mà chữ chốt được chỉ là "Hôm nay là thứ".
    /// 118ms sau đó bộ nhận báo lỗi vì đã bị huỷ giữa chừng.
    ///
    /// Lý do: `chuTamThoi` là kết quả TẠM. Từ vừa dứt còn đang được xử lý,
    /// và `dung()` gọi `viec?.cancel()` là vứt luôn phần đó. Nay: ngừng ĐẨY
    /// tiếng vào (`endAudio`) nhưng GIỮ bộ nhận sống thêm tối đa 900ms để nó
    /// trả nốt.
    private func chotCau() async {
        let choTu = Date()
        // Ngừng đẩy tiếng mới vào, nhưng KHÔNG huỷ bộ nhận.
        if mayThu.isRunning {
            mayThu.stop()
            mayThu.inputNode.removeTap(onBus: 0)
        }
        yeuCau?.endAudio()

        // 18 × 50ms = 900ms. Đủ cho một từ, mà vẫn không thành khoảng lặng
        // người dùng cảm thấy được.
        for _ in 0..<18 {
            if daCoKetQuaCuoi { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        let doiMs = Int(Date().timeIntervalSince(choTu) * 1000)

        let chu = chuCuoi.trimmingCharacters(in: .whitespacesAndNewlines)
        NhatKy.noi.info("thả nút → chốt: '\(chu)' · \(soKhoi) khối tiếng"
                        + " · đợi kết quả cuối \(doiMs)ms"
                        + (daCoKetQuaCuoi ? "" : " (HẾT GIỜ, lấy bản tạm)"))
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
    ///
    /// Tắt đèn "đang nghe" NGAY để giao diện phản hồi tức thì, còn việc đợi
    /// bộ nhận trả nốt thì làm ở nền.
    func chotNgay() {
        guard dangNghe else { return }
        dangNghe = false
        Task { @MainActor [weak self] in await self?.chotCau() }
    }
}
