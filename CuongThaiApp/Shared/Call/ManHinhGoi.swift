import SwiftUI

// ════════════════════════════════════════════════════════════════
// MÀN HÌNH GỌI THOẠI
//
// Nền tối cố định cho cả hai chế độ sáng/tối — đây là màn chiếm trọn máy,
// không phải một khối trong trang, nên nó không đi theo theme của app.
// ⚠️ Nền cố định thì chữ cũng phải ghi màu cố định: dùng
// `AppColors.textPrimary` ở đây là chữ đen trên nền đen ở chế độ sáng.
// ════════════════════════════════════════════════════════════════

struct ManHinhGoi: View {
    @ObservedObject var goi: CuocGoi
    let anhBenKia: String?

    @State private var tatMic = false
    @State private var loa = true
    /// Nhịp đập của vòng avatar lúc đang đổ chuông.
    @State private var dapNhip = false

    private let chuChinh = Color.white
    private let chuPhu = Color.white.opacity(0.66)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1B1230), Color(hex: 0x070710)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                ZStack {
                    if goi.trangThai == .dangGoi || goi.trangThai == .doChuong {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 2)
                            .frame(width: 168, height: 168)
                            .scaleEffect(dapNhip ? 1.22 : 1)
                            .opacity(dapNhip ? 0 : 1)
                            .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false),
                                       value: dapNhip)
                    }
                    UserAvatarView(url: anhBenKia, size: 132)
                }
                .frame(height: 176)

                Text(goi.tenBenKia)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundColor(chuChinh)
                    .padding(.top, Spacing.md)

                Text(dongTrangThai)
                    .font(.system(size: 16))
                    .foregroundColor(chuPhu)
                    .monospacedDigit()
                    .padding(.top, Spacing.xs)

                if let loi = goi.loi {
                    Text(loi)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0xFF8A8A))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.top, Spacing.sm)
                }

                Spacer()

                nutDieuKhien
                    .padding(.bottom, 56)
            }
        }
        .onAppear { dapNhip = true }
    }

    private var dongTrangThai: String {
        switch goi.trangThai {
        case .dangGoi: return "Đang gọi…"
        case .doChuong: return "Cuộc gọi thoại đến"
        case .dangNoi: return dinhDangGiay(goi.giay)
        case .roi: return "Đã kết thúc"
        }
    }

    /// `1:05` chứ không phải `65 giây`. Đồng hồ phải giống đồng hồ.
    private func dinhDangGiay(_ g: Int) -> String {
        String(format: "%d:%02d", g / 60, g % 60)
    }

    @ViewBuilder
    private var nutDieuKhien: some View {
        if goi.trangThai == .doChuong {
            HStack(spacing: 72) {
                NutTron(icon: "phone.down.fill", nen: Color(hex: 0xE5484D), nhan: "Từ chối") {
                    goi.tuChoi()
                }
                NutTron(icon: "phone.fill", nen: Color(hex: 0x2BA84A), nhan: "Nhận") {
                    Task { await goi.nhan() }
                }
            }
        } else {
            VStack(spacing: Spacing.xl) {
                HStack(spacing: Spacing.xl) {
                    NutTron(icon: tatMic ? "mic.slash.fill" : "mic.fill",
                            nen: tatMic ? Color.white.opacity(0.92) : Color.white.opacity(0.16),
                            mauIcon: tatMic ? Color(hex: 0x14141C) : .white,
                            cd: 62,
                            nhan: tatMic ? "Đã tắt tiếng" : "Tắt tiếng") {
                        tatMic.toggle()
                        goi.tatMicro(tatMic)
                    }

                    NutTron(icon: loa ? "speaker.wave.2.fill" : "iphone",
                            nen: loa ? Color.white.opacity(0.92) : Color.white.opacity(0.16),
                            mauIcon: loa ? Color(hex: 0x14141C) : .white,
                            cd: 62,
                            nhan: loa ? "Loa ngoài" : "Loa trong") {
                        loa.toggle()
                        goi.doiLoa(loa)
                    }
                }

                NutTron(icon: "phone.down.fill", nen: Color(hex: 0xE5484D), nhan: "Kết thúc") {
                    goi.cupMay()
                }
            }
        }
    }
}

private struct NutTron: View {
    let icon: String
    let nen: Color
    var mauIcon: Color = .white
    var cd: CGFloat = 74
    let nhan: String
    let bam: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Button(action: bam) {
                Image(systemName: icon)
                    .font(.system(size: cd * 0.36, weight: .medium))
                    .foregroundColor(mauIcon)
                    .frame(width: cd, height: cd)
                    .background(Circle().fill(nen))
            }
            .buttonStyle(.plain)

            Text(nhan)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.6))
        }
        // Đọc màn hình phải nói được nút này làm gì — nhãn chữ bên dưới là
        // trang trí, VoiceOver cần nhãn thật trên chính nút.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(nhan)
        .accessibilityAddTraits(.isButton)
    }
}
