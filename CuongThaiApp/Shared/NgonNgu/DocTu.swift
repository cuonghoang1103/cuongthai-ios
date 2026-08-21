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
        guard !sach.isEmpty, let ma = Self.maGiong(code),
              let giong = AVSpeechSynthesisVoice(language: ma) else { return }

        if may.isSpeaking { may.stopSpeaking(at: .immediate) }

        // `.ambient` + `.mixWithOthers`: tôn trọng công tắc im lặng và không
        // ngắt nhạc người dùng đang nghe. Cùng lý lẽ với tiếng tin nhắn.
        let phien = AVAudioSession.sharedInstance()
        try? phien.setCategory(.ambient, options: [.mixWithOthers])
        try? phien.setActive(true)

        let cau = AVSpeechUtterance(string: sach)
        cau.voice = giong
        // Tốc độ mặc định của Apple đọc tiếng Nhật/Trung nhanh hơn mức người
        // mới học bắt kịp. 0,42 nghe rõ từng âm mà chưa tới mức lè nhè.
        cau.rate = chamHon ? 0.32 : 0.42
        cau.pitchMultiplier = 1.0
        cau.postUtteranceDelay = 0
        dangDoc = id
        may.speak(cau)
    }

    func dung() {
        may.stopSpeaking(at: .immediate)
        dangDoc = nil
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
