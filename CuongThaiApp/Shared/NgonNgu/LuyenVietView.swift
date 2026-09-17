import SwiftUI

// ════════════════════════════════════════════════════════════════
// LUYỆN VIẾT BẰNG NGÓN TAY
//
// Người học viết từng nét lên ô vuông; app đối chiếu với ĐƯỜNG TIM của nét
// đó rồi cho qua hoặc bắt viết lại. Đây là chỗ điện thoại hơn hẳn web —
// trên web phải rê chuột, ở đây là viết bằng ngón tay như viết thật.
// ════════════════════════════════════════════════════════════════

struct LuyenVietView: View {
    let chu: String
    let phienAm: String?
    let lang: String

    @Environment(\.dismiss) private var dismiss
    @State private var net: NetChu?
    @State private var dangTai = true
    @State private var netHienTai = 0
    @State private var dangVe: [CGPoint] = []
    @State private var sai = false
    @State private var soLanSai = 0
    @State private var xong = false
    @State private var hienGoiY = false
    @State private var rung: CGFloat = 0

    /// Ô vuông viết. Cố định theo bề ngang màn để nét vẽ và đường tim luôn
    /// cùng một hệ toạ độ — đo lệch một chút là chấm sai hết.
    private var canh: CGFloat { min(UIScreen.main.bounds.width - 48, 340) }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                thanhDau

                if dangTai {
                    Spacer(); ProgressView(); Spacer()
                } else if let n = net {
                    Spacer(minLength: 0)
                    oViet(n)
                        .offset(x: rung)
                    thanhTien(n)
                    Spacer(minLength: 0)
                    nutDuoi(n)
                } else {
                    Spacer()
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "scribble.variable")
                            .font(.system(size: 38))
                            .foregroundColor(AppColors.textTertiary)
                        Text("Chữ này chưa có dữ liệu nét viết.")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .task { await tai() }
    }

    // ── Ô viết ──────────────────────────────────────────────────
    private func oViet(_ n: NetChu) -> some View {
        ZStack {
            // Khung + đường kẻ chia tư, như vở tập viết.
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard)
            Path { p in
                p.move(to: CGPoint(x: canh/2, y: 0)); p.addLine(to: CGPoint(x: canh/2, y: canh))
                p.move(to: CGPoint(x: 0, y: canh/2)); p.addLine(to: CGPoint(x: canh, y: canh/2))
            }
            .stroke(AppColors.divider, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

            // Chữ mờ phía sau làm mẫu.
            ForEach(0..<n.soNet, id: \.self) { i in
                // Vẽ theo ĐÚNG loại dữ liệu — xem `NetChu.laDuongTim`.
                if n.laDuongTim {
                    DuongSVG.doi(n.strokes[i], canh: canh)
                        .stroke(i < netHienTai
                                ? AppColors.primary
                                : AppColors.textPrimary.opacity(0.09),
                                style: StrokeStyle(lineWidth: n.beDayNet(canh: canh),
                                                   lineCap: .round, lineJoin: .round))
                } else {
                    DuongSVG.doi(n.strokes[i], canh: canh)
                        .fill(i < netHienTai
                              ? AppColors.primary                       // nét đã viết đúng
                              : AppColors.textPrimary.opacity(0.09))    // nét chưa tới
                }
            }

            // Gợi ý đường đi của nét ĐANG viết — chỉ hiện khi người dùng xin,
            // hoặc sau khi sai hai lần. Hiện sẵn thì thành tô lại chứ không
            // còn là nhớ mặt chữ nữa.
            if hienGoiY || soLanSai >= 2, netHienTai < n.soNet {
                let tim = n.duongTim(netHienTai, canh: canh)
                if tim.count > 1 {
                    Path { p in
                        p.move(to: tim[0])
                        for q in tim.dropFirst() { p.addLine(to: q) }
                    }
                    .stroke(AppColors.accent.opacity(0.8),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 6]))
                    // Chấm tròn ở ĐIỂM BẮT ĐẦU: thứ tự nét thì đường kẻ nói
                    // được, còn viết từ đầu nào thì không.
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 13, height: 13)
                        .position(tim[0])
                }
            }

            // Nét ngón tay đang vẽ.
            if dangVe.count > 1 {
                Path { p in
                    p.move(to: dangVe[0])
                    for q in dangVe.dropFirst() { p.addLine(to: q) }
                }
                .stroke(sai ? AppColors.error : AppColors.secondary,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: canh, height: canh)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if sai { return }
                    dangVe.append(g.location)
                }
                .onEnded { _ in ketThucNet(n) }
        )
    }

    private func thanhTien(_ n: NetChu) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<n.soNet, id: \.self) { i in
                Capsule()
                    .fill(i < netHienTai ? AppColors.primary : AppColors.backgroundTertiary)
                    .frame(height: 4)
            }
        }
        .frame(width: canh)
    }

    private var thanhDau: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Đóng")
            Spacer()
            VStack(spacing: 1) {
                Text(xong ? "Viết xong!" : "Viết chữ \(chu)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                if let pa = phienAm {
                    Text(pa).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, Spacing.sm)
    }

    private func nutDuoi(_ n: NetChu) -> some View {
        HStack(spacing: Spacing.md) {
            if xong {
                Button {
                    netHienTai = 0; xong = false; soLanSai = 0; hienGoiY = false
                } label: {
                    Text("Viết lại")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Capsule().fill(AppColors.primary))
                }
            } else {
                Button {
                    hienGoiY.toggle(); Haptics.cham()
                } label: {
                    Label(hienGoiY ? "Ẩn gợi ý" : "Gợi ý",
                          systemImage: hienGoiY ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill(AppColors.backgroundTertiary))
                }
                Button {
                    // Bỏ qua nét này. Có lối thoát thì người dùng không bị
                    // kẹt cứng ở một nét khó rồi bỏ luôn cả bài.
                    sangNet(n)
                } label: {
                    Label("Bỏ qua nét", systemImage: "forward")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill(AppColors.backgroundTertiary))
                }
            }
        }
        .frame(width: canh)
        .padding(.bottom, Spacing.lg)
    }

    // ── Chấm một nét ────────────────────────────────────────────
    private func ketThucNet(_ n: NetChu) {
        defer { dangVe = [] }
        guard netHienTai < n.soNet, dangVe.count > 2 else { return }
        let tim = n.duongTim(netHienTai, canh: canh)
        guard tim.count > 1 else { sangNet(n); return }

        if ChamNet.dat(nguoiVe: dangVe, duongTim: tim, canh: canh) {
            sangNet(n)
        } else {
            soLanSai += 1
            sai = true
            Haptics.hong()
            // Lắc ngang: báo sai mà không cần chữ, và không cướp chỗ trên màn.
            withAnimation(.default) {
                rung = 9
            }
            Task { @MainActor in
                for (i, x) in [-9.0, 7.0, -5.0, 0.0].enumerated() {
                    try? await Task.sleep(for: .milliseconds(i == 0 ? 55 : 50))
                    withAnimation(.linear(duration: 0.05)) { rung = x }
                }
                sai = false
            }
        }
    }

    private func sangNet(_ n: NetChu) {
        soLanSai = 0
        hienGoiY = false
        Haptics.cham()
        withAnimation(.easeOut(duration: 0.2)) {
            netHienTai += 1
            if netHienTai >= n.soNet {
                xong = true
                Haptics.xong()
            }
        }
    }

    private func tai() async {
        dangTai = true
        net = await KhoNetChu.shared.lay(chu, lang: lang)
        dangTai = false
    }
}
