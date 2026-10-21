import SwiftUI
import UIKit

// MARK: - Màn khởi động động của app CuongThai (21/10/2026)
//
// Nối tiếp màn tĩnh (LaunchScreen.storyboard: logo 120pt giữa nền `NenKhoiDong`) — khung đầu tiên Y HỆT nó, nên
// không có cú "nháy" giữa hai màn:
//   0,15–0,6 s   logo thu nhỏ, trượt xuống thành dấu cạnh chữ "CuongThai"
//   0,3–0,9 s    gấu trúc Bip ngoi lên (lò xo, nảy nhẹ) — "ló đầu"
//   0,85–1,6 s   Bip vẫy (đung đưa quanh chân, tắt dần) + bong bóng "Xin chào!"
//   0,75–1,2 s   chữ "CuongThai" + khẩu hiệu trượt lên
//   thoát        PHÓNG XUYÊN qua Bip (to dần phủ màn) + mờ ⇒ lộ màn bên dưới
// Không âm thanh (app chính không có âm thương hiệu, và không dùng giọng nói). Mốc thoát: `LichKhoiDong`
// (Shared/ChuyenDong) — khôi phục phiên sớm ⇒ thoát ngay khi đã hiện đủ; chậm ⇒ đợi tới trần. Chạm ⇒ bỏ qua.

enum KhoiDongApp {
    static let lich = LichKhoiDong(toiThieu: 1.3, tuNhien: 1.65, tran: 2.2, thoat: 0.4)
    static let lichGiam = LichKhoiDong(toiThieu: 0.5, tuNhien: 0.8, tran: 1.5, thoat: 0.25)

    /// Không dựng khi chạy kiểm thử, màn thử `CT_XEM_MAN` (trừ `CT_XEM_KHOIDONG=1`), hoặc `CT_KHONG_KHOIDONG=1`.
    static func nenHien(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        if env["XCTestConfigurationFilePath"] != nil { return false }
        if env["CT_KHONG_KHOIDONG"] == "1" { return false }
        #if DEBUG
        if let m = env["CT_XEM_MAN"], !m.isEmpty, env["CT_XEM_KHOIDONG"] != "1" { return false }
        #endif
        return true
    }
}

struct ManKhoiDongApp: View {
    let khoiPhucXong: Bool
    let xong: () -> Void

    @Environment(\.accessibilityReduceMotion) private var giam
    @Environment(\.colorScheme) private var cheDo
    @StateObject private var dieuPhoi: DieuPhoiKhoiDong

    init(khoiPhucXong: Bool, xong: @escaping () -> Void) {
        self.khoiPhucXong = khoiPhucXong
        self.xong = xong
        _dieuPhoi = StateObject(wrappedValue: DieuPhoiKhoiDong(
            lich: UIAccessibility.isReduceMotionEnabled ? KhoiDongApp.lichGiam : KhoiDongApp.lich))
    }

    var body: some View {
        TimelineView(.animation) { _ in
            let t = dieuPhoi.t
            let e = dieuPhoi.lich.tienDoThoat(batDau: dieuPhoi.mocThoat, t: t)
            canh(t: t, e: e)
                .opacity(1 - DuongCong.doan(e, giam ? 0 : 0.45, 1))
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { dieuPhoi.boQua() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "CuongThai"))
        .accessibilityHint(Text(T("Chạm hai lần để bỏ qua")))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { dieuPhoi.boQua() }
        .accessibilityIdentifier("khoiDong")
        .onAppear {
            dieuPhoi.chay { xong() }
            if khoiPhucXong { dieuPhoi.baoKhoiPhucXong() }
        }
        .onChange(of: khoiPhucXong) { _, moi in if moi { dieuPhoi.baoKhoiPhucXong() } }
        .onDisappear { dieuPhoi.dung() }
    }

    /// Vùng an toàn đáy của cửa sổ (màn này `ignoresSafeArea` nên GeometryReader báo 0).
    private static var dayAnToan: CGFloat {
        let w = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first }.first
        return w?.safeAreaInsets.bottom ?? 0
    }

    private func canh(t: Double, e: Double) -> some View {
        GeometryReader { g in
            let cx = g.size.width / 2
            let cy = g.size.height / 2
            let coBip = min(210, max(150, min(g.size.width, g.size.height) * 0.44))
            let bipY = cy - 40
            let hangY = cy + coBip * 0.5 + 34
            ZStack {
                Color("NenKhoiDong")
                quang(t: t, g: g.size)
                if giam { tinh(cx: cx, cy: cy, coBip: coBip, bipY: bipY, hangY: hangY, t: t, e: e) }
                else { dong(cx: cx, cy: cy, coBip: coBip, bipY: bipY, hangY: hangY, t: t, e: e) }
                // Chữ chân của LaunchScreen.storyboard (13pt, xám 50%, cách đáy vùng an toàn 30pt) — giữ đúng chỗ rồi mờ đi,
                // để khung đầu khớp màn tĩnh, không "nháy".
                Text(verbatim: "cuongthai.com")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(white: 0.5))
                    .opacity(1 - DuongCong.doan(t, 0.1, 0.4))
                    .position(x: cx, y: g.size.height - Self.dayAnToan - 30 - 8)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }

    private func quang(t: Double, g: CGSize) -> some View {
        let p = giam ? 1 : DuongCong.ra(DuongCong.doan(t, 0.1, 0.9))
        let toi = cheDo == .dark
        return ZStack {
            Circle().fill(AppColors.primary.opacity(toi ? 0.32 : 0.16))
                .frame(width: g.width * 0.95).blur(radius: 90)
                .offset(x: -g.width * 0.3, y: -g.height * 0.28)
            Circle().fill(AppColors.brandPink.opacity(toi ? 0.24 : 0.12))
                .frame(width: g.width * 0.85).blur(radius: 90)
                .offset(x: g.width * 0.34, y: g.height * 0.3)
        }
        .opacity(p)
    }

    /// Giảm chuyển động: mọi thứ ở chỗ cuối, chỉ hiện mờ dần.
    private func tinh(cx: CGFloat, cy: CGFloat, coBip: CGFloat, bipY: CGFloat, hangY: CGFloat, t: Double, e: Double) -> some View {
        let p = DuongCong.doan(t, 0, 0.3)
        return ZStack {
            Image("LinhVatBip").resizable().scaledToFit().frame(height: coBip)
                .position(x: cx, y: bipY)
            hangChu(t: 2, cx: cx, hangY: hangY, coLogo: 44)
            Image("AppLogo").resizable().scaledToFit().frame(width: 44, height: 44)
                .position(x: cx - 98, y: hangY)
        }
        .opacity(p)
    }

    private func dong(cx: CGFloat, cy: CGFloat, coBip: CGFloat, bipY: CGFloat, hangY: CGFloat, t: Double, e: Double) -> some View {
        // Logo: từ giữa màn 120pt (khớp LaunchScreen) ⇒ dấu 44pt cạnh chữ.
        let pl = DuongCong.vaoRa(DuongCong.doan(t, 0.15, 0.6))
        let coLogo = 120 - (120 - 44) * pl
        let logoX = cx - 98 * pl
        let logoY = cy + (hangY - cy) * pl
        // Bip ngoi lên: lò xo theo trục dọc.
        let ngoi = CGFloat(DuongCong.loXo(t - 0.3, tanSo: 11, giam: 6.5))
        let bipYNow = bipY + (1 - ngoi) * coBip * 0.75
        let tW = t - 0.85
        let vay = tW > 0 ? 8 * sin(tW * 11) * exp(-tW * 2.2) : 0
        let hienBip = DuongCong.doan(t, 0.3, 0.45)
        let bong = CGFloat(DuongCong.loXo(t - 0.95, tanSo: 14, giam: 8))
        let phong = 1 + 10 * DuongCong.vao(e)
        return ZStack {
            Image("LinhVatBip").resizable().scaledToFit().frame(height: coBip)
                .rotationEffect(.degrees(vay), anchor: .bottom)
                .opacity(hienBip)
                .scaleEffect(phong, anchor: .center)
                .position(x: cx, y: bipYNow)
                .zIndex(1)
            // Bong bóng "Xin chào!"
            Text(T("Xin chào!"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(AppColors.brandGradient))
                .scaleEffect(max(0.01, bong), anchor: .bottomLeading)
                .opacity(t > 0.95 ? 1 - DuongCong.doan(e, 0, 0.3) : 0)
                .position(x: cx + coBip * 0.42, y: bipY - coBip * 0.5)
            hangChu(t: t, cx: cx, hangY: hangY, coLogo: 44)
                .opacity(1 - DuongCong.doan(e, 0, 0.3))
            Image("AppLogo").resizable().scaledToFit().frame(width: coLogo, height: coLogo)
                .opacity(1 - DuongCong.doan(e, 0, 0.3))
                .position(x: logoX, y: logoY)
        }
    }

    private func hangChu(t: Double, cx: CGFloat, hangY: CGFloat, coLogo: CGFloat) -> some View {
        let p1 = DuongCong.ra(DuongCong.doan(t, 0.75, 1.05))
        let p2 = DuongCong.ra(DuongCong.doan(t, 0.9, 1.2))
        return ZStack {
            Text(verbatim: "CuongThai")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.brandGradient)
                .opacity(p1)
                .offset(y: 16 * (1 - p1))
                .position(x: cx + 26, y: hangY)
            Text(T("Học, kết nối và lớn lên mỗi ngày."))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .opacity(p2)
                .offset(y: 12 * (1 - p2))
                .position(x: cx, y: hangY + 42)
        }
    }
}
