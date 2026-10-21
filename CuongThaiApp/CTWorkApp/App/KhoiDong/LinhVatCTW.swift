import SwiftUI

// MARK: - Linh vật CT Work (bảng kẹp giấy biết cười) vẽ bằng Path — 21/10/2026
//
// Vẽ lại `Assets › LogoCTWork` (ảnh 384px) thành hình vector trong hệ toạ độ 100×100 để:
//   · màn khởi động VẼ được từng nét (trim 0→1) như bút phát sáng, rồi tô màu;
//   · hero đăng nhập / lớp "đang đăng nhập" phóng to bao nhiêu cũng nét, không kéo thêm ảnh.
// Toạ độ đo từ ảnh gốc (px / 3,84). Đổi logo ⇒ đo lại ở đây.

enum HinhLinhVatCTW {
    /// Đổi toạ độ 0…100 sang khung `r`.
    static func diem(_ x: CGFloat, _ y: CGFloat, _ r: CGRect) -> CGPoint {
        CGPoint(x: r.minX + x / 100 * r.width, y: r.minY + y / 100 * r.height)
    }
    static func khung(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGRect) -> CGRect {
        CGRect(origin: diem(x, y, r), size: CGSize(width: w / 100 * r.width, height: h / 100 * r.height))
    }
    static func ban(_ v: CGFloat, _ r: CGRect) -> CGFloat { v / 100 * r.width }

    static func nen(_ r: CGRect) -> Path {
        Path(roundedRect: r, cornerRadius: ban(22.5, r), style: .continuous)
    }
    static func than(_ r: CGRect) -> Path {
        Path(roundedRect: khung(23, 24, 53, 57, r), cornerRadius: ban(12.5, r), style: .continuous)
    }
    static func kep(_ r: CGRect) -> Path {
        Path(roundedRect: khung(36.5, 17.6, 27.5, 12.6, r), cornerRadius: ban(5.4, r), style: .continuous)
    }
    static func kepTrong(_ r: CGRect) -> Path {
        Path(roundedRect: khung(45, 21.4, 10.2, 3.9, r), cornerRadius: ban(1.95, r), style: .continuous)
    }
    /// Ba gạch đầu bảng: (x bắt đầu, x kết thúc).
    static let gach: [(CGFloat, CGFloat)] = [(32.6, 41.6), (45.6, 54.6), (58.8, 68.0)]
    static func gach(_ i: Int, _ r: CGRect) -> Path {
        var p = Path()
        p.move(to: diem(gach[i].0, 37.2, r))
        p.addLine(to: diem(gach[i].1, 37.2, r))
        return p
    }
    static func mat(_ trai: Bool, _ r: CGRect) -> Path {
        let c = diem(trai ? 41.6 : 57.8, 52, r)
        let rr = ban(4.1, r)
        return Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr * 1.08, width: rr * 2, height: rr * 2.16))
    }
    static func dongMat(_ trai: Bool, _ r: CGRect) -> Path {
        let c = diem(trai ? 42.8 : 59, 50.6, r)
        let rr = ban(1.25, r)
        return Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
    }
    static func ma(_ trai: Bool, _ r: CGRect) -> Path {
        Path(ellipseIn: khung(trai ? 33.1 : 59.1, 59.6, 6.8, 4.2, r))
    }
    static func mieng(_ r: CGRect) -> Path {
        var p = Path()
        p.move(to: diem(45.4, 61.4, r))
        p.addQuadCurve(to: diem(54.2, 61.4, r), control: diem(49.8, 66.6, r))
        return p
    }
    static func huyHieuNgoai(_ r: CGRect) -> Path { Path(ellipseIn: khung(62, 61.5, 26, 26, r)) }
    static func huyHieu(_ r: CGRect) -> Path { Path(ellipseIn: khung(64.4, 63.9, 21.2, 21.2, r)) }
    static func dauTich(_ r: CGRect) -> Path {
        var p = Path()
        p.move(to: diem(69.8, 75.0, r))
        p.addLine(to: diem(73.6, 78.8, r))
        p.addLine(to: diem(80.6, 70.8, r))
        return p
    }
    /// Ngôi sao 4 cánh (lấp lánh) tâm (x, y), bán kính `rr` (đơn vị 0…100).
    static func lapLanh(_ x: CGFloat, _ y: CGFloat, _ rr: CGFloat, _ r: CGRect) -> Path {
        let c = diem(x, y, r)
        let R = ban(rr, r)
        let e = R * 0.26
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - R))
        p.addQuadCurve(to: CGPoint(x: c.x + R, y: c.y), control: CGPoint(x: c.x + e, y: c.y - e))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + R), control: CGPoint(x: c.x + e, y: c.y + e))
        p.addQuadCurve(to: CGPoint(x: c.x - R, y: c.y), control: CGPoint(x: c.x - e, y: c.y + e))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - R), control: CGPoint(x: c.x - e, y: c.y - e))
        p.closeSubpath()
        return p
    }
}

/// Bảng màu của logo (đo từ ảnh gốc).
enum MauLinhVatCTW {
    static let nenTren = Color(red: 0.45, green: 0.85, blue: 0.83)     // xanh ngọc nhạt
    static let nenGiua = Color(red: 0.25, green: 0.66, blue: 0.91)
    static let nenDuoi = Color(red: 0.19, green: 0.47, blue: 0.91)     // xanh dương
    static let kep = Color(red: 0.12, green: 0.43, blue: 0.40)
    static let kepTrong = Color(red: 0.55, green: 0.92, blue: 0.80)
    static let gach: [Color] = [Color(red: 0.25, green: 0.82, blue: 0.75), Color(red: 0.29, green: 0.70, blue: 0.94),
                                Color(red: 0.55, green: 0.56, blue: 0.94)]
    static let mat = Color(red: 0.08, green: 0.15, blue: 0.29)
    static let ma = Color(red: 0.98, green: 0.70, blue: 0.78)
    static let xanhLa = Color(red: 0.13, green: 0.77, blue: 0.37)
    static let vang = Color(red: 1.0, green: 0.82, blue: 0.43)
    static let kem = Color(red: 1.0, green: 0.94, blue: 0.80)
    /// Nét bút khi vẽ (màu CT Work: indigo + xanh ngọc).
    static func butSang(toi: Bool) -> Color { toi ? Color(red: 0.24, green: 0.88, blue: 0.85) : Color(red: 0.06, green: 0.66, blue: 0.66) }
    static func butIndigo(toi: Bool) -> Color { toi ? Color(red: 0.55, green: 0.58, blue: 0.94) : Color(red: 0.31, green: 0.36, blue: 0.84) }
}

/// Linh vật ĐÃ TÔ MÀU (không có hoạt hình riêng) — tham số để người gọi điều khiển từng phần.
struct LinhVatCTWView: View {
    /// Độ hiện của phần tô (0 = trong suốt).
    var to: Double = 1
    /// Tiến độ dấu tích 0…1.
    var tich: Double = 1
    /// Tỉ lệ huy hiệu xanh (nhịp "nảy" khi tích).
    var coHuyHieu: CGFloat = 1
    /// Tỉ lệ hai ngôi sao lấp lánh.
    var saoTo: CGFloat = 1
    var saoNho: CGFloat = 1
    /// Ẩn nền vuông (chỉ còn bảng kẹp — dùng trong hero/lớp chờ).
    var coNen = true

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            if coNen {
                ctx.opacity = to
                ctx.fill(HinhLinhVatCTW.nen(r), with: .linearGradient(
                    Gradient(colors: [MauLinhVatCTW.nenTren, MauLinhVatCTW.nenGiua, MauLinhVatCTW.nenDuoi]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                // Ánh sáng góc trên trái.
                ctx.fill(HinhLinhVatCTW.nen(r), with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.32), .white.opacity(0)]),
                    center: CGPoint(x: size.width * 0.25, y: size.height * 0.08), startRadius: 0, endRadius: size.width * 0.8))
            }
            ctx.opacity = to
            // Thân bảng + bóng mềm.
            var bong = ctx
            bong.addFilter(.shadow(color: Color(red: 0.05, green: 0.2, blue: 0.4).opacity(0.25), radius: size.width * 0.03, y: size.width * 0.015))
            bong.fill(HinhLinhVatCTW.than(r), with: .linearGradient(
                Gradient(colors: [.white, Color(red: 0.91, green: 0.95, blue: 0.99)]),
                startPoint: HinhLinhVatCTW.diem(50, 24, r), endPoint: HinhLinhVatCTW.diem(50, 81, r)))
            ctx.fill(HinhLinhVatCTW.kep(r), with: .color(MauLinhVatCTW.kep))
            ctx.fill(HinhLinhVatCTW.kepTrong(r), with: .color(MauLinhVatCTW.kepTrong))
            let net = StrokeStyle(lineWidth: HinhLinhVatCTW.ban(2.2, r), lineCap: .round)
            for i in 0..<3 { ctx.stroke(HinhLinhVatCTW.gach(i, r), with: .color(MauLinhVatCTW.gach[i]), style: net) }
            for trai in [true, false] {
                ctx.fill(HinhLinhVatCTW.mat(trai, r), with: .color(MauLinhVatCTW.mat))
                ctx.fill(HinhLinhVatCTW.dongMat(trai, r), with: .color(.white))
                ctx.fill(HinhLinhVatCTW.ma(trai, r), with: .color(MauLinhVatCTW.ma.opacity(0.9)))
            }
            ctx.stroke(HinhLinhVatCTW.mieng(r), with: .color(MauLinhVatCTW.mat),
                       style: StrokeStyle(lineWidth: HinhLinhVatCTW.ban(2.1, r), lineCap: .round))

            // Huy hiệu xanh + dấu tích (nảy quanh tâm của nó).
            let tam = HinhLinhVatCTW.diem(75, 74.5, r)
            var hh = ctx
            hh.translateBy(x: tam.x, y: tam.y)
            hh.scaleBy(x: coHuyHieu, y: coHuyHieu)
            hh.translateBy(x: -tam.x, y: -tam.y)
            var bongHH = hh
            bongHH.addFilter(.shadow(color: .black.opacity(0.18), radius: size.width * 0.02, y: size.width * 0.01))
            bongHH.fill(HinhLinhVatCTW.huyHieuNgoai(r), with: .color(.white))
            hh.fill(HinhLinhVatCTW.huyHieu(r), with: .color(MauLinhVatCTW.xanhLa))
            if tich > 0 {
                hh.opacity = 1
                hh.stroke(HinhLinhVatCTW.dauTich(r).trimmedPath(from: 0, to: tich), with: .color(.white),
                          style: StrokeStyle(lineWidth: HinhLinhVatCTW.ban(3.3, r), lineCap: .round, lineJoin: .round))
            }

            // Lấp lánh.
            ve(sao: HinhLinhVatCTW.lapLanh(17, 22.5, 7.2, r), tam: HinhLinhVatCTW.diem(17, 22.5, r), co: saoTo,
               mau: MauLinhVatCTW.vang, ctx: ctx)
            ve(sao: HinhLinhVatCTW.lapLanh(86.5, 20.3, 4.4, r), tam: HinhLinhVatCTW.diem(86.5, 20.3, r), co: saoNho,
               mau: MauLinhVatCTW.kem, ctx: ctx)
        }
        .accessibilityHidden(true)
    }

    private func ve(sao: Path, tam: CGPoint, co: CGFloat, mau: Color, ctx: GraphicsContext) {
        guard co > 0.01 else { return }
        var c = ctx
        c.opacity = 1
        c.translateBy(x: tam.x, y: tam.y)
        c.scaleBy(x: co, y: co)
        c.translateBy(x: -tam.x, y: -tam.y)
        c.fill(sao, with: .color(mau))
    }
}

/// Lớp NÉT VẼ (bút phát sáng) — mỗi phần một tiến độ trim. Dùng trong màn khởi động.
struct NetVeLinhVatCTW: View {
    /// Tiến độ từng nét: nền, thân, kẹp, gạch (3), mắt, miệng, huy hiệu.
    var nen: Double
    var than: Double
    var kep: Double
    var gach: Double
    var mat: Double
    var mieng: Double
    var huyHieu: Double
    var toi: Bool
    /// Độ hiện của cả lớp nét (mờ dần khi tô màu).
    var hien: Double = 1

    /// Khung Canvas = linh vật × `phong`; lề mỗi bên = `le` (tính theo khung Canvas).
    static let phong: CGFloat = 1.3
    static let le: CGFloat = (1 - 1 / 1.3) / 2

    var body: some View {
        Canvas { ctx, size in
            // Vẽ trong khung THU VÀO `NetVeLinhVatCTW.le` mỗi bên — chừa chỗ cho quầng sáng/đầu bút, không bị cắt vuông
            // ở mép Canvas. Người gọi đặt khung lớn hơn linh vật đúng tỉ lệ `NetVeLinhVatCTW.phong`.
            let r = CGRect(origin: .zero, size: size).insetBy(dx: size.width * Self.le, dy: size.height * Self.le)
            let rong = HinhLinhVatCTW.ban(1.6, r)
            let ngoc = MauLinhVatCTW.butSang(toi: toi)
            let indigo = MauLinhVatCTW.butIndigo(toi: toi)
            var dsNet: [(Path, Color)] = []
            func them(_ p: Path, _ tien: Double, _ m: Color) {
                guard tien > 0 else { return }
                dsNet.append((p.trimmedPath(from: 0, to: min(1, tien)), m))
            }
            them(HinhLinhVatCTW.nen(r), nen, indigo)
            them(HinhLinhVatCTW.than(r), than, ngoc)
            them(HinhLinhVatCTW.kep(r), kep, indigo)
            for i in 0..<3 { them(HinhLinhVatCTW.gach(i, r), (gach * 3 - Double(i)), ngoc) }
            them(HinhLinhVatCTW.mat(true, r), mat, indigo)
            them(HinhLinhVatCTW.mat(false, r), mat, indigo)
            them(HinhLinhVatCTW.mieng(r), mieng, ngoc)
            them(HinhLinhVatCTW.huyHieu(r), huyHieu, ngoc)

            ctx.opacity = hien
            // Quầng sáng: cùng nét, dày hơn, làm mờ.
            var quang = ctx
            quang.addFilter(.blur(radius: rong * (toi ? 3.2 : 2.2)))
            for (p, m) in dsNet {
                quang.stroke(p, with: .color(m.opacity(toi ? 0.9 : 0.55)), style: StrokeStyle(lineWidth: rong * 2.6, lineCap: .round))
            }
            for (p, m) in dsNet {
                ctx.stroke(p, with: .color(m), style: StrokeStyle(lineWidth: rong, lineCap: .round, lineJoin: .round))
            }
            // Đầu bút: ở cuối nét nền (nét dài nhất) khi nó đang vẽ, sau đó ở nét thân.
            let dangVe: Path? = (nen > 0 && nen < 1) ? HinhLinhVatCTW.nen(r).trimmedPath(from: 0, to: nen)
                : (than > 0 && than < 1) ? HinhLinhVatCTW.than(r).trimmedPath(from: 0, to: than) : nil
            if let dangVe, let dau = dangVe.currentPoint {
                let R = rong * 2.4
                var sang = ctx
                sang.addFilter(.blur(radius: R * 1.4))
                sang.fill(Path(ellipseIn: CGRect(x: dau.x - R * 1.8, y: dau.y - R * 1.8, width: R * 3.6, height: R * 3.6)),
                          with: .color(ngoc.opacity(0.9)))
                ctx.fill(Path(ellipseIn: CGRect(x: dau.x - R / 2, y: dau.y - R / 2, width: R, height: R)), with: .color(.white))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Lớp "đang đăng nhập": bảng kẹp với ba dòng việc lần lượt được tích, lặp lại.
struct LinhVatTichViecCTW: View {
    @Environment(\.accessibilityReduceMotion) private var giam

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            let t = giam ? 1.1 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8)
            Canvas { ctx, size in
                let r = CGRect(origin: .zero, size: size)
                var bong = ctx
                bong.addFilter(.shadow(color: Color(red: 0.1, green: 0.2, blue: 0.5).opacity(0.22), radius: 8, y: 4))
                bong.fill(HinhLinhVatCTW.than(r), with: .color(.white))
                ctx.fill(HinhLinhVatCTW.kep(r), with: .color(MauLinhVatCTW.kep))
                ctx.fill(HinhLinhVatCTW.kepTrong(r), with: .color(MauLinhVatCTW.kepTrong))
                for i in 0..<3 {
                    let y = 38 + CGFloat(i) * 12.5
                    let o = HinhLinhVatCTW.khung(30, y, 8, 8, r)
                    let p = DuongCong.doan(t, 0.15 + Double(i) * 0.38, 0.4 + Double(i) * 0.38)
                    let oPath = Path(roundedRect: o, cornerRadius: o.width * 0.28)
                    ctx.fill(oPath, with: .color(p > 0 ? MauLinhVatCTW.xanhLa : Color(red: 0.88, green: 0.91, blue: 0.96)))
                    if p > 0 {
                        var tich = Path()
                        tich.move(to: CGPoint(x: o.minX + o.width * 0.22, y: o.midY))
                        tich.addLine(to: CGPoint(x: o.minX + o.width * 0.43, y: o.minY + o.height * 0.72))
                        tich.addLine(to: CGPoint(x: o.minX + o.width * 0.8, y: o.minY + o.height * 0.3))
                        ctx.stroke(tich.trimmedPath(from: 0, to: p), with: .color(.white),
                                   style: StrokeStyle(lineWidth: o.width * 0.16, lineCap: .round, lineJoin: .round))
                    }
                    var dong = Path()
                    dong.move(to: HinhLinhVatCTW.diem(43, y + 4, r))
                    dong.addLine(to: HinhLinhVatCTW.diem(i == 1 ? 62 : 68, y + 4, r))
                    ctx.stroke(dong, with: .color(MauLinhVatCTW.gach[i].opacity(p >= 1 ? 0.45 : 0.9)),
                               style: StrokeStyle(lineWidth: HinhLinhVatCTW.ban(3, r), lineCap: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
