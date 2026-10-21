import SwiftUI

// MARK: - Màn khởi động động của CT Work (21/10/2026)
//
// Sau màn tĩnh của hệ thống (UILaunchScreen = màu `NenKhoiDong`), app phủ màn này lên trên `GocCTW`:
//   0,05–0,88 s  bút phát sáng VẼ linh vật (nền vuông → thân bảng → kẹp → 3 gạch → mắt, miệng → huy hiệu)
//   0,86–1,06 s  tô màu + nhoè sắc (chromatic) thoáng qua, nét vẽ mờ đi
//   1,00 / 1,08  hai ngôi sao lấp lánh bật ra (lò xo)
//   1,05 s       dấu tích xanh "tách" vào + âm "ting! CT Work!" (nếu bật) + rung mềm
//   1,15–1,55 s  chữ "CT Work" + khẩu hiệu trượt lên
//   thoát        PHÓNG VÀO logo (to dần phủ màn) + mờ ⇒ lộ màn đăng nhập / màn chính bên dưới
// Mốc thoát theo `LichKhoiDong` (Shared/ChuyenDong): khôi phục phiên xong sớm ⇒ thoát ngay khi logo hiện đủ;
// chậm ⇒ đợi tối đa tới mốc trần. Chạm bất kỳ đâu ⇒ bỏ qua. Giảm chuyển động ⇒ logo hiện mờ dần, thoát bằng mờ.
// Chế độ tối: nền tối, nét bút sáng kiểu neon (như video mẫu 2) nhưng vẫn bảng màu indigo/ngọc của CT Work.

enum KhoiDongCTW {
    static let lich = LichKhoiDong(toiThieu: 1.5, tuNhien: 1.8, tran: 2.3, thoat: 0.4)
    static let lichGiam = LichKhoiDong(toiThieu: 0.5, tuNhien: 0.8, tran: 1.5, thoat: 0.25)
    /// Mốc dấu tích (đồng bộ âm thanh).
    static let mocTich: Double = 1.05
    static let mocTichGiam: Double = 0.3

    /// Có dựng màn khởi động ở lần mở này không. Không dựng khi: chạy kiểm thử đơn vị (app chủ của test), màn thử
    /// `CT_XEM_MAN` (trừ khi `CT_XEM_KHOIDONG=1`), hoặc `CT_KHONG_KHOIDONG=1`.
    static func nenHien(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        if env["XCTestConfigurationFilePath"] != nil { return false }
        if env["CT_KHONG_KHOIDONG"] == "1" { return false }
        #if DEBUG
        if let m = env["CT_XEM_MAN"], !m.isEmpty, env["CT_XEM_KHOIDONG"] != "1" { return false }
        #endif
        return true
    }
}

struct ManKhoiDongCTW: View {
    /// Khôi phục phiên đã xong (không token / chưa đồng ý / đã có hồ sơ).
    let khoiPhucXong: Bool
    let xong: () -> Void

    @Environment(\.accessibilityReduceMotion) private var giam
    @Environment(\.colorScheme) private var cheDo
    @StateObject private var dieuPhoi: DieuPhoiKhoiDong

    init(khoiPhucXong: Bool, giamChuyenDong: Bool = UIAccessibility.isReduceMotionEnabled, xong: @escaping () -> Void) {
        self.khoiPhucXong = khoiPhucXong
        self.xong = xong
        _dieuPhoi = StateObject(wrappedValue: DieuPhoiKhoiDong(lich: giamChuyenDong ? KhoiDongCTW.lichGiam : KhoiDongCTW.lich))
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
        .onTapGesture { boQua() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "CT Work"))
        .accessibilityHint(Text("Double-tap to skip"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { boQua() }
        .accessibilityIdentifier("khoiDong")
        .onAppear {
            AmThanhCTW.napSan("ctwork")
            dieuPhoi.chay { xong() }   // mốc 0 = khung hình đầu tiên
            if khoiPhucXong { dieuPhoi.baoKhoiPhucXong() }
            let moc = giam ? KhoiDongCTW.mocTichGiam : KhoiDongCTW.mocTich
            Task { @MainActor in
                // Theo ĐỒNG HỒ ẢO của màn (không phải giờ tường) ⇒ "ting" trúng đúng khung hình dấu tích kể cả khi máy nghẽn.
                while dieuPhoi.t < moc && dieuPhoi.mocBoQua == nil { try? await Task.sleep(nanoseconds: 10_000_000) }
                // Đã bỏ qua trước nhịp tích ⇒ im lặng (không "ting" giữa lúc màn đang biến mất).
                guard dieuPhoi.mocBoQua == nil else { return }
                AmThanhCTW.phatKhoiDong()
                RungNhe.mem()
            }
        }
        .onChange(of: khoiPhucXong) { _, moi in if moi { dieuPhoi.baoKhoiPhucXong() } }
        .onDisappear { dieuPhoi.dung() }
    }

    private func boQua() {
        dieuPhoi.boQua()
        if dieuPhoi.t < (giam ? KhoiDongCTW.mocTichGiam : KhoiDongCTW.mocTich) { AmThanhCTW.dung("ctwork") }
    }

    private var toi: Bool { cheDo == .dark }

    @ViewBuilder
    private func canh(t: Double, e: Double) -> some View {
        GeometryReader { g in
            let canhNgan = min(g.size.width, g.size.height)
            let co = min(200, max(132, canhNgan * 0.38))
            ZStack {
                Color("NenKhoiDong")
                quang(t: t, g: g.size)
                VStack(spacing: 22) {
                    linhVat(t: t, e: e, co: co)
                        .frame(width: co, height: co)
                        .scaleEffect(giam ? 1 : 1 + 11 * DuongCong.vao(e))
                        .zIndex(1)
                    chu(t: t)
                        .opacity(1 - DuongCong.doan(e, 0, 0.3))
                }
                .offset(y: -co * 0.12)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }

    /// Hai quầng màu mềm (indigo trên trái, ngọc dưới phải) — tối thì đậm hơn.
    private func quang(t: Double, g: CGSize) -> some View {
        let p = giam ? 1 : DuongCong.ra(DuongCong.doan(t, 0.1, 0.9))
        return ZStack {
            Circle().fill(MauLinhVatCTW.butIndigo(toi: toi).opacity(toi ? 0.35 : 0.18))
                .frame(width: g.width * 0.95).blur(radius: 90)
                .offset(x: -g.width * 0.32, y: -g.height * 0.28)
            Circle().fill(MauLinhVatCTW.butSang(toi: toi).opacity(toi ? 0.3 : 0.16))
                .frame(width: g.width * 0.85).blur(radius: 90)
                .offset(x: g.width * 0.34, y: g.height * 0.3)
        }
        .opacity(p)
    }

    @ViewBuilder
    private func linhVat(t: Double, e: Double, co: CGFloat) -> some View {
        if giam {
            LinhVatCTWView(to: DuongCong.ra(DuongCong.doan(t, 0, 0.3)))
        } else {
            let to = DuongCong.doan(t, 0.86, 1.06)
            let nhoe = 1 - DuongCong.doan(t, 0.86, 1.1)
            let lech = CGFloat(2.6 * sin(t * 95) * nhoe)
            let saoTo = CGFloat(DuongCong.loXo(t - 1.0))
            let saoNho = CGFloat(DuongCong.loXo(t - 1.08))
            let tich = DuongCong.ra(DuongCong.doan(t, KhoiDongCTW.mocTich, KhoiDongCTW.mocTich + 0.2))
            let nay = 1 + 0.16 * sin(.pi * DuongCong.doan(t, KhoiDongCTW.mocTich, KhoiDongCTW.mocTich + 0.28))
            ZStack {
                // Nhoè sắc: hai bản lệch màu ngọc/hồng thoáng qua lúc tô.
                if nhoe > 0 && to > 0 {
                    LinhVatCTWView(to: to * 0.5, tich: 0, saoTo: 0, saoNho: 0)
                        .colorMultiply(Color(red: 0.2, green: 0.95, blue: 1))
                        .offset(x: lech, y: -lech * 0.4)
                        .blendMode(toi ? .plusLighter : .multiply)
                    LinhVatCTWView(to: to * 0.5, tich: 0, saoTo: 0, saoNho: 0)
                        .colorMultiply(Color(red: 1, green: 0.3, blue: 0.75))
                        .offset(x: -lech, y: lech * 0.4)
                        .blendMode(toi ? .plusLighter : .multiply)
                }
                LinhVatCTWView(to: to, tich: tich, coHuyHieu: CGFloat(nay), saoTo: saoTo, saoNho: saoNho)
                NetVeLinhVatCTW(
                    nen: DuongCong.vaoRa(DuongCong.doan(t, 0.05, 0.6)),
                    than: DuongCong.vaoRa(DuongCong.doan(t, 0.18, 0.7)),
                    kep: DuongCong.ra(DuongCong.doan(t, 0.4, 0.72)),
                    gach: DuongCong.doan(t, 0.5, 0.8),
                    mat: DuongCong.ra(DuongCong.doan(t, 0.55, 0.8)),
                    mieng: DuongCong.ra(DuongCong.doan(t, 0.62, 0.84)),
                    huyHieu: DuongCong.ra(DuongCong.doan(t, 0.6, 0.88)),
                    toi: toi,
                    hien: 1 - DuongCong.doan(t, 0.95, 1.15))
                    .frame(width: co * NetVeLinhVatCTW.phong, height: co * NetVeLinhVatCTW.phong)
            }
            .frame(width: co, height: co)
            .shadow(color: MauLinhVatCTW.butIndigo(toi: toi).opacity(0.25 * to), radius: 22, y: 10)
        }
    }

    private func chu(t: Double) -> some View {
        let p1 = giam ? DuongCong.doan(t, 0.15, 0.4) : DuongCong.ra(DuongCong.doan(t, 1.15, 1.45))
        let p2 = giam ? DuongCong.doan(t, 0.2, 0.45) : DuongCong.ra(DuongCong.doan(t, 1.25, 1.55))
        return VStack(spacing: 8) {
            Text(verbatim: "CT Work")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [MauLinhVatCTW.butIndigo(toi: toi), MauLinhVatCTW.butSang(toi: toi)],
                                                startPoint: .leading, endPoint: .trailing))
                .opacity(p1)
                .offset(y: giam ? 0 : 18 * (1 - p1))
            Text("Plan, track and ship together.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .opacity(p2)
                .offset(y: giam ? 0 : 14 * (1 - p2))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }
}
