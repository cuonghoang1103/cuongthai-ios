import SwiftUI
import AVKit

/// Màn xem tin toàn màn hình: thanh tiến độ trên đỉnh, tự chạy sang tin kế,
/// chạm trái/phải để lùi/tới, giữ để tạm dừng.
struct XemTinView: View {
    let tinDauTien: Tin
    /// Gọi lại khi đóng, để hàng tin vẽ lại vòng "đã xem".
    var dongLai: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var ds: [Tin] = []
    @State private var chiSo = 0
    @State private var tienDo: Double = 0
    @State private var tamDung = false
    @State private var dangTai = true

    private let nhip = 0.05

    private var tin: Tin? { ds.indices.contains(chiSo) ? ds[chiSo] : nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let tin {
                anhNen(tin)
                    .ignoresSafeArea()

                // Hai lớp mờ trên/dưới: ảnh sáng thì chữ trắng và thanh tiến độ
                // biến mất hoàn toàn nếu không có nền tối đỡ phía sau.
                VStack {
                    LinearGradient(colors: [.black.opacity(0.55), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 160)
                    Spacer()
                    if tin.caption?.isEmpty == false {
                        LinearGradient(colors: [.clear, .black.opacity(0.6)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 180)
                    }
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    thanhTienDo
                    dauTrang(tin)
                    Spacer()
                    if let c = tin.caption, !c.isEmpty {
                        Text(c)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.bottom, 40)
                    }
                }

                vungCham
            } else if dangTai {
                ProgressView().tint(.white)
            }
        }
        .task { await tai() }
        .onReceive(Timer.publish(every: nhip, on: .main, in: .common).autoconnect()) { _ in
            chay()
        }
        .statusBarHiddenNeuCo()
    }

    // MARK: Các mảnh

    private var thanhTienDo: some View {
        HStack(spacing: 3) {
            ForEach(ds.indices, id: \.self) { i in
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.35))
                        Capsule().fill(.white)
                            .frame(width: g.size.width * (i < chiSo ? 1 : i == chiSo ? tienDo : 0))
                    }
                }
                .frame(height: 2.5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    private func dauTrang(_ t: Tin) -> some View {
        HStack(spacing: 10) {
            UserAvatarView(url: t.user?.avatarUrl, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(t.tenNguoi)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(t.conLai)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
            }
            Spacer()
            Button {
                dongLai()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, 10)
    }

    @ViewBuilder
    private func anhNen(_ t: Tin) -> some View {
        if let u = t.mediaUrl, let url = URL(string: u) {
            if t.laVideo {
                VideoPlayer(player: AVPlayer(url: url))
            } else {
                AsyncImage(url: url) { pha in
                    if let img = try? pha.image {
                        img.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        ProgressView().tint(.white)
                    }
                }
            }
        } else {
            // Tin chỉ có chữ: nền là màu người đăng chọn.
            (t.backgroundColor.flatMap { Color(hexChuoi: $0) } ?? AppColors.primary)
        }
    }

    /// Nửa trái lùi, nửa phải tới. Giữ thì tạm dừng — ảnh có chữ dài mà cứ 5
    /// giây tự chạy thì không ai đọc kịp.
    private var vungCham: some View {
        HStack(spacing: 0) {
            Color.clear.contentShape(Rectangle())
                .onTapGesture { lui() }
            Color.clear.contentShape(Rectangle())
                .onTapGesture { toi() }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in tamDung = true }
                .onEnded { _ in tamDung = false }
        )
    }

    // MARK: Điều khiển

    private func tai() async {
        ds = [tinDauTien]
        // Lấy đủ tin của người đó; hỏng thì vẫn xem được tin đầu.
        if let day: [Tin] = try? await APIClient.shared
            .request(.layTinCuaNguoi(userId: tinDauTien.userId)), !day.isEmpty {
            ds = day
            chiSo = day.firstIndex { $0.id == tinDauTien.id } ?? 0
        }
        dangTai = false
        await danhDau()
    }

    private func chay() {
        guard !tamDung, !dangTai, let tin else { return }
        tienDo += nhip / tin.soGiay
        if tienDo >= 1 { toi() }
    }

    private func toi() {
        tienDo = 0
        if chiSo < ds.count - 1 {
            chiSo += 1
            Task { await danhDau() }
        } else {
            dongLai()
            dismiss()
        }
    }

    private func lui() {
        tienDo = 0
        if chiSo > 0 { chiSo -= 1 }
    }

    private func danhDau() async {
        guard let t = tin, !t.laCuaToi else { return }
        // Đánh dấu đã xem là việc phụ — hỏng thì kệ, đừng chặn màn hình.
        _ = try? await APIClient.shared.send(.danhDauDaXemTin(storyId: t.id))
    }
}
