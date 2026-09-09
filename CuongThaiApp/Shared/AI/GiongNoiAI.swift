import Foundation
import AVFoundation

// ════════════════════════════════════════════════════════════════
// GIỌNG NÓI CHO AI CHAT — nói để hỏi, và nghe câu trả lời
//
// Hai đường độc lập nhau, hỏng cái này không kéo cái kia:
//   • Nói → chữ : POST /api/v1/ai/stt   (multipart, trường `audio`)
//   • Chữ → nói : POST /api/v1/voice-mini/tts {text, voice} → { jobId }
//                 GET  /api/v1/voice-mini/tts/:jobId → 202 (đang chạy)
//                                                    → 200 + audio/wav
//
// ⚠️ TTS là việc BẤT ĐỒNG BỘ, không phải một lời gọi trả về tiếng ngay. Máy
// đọc chạy trên máy nhà; hỏi kết quả quá sớm thì nhận 202 chứ không phải lỗi.
// ════════════════════════════════════════════════════════════════

enum GiongNoiAI {
    /// Gửi đoạn ghi âm lên, nhận lại chữ.
    ///
    /// Trả `nil` khi máy chủ báo `heard: false` — tức nó nghe thấy tiếng
    /// nhưng không ra lời (gió, tiếng gõ bàn). Ném lỗi thì là chuyện khác.
    static func chuTuGiong(_ duLieu: Data) async throws -> String? {
        guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/ai/stt") else {
            throw APIError.invalidURL
        }
        let ranh = "Ranh-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(ranh)", forHTTPHeaderField: "Content-Type")
        if let token = StorageManager.shared.getAuthToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var than = Data()
        func themChu(_ s: String) { than.append(Data(s.utf8)) }
        themChu("--\(ranh)\r\n")
        // Tên trường PHẢI là `audio` — `voiceUpload.single('audio')` ở backend.
        themChu("Content-Disposition: form-data; name=\"audio\"; filename=\"hoi.m4a\"\r\n")
        themChu("Content-Type: audio/m4a\r\n\r\n")
        than.append(duLieu)
        themChu("\r\n--\(ranh)--\r\n")
        req.httpBody = than
        req.timeoutInterval = 60

        let (d, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.serverError("Không nhận dạng được giọng nói")
        }
        struct Vo: Decodable { let data: Ruot?; struct Ruot: Decodable { let text: String?; let heard: Bool? } }
        let v = try JSONDecoder().decode(Vo.self, from: d)
        guard v.data?.heard == true, let t = v.data?.text, !t.isEmpty else { return nil }
        return t
    }
}


/// Đọc câu trả lời thành tiếng — THEO TỪNG MẨU.
///
/// ⚠️ BẢN CŨ ĐỌC CẢ CÂU TRẢ LỜI TRONG MỘT LƯỢT, VÀ VỚI BÀI DÀI THÌ KHÔNG BAO
/// GIỜ XONG ĐƯỢC. Nó cắt 1.200 ký tự rồi hỏi kết quả 25 lượt, giãn dần
/// 0,6s → 2s: tổng đúng **44,4 giây**. Nhưng máy đọc chạy ở RTF ~0,97, tức
/// 1.200 ký tự tiếng Việt (~80 giây tiếng nói) mất ~78 giây để sinh. Ngân
/// sách chờ nhỏ hơn thời gian sinh ⇒ mọi câu trả lời dài đều hết giờ, lượt
/// nào cũng vậy, không phải chuyện may rủi.
///
/// Nay cắt thành mẩu ~220 ký tự và **nạp mẩu sau trong lúc phát mẩu trước**.
/// Tiếng đầu tiên ra sau vài giây thay vì hơn một phút, và bài dài bao nhiêu
/// cũng đọc được vì không còn mẩu nào chạm trần.
///
/// Đúng 2 việc chạy cùng lúc — khớp `MAX_RUNNING_PER_USER = 2` ở backend.
@MainActor
final class MayDoc: NSObject, ObservableObject {
    /// Tin đang đọc (hoặc đang nạp tiếng cho nó).
    @Published private(set) var dangDoc: UUID?
    /// Đang chờ mẩu ĐẦU TIÊN — lúc này chưa có tiếng nào ra.
    @Published private(set) var dangCho = false
    /// Đang đọc mẩu thứ mấy / tổng bao nhiêu mẩu. Giao diện cần nó để nói
    /// "đang đọc 2/9" thay vì đứng im.
    @Published private(set) var mau = 0
    @Published private(set) var tongMau = 0
    @Published var loi: String?

    private var may: AVAudioPlayer?
    private var viec: Task<Void, Never>?
    private var nap: Task<Data, Error>?
    private var xongMau: CheckedContinuation<Void, Never>?
    /// Mã việc đã đặt mà chưa lấy xong. Bấm Dừng thì phải TRẢ LẠI, không thì
    /// ô ở backend nằm treo — đúng lỗi vừa vá bên đó.
    private var jobTreo = Set<String>()
    /// Màn "Nói chuyện" tự giữ phiên âm thanh ở `.playAndRecord` cho cả nghe
    /// lẫn nói. Đặt cờ này để máy đọc ĐỪNG đổi sang `.playback` — mỗi lần đổi
    /// là một lần hệ thống đổi tuyến âm thanh, và lượt bấm mic ngay sau đó
    /// phải trả giá bằng nửa giây chờ.
    var nguoiKhacGiuPhien = false

    func batTat(_ id: UUID, chu: String) {
        if dangDoc == id { dung(); return }
        dung()
        let cacMau = MayDoc.chiaMau(chu)
        guard !cacMau.isEmpty else {
            loi = "Đoạn này chỉ có mã, không có gì để đọc."
            return
        }
        dangDoc = id
        dangCho = true
        mau = 0
        tongMau = cacMau.count
        loi = nil
        viec = Task { [weak self] in await self?.chay(cacMau) }
    }

    func dung() {
        viec?.cancel(); viec = nil
        nap?.cancel(); nap = nil
        ketThucMau()
        traLaiO()
        dangDoc = nil; dangCho = false; mau = 0; tongMau = 0
    }

    // MARK: - Vòng đọc

    private func chay(_ cacMau: [String]) async {
        var sanTruoc: Task<Data, Error>?
        do {
            for (i, doan) in cacMau.enumerated() {
                let dangNap = sanTruoc ?? Task { try await self.layTieng(doan) }
                nap = dangNap
                let wav = try await dangNap.value
                try Task.checkCancellation()

                // Nạp mẩu KẾ TIẾP ngay, để nó sinh xong trong lúc mẩu này
                // đang phát. Đây là toàn bộ lý do tiếng ra liền mạch.
                if i + 1 < cacMau.count {
                    let sau = cacMau[i + 1]
                    sanTruoc = Task { try await self.layTieng(sau) }
                    nap = sanTruoc
                } else {
                    sanTruoc = nil
                    nap = nil
                }

                dangCho = false
                mau = i + 1
                try await phatVaCho(wav)
            }
            sanTruoc?.cancel()
            dangDoc = nil; dangCho = false; mau = 0; tongMau = 0
        } catch is CancellationError {
            // Người dùng tự bấm Dừng — `dung()` đã dọn sạch rồi.
            sanTruoc?.cancel()
        } catch {
            sanTruoc?.cancel()
            dangDoc = nil; dangCho = false; mau = 0; tongMau = 0
            // ⚠️ Câu lỗi phải NÓI RA ĐƯỢC nguyên nhân. Bản cũ nuốt mọi lỗi
            // thành `loi` mà giao diện không hiện — nên 429 "đang có 2 bản
            // đọc chạy dở" trông y hệt "bấm không ăn gì".
            loi = MayDoc.viLoi(error)
        }
    }

    private func phatVaCho(_ wav: Data) async throws {
        #if os(iOS)
        if !nguoiKhacGiuPhien {
            // `.playback` để tiếng vẫn ra khi máy đang gạt nút im lặng —
            // người dùng chủ động bấm nghe thì họ muốn nghe.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        #endif
        let m = try AVAudioPlayer(data: wav)
        m.delegate = self
        m.prepareToPlay()
        may = m
        await withTaskCancellationHandler {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                xongMau = c
                m.play()
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.ketThucMau() }
        }
        try Task.checkCancellation()
    }

    /// Đóng mẩu đang phát. Phải chịu được gọi nhiều lần — cả bộ phát báo
    /// xong lẫn người bấm Dừng đều đi qua đây, và `resume` hai lần là SẬP app.
    private func ketThucMau() {
        may?.stop(); may = nil
        if let c = xongMau { xongMau = nil; c.resume() }
    }

    // MARK: - Gọi máy chủ

    /// Đặt việc rồi hỏi lại tới khi có tiếng.
    ///
    /// Trần chờ tính THEO ĐỘ DÀI của mẩu chứ không phải một con số cố định:
    /// RTF ~1 nghĩa là mẩu dài gấp đôi thì sinh lâu gấp đôi. Cộng thêm 20
    /// giây cho lần đầu nạp model (đo 18/08: 11,7s).
    private func layTieng(_ chu: String) async throws -> Data {
        struct Dat: Decodable { let jobId: String }
        let dat: Dat = try await APIClient.shared.request(
            .datViecDoc(text: chu, voice: GiongTroLy.shared.idDaChon))
        jobTreo.insert(dat.jobId)
        defer { jobTreo.remove(dat.jobId) }

        let tranGiay = Double(chu.count) / 12.0 * 1.6 + 20.0
        var daCho = 0.0
        var cho = 0.5
        while daCho < tranGiay {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: UInt64(cho * 1_000_000_000))
            daCho += cho
            cho = min(cho + 0.2, 2.0)
            if let wav = try await hoiTieng(dat.jobId) { return wav }
        }
        throw APIError.serverError("Máy đọc lâu quá")
    }

    /// `nil` = còn đang chạy (202). Có dữ liệu = xong.
    private func hoiTieng(_ jobId: String) async throws -> Data? {
        guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/voice-mini/tts/\(jobId)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        if let token = StorageManager.shared.getAuthToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (d, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { return nil }
        if http.statusCode == 202 { return nil }
        guard http.statusCode == 200, d.count > 1024 else {
            throw APIError.serverError(MayDoc.docLoiMayChu(d) ?? "Máy đọc trả lỗi \(http.statusCode)")
        }
        return d
    }

    /// Trả lại ô ở backend cho mọi việc còn treo.
    ///
    /// Không có bước này thì bấm Dừng hai lần là khoá chết máy đọc cho tới khi
    /// ô tự hết hạn — chính là lỗi người dùng gặp ngày 09/09/2026.
    private func traLaiO() {
        let treo = jobTreo
        jobTreo.removeAll()
        guard !treo.isEmpty else { return }
        let token = StorageManager.shared.getAuthToken()
        for id in treo {
            guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/voice-mini/tts/\(id)") else { continue }
            var r = URLRequest(url: url)
            r.httpMethod = "DELETE"
            if let token { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            // Gửi rồi quên: trả được thì tốt, không thì hạn 3 phút bên kia lo.
            URLSession.shared.dataTask(with: r).resume()
        }
    }

    private static func docLoiMayChu(_ d: Data) -> String? {
        struct Vo: Decodable { let message: String? }
        guard let v = try? JSONDecoder().decode(Vo.self, from: d), let m = v.message, !m.isEmpty else {
            return nil
        }
        return m
    }

    private static func viLoi(_ e: Error) -> String {
        if let a = e as? APIError, case .serverError(let m) = a, !m.isEmpty { return m }
        return "Không đọc được đoạn này. Thử lại sau một lát giúp mình."
    }
}

// MARK: - Cắt chữ cho máy đọc

extension MayDoc {
    /// Trần tổng số mẩu. Một bài giảng dài đọc hết là mười mấy phút — quá số
    /// này thì dừng, còn hơn để người dùng không biết bao giờ mới xong.
    static let TRAN_MAU = 30
    /// Mẩu dài khoảng ngần này là hợp: đủ để câu không bị chặt vụn, mà vẫn
    /// sinh xong trong dưới 20 giây.
    static let DAI_MAU = 220
    /// Mẩu ĐẦU ngắn hơn hẳn: nó quyết định khoảng lặng người dùng cảm thấy.
    static let DAI_MAU_DAU = 90

    /// Bỏ dấu Markdown trước khi đọc.
    ///
    /// ⚠️ Đọc thẳng chữ Markdown ra tiếng là nghe thấy cả dấu sao và dấu
    /// huyền sổ. Nặng nhất là **khối mã**: câu trả lời lập trình có cả chục
    /// dòng `int *p = &val;` mà đọc từng ký tự thì vừa dài vừa vô nghĩa —
    /// nên bỏ hẳn, chỉ nói là có khối mã.
    static func docDuoc(_ chu: String) -> String {
        var s = chu

        // Khối mã ``` ... ``` → một câu ngắn.
        s = s.replacingOccurrences(
            of: "```[\\s\\S]*?```", with: " (có một khối mã ở đây) ",
            options: .regularExpression)
        // Khối mã chưa đóng ở cuối câu trả lời đang chảy dở.
        s = s.replacingOccurrences(
            of: "```[\\s\\S]*$", with: " (có một khối mã ở đây) ",
            options: .regularExpression)
        // ⚠️ CẤT MÃ NGẮN RA TRƯỚC KHI GỠ DẤU NHẤN. Bước gỡ `*` bên dưới
        // không phân biệt được dấu in đậm với dấu con trỏ, nên `int *p` biến
        // thành `int p` — đúng bài học về con trỏ thì hỏng nghĩa hẳn.
        var kho: [String] = []
        while let r = s.range(of: "`[^`\n]+`", options: .regularExpression) {
            kho.append(String(s[r]).trimmingCharacters(in: CharacterSet(charactersIn: "`")))
            s.replaceSubrange(r, with: "\u{E000}\(kho.count - 1)\u{E001}")
        }

        // Ảnh ![alt](url) → bỏ hẳn; link [chữ](url) → giữ chữ.
        s = s.replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^)]*\\)", with: " ",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1",
                                   options: .regularExpression)
        // Đường kẻ ngang, dấu đầu dòng, dấu tiêu đề.
        s = s.replacingOccurrences(of: "(?m)^\\s*([-*_]\\s*){3,}$", with: " ",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "(?m)^\\s{0,3}#{1,6}\\s*", with: "",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "(?m)^\\s{0,4}[-*+]\\s+", with: "",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "(?m)^\\s{0,4}>\\s?", with: "",
                                   options: .regularExpression)
        // Bảng: gạch dọc đọc thành "gạch" thì rối — đổi thành dấu phẩy.
        s = s.replacingOccurrences(of: "(?m)^\\s*\\|?\\s*[-: ]+\\|[-:| ]*$", with: " ",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "|", with: ", ")
        // Dấu nhấn còn lại.
        s = s.replacingOccurrences(of: "`", with: "")
        s = s.replacingOccurrences(of: "*", with: "")
        s = s.replacingOccurrences(of: "~", with: "")
        s = s.replacingOccurrences(of: "_", with: " ")
        // Trả mã ngắn về chỗ cũ, nguyên vẹn cả `*` lẫn `_`.
        for (i, m) in kho.enumerated() {
            s = s.replacingOccurrences(of: "\u{E000}\(i)\u{E001}", with: m)
        }

        // Gộp khoảng trắng — nhiều dòng trống làm máy đọc ngắt vô cớ.
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        // Bảng đã thành dấu phẩy: dọn chuỗi phẩy liền nhau và phẩy đầu/cuối
        // dòng, không thì máy đọc ngắt quãng liên tục ở mỗi ô trống.
        s = s.replacingOccurrences(of: "(,\\s*){2,}", with: ", ", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?m)^\\s*,\\s*", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?m)\\s*,\\s*$", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?m)^\\s*$\\n", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{2,}", with: "\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cắt thành mẩu, ưu tiên ngắt ở cuối câu.
    static func chiaMau(_ chu: String) -> [String] {
        let sach = docDuoc(chu)
        guard !sach.isEmpty else { return [] }

        // Tách theo câu trước, rồi mới gom lại cho đủ dài. Cắt thô theo số ký
        // tự sẽ chặt giữa từ và máy đọc phát âm sai.
        var cau: [String] = []
        var dang = ""
        for k in sach {
            dang.append(k)
            if ".!?\n;:".contains(k), dang.count >= 40 {
                cau.append(dang); dang = ""
            }
        }
        if !dang.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { cau.append(dang) }

        var ra: [String] = []
        var gom = ""
        for c in cau {
            // ⚠️ MẨU ĐẦU CỐ Ý NGẮN. Người dùng đo "nhạy hay không" bằng đúng
            // khoảng lặng từ lúc bấm tới lúc nghe thấy tiếng đầu tiên. Mẩu
            // 220 ký tự mất ~15 giây để sinh; mẩu 90 ký tự mất ~6 giây. Các
            // mẩu sau dài lại cho liền mạch, vì lúc đó chúng đã được nạp sẵn
            // trong khi mẩu trước còn đang phát.
            let tran = ra.isEmpty ? DAI_MAU_DAU : DAI_MAU
            // Câu đơn lẻ dài hơn cả mẩu thì để riêng, đừng nhồi thêm.
            if gom.count + c.count > tran, !gom.isEmpty {
                ra.append(donMau(gom))
                gom = ""
            }
            gom += c
            if ra.count >= TRAN_MAU { break }
        }
        let cuoi = donMau(gom)
        if !cuoi.isEmpty, ra.count < TRAN_MAU { ra.append(cuoi) }
        return ra.filter { !$0.isEmpty }
    }

    /// Bỏ khoảng trắng và dấu phẩy thừa ở hai đầu mẩu — cắt giữa một hàng
    /// bảng thì mẩu sau hay bắt đầu bằng ", ".
    private static func donMau(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n,;:"))
    }
}

extension MayDoc: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.ketThucMau() }
    }
}
