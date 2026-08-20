import Foundation
import AVFoundation

/// Ghi tin thoại. Xuất `.m4a` (AAC) — đây là thứ iOS ghi ra tự nhiên nhất và
/// mọi máy đều phát được.
///
/// ⚠️ File đi qua `POST /messages/upload`, mà đường đó chuyển file KHÔNG PHẢI
/// ảnh sang `uploadDocument()` — hàm này KHÔNG lọc kiểu file, chỉ chặn dung
/// lượng. Nếu có ai đổi nó sang dùng `ALLOWED_AUDIO_TYPES` thì tin thoại sẽ
/// hỏng CÂM, vì danh sách đó có `audio/aac` nhưng KHÔNG có `audio/m4a`.
@MainActor
final class GhiAmThoai: NSObject, ObservableObject {
    @Published private(set) var dangGhi = false
    @Published private(set) var giay: Int = 0
    @Published var loi: String?

    private var may: AVAudioRecorder?
    private var dongHo: Timer?
    private var duong: URL?

    /// 32kbps mono là đủ cho giọng nói và cho ra ~4KB/giây — trần 10MB của máy
    /// chủ tương đương khoảng 40 phút, dài hơn mọi tin thoại thực tế.
    private static let caiDat: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 22_050,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 32_000,
    ]

    func batDau() async {
        guard !dangGhi else { return }
        guard await xinQuyen() else {
            loi = "Bạn chưa cho phép dùng micro. Bật lại trong Cài đặt → Quyền riêng tư → Micro."
            return
        }
        #if os(iOS)
        do {
            let phien = AVAudioSession.sharedInstance()
            // `.playAndRecord` chứ không phải `.record`: sau khi ghi xong người
            // dùng thường bấm nghe lại ngay, mà `.record` thì loa câm.
            try phien.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try phien.setActive(true)
        } catch {
            loi = "Không mở được micro: \(error.localizedDescription)"
            return
        }
        #endif

        let f = FileManager.default.temporaryDirectory
            .appendingPathComponent("thoai-\(UUID().uuidString).m4a")
        do {
            let m = try AVAudioRecorder(url: f, settings: Self.caiDat)
            m.record()
            may = m
            duong = f
            dangGhi = true
            giay = 0
            dongHo = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.giay += 1 }
            }
        } catch {
            loi = "Không ghi âm được: \(error.localizedDescription)"
        }
    }

    /// Dừng và trả về dữ liệu. `nil` nếu huỷ hoặc file rỗng.
    @discardableResult
    func dungLai(huy: Bool = false) -> (data: Data, giay: Int)? {
        dongHo?.invalidate(); dongHo = nil
        may?.stop(); may = nil
        dangGhi = false
        let doDai = giay
        giay = 0

        guard let f = duong else { return nil }
        duong = nil
        defer { try? FileManager.default.removeItem(at: f) }
        if huy { return nil }

        // Bấm nhả quá nhanh thì file chỉ có phần đầu định dạng, phát ra là im
        // lặng — chặn ở đây thay vì gửi một tin thoại rỗng.
        guard doDai >= 1, let d = try? Data(contentsOf: f), d.count > 1024 else { return nil }
        return (d, doDai)
    }

    private func xinQuyen() async -> Bool {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { c in
                AVAudioSession.sharedInstance().requestRecordPermission { c.resume(returning: $0) }
            }
        }
        #else
        return true
        #endif
    }
}
