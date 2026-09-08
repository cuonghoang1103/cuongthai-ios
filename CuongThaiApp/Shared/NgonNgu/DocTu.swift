import Foundation
import AVFoundation

// ════════════════════════════════════════════════════════════════
// ĐỌC TỪ
//
// Dùng bộ đọc CÓ SẴN TRONG MÁY. Web phải gọi backend cho việc này, iOS thì
// không: `AVSpeechSynthesizer` đọc được ja-JP / zh-CN / en-US ngay trên máy,
// **chạy offline, không tốn một đồng token nào, và không có độ trễ mạng**.
//
// ⚠️ KHÔNG có tiếng Việt trong danh sách — cố ý. Ở đây chỉ đọc TỪ CẦN HỌC,
// mà nghĩa tiếng Việt thì người dùng đọc được rồi. Nhét vi-VN vào là phát ra
// giọng máy đọc nghĩa, vừa thừa vừa khó chịu.
// ════════════════════════════════════════════════════════════════

@MainActor
final class DocTu: NSObject, ObservableObject {
    static let shared = DocTu()
    private let may = AVSpeechSynthesizer()
    @Published private(set) var dangDoc: Int?
    /// Đang CHỜ máy nhà đọc — chỉ đúng với giọng máy nhà, giọng trong máy
    /// phát ra tức thì.
    @Published private(set) var dangCho = false
    @Published var loi: String?
    private var phatNha: AVAudioPlayer?
    private var viecNha: Task<Void, Never>?

    private override init() {
        super.init()
        may.delegate = self
    }

    /// Mã giọng theo mã ngôn ngữ của máy chủ.
    private static func maGiong(_ code: String) -> String? {
        switch code {
        case "ja":  return "ja-JP"
        case "zh":  return "zh-CN"
        case "en":  return "en-US"
        case "fr":  return "fr-FR"
        case "ger": return "de-DE"
        case "rus": return "ru-RU"
        default:    return nil
        }
    }

    static func doDuoc(_ code: String) -> Bool {
        guard let ma = maGiong(code) else { return false }
        // Có mã KHÔNG có nghĩa là máy đã tải giọng đó về. Người dùng chưa
        // tải gói tiếng Nhật thì `AVSpeechSynthesisVoice(language:)` trả nil
        // và bấm loa sẽ IM LẶNG — không lỗi, không gì cả. Kiểm trước để còn
        // ẩn nút đi thay vì để nó chết câm.
        return AVSpeechSynthesisVoice(language: ma) != nil
    }

    func doc(_ chu: String, code: String, id: Int? = nil, chamHon: Bool = false) {
        let sach = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sach.isEmpty, let ma = Self.maGiong(code) else { return }

        // Người dùng chọn giọng máy nhà (vd robot tiếng Anh) thì đi đường
        // mạng, không dùng bộ đọc trong máy.
        if case .mayNha(let maGiongNha)? = CaiDatGiong.shared.luaChon(code)?.nguon {
            docQuaMayNha(sach, giong: maGiongNha, id: id)
            return
        }

        // Giọng người dùng đã chọn; không chọn thì lấy mặc định của hệ thống.
        // `AVSpeechSynthesisVoice(identifier:)` trả nil khi người dùng ĐÃ GỠ
        // gói giọng đó trong Cài đặt — rơi về mặc định thay vì im lặng.
        let giong: AVSpeechSynthesisVoice
        if case .trongMay(let idGiong)? = CaiDatGiong.shared.luaChon(code)?.nguon,
           let g = AVSpeechSynthesisVoice(identifier: idGiong) {
            giong = g
        } else if let g = AVSpeechSynthesisVoice(language: ma) {
            giong = g
        } else {
            return
        }

        dungTatCa()

        // `.ambient` + `.mixWithOthers`: tôn trọng công tắc im lặng và không
        // ngắt nhạc người dùng đang nghe. Cùng lý lẽ với tiếng tin nhắn.
        let phien = AVAudioSession.sharedInstance()
        try? phien.setCategory(.ambient, options: [.mixWithOthers])
        try? phien.setActive(true)

        let cau = AVSpeechUtterance(string: sach)
        cau.voice = giong
        // Tốc độ mặc định của Apple đọc tiếng Nhật/Trung nhanh hơn mức người
        // mới học bắt kịp. 0,42 nghe rõ từng âm mà chưa tới mức lè nhè.
        // Tốc độ do người dùng đặt (mặc định 0,45). "Chậm hơn" trừ đi 0,10.
        let td = CaiDatGiong.shared.tocDo
        cau.rate = Float(max(0.25, chamHon ? td - 0.10 : td))
        cau.pitchMultiplier = 1.0
        cau.postUtteranceDelay = 0
        dangDoc = id
        may.speak(cau)
    }

    func dung() { dungTatCa() }

    /// Nghe thử MỘT giọng cụ thể, không phụ thuộc giọng đang chọn.
    func docThu(_ chu: String, code: String, giong: LuaChonGiong?) {
        guard let ma = Self.maGiong(code) else { return }
        switch giong?.nguon {
        case .mayNha(let m):
            docQuaMayNha(chu, giong: m, id: -1)
        case .trongMay(let idG):
            noiTrongMay(chu, giong: AVSpeechSynthesisVoice(identifier: idG)
                        ?? AVSpeechSynthesisVoice(language: ma), id: -1)
        case nil:
            noiTrongMay(chu, giong: AVSpeechSynthesisVoice(language: ma), id: -1)
        }
    }

    private func noiTrongMay(_ chu: String, giong: AVSpeechSynthesisVoice?, id: Int?) {
        guard let giong else { return }
        dungTatCa()
        let phien = AVAudioSession.sharedInstance()
        try? phien.setCategory(.ambient, options: [.mixWithOthers])
        try? phien.setActive(true)
        let cau = AVSpeechUtterance(string: chu)
        cau.voice = giong
        cau.rate = Float(max(0.25, CaiDatGiong.shared.tocDo))
        dangDoc = id
        may.speak(cau)
    }

    private func dungTatCa() {
        if may.isSpeaking { may.stopSpeaking(at: .immediate) }
        phatNha?.stop(); phatNha = nil
        viecNha?.cancel(); viecNha = nil
        dangDoc = nil
    }

    // ── Giọng chạy ở máy nhà ─────────────────────────────────────
    //
    // Đường này KHÁC hẳn bộ đọc trong máy: nó cần mạng, mất vài giây, và là
    // việc BẤT ĐỒNG BỘ (đặt việc → hỏi lại tới khi có tiếng). Vì thế có
    // `dangCho` riêng để giao diện hiện vòng xoay — không thì người dùng bấm
    // loa rồi tưởng hỏng vì mấy giây đầu chẳng có gì.
    private func docQuaMayNha(_ chu: String, giong: String, id: Int?) {
        dungTatCa()
        dangDoc = id
        dangCho = true
        viecNha = Task {
            defer { Task { @MainActor in self.dangCho = false } }
            do {
                let wav = try await Self.layTiengNha(String(chu.prefix(600)), giong: giong)
                try Task.checkCancellation()
                try await MainActor.run {
                    // `.playback`: người dùng chủ động bấm loa thì họ muốn
                    // nghe, kể cả khi đang gạt nút im lặng.
                    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                    try? AVAudioSession.sharedInstance().setActive(true)
                    let m = try AVAudioPlayer(data: wav)
                    m.delegate = self
                    m.prepareToPlay(); m.play()
                    self.phatNha = m
                }
            } catch {
                await MainActor.run {
                    self.dangDoc = nil
                    if error is CancellationError { return }
                    // Nói ĐÚNG lý do. 429 = máy nhà đang chạy đủ 3 việc, chờ
                    // vài giây là được — khác hẳn "máy tắt", mà bản đầu gộp
                    // cả hai thành một câu chung.
                    let m = (error as NSError).localizedDescription
                    self.loi = m.contains("429") || m.lowercased().contains("bận")
                        ? T("Máy nhà đang đọc cho việc khác — chờ vài giây rồi bấm lại.")
                        : T("Máy nhà không đọc được lúc này. Chọn tạm một giọng trong máy.")
                }
            }
        }
    }

    /// Đặt việc rồi hỏi lại tới khi có tiếng. Hỏi thưa dần — hỏi dồn dập chỉ
    /// tốn pin và làm nặng máy nhà chứ không nhanh hơn.
    private static func layTiengNha(_ chu: String, giong: String) async throws -> Data {
        struct Dat: Decodable { let jobId: String }
        let dat: Dat = try await APIClient.shared.request(.datViecDoc(text: chu, voice: giong))
        var cho: UInt64 = 600_000_000
        for _ in 0..<25 {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: cho)
            cho = min(cho + 200_000_000, 2_000_000_000)
            guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/voice-mini/tts/\(dat.jobId)")
            else { throw APIError.invalidURL }
            var req = URLRequest(url: url)
            if let t = StorageManager.shared.getAuthToken() {
                req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
            }
            let (d, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { continue }
            if http.statusCode == 202 { continue }          // còn đang chạy
            guard http.statusCode == 200, d.count > 1024 else {
                throw APIError.serverError("Máy đọc trả lỗi \(http.statusCode)")
            }
            return d
        }
        throw APIError.serverError("Máy đọc lâu quá")
    }
}

extension DocTu: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully f: Bool) {
        Task { @MainActor in self.dangDoc = nil; self.phatNha = nil }
    }
}

extension DocTu: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.dangDoc = nil }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in self.dangDoc = nil }
    }
}
