import SwiftUI

// MARK: - Gấu trúc Bip — linh vật của app CuongThai (21/10/2026)
//
// Ảnh `LinhVatBip` (Resources/Assets.xcassets, lấy từ web `frontend/public/mascots/bip.png` — Bip vẫy tay).
// Dùng ở: hero màn đăng nhập, lớp "Đang đăng nhập…", màn khởi động động (iOS/KhoiDong/ManKhoiDongApp.swift).
// Chuyển động đều tôn trọng "Giảm chuyển động".

/// Bip vẫy tay: cả hình đung đưa quanh chân (không có khớp tay riêng — ảnh phẳng), chu kỳ thong thả.
struct BipVayTay: View {
    var co: CGFloat = 150
    @Environment(\.accessibilityReduceMotion) private var giam
    @State private var lac = false

    var body: some View {
        Image("LinhVatBip")
            .resizable()
            .scaledToFit()
            .frame(height: co)
            .rotationEffect(.degrees(giam ? 0 : (lac ? 4 : -3)), anchor: .bottom)
            .onAppear {
                guard !giam else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { lac = true }
            }
            .accessibilityHidden(true)
    }
}

/// Bip nhảy tưng tưng + bóng dưới chân co giãn — lớp "Đang đăng nhập…".
struct BipNhay: View {
    var co: CGFloat = 96
    @Environment(\.accessibilityReduceMotion) private var giam

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            // Nửa sin tuyệt đối = nảy; ép dẹt nhẹ lúc chạm đất.
            let pha = abs(sin(t * .pi / 0.55))
            let cao = giam ? 0 : CGFloat(pha) * co * 0.16
            let dep = giam ? 1 : 1 - 0.06 * CGFloat(1 - pha)
            VStack(spacing: 0) {
                Image("LinhVatBip")
                    .resizable()
                    .scaledToFit()
                    .frame(height: co)
                    .scaleEffect(x: 2 - dep, y: dep, anchor: .bottom)
                    .offset(y: -cao)
                Ellipse()
                    .fill(Color.black.opacity(0.14))
                    .frame(width: co * (0.62 - 0.18 * CGFloat(pha)), height: co * 0.08)
                    .offset(y: -co * 0.04)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Hero màn đăng nhập: Bip vẫy tay giữa vài chip học tập lơ lửng + dấu thương hiệu góc trên trái.
struct HeroDangNhapBip: View {
    let gon: Bool
    @Environment(\.colorScheme) private var cheDo

    var body: some View {
        GeometryReader { g in
            let co = gon ? min(96, g.size.height * 0.7) : min(178, g.size.height * 0.72)
            let cx = g.size.width * 0.55
            let kep = { (x: CGFloat) in min(max(x, 70), g.size.width - 70) }
            ZStack {
                Circle().fill(Color.white.opacity(cheDo == .dark ? 0.07 : 0.6))
                    .frame(width: co * 1.45, height: co * 1.45).blur(radius: 28)
                    .position(x: cx, y: g.size.height * 0.6)
                BipVayTay(co: co)
                    .noiLoLung(bienDo: 4, chuKy: 3.8)
                    .position(x: cx, y: g.size.height * 0.6)
                if !gon {
                    ChipNoi(bieuTuong: "book.fill", chu: T("Bài học mới"), mau: AppColors.primary)
                        .noiLoLung(bienDo: 7, chuKy: 3.0, lech: 0.3)
                        .position(x: kep(cx - co * 0.85), y: g.size.height * 0.36)
                    ChipNoi(bieuTuong: "flame.fill", chu: T("Chuỗi 7 ngày"), mau: Color(red: 0.95, green: 0.45, blue: 0.1))
                        .noiLoLung(bienDo: 6, chuKy: 3.5, lech: 0.7)
                        .position(x: kep(cx + co * 0.78), y: g.size.height * 0.28)
                    ChipNoi(bieuTuong: "star.fill", chu: "+20 EXP", mau: Color(red: 0.95, green: 0.7, blue: 0.1))
                        .noiLoLung(bienDo: 6, chuKy: 2.8, lech: 0.1)
                        .position(x: kep(cx + co * 0.72), y: g.size.height * 0.86)
                }
                HStack(spacing: 8) {
                    Image("AppLogo").resizable().scaledToFit().frame(width: 30, height: 30)
                        .padding(3)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white))
                    Text(verbatim: "CuongThai")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.brandGradient)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "CuongThai"))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 24)
                .padding(.top, 8)
            }
        }
    }
}
