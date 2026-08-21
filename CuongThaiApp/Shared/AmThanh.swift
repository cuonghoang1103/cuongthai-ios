import Foundation
import AVFoundation

// ════════════════════════════════════════════════════════════════
// ÂM THANH GIAO DIỆN
//
// Tiếng nhắn tin / thông báo lấy nguyên từ web (`frontend/public/sounds/`)
// nên hai nơi nghe giống hệt nhau. Tiếng chuông gọi thì web KHÔNG có —
// bốn file `goi-*.wav` được dựng bằng script, xem ghi chú trong commit.
//
// ⚠️ ĐIỂM QUAN TRỌNG NHẤT: mỗi loại tiếng cần MỘT CHẾ ĐỘ phiên khác nhau.
// Dùng chung một chế độ là hoặc tiếng nhắn tin ngắt nhạc người dùng đang
// nghe, hoặc chuông gọi im re khi máy gạt sang chế độ rung.
// ════════════════════════════════════════════════════════════════

@MainActor
final class AmThanh {
    static let shared = AmThanh()
    private init() {}

    enum Tieng: String {
        case tinNhanToi   = "tin-nhan"
        case guiDi        = "gui-di"
        case thongBao     = "thong-bao"
        case thich        = "thich"
        case goiDi        = "goi-di"
        case goiDen       = "goi-den"
        case goiKetThuc   = "goi-ket-thuc"
        case goiNoiDuoc   = "goi-noi-duoc"

        var duoi: String { self == .goiDi || self == .goiDen
                        || self == .goiKetThuc || self == .goiNoiDuoc ? "wav" : "mp3" }

        /// Lặp mãi cho tới khi có người bảo dừng.
        var lapMai: Bool { self == .goiDi || self == .goiDen }

        /// Tiếng này có được phép kêu khi máy đang gạt sang chế độ rung không.
        ///
        /// CHỈ chuông gọi. Cuộc gọi là thứ khẩn — Messenger, WhatsApp đều reo
        /// dù máy im. Còn tin nhắn với thông báo mà cũng kêu bất chấp thì
        /// người dùng đang họp sẽ gỡ app.
        var batChapImLang: Bool { self == .goiDen }
    }

    private var may: [Tieng: AVAudioPlayer] = [:]
    /// Có cuộc gọi đang chạy không. Trong lúc gọi thì TUYỆT ĐỐI không đụng
    /// vào phiên âm thanh — WebRTC đang giữ nó, giành là mất tiếng cả cuộc.
    var dangTrongCuocGoi = false

    func phat(_ t: Tieng, am: Float = 1.0) {
        guard let url = Bundle.main.url(forResource: t.rawValue, withExtension: t.duoi) else {
            NhatKy.goi.error("thiếu file âm thanh \(t.rawValue).\(t.duoi)")
            return
        }
        chuanBiPhien(cho: t)
        do {
            let m = try AVAudioPlayer(contentsOf: url)
            m.numberOfLoops = t.lapMai ? -1 : 0
            m.volume = am
            m.prepareToPlay()
            m.play()
            may[t] = m
        } catch {
            NhatKy.goi.error("không phát được \(t.rawValue): \(error)")
        }
    }

    func dung(_ t: Tieng) {
        may[t]?.stop()
        may[t] = nil
    }

    func dungHetTiengGoi() {
        for t in [Tieng.goiDi, .goiDen] { dung(t) }
    }

    // ── Phiên âm thanh ──────────────────────────────────────────
    private func chuanBiPhien(cho t: Tieng) {
        // Đang gọi thì WebRTC đã dựng phiên `.playAndRecord/.voiceChat` rồi.
        // Đổi nó lúc này là cắt đường tiếng của chính cuộc gọi — đúng cái bẫy
        // đã làm hai bên "báo đang nói mà không ai nghe thấy gì".
        if dangTrongCuocGoi { return }

        let phien = AVAudioSession.sharedInstance()
        if t.batChapImLang {
            // `.playback` kêu cả khi gạt công tắc im lặng. `.duckOthers` hạ
            // nhỏ nhạc/podcast thay vì dừng hẳn — hết chuông là nhạc tự to
            // lại, người dùng không phải bấm play.
            try? phien.setCategory(.playback, options: [.duckOthers])
        } else {
            // `.ambient` = tôn trọng công tắc im lặng VÀ hoà cùng nhạc đang
            // nghe. Đây mới là đúng cho tiếng tin nhắn: nó là thông tin phụ,
            // không có quyền ngắt thứ người ta đang nghe.
            try? phien.setCategory(.ambient, options: [.mixWithOthers])
        }
        try? phien.setActive(true)
    }
}
