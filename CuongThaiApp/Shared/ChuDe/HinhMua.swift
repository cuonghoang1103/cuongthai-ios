import SwiftUI

// ════════════════════════════════════════════════════════════════
// HÌNH TỰ VẼ cho chủ đề mùa — toàn bộ là Path, không ảnh, không tài sản bản quyền.
// Mỗi hình dựng một lần (static let) trong hộp đơn vị [-0,5…0,5], lúc vẽ mới tịnh tiến/xoay/phóng.
// ════════════════════════════════════════════════════════════════

enum HinhMua {
    /// Một cánh hoa đào/anh đào: gốc ở dưới (0; 0,5), đầu có khía ở trên.
    static let canhHoa: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.5))
        p.addCurve(to: CGPoint(x: 0.12, y: -0.48), control1: CGPoint(x: 0.40, y: 0.25), control2: CGPoint(x: 0.44, y: -0.32))
        p.addLine(to: CGPoint(x: 0, y: -0.34))
        p.addLine(to: CGPoint(x: -0.12, y: -0.48))
        p.addCurve(to: CGPoint(x: 0, y: 0.5), control1: CGPoint(x: -0.44, y: -0.32), control2: CGPoint(x: -0.40, y: 0.25))
        p.closeSubpath()
        return p
    }()

    /// Hoa 5 cánh (đào, mai, anh đào) — chưa có nhuỵ; nhuỵ vẽ riêng một chấm khác màu.
    static let hoa5: Path = {
        var p = Path()
        for k in 0..<5 {
            let t = CGAffineTransform(rotationAngle: CGFloat(k) * .pi * 2 / 5)
                .translatedBy(x: 0, y: -0.25).scaledBy(x: 0.5, y: 0.5)
            p.addPath(canhHoa.applying(t))
        }
        return p
    }()

    /// Lá phong 5 thuỳ, cuống ở dưới.
    static let laPhong: Path = {
        let phai: [CGPoint] = [
            .init(x: 0, y: -0.5), .init(x: 0.07, y: -0.30), .init(x: 0.17, y: -0.38), .init(x: 0.15, y: -0.17),
            .init(x: 0.40, y: -0.31), .init(x: 0.33, y: -0.12), .init(x: 0.49, y: -0.06), .init(x: 0.30, y: 0.06),
            .init(x: 0.36, y: 0.18), .init(x: 0.14, y: 0.13), .init(x: 0.05, y: 0.24), .init(x: 0.02, y: 0.21),
            .init(x: 0.02, y: 0.5),
        ]
        var p = Path()
        p.move(to: phai[0])
        for d in phai.dropFirst() { p.addLine(to: d) }
        for d in phai.reversed().dropLast() { p.addLine(to: CGPoint(x: -d.x, y: d.y)) }
        p.closeSubpath()
        return p
    }()

    /// Gân lá phong (nét).
    static let ganLa: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.32)); p.addLine(to: CGPoint(x: 0, y: -0.40))
        p.move(to: CGPoint(x: 0, y: 0.08)); p.addLine(to: CGPoint(x: 0.34, y: -0.22))
        p.move(to: CGPoint(x: 0, y: 0.08)); p.addLine(to: CGPoint(x: -0.34, y: -0.22))
        return p
    }()

    /// Bông tuyết 6 cánh (nét).
    static let bongTuyet: Path = {
        var p = Path()
        for k in 0..<6 {
            let g = CGFloat(k) * .pi / 3
            func d(_ r: CGFloat, _ lech: CGFloat = 0) -> CGPoint {
                CGPoint(x: sin(g + lech) * r, y: -cos(g + lech) * r)
            }
            p.move(to: .zero); p.addLine(to: d(0.5))
            let goc = d(0.28)
            p.move(to: goc); p.addLine(to: CGPoint(x: goc.x + sin(g + 0.7) * 0.15, y: goc.y - cos(g + 0.7) * 0.15))
            p.move(to: goc); p.addLine(to: CGPoint(x: goc.x + sin(g - 0.7) * 0.15, y: goc.y - cos(g - 0.7) * 0.15))
        }
        return p
    }()

    /// Ngôi sao lấp lánh 4 cánh.
    static let lapLanh: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -0.5))
        p.addQuadCurve(to: CGPoint(x: 0.5, y: 0), control: CGPoint(x: 0.07, y: -0.07))
        p.addQuadCurve(to: CGPoint(x: 0, y: 0.5), control: CGPoint(x: 0.07, y: 0.07))
        p.addQuadCurve(to: CGPoint(x: -0.5, y: 0), control: CGPoint(x: -0.07, y: 0.07))
        p.addQuadCurve(to: CGPoint(x: 0, y: -0.5), control: CGPoint(x: -0.07, y: -0.07))
        p.closeSubpath()
        return p
    }()

    /// Sao 5 cánh (đèn ông sao, ngọn cây thông).
    static func sao5(trong: CGFloat = 0.42) -> Path {
        var p = Path()
        for k in 0..<10 {
            let r: CGFloat = k % 2 == 0 ? 0.5 : 0.5 * trong
            let g = CGFloat(k) * .pi / 5
            let d = CGPoint(x: sin(g) * r, y: -cos(g) * r)
            if k == 0 { p.move(to: d) } else { p.addLine(to: d) }
        }
        p.closeSubpath()
        return p
    }
    static let sao = sao5()
    static let saoBien = sao5(trong: 0.5)

    /// Hải âu: hai cánh cong. `vo` ∈ [-1; 1] = nhịp vỗ cánh.
    static func haiAu(vo: CGFloat) -> Path {
        var p = Path()
        let y = -0.18 * vo
        p.move(to: CGPoint(x: -0.5, y: y))
        p.addQuadCurve(to: CGPoint(x: 0, y: 0.08), control: CGPoint(x: -0.22, y: -0.32 + y))
        p.addQuadCurve(to: CGPoint(x: 0.5, y: y), control: CGPoint(x: 0.22, y: -0.32 + y))
        return p
    }

    /// Đám mây (ba vòm + đáy phẳng), hộp 1×0,55.
    static let may: Path = {
        var p = Path()
        p.addEllipse(in: CGRect(x: -0.5, y: -0.05, width: 0.42, height: 0.32))
        p.addEllipse(in: CGRect(x: -0.26, y: -0.28, width: 0.50, height: 0.50))
        p.addEllipse(in: CGRect(x: 0.06, y: -0.12, width: 0.44, height: 0.38))
        p.addRoundedRect(in: CGRect(x: -0.42, y: 0.04, width: 0.86, height: 0.24), cornerSize: CGSize(width: 0.12, height: 0.12))
        return p
    }()
}

// MARK: - Bộ vẽ chung

/// Gói ngữ cảnh vẽ + vài tiện ích để các hàm vẽ ngắn gọn.
struct ButVe {
    var ctx: GraphicsContext

    /// Vẽ `path` (hộp đơn vị) tại `tam`, cỡ `co`, xoay `goc` (radian), lật ngang `latX` (−1…1, giả 3D khi lá lộn).
    func to(_ path: Path, _ mau: Color, tam: CGPoint, co: CGFloat, goc: CGFloat = 0, latX: CGFloat = 1, doMo: Double = 1) {
        var c = ctx
        c.opacity = doMo
        c.translateBy(x: tam.x, y: tam.y)
        if goc != 0 { c.rotate(by: .radians(goc)) }
        c.scaleBy(x: co * latX, y: co)
        c.fill(path, with: .color(mau))
    }

    func net(_ path: Path, _ mau: Color, tam: CGPoint, co: CGFloat, goc: CGFloat = 0, day: CGFloat, doMo: Double = 1) {
        var c = ctx
        c.opacity = doMo
        c.translateBy(x: tam.x, y: tam.y)
        if goc != 0 { c.rotate(by: .radians(goc)) }
        c.scaleBy(x: co, y: co)
        c.stroke(path, with: .color(mau), style: StrokeStyle(lineWidth: day / co, lineCap: .round, lineJoin: .round))
    }

    func tron(_ tam: CGPoint, _ r: CGFloat, _ mau: Color, doMo: Double = 1) {
        var c = ctx
        c.opacity = doMo
        c.fill(Path(ellipseIn: CGRect(x: tam.x - r, y: tam.y - r, width: r * 2, height: r * 2)), with: .color(mau))
    }

    /// Một ngữ cảnh con đã dời gốc về `goc0`, phóng `k`, xoay `xoay` — để vẽ một cụm trang trí bằng toạ độ cục bộ.
    func cum(_ goc0: CGPoint, k: CGFloat, xoay: CGFloat = 0, doMo: Double = 1, _ ve: (ButVe) -> Void) {
        var c = ctx
        c.opacity = doMo
        c.translateBy(x: goc0.x, y: goc0.y)
        if xoay != 0 { c.rotate(by: .radians(xoay)) }
        c.scaleBy(x: k, y: k)
        ve(ButVe(ctx: c))
    }

    // Tiện ích vẽ theo toạ độ CỤC BỘ (dùng bên trong `cum`).
    func hcn(_ r: CGRect, _ mau: Color, bo: CGFloat = 0) {
        ctx.fill(Path(roundedRect: r, cornerRadius: bo), with: .color(mau))
    }
    func elip(_ r: CGRect, _ mau: Color) { ctx.fill(Path(ellipseIn: r), with: .color(mau)) }
    func duong(_ p: Path, _ mau: Color, _ day: CGFloat) {
        ctx.stroke(p, with: .color(mau), style: StrokeStyle(lineWidth: day, lineCap: .round, lineJoin: .round))
    }
    func tamGiac(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ mau: Color) {
        var p = Path(); p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.closeSubpath()
        ctx.fill(p, with: .color(mau))
    }
}

/// Số giả ngẫu nhiên ỔN ĐỊNH theo chỉ số — hạt không cần trạng thái: vị trí là hàm của (chỉ số, thời gian).
@inline(__always) func ngauNhien(_ i: Int, _ k: Int) -> CGFloat {
    let x = sin(Double(i &* 127 &+ k &* 311) * 12.9898) * 43758.5453
    return CGFloat(x - x.rounded(.down))
}

@inline(__always) func tronTru(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}

extension Color {
    static func h(_ hex: UInt32) -> Color { Color(hex: hex) }
}
