import SwiftUI

// ════════════════════════════════════════════════════════════════
// NỀN MÙA — lớp nền loang + hạt rơi + trang trí 4 góc, vẽ bằng `Canvas` trong `TimelineView`.
//
// Hiệu năng (đo ở báo cáo 23/10/2026):
//   · trần 30 khung/giây (`minimumInterval`), Canvas vẽ KHÔNG đồng bộ (`rendersAsynchronously`) — không chiếm
//     luồng chính lúc cuộn;
//   · hạt KHÔNG có trạng thái: vị trí = hàm của (chỉ số, thời gian) ⇒ mỗi khung không cập nhật @State nào,
//     SwiftUI không dựng lại cây view — chỉ Canvas vẽ lại;
//   · dừng hẳn (timeline `paused`) khi: màn không hiện, app ra nền/khoá màn, Giảm chuyển động, Chế độ nguồn
//     điện thấp, công tắc Hiệu ứng động tắt, hoặc đang có màn đọc dài (`.nenMuaYen()`). Dừng thì vẫn vẽ một
//     khung tĩnh đẹp (hạt rải sẵn) — không phải nền trống.
// ════════════════════════════════════════════════════════════════

enum KieuNen {
    /// Màn chính: đủ nền loang + hạt + trang trí góc.
    case trangChinh
    /// Thanh bên iPad: nền loang + một trang trí nhỏ ở đáy, không hạt (chữ menu nằm thẳng trên nền).
    case thanhBen
    /// Thẻ xem trước ở Cài đặt.
    case xemThu
    /// Lớp phủ thưa ở MÉP các màn con (vẽ TRÊN nội dung, không nhận chạm).
    case phuMoiTrang
}

/// Đọc cài đặt + môi trường rồi quyết có chạy hay đứng yên. Dùng cho mọi chỗ trong app (trừ thẻ xem trước).
struct NenMuaTuDong: View {
    let kieu: KieuNen
    /// `false` ở màn TIÊU ĐỀ LỚN (Học, Tất cả tính năng): bỏ trang trí dải trên (cành hoa, đèn, mây, đèn dây) vì
    /// chữ tiêu đề lớn nằm đúng dải đó.
    var tren = true
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong
    @Environment(\.scenePhase) private var pha
    @State private var dangHien = false

    var body: some View {
        let ql = QuanLyChuDe.shared
        GeometryReader { g in
            NenMua(mua: ql.mua, kieu: kieu, matDo: ql.matDo, trangTri: ql.trangTriGoc, tren: tren,
                   chay: dangHien && ql.dongDuoc && !giamChuyenDong && pha == .active,
                   vungAnToan: g.safeAreaInsets)
                .ignoresSafeArea()
        }
        .onAppear { dangHien = true }
        .onDisappear { dangHien = false }
    }
}

struct NenMua: View {
    let mua: Mua?
    var kieu: KieuNen = .trangChinh
    var matDo: MatDoHat = .vua
    var trangTri = true
    var tren = true
    var chay = true
    var vungAnToan = EdgeInsets()

    var body: some View {
        ZStack {
            if kieu != .phuMoiTrang { NenLoang(mua: mua) }
            if mua != nil {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !chay)) { tl in
                    Canvas(rendersAsynchronously: true) { ctx, co in
                        // Đứng yên ⇒ một thời điểm cố định (hạt rải đều, đèn sáng vừa) thay vì "khung lúc dừng".
                        let t = chay ? tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 36_000) : 1_234.5
                        VeMua(but: ButVe(ctx: ctx), co: co, t: CGFloat(t), mua: mua!, kieu: kieu,
                              matDo: matDo, trangTri: trangTri, tren: tren, an: vungAnToan, chay: chay).ve()
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Lớp nền loang tĩnh: màu nền + dải màu trên→dưới + quầng sáng góc trên phải. Chế độ sáng nhờ lớp này mà
/// không còn là "nền trắng phẳng".
struct NenLoang: View {
    let mua: Mua?
    var body: some View {
        let m = BoMauTrangTri.cua(mua)
        ZStack {
            BangMauChuDe.cua(mua).backgroundPrimary
            LinearGradient(stops: [.init(color: m.nenTren, location: 0),
                                   .init(color: m.nenGiua.opacity(0), location: 0.42),
                                   .init(color: m.nenGiua.opacity(0), location: 0.70),
                                   .init(color: m.nenDuoi, location: 1)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [m.quang, m.quang.opacity(0)], center: UnitPoint(x: 0.92, y: 0.02),
                           startRadius: 0, endRadius: 420)
        }
    }
}

// MARK: - Bộ vẽ

struct VeMua {
    let but: ButVe
    let co: CGSize
    let t: CGFloat
    let mua: Mua
    let kieu: KieuNen
    let matDo: MatDoHat
    let trangTri: Bool
    let tren: Bool
    let an: EdgeInsets
    let chay: Bool

    private var w: CGFloat { co.width }
    private var h: CGFloat { co.height }
    /// Hệ số cỡ trang trí theo màn (iPhone ≈ 0,95, iPad ≈ 1,3; thẻ xem trước nhỏ hơn).
    private var k: CGFloat {
        if kieu == .xemThu { return max(0.42, min(w, h) / 300) }
        return min(max(min(w, h) / 410, 0.85), 1.3)
    }
    private var mau: BoMauTrangTri { BoMauTrangTri.cua(mua) }

    func ve() {
        if kieu == .trangChinh || kieu == .xemThu { veSauHat() }
        if kieu != .thanhBen { veHat() }
        if trangTri, kieu == .trangChinh || kieu == .xemThu { veGoc() }
        if kieu == .thanhBen { veDayThanhBen() }
    }

    // MARK: Hạt rơi

    private var soHat: Int {
        switch kieu {
        case .xemThu: return 5 + matDo.rawValue * 3
        case .thanhBen: return 0
        case .trangChinh, .phuMoiTrang:
            let dienTich = min(max(Double(w * h) / (390 * 844), 1), 2.2)
            let n = Double(matDo.soHatCoSo) * dienTich
            return Int(kieu == .phuMoiTrang ? n * 0.4 : n)
        }
    }

    private func veHat() {
        let n = soHat
        guard n > 0 else { return }
        let ds = mau.hat
        let tiLe: CGFloat = kieu == .xemThu ? 0.6 : 1
        for i in 0..<n {
            let r1 = ngauNhien(i, 1), r2 = ngauNhien(i, 2), r3 = ngauNhien(i, 3)
            let r4 = ngauNhien(i, 4), r5 = ngauNhien(i, 5), r6 = ngauNhien(i, 6)
            let len = mua == .ha                         // hạ: bong bóng/nắng bay LÊN
            let vanToc = (mua == .dong ? 16 + r2 * 22 : 20 + r2 * 26) * (kieu == .xemThu ? 0.55 : 1)
            let bien: CGFloat = 30
            let quang = h + bien * 2
            var y = (r3 * quang + t * vanToc).truncatingRemainder(dividingBy: quang) - bien
            if len { y = h - y }

            // Phân bố ngang: lớp phủ chỉ ở MÉP (né cột nội dung), màn chính rải đều rồi làm mờ vùng giữa.
            var x0 = r1 * w
            if kieu == .phuMoiTrang {
                let mep = min(w * 0.12, 70)
                x0 = r1 < 0.5 ? an.leading + r1 * 2 * mep : w - an.trailing - (r1 - 0.5) * 2 * mep
            }
            let lac = sin(t * (0.35 + r4 * 0.55) + r5 * 6.28) * (8 + r6 * 20) * tiLe
            let x = x0 + lac
            let goc = t * (0.25 + r4 * 0.8) * (r5 > 0.5 ? 1 : -1) + r6 * 6.28

            // Độ mờ: vùng giữa (nơi nội dung) mờ hơn; lớp phủ còn mờ dần về đáy (thanh tab).
            let lechGiua = abs(x / max(w, 1) - 0.5) * 2
            var doMo: Double
            switch kieu {
            case .trangChinh: doMo = Double(0.40 + 0.60 * tronTru(0.15, 0.85, lechGiua)) * 0.9
            case .phuMoiTrang:
                doMo = 0.55 * Double(1 - tronTru(h * 0.55, h - an.bottom - 20, y) * 0.9)
            default: doMo = 0.9
            }
            let mauHat = ds[i % ds.count]
            let s = (7 + r2 * 9) * tiLe

            switch mua {
            case .xuan:
                if i % 3 == 0 {
                    but.to(HinhMua.hoa5, mauHat, tam: CGPoint(x: x, y: y), co: s * 1.35, goc: goc, doMo: doMo)
                    but.tron(CGPoint(x: x, y: y), s * 0.16, Color.h(0xE8A317), doMo: doMo)
                } else {
                    but.to(HinhMua.canhHoa, mauHat, tam: CGPoint(x: x, y: y), co: s, goc: goc,
                           latX: max(0.25, abs(cos(goc * 1.3))), doMo: doMo)
                }
            case .thu:
                if i % 2 == 0 {
                    let lat = cos(goc * 1.2)
                    but.to(HinhMua.laPhong, mauHat, tam: CGPoint(x: x, y: y), co: s * 1.7, goc: goc,
                           latX: abs(lat) < 0.2 ? (lat < 0 ? -0.2 : 0.2) : lat, doMo: doMo)
                } else {
                    but.to(HinhMua.canhHoa, Color.h(0xF4A7BE), tam: CGPoint(x: x, y: y), co: s * 0.95, goc: goc,
                           latX: max(0.25, abs(cos(goc * 1.4))), doMo: doMo)
                }
            case .dong:
                if i % 4 == 0 {
                    but.net(HinhMua.bongTuyet, mauHat, tam: CGPoint(x: x, y: y), co: s * 1.7, goc: goc * 0.4,
                            day: 1.4 * tiLe, doMo: doMo)
                } else {
                    but.tron(CGPoint(x: x, y: y), (1.6 + r2 * 2.6) * tiLe, mauHat, doMo: doMo * 0.95)
                }
            case .ha:
                if i % 3 == 0 {
                    // lấp lánh nắng — nhấp nháy
                    let nhay = Double(0.35 + 0.65 * abs(sin(t * 1.6 + r5 * 6)))
                    but.to(HinhMua.lapLanh, mau.hat[2 % ds.count], tam: CGPoint(x: x, y: y), co: s * 1.1,
                           goc: 0, doMo: doMo * nhay)
                } else {
                    let r = (3 + r2 * 5) * tiLe
                    var c = but.ctx
                    c.opacity = doMo * 0.9
                    let o = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    c.stroke(Path(ellipseIn: o), with: .color(mauHat), lineWidth: 1.2)
                    c.fill(Path(ellipseIn: o.insetBy(dx: r * 0.55, dy: r * 0.55).offsetBy(dx: -r * 0.3, dy: -r * 0.3)),
                           with: .color(Color.white.opacity(0.85)))
                }
            }
        }
    }

    // MARK: Lớp sau hạt (pháo hoa, mây, sóng, đèn dây…) — chỉ màn chính + xem trước

    private func veSauHat() {
        switch mua {
        case .xuan: veXuanSau()
        case .ha: veHaSau()
        case .thu: veThuSau()
        case .dong: veDongSau()
        }
    }

    private var dinh: CGFloat { kieu == .xemThu ? 0 : an.top }
    private var day: CGFloat { kieu == .xemThu ? h : h - an.bottom }

    // MARK: Xuân

    private func veXuanSau() {
        guard kieu == .trangChinh, chay else { return }
        // Pháo hoa nhẹ — mỗi 7 giây một chùm, chỉ ở nửa trên.
        let chuKy: CGFloat = 7
        let lan = Int(t / chuKy)
        let tau = t - CGFloat(lan) * chuKy
        guard tau < 2.2 else { return }
        let tam = CGPoint(x: w * (0.22 + 0.56 * ngauNhien(lan, 11)), y: dinh + 30 + ngauNhien(lan, 12) * h * 0.22)
        let mauPhao = [Color.h(0xF5B700), Color.h(0xE53935), Color.h(0xF06292)][lan % 3]
        let tienDo = 1 - pow(1 - min(tau / 1.5, 1), 3)
        let banKinh = 62 * k * tienDo
        let doMo = Double(max(0, 1 - tau / 2.2)) * 0.8
        for j in 0..<16 {
            let g = CGFloat(j) / 16 * .pi * 2
            let d = CGPoint(x: tam.x + cos(g) * banKinh, y: tam.y + sin(g) * banKinh + tau * tau * 6)
            but.tron(d, 2.3 * k, mauPhao, doMo: doMo)
            but.tron(CGPoint(x: tam.x + cos(g) * banKinh * 0.6, y: tam.y + sin(g) * banKinh * 0.6 + tau * tau * 4),
                     1.3 * k, mauPhao, doMo: doMo * 0.6)
        }
    }

    // MARK: Hạ

    private func veHaSau() {
        // Mây trôi ở dải thanh tiêu đề (cao hơn dòng chào/ngày — mây trắng sau chữ xám là chìm chữ ở nền tối).
        for j in 0..<2 where tren {
            let rong = (j == 0 ? 120 : 90) * k
            let vt = (t * (6 + CGFloat(j) * 3) + CGFloat(j) * 340).truncatingRemainder(dividingBy: w + rong * 2) - rong
            let yMay = kieu == .xemThu ? (j == 0 ? 14 : 34) * k : dinh - (j == 0 ? 30 : 12) * k
            but.to(HinhMua.may, Color.theoCheDo(sang: .white, toi: Color.white.opacity(0.35)), tam: CGPoint(x: vt, y: yMay),
                   co: rong * (kieu == .xemThu ? 1 : 0.8), doMo: kieu == .xemThu ? 0.85 : 0.8)
        }
        // Hải âu bay ngang mỗi 18 giây.
        if kieu == .trangChinh, tren {
            let chuKy: CGFloat = 18
            let tau = t.truncatingRemainder(dividingBy: chuKy)
            if tau < 11 {
                for j in 0..<2 {
                    let x = -40 + (w + 80) * (tau - CGFloat(j) * 0.6) / 11
                    let y = dinh + 90 * k + sin(tau * 1.1 + CGFloat(j)) * 10 + CGFloat(j) * 18
                    but.net(HinhMua.haiAu(vo: sin(t * 7 + CGFloat(j))), Color.h(0x3A4E5C), tam: CGPoint(x: x, y: y),
                            co: (22 - CGFloat(j) * 5) * k, day: 2, doMo: 0.75)
                }
            }
        }
        // Sóng ở đáy màn.
        let mauSong: [(Color, Double)] = [(Color.h(0x9FD9F0), 0.55), (Color.h(0x5DBBE3), 0.50), (Color.h(0x2C93CB), 0.50)]
        for (j, (m, a)) in mauSong.enumerated() {
            let cao = (kieu == .xemThu ? 10 : 22) + CGFloat(j) * (kieu == .xemThu ? 5 : 11) * k
            let goc0 = h - cao
            var p = Path()
            p.move(to: CGPoint(x: 0, y: h))
            var x: CGFloat = 0
            while x <= w + 12 {
                let y = goc0 + sin(x / (46 * k) + t * (0.8 + CGFloat(j) * 0.25) + CGFloat(j) * 1.7) * (3 + CGFloat(j)) * k
                p.addLine(to: CGPoint(x: x, y: y))
                x += 12
            }
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
            var c = but.ctx
            c.opacity = a
            c.fill(p, with: .color(m))
        }
    }

    // MARK: Thu

    private func veThuSau() {
        guard tren else { return }
        // Trăng rằm góc trên phải (đằng sau mọi thứ).
        let r = 24 * k
        let tam = kieu == .xemThu ? CGPoint(x: w - 34 * k, y: 30 * k)
                                  : CGPoint(x: w - an.trailing - 170 * k, y: dinh + 24 * k)
        var c = but.ctx
        c.fill(Path(ellipseIn: CGRect(x: tam.x - r * 2.2, y: tam.y - r * 2.2, width: r * 4.4, height: r * 4.4)),
               with: .radialGradient(Gradient(colors: [Color.h(0xFFE9B0).opacity(0.55), Color.h(0xFFE9B0).opacity(0)]),
                                     center: tam, startRadius: r * 0.8, endRadius: r * 2.2))
        c.fill(Path(ellipseIn: CGRect(x: tam.x - r, y: tam.y - r, width: r * 2, height: r * 2)),
               with: .radialGradient(Gradient(colors: [Color.h(0xFFF1C4), Color.h(0xF4C95D)]),
                                     center: CGPoint(x: tam.x - r * 0.3, y: tam.y - r * 0.3), startRadius: 1, endRadius: r * 1.3))
        c.opacity = 0.35
        c.fill(Path(ellipseIn: CGRect(x: tam.x - r * 0.45, y: tam.y - r * 0.3, width: r * 0.42, height: r * 0.36)), with: .color(Color.h(0xE8C47E)))
        c.fill(Path(ellipseIn: CGRect(x: tam.x + r * 0.15, y: tam.y + r * 0.2, width: r * 0.3, height: r * 0.26)), with: .color(Color.h(0xE8C47E)))
    }

    // MARK: Đông

    private func veDongSau() {
        if tren { veDenDay() }
        veTuyetDong()
    }

    private func veDenDay() {
        // Đèn dây chăng ở dải thanh tiêu đề, nhấp nháy — CHỪA khoảng giữa (nơi tiêu đề màn) để dây không cắt qua chữ.
        let y0 = kieu == .xemThu ? 6 : max(an.top - 44, 6)
        let vong = (kieu == .xemThu ? 10 : 12) * k
        let giua = (an.leading + w - an.trailing) / 2
        let chua: CGFloat = kieu == .xemThu ? 0 : 84
        let doanDay: [(CGFloat, CGFloat)] = chua == 0 ? [(-10, w + 10)] : [(an.leading - 10, giua - chua), (giua + chua, w + 10)]
        let mauDen = [Color.h(0xE53935), Color.h(0xF9C74F), Color.h(0x43A047), Color.h(0x42A5F5)]
        var i = 0
        for (dau, cuoi) in doanDay where cuoi - dau > 40 {
            let doan = max(1, Int((cuoi - dau) / (150 * k)))
            let rong = (cuoi - dau) / CGFloat(doan)
            var day = Path()
            day.move(to: CGPoint(x: dau, y: y0))
            for j in 0..<doan {
                let a = dau + CGFloat(j) * rong, b = a + rong
                day.addQuadCurve(to: CGPoint(x: b, y: y0), control: CGPoint(x: (a + b) / 2, y: y0 + vong * 2))
            }
            var c = but.ctx
            c.opacity = 0.6
            c.stroke(day, with: .color(Color.h(0x2F4F3A)), lineWidth: 1.4)
            let soBong = max(2, Int(rong / (32 * k)))
            for j in 0..<doan {
                for q in 1..<soBong {
                    let u = CGFloat(q) / CGFloat(soBong)
                    let x = dau + (CGFloat(j) + u) * rong
                    let y = y0 + vong * 2 * u * (1 - u) * 2 * 0.98 + 1
                    let nhay = chay ? Double(0.45 + 0.55 * (0.5 + 0.5 * sin(t * 2.4 + CGFloat(i) * 1.9))) : 0.9
                    let m = mauDen[i % mauDen.count]
                    but.tron(CGPoint(x: x, y: y + 3 * k), 7 * k, m, doMo: nhay * 0.25)
                    var b = but.ctx
                    b.opacity = nhay
                    b.fill(Path(roundedRect: CGRect(x: x - 2.6 * k, y: y, width: 5.2 * k, height: 7.5 * k), cornerRadius: 2.6 * k),
                           with: .color(m))
                    i += 1
                }
            }
        }
    }

    private func veTuyetDong() {
        // Tuyết đọng ở đáy.
        var p = Path()
        let cao = (kieu == .xemThu ? 10 : 20) * k
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: h - cao))
        p.addCurve(to: CGPoint(x: w * 0.55, y: h - cao * 0.7), control1: CGPoint(x: w * 0.18, y: h - cao * 1.9),
                   control2: CGPoint(x: w * 0.36, y: h - cao * 0.2))
        p.addCurve(to: CGPoint(x: w, y: h - cao * 1.2), control1: CGPoint(x: w * 0.72, y: h - cao * 1.3),
                   control2: CGPoint(x: w * 0.88, y: h - cao * 1.6))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        var s = but.ctx
        s.fill(p, with: .color(Color.theoCheDo(sang: Color.white, toi: Color.h(0xDCE8F7).opacity(0.85))))
        s.stroke(p, with: .color(Color.h(0x9DBDE3).opacity(0.6)), lineWidth: 1)
    }

    // MARK: Trang trí 4 góc

    private func veGoc() {
        // Trên màn chính, hai góc TRÊN nằm dưới thanh tiêu đề (trong suốt khi chưa cuộn) — trang trí treo từ mép
        // trên, né cụm nút bên phải 64pt; hai góc DƯỚI đứng ngay trên thanh tab / vạch Home.
        // iPadOS 26: cột chi tiết kéo dài DƯỚI thanh bên nổi ⇒ phải cộng lề an toàn trái/phải, không thì trang trí
        // góc trái nằm khuất sau thanh bên.
        let xTrai: CGFloat = kieu == .xemThu ? 4 : an.leading + 6
        let xPhai = w - (kieu == .xemThu ? 4 : an.trailing + 6)
        switch mua {
        case .xuan:
            if tren {
                canhHoa(goc: CGPoint(x: xTrai - 8 * k, y: dinh - 38 * k), latNgang: false,
                        mauHoa: Color.h(0xF48FB1), mauNhuy: Color.h(0xC2185B))
                denLong(CGPoint(x: xPhai - 160 * k, y: dinh - 4), day: 26 * k, pha: 0)
                denLong(CGPoint(x: xPhai - 116 * k, y: dinh - 4), day: 44 * k, pha: 1.7)
            }
            baoLiXi(CGPoint(x: xTrai + 30 * k, y: day - 30 * k))
            canhHoa(goc: CGPoint(x: xPhai + 8 * k, y: day + 4 * k), latNgang: true, mauHoa: Color.h(0xF7C531),
                    mauNhuy: Color.h(0xC77800), huongLen: true)
        case .ha:
            if tren { matTroi(CGPoint(x: xPhai - 140 * k, y: dinh + 22 * k)) }
            oBaiBien(CGPoint(x: xTrai + 44 * k, y: day - 4 * k))
            bongBien(CGPoint(x: xPhai - 46 * k, y: h - 30 * k))
        case .thu:
            if tren {
                canhHoa(goc: CGPoint(x: xTrai - 8 * k, y: dinh - 38 * k), latNgang: false,
                        mauHoa: Color.h(0xF8BBD0), mauNhuy: Color.h(0xD81B60))
                denOngSao(CGPoint(x: xPhai - 96 * k, y: dinh - 4), day: 34 * k)
            }
            dongLa(CGPoint(x: xTrai + 40 * k, y: day - 8 * k))
            canhPhong(CGPoint(x: xPhai - 20 * k, y: day))
        case .dong:
            cayThong(CGPoint(x: xTrai + 46 * k, y: day - 2 * k))
            nguoiTuyet(CGPoint(x: xPhai - 96 * k, y: day - 4 * k))
            chimCanhCut(CGPoint(x: xPhai - 40 * k, y: day - 2 * k))
            if kieu == .trangChinh, tren {
                but.net(HinhMua.bongTuyet, Color.h(0x7FA8D8), tam: CGPoint(x: xPhai - 130 * k, y: dinh + 34 * k),
                        co: 30 * k, goc: t * 0.15, day: 2, doMo: 0.5)
            }
        }
    }

    private func veDayThanhBen() {
        guard trangTri else { return }
        let goc = CGPoint(x: w - 50 * k, y: h - an.bottom - 8)
        switch mua {
        case .xuan: baoLiXi(CGPoint(x: goc.x, y: goc.y - 24 * k))
        case .ha: oBaiBien(goc)
        case .thu: dongLa(goc)
        case .dong: chimCanhCut(goc)
        }
    }

    // MARK: Hình trang trí (toạ độ cục bộ, gốc ở điểm neo)

    /// Cành hoa từ một góc vào trong. `latNgang` = mọc từ phải sang trái; `huongLen` = mọc lên (góc dưới).
    private func canhHoa(goc: CGPoint, latNgang: Bool, mauHoa: Color, mauNhuy: Color, huongLen: Bool = false) {
        let lac = chay ? sin(t * 0.9) * 0.02 : 0
        but.cum(goc, k: k, xoay: lac) { b in
            var c = b.ctx
            c.scaleBy(x: latNgang ? -1 : 1, y: huongLen ? -1 : 1)
            let cb = ButVe(ctx: c)
            // Cành NÔNG (cao ≤ 40pt cục bộ) — nằm gọn trong dải thanh tiêu đề, không chạm lời chào bên dưới.
            var than = Path()
            than.move(to: CGPoint(x: 0, y: 0))
            than.addCurve(to: CGPoint(x: 150, y: 26), control1: CGPoint(x: 50, y: 4), control2: CGPoint(x: 100, y: 30))
            cb.duong(than, Color.h(0x6B4226), 4.5)
            var nhanh = Path()
            nhanh.move(to: CGPoint(x: 70, y: 14)); nhanh.addQuadCurve(to: CGPoint(x: 100, y: -4), control: CGPoint(x: 86, y: 12))
            nhanh.move(to: CGPoint(x: 112, y: 24)); nhanh.addQuadCurve(to: CGPoint(x: 132, y: 38), control: CGPoint(x: 120, y: 34))
            cb.duong(nhanh, Color.h(0x6B4226), 2.6)
            let hoa: [(CGFloat, CGFloat, CGFloat)] = [(38, 6, 20), (76, 16, 24), (100, -4, 18), (132, 38, 16),
                                                       (150, 26, 22), (58, 10, 13), (118, 22, 14)]
            for (j, (x, y, s)) in hoa.enumerated() {
                let tam = CGPoint(x: x, y: y)
                cb.to(HinhMua.hoa5, mauHoa, tam: tam, co: s, goc: CGFloat(j) * 0.7)
                cb.tron(tam, s * 0.13, mauNhuy)
            }
            cb.tron(CGPoint(x: 90, y: 20), 3.2, mauHoa)   // nụ
            cb.tron(CGPoint(x: 140, y: 34), 2.8, mauHoa)
        }
    }

    private func denLong(_ neo: CGPoint, day: CGFloat, pha: CGFloat) {
        let xoay = chay ? sin(t * 1.2 + pha) * 0.07 : 0.03
        but.cum(neo, k: k, xoay: xoay) { b in
            let L = day / k
            var soi = Path(); soi.move(to: .zero); soi.addLine(to: CGPoint(x: 0, y: L))
            b.duong(soi, Color.h(0x8D6E63), 1.2)
            b.hcn(CGRect(x: -8, y: L, width: 16, height: 5), Color.h(0xE0A800), bo: 1.5)
            var thanDen = b.ctx
            thanDen.fill(Path(ellipseIn: CGRect(x: -16, y: L + 4, width: 32, height: 34)),
                         with: .radialGradient(Gradient(colors: [Color.h(0xFF5A4E), Color.h(0xC62828)]),
                                               center: CGPoint(x: -3, y: L + 16), startRadius: 2, endRadius: 22))
            b.ctx.stroke(Path(ellipseIn: CGRect(x: -8, y: L + 4, width: 16, height: 34)), with: .color(Color.h(0x9E1B1B).opacity(0.6)), lineWidth: 1)
            b.hcn(CGRect(x: -8, y: L + 36, width: 16, height: 5), Color.h(0xE0A800), bo: 1.5)
            var tua = Path()
            for dx in [-3, 0, 3] as [CGFloat] { tua.move(to: CGPoint(x: dx, y: L + 41)); tua.addLine(to: CGPoint(x: dx * 1.3, y: L + 56)) }
            b.duong(tua, Color.h(0xE53935), 1.6)
        }
    }

    private func baoLiXi(_ tam: CGPoint) {
        but.cum(tam, k: k, xoay: -0.18) { b in
            b.hcn(CGRect(x: -15, y: -21, width: 30, height: 42), Color.h(0xD32F2F), bo: 4)
            var nap = Path()
            nap.move(to: CGPoint(x: -15, y: -17)); nap.addQuadCurve(to: CGPoint(x: 15, y: -17), control: CGPoint(x: 0, y: -2))
            nap.addLine(to: CGPoint(x: 15, y: -21)); nap.addLine(to: CGPoint(x: -15, y: -21)); nap.closeSubpath()
            b.ctx.fill(nap, with: .color(Color.h(0xA51C1C)))
            b.tron(CGPoint(x: 0, y: 3), 7, Color.h(0xF5C542))
            b.ctx.stroke(Path(ellipseIn: CGRect(x: -4.5, y: -1.5, width: 9, height: 9)), with: .color(Color.h(0xC62828)), lineWidth: 1.2)
        }
        but.cum(CGPoint(x: tam.x + 26 * k, y: tam.y + 6 * k), k: k * 0.8, xoay: 0.22) { b in
            b.hcn(CGRect(x: -15, y: -21, width: 30, height: 42), Color.h(0xE53935), bo: 4)
            b.tron(CGPoint(x: 0, y: 3), 7, Color.h(0xF5C542))
        }
    }

    private func matTroi(_ tam: CGPoint) {
        let quay = chay ? t * 0.12 : 0.2
        but.cum(tam, k: k) { b in
            var q = b.ctx
            q.fill(Path(ellipseIn: CGRect(x: -64, y: -64, width: 128, height: 128)),
                   with: .radialGradient(Gradient(colors: [Color.h(0xFFD54F).opacity(0.55), Color.h(0xFFD54F).opacity(0)]),
                                         center: .zero, startRadius: 18, endRadius: 64))
            var tia = b.ctx
            tia.rotate(by: .radians(quay))
            for j in 0..<12 {
                let g = CGFloat(j) / 12 * .pi * 2
                var p = Path()
                p.move(to: CGPoint(x: cos(g - 0.12) * 28, y: sin(g - 0.12) * 28))
                p.addLine(to: CGPoint(x: cos(g) * (j % 2 == 0 ? 44 : 38), y: sin(g) * (j % 2 == 0 ? 44 : 38)))
                p.addLine(to: CGPoint(x: cos(g + 0.12) * 28, y: sin(g + 0.12) * 28))
                p.closeSubpath()
                tia.fill(p, with: .color(Color.h(0xFFB300).opacity(0.85)))
            }
            b.ctx.fill(Path(ellipseIn: CGRect(x: -24, y: -24, width: 48, height: 48)),
                       with: .radialGradient(Gradient(colors: [Color.h(0xFFF3B0), Color.h(0xFFC107)]),
                                             center: CGPoint(x: -6, y: -6), startRadius: 2, endRadius: 30))
        }
    }

    private func oBaiBien(_ goc: CGPoint) {
        but.cum(goc, k: k) { b in
            b.elip(CGRect(x: -60, y: -12, width: 130, height: 30), Color.h(0xF3D9A4))
            var can = Path(); can.move(to: CGPoint(x: 0, y: 4)); can.addLine(to: CGPoint(x: 8, y: -60))
            b.duong(can, Color.h(0x8D6E63), 2.4)
            // tán ô: 4 múi đỏ/trắng
            let tam = CGPoint(x: 8, y: -60)
            for j in 0..<4 {
                var p = Path()
                p.move(to: tam)
                let a0 = CGFloat.pi + CGFloat(j) * .pi / 4 - 0.12, a1 = a0 + .pi / 4
                p.addArc(center: tam, radius: 40, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
                p.closeSubpath()
                var c = b.ctx
                c.rotate(by: .radians(0.12))
                c.fill(p, with: .color(j % 2 == 0 ? Color.h(0xE53935) : Color.h(0xFFF8E1)))
            }
            b.to(HinhMua.saoBien, Color.h(0xFF8A50), tam: CGPoint(x: 40, y: -2), co: 16, goc: 0.3)
        }
    }

    private func bongBien(_ tam: CGPoint) {
        let nhun = chay ? sin(t * 1.5) * 3 : 0
        but.cum(CGPoint(x: tam.x, y: tam.y + nhun), k: k, xoay: chay ? sin(t * 0.8) * 0.2 : 0) { b in
            let r: CGFloat = 14
            let mauM = [Color.h(0xE53935), Color.h(0xFFFFFF), Color.h(0x1E88E5), Color.h(0xFFFFFF), Color.h(0xFDD835), Color.h(0xFFFFFF)]
            for j in 0..<6 {
                var p = Path()
                p.move(to: .zero)
                p.addArc(center: .zero, radius: r, startAngle: .radians(Double(j) * .pi / 3),
                         endAngle: .radians(Double(j + 1) * .pi / 3), clockwise: false)
                p.closeSubpath()
                b.ctx.fill(p, with: .color(mauM[j]))
            }
            b.ctx.stroke(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(Color.black.opacity(0.15)), lineWidth: 1)
        }
    }

    private func denOngSao(_ neo: CGPoint, day: CGFloat) {
        let xoay = chay ? sin(t * 1.1) * 0.08 : 0.04
        but.cum(neo, k: k, xoay: xoay) { b in
            let L = day / k
            var soi = Path(); soi.move(to: .zero); soi.addLine(to: CGPoint(x: 0, y: L))
            b.duong(soi, Color.h(0x8D6E63), 1.2)
            let tam = CGPoint(x: 0, y: L + 16)
            var q = b.ctx
            q.fill(Path(ellipseIn: CGRect(x: tam.x - 28, y: tam.y - 28, width: 56, height: 56)),
                   with: .radialGradient(Gradient(colors: [Color.h(0xFFD54F).opacity(0.5), Color.h(0xFFD54F).opacity(0)]),
                                         center: tam, startRadius: 6, endRadius: 28))
            b.to(HinhMua.sao, Color.h(0xF9C846), tam: tam, co: 34)
            b.net(HinhMua.sao, Color.h(0xD84315), tam: tam, co: 34, day: 1.4)
            b.tron(tam, 4, Color.h(0xE53935))
            var tua = Path()
            tua.move(to: CGPoint(x: -4, y: L + 30)); tua.addLine(to: CGPoint(x: -6, y: L + 44))
            tua.move(to: CGPoint(x: 4, y: L + 30)); tua.addLine(to: CGPoint(x: 6, y: L + 44))
            b.duong(tua, Color.h(0xE53935), 1.6)
        }
    }

    private func dongLa(_ goc: CGPoint) {
        but.cum(goc, k: k) { b in
            let la: [(CGFloat, CGFloat, CGFloat, CGFloat, UInt32)] = [
                (-34, -6, 26, -0.6, 0xC94A2C), (-8, -10, 30, 0.2, 0xE0662A), (20, -6, 26, 0.9, 0xE8A33A),
                (-20, -22, 24, -0.2, 0xD9572B), (8, -26, 22, 0.5, 0xF0A030), (40, -4, 20, 1.4, 0xC94A2C),
            ]
            for (x, y, s, g, m) in la {
                b.to(HinhMua.laPhong, Color.h(m), tam: CGPoint(x: x, y: y), co: s, goc: g)
                b.net(HinhMua.ganLa, Color.h(0x7A2E12).opacity(0.5), tam: CGPoint(x: x, y: y), co: s, goc: g, day: 0.8)
            }
        }
    }

    private func canhPhong(_ goc: CGPoint) {
        let lac = chay ? sin(t * 0.9 + 1) * 0.03 : 0
        but.cum(goc, k: k, xoay: lac) { b in
            var than = Path()
            than.move(to: CGPoint(x: 10, y: 6)); than.addQuadCurve(to: CGPoint(x: -40, y: -96), control: CGPoint(x: -6, y: -50))
            b.duong(than, Color.h(0x6B4226), 3.5)
            let la: [(CGFloat, CGFloat, CGFloat, CGFloat, UInt32)] = [(-40, -100, 28, -0.4, 0xE0662A),
                                                                     (-18, -62, 24, -1.1, 0xC94A2C),
                                                                     (-8, -34, 22, 0.8, 0xE8A33A)]
            for (x, y, s, g, m) in la {
                b.to(HinhMua.laPhong, Color.h(m), tam: CGPoint(x: x, y: y), co: s, goc: g)
                b.net(HinhMua.ganLa, Color.h(0x7A2E12).opacity(0.5), tam: CGPoint(x: x, y: y), co: s, goc: g, day: 0.8)
            }
        }
    }

    private func cayThong(_ goc: CGPoint) {
        but.cum(goc, k: k) { b in
            b.hcn(CGRect(x: -6, y: -14, width: 12, height: 14), Color.h(0x6D4C41), bo: 2)
            let xanh = [Color.h(0x2E7D32), Color.h(0x388E3C), Color.h(0x43A047)]
            b.tamGiac(CGPoint(x: 0, y: -66), CGPoint(x: -42, y: -14), CGPoint(x: 42, y: -14), xanh[0])
            b.tamGiac(CGPoint(x: 0, y: -88), CGPoint(x: -34, y: -42), CGPoint(x: 34, y: -42), xanh[1])
            b.tamGiac(CGPoint(x: 0, y: -108), CGPoint(x: -26, y: -66), CGPoint(x: 26, y: -66), xanh[2])
            let qua: [(CGFloat, CGFloat, UInt32)] = [(-18, -22, 0xE53935), (14, -30, 0xFDD835), (-8, -50, 0x42A5F5),
                                                     (16, -56, 0xE53935), (-6, -78, 0xFDD835), (24, -20, 0x42A5F5)]
            for (j, (x, y, m)) in qua.enumerated() {
                let nhay = chay ? Double(0.6 + 0.4 * sin(t * 2 + CGFloat(j) * 1.3)) : 1
                b.tron(CGPoint(x: x, y: y), 3.6, Color.h(m), doMo: nhay)
            }
            let sang = chay ? 0.85 + 0.15 * sin(t * 3) : 1
            b.to(HinhMua.sao, Color.h(0xFFD54F), tam: CGPoint(x: 0, y: -110), co: 18 * sang, goc: chay ? sin(t) * 0.1 : 0)
        }
    }

    private func nguoiTuyet(_ goc: CGPoint) {
        but.cum(goc, k: k * 0.9) { b in
            let vien = Color.h(0x9DBDE3)
            b.elip(CGRect(x: -18, y: -34, width: 36, height: 34), .white)
            b.ctx.stroke(Path(ellipseIn: CGRect(x: -18, y: -34, width: 36, height: 34)), with: .color(vien), lineWidth: 1.2)
            b.elip(CGRect(x: -13, y: -58, width: 26, height: 26), .white)
            b.ctx.stroke(Path(ellipseIn: CGRect(x: -13, y: -58, width: 26, height: 26)), with: .color(vien), lineWidth: 1.2)
            b.hcn(CGRect(x: -12, y: -38, width: 24, height: 5), Color.h(0x2E7D32), bo: 2.5)
            b.hcn(CGRect(x: -10, y: -64, width: 20, height: 4), Color.h(0x263238), bo: 1)
            b.hcn(CGRect(x: -6.5, y: -76, width: 13, height: 13), Color.h(0x263238), bo: 2)
            b.tron(CGPoint(x: -4.5, y: -48), 1.6, Color.h(0x263238))
            b.tron(CGPoint(x: 4.5, y: -48), 1.6, Color.h(0x263238))
            b.tamGiac(CGPoint(x: 0, y: -45), CGPoint(x: 0, y: -42), CGPoint(x: 9, y: -43), Color.h(0xFB8C00))
            for y in [-26, -18, -10] as [CGFloat] { b.tron(CGPoint(x: 0, y: y), 1.6, Color.h(0x263238)) }
        }
    }

    private func chimCanhCut(_ goc: CGPoint) {
        let lac = chay ? sin(t * 2.2) * 0.07 : 0
        but.cum(goc, k: k, xoay: lac) { b in
            let den = Color.h(0x1F2A36)
            b.elip(CGRect(x: -12, y: -8, width: 11, height: 7), Color.h(0xFB8C00))
            b.elip(CGRect(x: 1, y: -8, width: 11, height: 7), Color.h(0xFB8C00))
            var canhT = b.ctx; canhT.translateBy(x: -19, y: -34); canhT.rotate(by: .radians(0.35))
            canhT.fill(Path(ellipseIn: CGRect(x: -4, y: -12, width: 8, height: 26)), with: .color(den))
            var canhP = b.ctx; canhP.translateBy(x: 19, y: -34); canhP.rotate(by: .radians(-0.35 + (chay ? sin(t * 3) * 0.15 : 0)))
            canhP.fill(Path(ellipseIn: CGRect(x: -4, y: -12, width: 8, height: 26)), with: .color(den))
            b.elip(CGRect(x: -19, y: -64, width: 38, height: 60), den)
            b.elip(CGRect(x: -13, y: -50, width: 26, height: 44), Color.h(0xFAFAFA))
            b.elip(CGRect(x: -12, y: -58, width: 11, height: 12), Color.h(0xFAFAFA))
            b.elip(CGRect(x: 1, y: -58, width: 11, height: 12), Color.h(0xFAFAFA))
            b.tron(CGPoint(x: -5, y: -52), 2.2, den)
            b.tron(CGPoint(x: 5, y: -52), 2.2, den)
            b.tron(CGPoint(x: -4.3, y: -52.8), 0.8, .white)
            b.tron(CGPoint(x: 5.7, y: -52.8), 0.8, .white)
            b.tamGiac(CGPoint(x: -4, y: -47), CGPoint(x: 4, y: -47), CGPoint(x: 0, y: -42), Color.h(0xFB8C00))
            b.tron(CGPoint(x: -10, y: -45), 2.4, Color.h(0xF48FB1), doMo: 0.7)
            b.tron(CGPoint(x: 10, y: -45), 2.4, Color.h(0xF48FB1), doMo: 0.7)
            // khăn quàng đỏ
            b.hcn(CGRect(x: -15, y: -40, width: 30, height: 6), Color.h(0xE53935), bo: 3)
            b.hcn(CGRect(x: 5, y: -37, width: 6, height: 14), Color.h(0xC62828), bo: 2.5)
            // mũ len
            b.tamGiac(CGPoint(x: -14, y: -60), CGPoint(x: 14, y: -60), CGPoint(x: 6, y: -78), Color.h(0xE53935))
            b.hcn(CGRect(x: -15, y: -63, width: 30, height: 5), Color.white, bo: 2.5)
            b.tron(CGPoint(x: 6, y: -79), 3.4, .white)
        }
    }
}
