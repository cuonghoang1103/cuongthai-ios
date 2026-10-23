import Foundation
import AVFoundation

// ════════════════════════════════════════════════════════════════
// GIỌNG ĐỌC của khoá kiểu sách — làm y như web (`components/sach-hoc/audio.ts`):
//   1. Đã đăng nhập ⇒ `POST /api/v1/ielts/doc {text, giong, toc}` ⇒ mp3 (giọng
//      Google/WaveNet do máy chủ sinh, lưu R2) ⇒ phát bằng AVPlayer.
//   2. Chưa đăng nhập / máy chủ không có khoá TTS / mất mạng ⇒ giọng TRONG MÁY
//      (AVSpeechSynthesizer ja-JP / zh-CN / en-GB…), giọng tốt nhất máy có.
// MỘT hàng phát cho cả app: bấm loa khác thì câu đang đọc dừng ngay — hai giọng
// chồng nhau là thứ người học ghét nhất.
//
// Sống ở mức ỨNG DỤNG (singleton), không trong view (bài học 08/2026: thứ đang
// phát để trong màn hình thì đổi màn là chết theo, không lỗi nào để thấy).
// ════════════════════════════════════════════════════════════════

struct ClipSH {
    let text: String
    /// ja-nu · ja-nam · zh-nu · uk-nu…; nil ⇒ giọng mặc định của khoá.
    var giong: String?
    var toc: Double?
}

@MainActor
final class GiongSachHoc: NSObject, ObservableObject {
    static let chung = GiongSachHoc()

    /// Khoá của nút/nhóm đang phát (nút đổi hình khi khớp).
    @Published private(set) var dangPhat: String?
    /// Câu thứ mấy trong lượt đang phát (tô sáng dòng hội thoại).
    @Published private(set) var cauDangDoc: Int?
    @Published private(set) var dangCho = false

    /// Giọng mặc định của khoá đang mở — màn khoá đặt.
    var giongMacDinh = "ja-nu"

    private let may = AVSpeechSynthesizer()
    private var player: AVPlayer?
    private var luot = 0
    private var xongCau: CheckedContinuation<Void, Never>?
    private var viec: Task<Void, Never>?
    private var boNho: [String: (url: URL?, don: Bool)] = [:]
    /// Máy chủ báo không có khoá TTS ⇒ khỏi hỏi lại mỗi câu.
    private var mayChuTat = false
    private var quanSat: [NSObjectProtocol] = []
    /// Câu máy đang nói — delegate báo xong/huỷ của câu CŨ thì bỏ qua (không được kết thúc nhầm câu mới).
    private var idCau: ObjectIdentifier?

    private override init() {
        super.init()
        may.delegate = self
    }

    /// Tốc độ người học chọn (0,75 / 1 / 1,25) — áp lên cả mp3 lẫn giọng máy.
    private var tiLeToc: Double {
        let v = UserDefaults.standard.double(forKey: CaiDatDocSH.tocDo)
        return (0.5...1.5).contains(v) ? v : 1
    }

    func phat(_ clip: ClipSH, khoa: String) { phat([clip], khoa: khoa) }

    /// Phát lần lượt; bấm lại đúng nút đang phát ⇒ dừng.
    func phat(_ clips: [ClipSH], khoa: String) {
        if dangPhat == khoa { dung(); return }
        dung()
        luot += 1
        let my = luot
        dangPhat = khoa
        moPhien()
        viec = Task { [weak self] in
            guard let self else { return }
            for (i, c) in clips.enumerated() {
                guard my == self.luot, !Task.isCancelled else { return }
                self.cauDangDoc = i
                await self.docMot(c, my: my)
            }
            if my == self.luot { self.dangPhat = nil; self.cauDangDoc = nil }
        }
    }

    func dung() {
        luot += 1
        viec?.cancel(); viec = nil
        idCau = nil
        if may.isSpeaking { may.stopSpeaking(at: .immediate) }
        player?.pause(); player = nil
        boQuanSat()
        xong()
        dangPhat = nil; cauDangDoc = nil; dangCho = false
    }

    private func boQuanSat() {
        quanSat.forEach { NotificationCenter.default.removeObserver($0) }
        quanSat = []
    }

    private func xong() { xongCau?.resume(); xongCau = nil }

    private func moPhien() {
        // `.playback`: người học CHỦ ĐỘNG bấm nghe ⇒ phải kêu kể cả khi gạt im lặng (như video).
        let p = AVAudioSession.sharedInstance()
        try? p.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? p.setActive(true)
    }

    // MARK: Một câu

    private func docMot(_ c: ClipSH, my: Int) async {
        let chu = PhanTichChuSH.choGiong(c.text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chu.isEmpty else { return }
        let giong = c.giong ?? giongMacDinh
        if let r = await urlMayChu(chu, giong: giong, toc: c.toc), let url = r.0, my == luot {
            await phatTep(url, nam: r.1 && giong.hasSuffix("nam"), my: my)
        } else if my == luot {
            await noiTrongMay(chu, giong: giong, toc: c.toc)
        }
    }

    private func urlMayChu(_ chu: String, giong: String, toc: Double?) async -> (URL?, Bool)? {
        guard !mayChuTat, StorageManager.shared.getAuthToken() != nil else { return nil }
        let k = "\(giong)|\(toc ?? 0.95)|\(chu)"
        if let co = boNho[k] { return (co.url, co.don) }
        struct Kq: Decodable { let url: String?; let lyDo: String?; let giongDon: Bool? }
        dangCho = true
        defer { dangCho = false }
        var than: [String: Any] = ["text": chu, "giong": giong]
        if let toc { than["toc"] = toc }
        do {
            let kq: Kq = try await APIClient.shared.request(.sachHocDoc(than))
            if kq.lyDo == "no_tts_key" { mayChuTat = true }
            let u = kq.url.flatMap(URL.init(string:))
            boNho[k] = (u, kq.giongDon ?? false)
            return (u, kq.giongDon ?? false)
        } catch {
            return nil   // 401/mất mạng: lần này đọc bằng máy, lần sau hỏi lại
        }
    }

    private func phatTep(_ url: URL, nam: Bool, my: Int) async {
        let item = AVPlayerItem(url: url)
        // Máy chủ chỉ có MỘT giọng mỗi thứ tiếng ⇒ vai nam: chậm lại + hạ cao độ (như web, NAM_RATE 0,86).
        item.audioTimePitchAlgorithm = nam ? .varispeed : .timeDomain
        let p = AVPlayer(playerItem: item)
        player = p
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in
            xongCau = k
            for ten in [Notification.Name.AVPlayerItemDidPlayToEndTime, .AVPlayerItemFailedToPlayToEndTime] {
                quanSat.append(NotificationCenter.default.addObserver(forName: ten, object: item, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.xong() }
                })
            }
            p.playImmediately(atRate: Float(tiLeToc * (nam ? 0.86 : 1)))
        }
        boQuanSat()
        if my == luot { player = nil }
    }

    private func noiTrongMay(_ chu: String, giong: String, toc: Double?) async {
        let ma = giong.hasPrefix("ja") ? "ja" : giong.hasPrefix("zh") ? "zh" : "en"
        let vung = ma == "ja" ? "ja-JP" : ma == "zh" ? "zh-CN" : (giong.hasPrefix("us") ? "en-US" : "en-GB")
        let u = AVSpeechUtterance(string: chu)
        // Giọng người học đã chọn ở màn "Giọng đọc" (nếu là giọng trong máy) ⇒ tốt nhất máy có ⇒ mặc định vùng.
        if case .trongMay(let idG)? = CaiDatGiong.shared.luaChon(ma)?.nguon, let g = AVSpeechSynthesisVoice(identifier: idG) {
            u.voice = g
        } else {
            u.voice = CaiDatGiong.giongTuDong(ma) ?? AVSpeechSynthesisVoice(language: vung)
        }
        let goc = Float(CaiDatGiong.shared.tocDo)
        u.rate = max(0.25, min(0.62, goc * Float(toc ?? 1) * Float(tiLeToc)))
        if giong.hasSuffix("nam") { u.pitchMultiplier = 0.8 }
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in
            xongCau = k
            idCau = ObjectIdentifier(u)
            may.speak(u)
        }
    }
}

extension GiongSachHoc: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        let id = ObjectIdentifier(u)
        Task { @MainActor in if self.idCau == id { self.idCau = nil; self.xong() } }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        let id = ObjectIdentifier(u)
        Task { @MainActor in if self.idCau == id { self.idCau = nil; self.xong() } }
    }
}
