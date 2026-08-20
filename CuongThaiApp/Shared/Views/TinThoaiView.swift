import SwiftUI
import AVFoundation

/// Bong bóng tin thoại: nút phát + dải sóng + thời lượng.
///
/// Dải sóng vẽ từ CHÍNH tên file (băm ra số), không phải đo biên độ thật: đo
/// thật thì phải tải cả file về và giải mã trước khi vẽ được một pixel, tức
/// khung chat đứng hình. Messenger cũng vẽ sóng trang trí như vậy.
struct TinThoaiView: View {
    let tep: MessageAttachment
    let mauChu: Color
    let mauNen: Color

    @StateObject private var may = PhatThoai()

    private var cot: [CGFloat] {
        var h = UInt64(abs(tep.url.hashValue)) | 1
        return (0..<26).map { _ in
            h = h &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((h >> 33) % 100) / 100 * 15 + 4
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            Button {
                may.batTat(URL(string: tep.url))
            } label: {
                Image(systemName: may.dangPhat ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(mauNen)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(mauChu))
            }
            .buttonStyle(.plain)

            HStack(spacing: 2) {
                ForEach(Array(cot.enumerated()), id: \.offset) { i, h in
                    Capsule()
                        .fill(mauChu.opacity(may.phanTram > Double(i) / Double(cot.count) ? 1 : 0.42))
                        .frame(width: 2.5, height: h)
                }
            }
            .frame(height: 22)

            Text(may.nhan(macDinh: tep.fileSize))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(mauChu.opacity(0.85))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(mauNen)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

@MainActor
final class PhatThoai: NSObject, ObservableObject {
    @Published var dangPhat = false
    @Published var phanTram: Double = 0
    @Published var conLai: Double = 0

    private var may: AVPlayer?
    private var moc: Any?

    func batTat(_ url: URL?) {
        guard let url else { return }
        if dangPhat { may?.pause(); dangPhat = false; return }

        if may == nil {
            #if os(iOS)
            // Không đặt category thì tin thoại IM khi máy đang gạt nút im lặng
            // — người dùng tưởng file hỏng.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            let m = AVPlayer(url: url)
            moc = m.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                                            queue: .main) { [weak self, weak m] t in
                guard let self, let m, let item = m.currentItem else { return }
                let tong = item.duration.seconds
                guard tong.isFinite, tong > 0 else { return }
                Task { @MainActor in
                    self.phanTram = t.seconds / tong
                    self.conLai = max(0, tong - t.seconds)
                }
            }
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: m.currentItem, queue: .main
            ) { [weak self, weak m] _ in
                Task { @MainActor in
                    self?.dangPhat = false
                    self?.phanTram = 0
                    m?.seek(to: .zero)
                }
            }
            may = m
        }
        may?.play()
        dangPhat = true
    }

    /// Đang phát thì đếm ngược; chưa phát thì ƯỚC thời lượng từ cỡ file.
    /// Máy chủ không trả thời lượng, mà 32kbps ≈ 4KB/giây nên ước khá sát.
    func nhan(macDinh byte: Int?) -> String {
        let giay = conLai > 0 ? conLai : Double(byte ?? 0) / 4000
        guard giay.isFinite, giay > 0 else { return "0:00" }
        let g = Int(giay.rounded())
        return String(format: "%d:%02d", g / 60, g % 60)
    }
}
