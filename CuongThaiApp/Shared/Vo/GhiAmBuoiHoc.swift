#if os(iOS)
import AVFoundation
import Foundation

/// Ghi âm buổi học, gắn mốc thời gian vào từng nét viết.
///
/// Đây là thứ khiến một cuốn vở điện tử hơn hẳn vở giấy: chạm vào chữ đã
/// viết, nhảy tới đúng giây thầy đang giảng lúc viết chữ đó. Nghe lại một
/// chỗ không hiểu mà không phải tua mò cả tiếng đồng hồ.
@MainActor
final class GhiAmBuoiHoc: NSObject, ObservableObject {
    static let shared = GhiAmBuoiHoc()

    @Published private(set) var dangGhi = false
    @Published private(set) var dangPhat = false
    @Published private(set) var giay: Double = 0
    /// Trang đang được ghi âm — chỉ một trang tại một thời điểm.
    @Published private(set) var idTrangDangGhi: UUID?

    private var mayGhi: AVAudioRecorder?
    private var mayPhat: AVAudioPlayer?
    private var dongHo: Timer?
    private var tenTepDangGhi: String?

    private override init() { super.init() }

    static var thuMuc: URL {
        let u = KhoVo.thuMucGoc.appendingPathComponent("tieng", isDirectory: true)
        if !FileManager.default.fileExists(atPath: u.path) {
            try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        }
        return u
    }
    static func duongDan(_ ten: String) -> URL { thuMuc.appendingPathComponent(ten) }

    // MARK: Ghi

    /// Xin quyền rồi bắt đầu ghi. Trả về tên tệp, hoặc `nil` kèm lý do.
    func batDau(choTrang id: UUID) async -> (ten: String?, loi: String?) {
        guard !dangGhi else { return (nil, T("Đang ghi âm rồi")) }
        let duoc = await AVAudioApplication.requestRecordPermission()
        guard duoc else {
            return (nil, T("Chưa được phép dùng micro — bật ở Cài đặt › Quyền riêng tư"))
        }
        do {
            let phien = AVAudioSession.sharedInstance()
            // `.playAndRecord` + `.defaultToSpeaker`: ghi xong nghe lại ngay
            // mà không phải đổi chế độ. `.mixWithOthers` để không cắt nhạc
            // hay cuộc gọi đang chạy của người dùng.
            try phien.setCategory(.playAndRecord, mode: .spokenAudio,
                                  options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try phien.setActive(true)

            let ten = "\(UUID().uuidString).m4a"
            // 32kbps mono AAC ≈ 14MB/giờ. Giọng giảng bài không cần hơn, và
            // con số này nhân theo từng buổi học suốt một học kỳ.
            let cai: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 22050,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32000,
            ]
            let m = try AVAudioRecorder(url: Self.duongDan(ten), settings: cai)
            m.record()
            mayGhi = m
            tenTepDangGhi = ten
            dangGhi = true
            idTrangDangGhi = id
            batDongHo()
            NhatKy.vo.info("bắt đầu ghi âm trang \(id.uuidString)")
            return (ten, nil)
        } catch {
            NhatKy.vo.error("ghi âm hỏng: \(error.localizedDescription)")
            return (nil, error.localizedDescription)
        }
    }

    /// Dừng ghi. Trả về (tên tệp, độ dài giây).
    @discardableResult
    func dung() -> (ten: String, dai: Double)? {
        guard let m = mayGhi, let ten = tenTepDangGhi else { return nil }
        let dai = m.currentTime
        m.stop()
        mayGhi = nil
        tenTepDangGhi = nil
        dangGhi = false
        idTrangDangGhi = nil
        tatDongHo()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        NhatKy.vo.info("dừng ghi âm — \(Int(dai))s")
        return (ten, dai)
    }

    /// Giây hiện tại của bản ghi — dùng làm mốc cho nét vừa viết xong.
    var giayHienTai: Double { mayGhi?.currentTime ?? 0 }

    // MARK: Phát

    func phat(ten: String, tuGiay: Double = 0) {
        dungPhat()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio,
                                                            options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: Self.duongDan(ten))
            p.delegate = self
            p.currentTime = max(0, min(tuGiay, p.duration - 0.1))
            p.play()
            mayPhat = p
            dangPhat = true
            batDongHo()
        } catch {
            NhatKy.vo.error("phát lại hỏng: \(error.localizedDescription)")
        }
    }

    func dungPhat() {
        mayPhat?.stop()
        mayPhat = nil
        dangPhat = false
        tatDongHo()
    }

    // MARK: Đồng hồ

    private func batDongHo() {
        tatDongHo()
        dongHo = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.giay = self.mayGhi?.currentTime ?? self.mayPhat?.currentTime ?? 0
            }
        }
    }
    private func tatDongHo() { dongHo?.invalidate(); dongHo = nil; giay = 0 }

    static func doDaiChu(_ giay: Double) -> String {
        let t = Int(giay.rounded())
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

extension GhiAmBuoiHoc: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.dungPhat() }
    }
}
#endif
