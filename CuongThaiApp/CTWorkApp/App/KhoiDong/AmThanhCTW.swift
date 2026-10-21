import AVFoundation
import Foundation

// MARK: - Âm thanh trong app CT Work (21/10/2026)
//
// · "ting! CT Work!" (ctwork.caf, 1,23 s) — phát MỘT lần ở màn khởi động, khớp đúng nhịp dấu tích, CHỈ khi mở
//   nguội (màn khởi động chỉ dựng một lần mỗi tiến trình). Công tắc: Account › Âm thanh › "Launch sound".
// · xong.caf — khi một thẻ vừa sang cột Done (Board / chuyển nhanh ở My Work). Công tắc: "Sound effects".
// Phiên âm thanh `.ambient`: tôn trọng nút gạt im lặng và TRỘN với nhạc/podcast đang phát (không cắt ngang).
// Hai tệp nằm ở GỐC gói app (project.yml › Resources/Sounds) — chung chỗ với âm thông báo đẩy.

@MainActor
enum AmThanhCTW {
    static let khoaKhoiDong = "ctw.amThanh.khoiDong"
    static let khoaHieuUng = "ctw.amThanh.hieuUng"

    /// Mặc định BẬT (UserDefaults trả `false` khi chưa có khoá ⇒ đăng ký giá trị mặc định).
    static func dangKyMacDinh() {
        UserDefaults.standard.register(defaults: [khoaKhoiDong: true, khoaHieuUng: true])
    }

    static var batKhoiDong: Bool { UserDefaults.standard.bool(forKey: khoaKhoiDong) }
    static var batHieuUng: Bool { UserDefaults.standard.bool(forKey: khoaHieuUng) }

    private static var dangPhat: [String: AVAudioPlayer] = [:]

    /// Nạp sẵn (đọc tệp + giải mã) để lúc phát không trễ nhịp so với hoạt hình.
    @discardableResult
    static func napSan(_ ten: String) -> AVAudioPlayer? {
        if let p = dangPhat[ten] { return p }
        guard let url = Bundle.main.url(forResource: ten, withExtension: "caf"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.prepareToPlay()
        dangPhat[ten] = p
        return p
    }

    static func phat(_ ten: String, amLuong: Float = 1) {
        guard let p = napSan(ten) else { return }
        // `.ambient` + mixWithOthers: không giành phiên âm thanh của app khác; gạt im lặng ⇒ không kêu.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        p.volume = amLuong
        p.currentTime = 0
        p.play()
    }

    static func dung(_ ten: String) {
        dangPhat[ten]?.stop()
    }

    /// Âm khởi động — chỉ khi công tắc bật.
    static func phatKhoiDong() {
        guard batKhoiDong else { return }
        phat("ctwork")
    }

    /// Âm "xong" — chỉ khi công tắc hiệu ứng bật.
    static func phatXong() {
        guard batHieuUng else { return }
        phat("xong", amLuong: 0.8)
    }
}
