import SwiftUI
import AVFoundation

// ════════════════════════════════════════════════════════════════
// LUYỆN NGHE
//
// Kho đã có sẵn trên máy chủ từ 07/07/2026 mà app chưa hề đọc tới: mô hình
// không khai `BaiNghe`, `APIEndpoint` không có `/listening`, và hub không có
// thẻ nào. Hệ quả kèm theo: 3 trong 38 nút lộ trình tiếng Anh trỏ vào
// `listening` nên bấm ra màn trống (xem `LoaiNoiDung.coManHinh`).
//
// ⚠️ Kho MỎNG và KHÔNG ĐỀU — đo thật 24/08/2026, tiếng Anh 11 bài (Nhật và
// Trung 0): 7 bài có transcript + bản dịch, 10 bài có 4 câu hỏi, và đúng 1
// bài ("Podcast") chỉ có mỗi đường YouTube. Nên mọi khối ở đây đều tự ẩn khi
// thiếu dữ liệu, thay vì vẽ ra ô rỗng.
// ════════════════════════════════════════════════════════════════

struct NgheView: View {
    let ngonNgu: NgonNgu

    @State private var muc: [BaiNghe] = []
    @State private var dangTai = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                if dangTai && muc.isEmpty {
                    ProgressView().padding(.top, Spacing.xl)
                } else if muc.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "headphones")
                            .font(.system(size: 40)).foregroundColor(AppColors.textTertiary)
                        Text("Chưa có bài nghe cho \(ngonNgu.name).")
                            .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, Spacing.xxl)
                }
                ForEach(muc) { b in
                    NavigationLink(destination: NgheChiTietView(bai: b)) { hang(b) }
                        .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Luyện nghe")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard muc.isEmpty else { return }
            dangTai = true
            let r: ([BaiNghe], Int?, Bool)? = try? await APIClient.shared
                .requestList(.baiNghe(code: ngonNgu.code, page: 1, limit: 100))
            muc = r?.0 ?? []
            dangTai = false
        }
    }

    private func hang(_ b: BaiNghe) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: b.laYouTube ? "play.rectangle.fill" : "headphones")
                .font(.system(size: 18))
                .foregroundColor(AppColors.primary)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text(b.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                // Nói TRƯỚC bài này có gì, để không mở ra rồi mới biết nó trống.
                HStack(spacing: Spacing.xs) {
                    if let l = b.level, !l.isEmpty { the(l, AppColors.accent) }
                    if b.coLoiThoai { the("lời thoại", AppColors.success) }
                    if !b.dsCauHoi.isEmpty { the("\(b.dsCauHoi.count) câu hỏi", AppColors.primary) }
                    if !b.coNoiDungHoc { the("chỉ video", AppColors.textTertiary) }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private func the(_ chu: String, _ mau: Color) -> some View {
        Text(chu)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(mau)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(mau.opacity(0.14)))
    }
}

// MARK: - Một bài nghe

struct NgheChiTietView: View {
    let bai: BaiNghe

    @StateObject private var may = MayPhat()
    @State private var hienLoiThoai = false
    @State private var hienDich = false
    @State private var moDapAn: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(bai.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let u = bai.duongAmThanh, !bai.laYouTube {
                    khungPhat(u)
                } else if let y = bai.duongYouTube {
                    Link(destination: y) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "play.rectangle.fill")
                            Text("Mở trên YouTube").font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .foregroundColor(.white)
                        .padding(Spacing.md)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color(hex: 0xFF0000)))
                    }
                }

                if bai.coLoiThoai { khoiLoiThoai }
                if !bai.dsCauHoi.isEmpty { khoiCauHoi }

                if !bai.coNoiDungHoc {
                    Text("Bài này chưa có lời thoại và câu hỏi — mới chỉ có phần nghe.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.xl)
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Bài nghe")
        .navigationBarTitleDisplayMode(.inline)
        // ⚠️ PHẢI dừng khi rời màn. Người học bấm quay lại mà tiếng vẫn chạy
        // dưới nền là không tắt được bằng đường nào trong app.
        .onDisappear { may.dung() }
    }

    // ── Trình phát ───────────────────────────────────────────────
    private func khungPhat(_ u: URL) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.lg) {
                nut("gobackward.10") { may.nhay(-10) }
                Button { may.batTat(u) } label: {
                    Image(systemName: may.dangPhat ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
                nut("goforward.10") { may.nhay(10) }
            }

            // Thanh tua LUÔN có mặt, kể cả khi chưa biết độ dài. Vẽ nó theo
            // điều kiện thì lúc bấm phát cả khung phình ra và mọi thứ bên
            // dưới nhảy chỗ — đúng lúc người dùng vừa chạm tay.
            Slider(value: Binding(get: { may.viTri },
                                  set: { may.tuaToi($0) }),
                   in: 0...max(may.tong, 0.01))
                .tint(AppColors.primary)
                .disabled(may.tong <= 0)
            HStack {
                Text(MayPhat.dinhDang(may.viTri))
                Spacer()
                Text(may.tong > 0 ? MayPhat.dinhDang(may.tong) : "--:--")
            }
            .font(.system(size: 11).monospacedDigit())
            .foregroundColor(AppColors.textTertiary)

            // Tốc độ là thứ dùng nhiều nhất khi luyện nghe: nghe chậm để bắt
            // âm, rồi tăng dần về tốc độ người bản xứ nói.
            HStack(spacing: Spacing.sm) {
                ForEach([0.75, 1.0, 1.25, 1.5], id: \.self) { t in
                    Button { may.doiTocDo(Float(t)) } label: {
                        Text(t == 1.0 ? "1×" : String(format: "%g×", t))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(may.tocDo == Float(t) ? AppColors.onPrimary : AppColors.textSecondary)
                            .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 5)
                            .background(Capsule().fill(may.tocDo == Float(t)
                                                       ? AppColors.primary : AppColors.backgroundTertiary))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private func nut(_ ten: String, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Image(systemName: ten).font(.system(size: 22))
                .foregroundColor(AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // ── Lời thoại ────────────────────────────────────────────────
    private var khoiLoiThoai: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Mặc định ĐÓNG: nhìn thấy chữ trước khi nghe là mất hẳn phần
            // luyện nghe, chỉ còn luyện đọc.
            Button { withAnimation(.snappy(duration: 0.2)) { hienLoiThoai.toggle() } } label: {
                HStack {
                    Image(systemName: hienLoiThoai ? "eye.slash" : "eye")
                    Text(hienLoiThoai ? "Ẩn lời thoại" : "Xem lời thoại")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .foregroundColor(AppColors.primary)
            }
            .buttonStyle(.plain)

            if hienLoiThoai {
                Text(bai.transcript ?? "")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let d = bai.translation, !d.isEmpty {
                    Button { withAnimation(.snappy(duration: 0.2)) { hienDich.toggle() } } label: {
                        Text(hienDich ? "Ẩn bản dịch" : "Xem bản dịch tiếng Việt")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                    .buttonStyle(.plain)
                    if hienDich {
                        Text(d)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    // ── Câu hỏi ──────────────────────────────────────────────────
    private var khoiCauHoi: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("CÂU HỎI (\(bai.dsCauHoi.count))")
                .font(.system(size: 10, weight: .bold)).kerning(0.5)
                .foregroundColor(AppColors.textTertiary)
            ForEach(bai.dsCauHoi) { c in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(c.question ?? "")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    // Đáp án là câu trả lời MỞ (kèm nghĩa tiếng Việt trong
                    // ngoặc), không phải trắc nghiệm — nên chỉ có mở/đóng.
                    if moDapAn.contains(c.id) {
                        Text(c.answer ?? "")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.success)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { _ = moDapAn.insert(c.id) }
                        } label: {
                            Text("Xem đáp án")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundCard))
            }
        }
    }
}

// MARK: - Máy phát

/// Bọc `AVPlayer` cho một tệp âm thanh trên mạng.
///
/// ⚠️ Phải đặt `AVAudioSession` sang `.playback`, không thì tiếng KHÔNG ra khi
/// máy đang gạt nút im lặng — người dùng sẽ báo "bấm phát mà không nghe gì".
@MainActor
final class MayPhat: ObservableObject {
    @Published private(set) var dangPhat = false
    @Published private(set) var viTri: Double = 0
    @Published private(set) var tong: Double = 0
    @Published private(set) var tocDo: Float = 1.0

    private var may: AVPlayer?
    private var theoDoi: Any?

    func batTat(_ u: URL) {
        if may == nil { nap(u) }
        guard let may else { return }
        if dangPhat { may.pause(); dangPhat = false }
        else {
            // `rate` phải đặt SAU `play()`: gọi `play()` luôn kéo rate về 1.0,
            // nên đặt trước là tốc độ đã chọn bị mất im lặng.
            may.play(); may.rate = tocDo; dangPhat = true
        }
    }

    func nhay(_ giay: Double) {
        guard let may else { return }
        let m = max(0, min(tong, viTri + giay))
        may.seek(to: CMTime(seconds: m, preferredTimescale: 600))
    }

    func tuaToi(_ giay: Double) {
        guard let may else { return }
        viTri = giay
        may.seek(to: CMTime(seconds: giay, preferredTimescale: 600))
    }

    func doiTocDo(_ t: Float) {
        tocDo = t
        if dangPhat { may?.rate = t }
    }

    func dung() {
        may?.pause(); dangPhat = false
        if let theoDoi { may?.removeTimeObserver(theoDoi) }
        theoDoi = nil; may = nil
    }

    private func nap(_ u: URL) {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let p = AVPlayer(url: u)
        theoDoi = p.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
        ) { [weak self] t in
            Task { @MainActor in
                guard let self else { return }
                self.viTri = t.seconds
                if let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 { self.tong = d }
                if let d = p.currentItem?.duration.seconds, d.isFinite, t.seconds >= d - 0.05 {
                    self.dangPhat = false
                }
            }
        }
        may = p
    }

    static func dinhDang(_ giay: Double) -> String {
        guard giay.isFinite, giay >= 0 else { return "0:00" }
        let t = Int(giay)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}
