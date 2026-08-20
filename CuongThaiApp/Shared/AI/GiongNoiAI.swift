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

/// Đọc câu trả lời thành tiếng.
///
/// Giữ trạng thái ở một chỗ để giao diện biết đang đọc tin NÀO — không thì
/// bấm loa ở tin thứ hai trong lúc tin đầu đang đọc sẽ chồng hai giọng lên nhau.
@MainActor
final class MayDoc: NSObject, ObservableObject {
    @Published private(set) var dangDoc: UUID?
    @Published private(set) var dangCho = false
    @Published var loi: String?

    private var may: AVAudioPlayer?
    private var viec: Task<Void, Never>?

    func batTat(_ id: UUID, chu: String) {
        if dangDoc == id || dangCho { dung(); return }
        dung()
        dangDoc = id
        dangCho = true
        viec = Task { [weak self] in
            guard let self else { return }
            do {
                let wav = try await self.layTieng(chu)
                if Task.isCancelled { return }
                try self.phat(wav)
                self.dangCho = false
            } catch {
                self.dangCho = false
                self.dangDoc = nil
                self.loi = (error as? APIError).map { _ in "Máy đọc chưa sẵn sàng, thử lại sau một lát." }
                        ?? "Không đọc được đoạn này."
            }
        }
    }

    func dung() {
        viec?.cancel(); viec = nil
        may?.stop(); may = nil
        dangDoc = nil; dangCho = false
    }

    /// Đặt việc rồi hỏi lại tới khi có tiếng.
    ///
    /// Hỏi thưa dần (0,6s → 2s): máy đọc mất vài giây cho câu dài, hỏi dồn dập
    /// chỉ tốn pin và làm nặng máy nhà mà không nhanh hơn.
    private func layTieng(_ chu: String) async throws -> Data {
        // Trần ký tự: cả câu trả lời dài chục nghìn chữ thì đọc cả buổi, mà
        // backend cũng chặn. Cắt ở đoạn đầu — đủ để nghe ý chính.
        let ngan = String(chu.prefix(1200))
        struct Dat: Decodable { let jobId: String }
        let dat: Dat = try await APIClient.shared.request(.datViecDoc(text: ngan))

        var cho: UInt64 = 600_000_000
        for _ in 0..<25 {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: cho)
            cho = min(cho + 200_000_000, 2_000_000_000)
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
            throw APIError.serverError("Máy đọc trả lỗi \(http.statusCode)")
        }
        return d
    }

    private func phat(_ wav: Data) throws {
        #if os(iOS)
        // `.playback` để tiếng vẫn ra khi máy đang gạt nút im lặng — người dùng
        // chủ động bấm nghe thì họ muốn nghe.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let m = try AVAudioPlayer(data: wav)
        m.delegate = self
        m.prepareToPlay()
        m.play()
        may = m
    }
}

extension MayDoc: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.dangDoc = nil; self?.may = nil }
    }
}
