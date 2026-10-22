import SwiftUI
import Combine
#if os(iOS)
import AVKit
import AVFoundation
#endif

// ════════════════════════════════════════════════════════════════
// TRÌNH PHÁT VIDEO BÀI HỌC — R2 (AVPlayer) + YouTube (khung nhúng)
//
// Trước 22/10/2026 app CHỈ phát YouTube: video bài giảng tự quay đưa thẳng lên
// R2 (FER202: 48 bài) hiện "Bài này chưa có video" dù web phát bình thường.
// Video R2 là file RIÊNG — URL ký 6 giờ, chỉ `GET /courses/:id/lessons/:id`
// trả về (mục lục giấu bằng `locked: true`). AVPlayer đọc Range nên tua được.
//
// ⚠️ App Store 5.2.3: chỉ PHÁT, không có nút tải video. Video R2 là nội dung
// của chính nền tảng; YouTube vẫn đi khung nhúng chính thức.
// ════════════════════════════════════════════════════════════════

#if os(iOS)

/// Bộ não của trình phát: giữ `AVPlayer`, báo mốc giây, báo hết, báo hỏng.
@MainActor
final class BoPhatVideo: NSObject, ObservableObject {
    let player = AVPlayer()

    @Published private(set) var giay: Double = 0
    @Published private(set) var thoiLuong: Double = 0
    @Published private(set) var dangPhat = false
    @Published private(set) var dangCho = false
    @Published private(set) var loi: String?
    @Published var tocDo: Float = 1 {
        didSet {
            player.defaultRate = tocDo
            if player.timeControlStatus != .paused { player.rate = tocDo }
        }
    }

    /// Mỗi giây một lần khi đang phát: (mốc, thời lượng).
    var khiTick: ((Double, Double) -> Void)?
    /// Người học bấm dừng — lưu mốc NGAY (web lưu khi pause).
    var khiDung: ((Double) -> Void)?
    var khiHet: (() -> Void)?
    /// Biết thời lượng thật lần đầu — để báo `POST /lessons/:id/duration`.
    var khiCoThoiLuong: ((Double) -> Void)?
    /// File không phát được (URL ký hết hạn 403, mạng…). Trả `true` nếu bên ngoài
    /// sẽ xin URL mới và gọi `nap` lại — khi đó KHÔNG hiện lỗi.
    var khiHong: ((Double) -> Bool)?

    private var khoaDangNap: String?
    private var mocCho: Double = 0
    private var quanSatGio: Any?
    private var huy = Set<AnyCancellable>()
    private var huyItem = Set<AnyCancellable>()
    private var daBaoThoiLuong = false

    override init() {
        super.init()
        player.allowsExternalPlayback = true
        quanSatGio = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600),
                                                    queue: .main) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self else { return }
                let s = t.seconds
                guard s.isFinite else { return }
                self.giay = s
                if self.dangPhat { self.khiTick?(s, self.thoiLuong) }
            }
        }
        player.publisher(for: \.timeControlStatus)
            .receive(on: RunLoop.main)
            .sink { [weak self] st in
                guard let self else { return }
                let truoc = self.dangPhat
                self.dangPhat = st == .playing
                self.dangCho = st == .waitingToPlayAtSpecifiedRate
                if st == .playing { Self.batPhienAmThanh() }
                if truoc && st == .paused { self.khiDung?(self.giay) }
            }
            .store(in: &huy)
    }

    deinit {
        if let quanSatGio { player.removeTimeObserver(quanSatGio) }
    }

    /// Nạp một file. Gọi lại với CÙNG `khoa` là không làm gì (SwiftUI vẽ lại liên tục).
    /// `khoa` = "<bài>-<luồng>-<url>" — URL mới (ký lại) thì nạp lại, giữ mốc.
    func nap(url: URL, khoa: String, batDau: Double, tuPhat: Bool = false) {
        guard khoaDangNap != khoa else { return }
        khoaDangNap = khoa
        loi = nil
        mocCho = batDau
        giay = batDau
        thoiLuong = 0
        daBaoThoiLuong = false
        huyItem.removeAll()

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 20
        item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self, weak item] st in
                guard let self, let item else { return }
                switch st {
                case .readyToPlay:
                    let d = item.duration.seconds
                    if d.isFinite, d > 0 {
                        self.thoiLuong = d
                        if !self.daBaoThoiLuong { self.daBaoThoiLuong = true; self.khiCoThoiLuong?(d) }
                    }
                    if self.mocCho > 0 {
                        let moc = self.mocCho
                        self.mocCho = 0
                        self.player.seek(to: CMTime(seconds: moc, preferredTimescale: 600),
                                         toleranceBefore: .zero, toleranceAfter: CMTime(seconds: 1, preferredTimescale: 600))
                    }
                case .failed:
                    self.baoHong(item.error)
                default: break
                }
            }
            .store(in: &huyItem)
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.khiHet?() }
            .store(in: &huyItem)
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] n in
                self?.baoHong(n.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)
            }
            .store(in: &huyItem)

        player.replaceCurrentItem(with: item)
        player.defaultRate = tocDo
        if tuPhat { player.playImmediately(atRate: tocDo) }
    }

    func phat() { player.playImmediately(atRate: tocDo) }
    func dung() { player.pause() }

    func tua(_ giay: Double) {
        player.seek(to: CMTime(seconds: max(0, giay), preferredTimescale: 600))
    }

    /// Rời màn / đổi bài: dừng + nhả file (không để tiếng chạy tiếp sau lưng).
    func thaRa() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        khoaDangNap = nil
        huyItem.removeAll()
    }

    private func baoHong(_ e: Error?) {
        let moc = giay
        // Cho phép nạp lại cùng khoá sau khi bên ngoài xin được URL mới.
        khoaDangNap = nil
        if khiHong?(moc) == true { return }
        loi = e?.localizedDescription ?? T("Không phát được video này.")
    }

    /// Phát cả khi máy đang gạt im lặng (video bài giảng là nội dung chính, không
    /// phải âm thanh phụ) + cho Hình trong hình chạy nền (Info.plist đã có `audio`).
    private static func batPhienAmThanh() {
        let p = AVAudioSession.sharedInstance()
        if p.category != .playback {
            try? p.setCategory(.playback, mode: .moviePlayback, options: [])
        }
        try? p.setActive(true)
    }
}

/// `AVPlayerViewController` thật: toàn màn hình, Hình trong hình, AirPlay, menu tốc độ
/// gốc của iOS — những thứ người học quen tay, tự vẽ lại là thiếu.
struct KhungAVPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.allowsPictureInPicturePlayback = true
        vc.canStartPictureInPictureAutomaticallyFromInline = true
        vc.entersFullScreenWhenPlaybackBegins = false
        vc.exitsFullScreenWhenPlaybackEnds = true
        vc.updatesNowPlayingInfoCenter = true
        vc.videoGravity = .resizeAspect
        vc.view.backgroundColor = .black
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player { vc.player = player }
    }
}

#endif

// MARK: - Khối video của màn học

/// Bộ chọn luồng VN / EN / YT + khung phát + tốc độ + nguồn.
struct KhoiVideoBai: View {
    let dsO: [OLuongVideo]
    let dangChon: OLuongVideo?
    let dangTaiBai: Bool
    let loiTaiBai: String?
    #if os(iOS)
    @ObservedObject var bo: BoPhatVideo
    #endif
    let khiChonLuong: (String) -> Void
    let khiThuLai: () -> Void
    /// Bấm "Hỏi về đoạn này" — mở CuongMini kèm mốc giây.
    var khiHoiDoanNay: (() -> Void)?

    private let tocDos: [Float] = [0.75, 1, 1.25, 1.5, 1.75, 2]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if dsO.filter(\.coVideo).count > 0 { boChon }
            khung
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            hangDuoi
        }
    }

    // ── Bộ chọn luồng ─────────────────────────────────────────────
    private var boChon: some View {
        HStack(spacing: 4) {
            ForEach(dsO) { o in
                let chon = dangChon?.track == o.track
                Button {
                    guard o.coVideo, !chon else { return }
                    Haptics.cham()
                    khiChonLuong(o.track)
                } label: {
                    HStack(spacing: 4) {
                        Text(o.nhanNgan).font(.system(size: 12.5, weight: .bold))
                        if !o.coVideo {
                            Text(T("Sắp có")).font(.system(size: 10.5, weight: .medium)).opacity(0.75)
                        }
                    }
                    .foregroundColor(chon ? AppColors.onPrimary : (o.coVideo ? AppColors.textPrimary : AppColors.textTertiary))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(chon ? AnyShapeStyle(AppColors.brandGradient) : AnyShapeStyle(Color.clear)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!o.coVideo)
                .accessibilityLabel(o.nhanDai + (o.coVideo ? "" : ", " + T("sắp có")))
                .accessibilityAddTraits(chon ? .isSelected : [])
            }
            Spacer(minLength: 0)
            if let o = dangChon {
                Text(o.nhanDai)
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(4)
        .background(Capsule().fill(AppColors.backgroundTertiary))
    }

    // ── Khung phát ────────────────────────────────────────────────
    @ViewBuilder
    private var khung: some View {
        if let o = dangChon, o.trangThai == .phatDuoc {
            #if os(iOS)
            if o.laYouTube, let ma = maVideoYouTube(o.url) {
                YouTubePlayer(videoId: ma)
            } else if o.laFileRieng {
                ZStack {
                    KhungAVPlayer(player: bo.player)
                    if let l = bo.loi { lopLoi(l) }
                }
            } else if let u = o.url, let url = URL(string: u) {
                // Nhúng lạ (không YouTube, không file) — mở bằng trình duyệt trong app.
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "play.rectangle").font(.system(size: 34)).foregroundColor(.white.opacity(0.8))
                    Link(T("Mở video"), destination: url).font(.buttonSmall).foregroundColor(.white)
                }
            }
            #else
            lopChu(T("Trình phát video chỉ có trên iOS"))
            #endif
        } else if dangTaiBai || dangChon?.trangThai == .dangTai {
            if let l = loiTaiBai, !dangTaiBai {
                lopLoi(l)
            } else {
                VStack(spacing: Spacing.sm) {
                    ProgressView().tint(.white)
                    Text(T("Đang tải video…")).font(.caption).foregroundColor(.white.opacity(0.75))
                }
            }
        } else {
            lopChu(T("Bài này chưa có video"))
        }
    }

    private func lopChu(_ s: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "video.slash").font(.system(size: 28)).foregroundColor(.white.opacity(0.6))
            Text(s).font(.bodySmall).foregroundColor(.white.opacity(0.75))
        }
    }

    private func lopLoi(_ l: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 26)).foregroundColor(AppColors.warning)
            Text(l).font(.bodySmall).foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center).padding(.horizontal, Spacing.lg)
            Button {
                Haptics.cham(); khiThuLai()
            } label: {
                Label(T("Thử lại"), systemImage: "arrow.clockwise")
                    .font(.buttonSmall).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
    }

    // ── Hàng dưới: tốc độ · nguồn · hỏi đoạn này ─────────────────
    @ViewBuilder
    private var hangDuoi: some View {
        if let o = dangChon, o.trangThai == .phatDuoc {
            VStack(alignment: .leading, spacing: 6) {
                #if os(iOS)
                if o.laFileRieng {
                    HStack(spacing: Spacing.sm) {
                        Menu {
                            ForEach(tocDos, id: \.self) { t in
                                Button {
                                    bo.tocDo = t
                                } label: {
                                    if bo.tocDo == t { Label(nhanTocDo(t), systemImage: "checkmark") } else { Text(nhanTocDo(t)) }
                                }
                            }
                        } label: {
                            Label(nhanTocDo(bo.tocDo), systemImage: "gauge.with.dots.needle.67percent")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(AppColors.backgroundTertiary))
                        }
                        .accessibilityLabel(T("Tốc độ phát") + " " + nhanTocDo(bo.tocDo))
                        if bo.thoiLuong > 0 {
                            Text("\(TienDoXem.dongHo(bo.giay)) / \(TienDoXem.dongHo(bo.thoiLuong))")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Spacer(minLength: 0)
                        if let khiHoiDoanNay {
                            Button { Haptics.cham(); khiHoiDoanNay() } label: {
                                Label(T("Hỏi đoạn này"), systemImage: "sparkles")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(AppColors.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                #endif
                if o.track == "YT" {
                    HStack(spacing: Spacing.md) {
                        if let c = o.credit, !c.isEmpty {
                            Label {
                                Text(T("Nguồn:") + " " + c).fixedSize(horizontal: false, vertical: true)
                            } icon: { Image(systemName: "info.circle") }
                        }
                        Spacer(minLength: 0)
                        if let ma = maVideoYouTube(o.url), let u = URL(string: "https://www.youtube.com/watch?v=\(ma)") {
                            Link(destination: u) {
                                Label(T("Xem trên YouTube"), systemImage: "arrow.up.forward.app")
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                }
            }
        }
    }

    private func nhanTocDo(_ t: Float) -> String {
        t == 1 ? "1×" : String(format: "%g×", t)
    }
}

/// Lớp "Bài tiếp theo" hiện khi video hết — tự chuyển sau vài giây, huỷ được.
struct LopBaiTiep: View {
    let tenBai: String
    let giayCho: Int
    let khiChuyen: () -> Void
    let khiHuy: () -> Void

    @State private var conLai: Int = 5
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().stroke(AppColors.onPrimary.opacity(0.25), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(conLai) / CGFloat(max(giayCho, 1)))
                    .stroke(AppColors.onPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(giamChuyenDong ? nil : .linear(duration: 1), value: conLai)
                Text("\(conLai)").font(.system(size: 13, weight: .bold)).foregroundColor(AppColors.onPrimary)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(T("Bài tiếp theo")).font(.captionBold).foregroundColor(AppColors.onPrimary.opacity(0.85))
                Text(tenBai).font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.onPrimary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button(T("Huỷ"), action: khiHuy)
                .font(.buttonSmall).foregroundColor(AppColors.onPrimary.opacity(0.85))
            Button {
                khiChuyen()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppColors.onPrimary))
            }
            .accessibilityLabel(T("Học bài tiếp theo ngay"))
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.brandGradient))
        .shadow(color: AppColors.primary.opacity(0.3), radius: 12, y: 4)
        .task {
            conLai = giayCho
            while conLai > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                conLai -= 1
            }
            khiChuyen()
        }
    }
}
