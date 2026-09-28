#if (DEBUG && os(iOS)) || LAMGON_MAC
import CoreGraphics
import Foundation
import PencilKit
#if os(iOS)
import UIKit
typealias MauMuc = UIColor
#else
import AppKit
typealias MauMuc = NSColor
#endif

// MARK: - Bàn thử "Làm gọn chữ" (CHỈ bản DEBUG)
//
// Dựng nét viết tay GIẢ nhưng xấu như thật — dòng nghiêng 5°, chữ nhảy lên
// xuống, cỡ to nhỏ lộn xộn, run tay, bảng 3×3 kẻ lệch, vòng tròn méo, chữ có
// dấu tiếng Việt — rồi đo TRƯỚC/SAU bằng số, không bằng mắt.
//
//   macOS (nhanh):  swiftc -D LAMGON_MAC LamGonChu.swift ThuLamGon.swift main.swift
//   máy ảo iPad:    CT_XEM_MAN=vo-lamgon-thu   (in ra màn + NSLog [THU-LAMGON])
//                   CT_XEM_MAN=vo-lamgon       (gieo trang xấu, mở màn viết)

enum ThuLamGon {

    // MARK: Nguồn ngẫu nhiên cố định (chạy lại ra đúng số cũ)

    struct NgauNhien {
        var s: UInt64
        mutating func tiep() -> UInt64 {
            s &+= 0x9E3779B97F4A7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func so(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
            a + (b - a) * CGFloat(Double(tiep() % 1_000_000) / 1_000_000)
        }
        mutating func chuan(_ sd: CGFloat) -> CGFloat {
            var t: CGFloat = 0
            for _ in 0..<4 { t += so(-1, 1) }
            return t / 2 * sd * 1.22
        }
    }

    // MARK: Phông nét đơn (đơn vị: chiều cao chữ thường = 1, y hướng LÊN)

    private static func cung(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                             _ a0: CGFloat, _ a1: CGFloat) -> [CGPoint] {
        let n = max(6, Int(abs(a1 - a0) / 12))
        return (0...n).map { i in
            let a = (a0 + (a1 - a0) * CGFloat(i) / CGFloat(n)) * .pi / 180
            return CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a))
        }
    }
    private static func d(_ ps: (CGFloat, CGFloat)...) -> [CGPoint] { ps.map { CGPoint(x: $0.0, y: $0.1) } }

    /// (bề rộng, các nét)
    private static let phong: [Character: (CGFloat, [[CGPoint]])] = {
        let buouO = cung(0.42, 0.5, 0.37, 0.48, 20, 360)
        let buouH = d((0.1, 0.55)) + cung(0.45, 0.55, 0.35, 0.45, 180, 0) + d((0.8, 0))
        return [
            "o": (0.95, [cung(0.45, 0.5, 0.4, 0.5, 90, 450)]),
            "a": (1.0, [cung(0.42, 0.5, 0.37, 0.48, 20, 350), d((0.8, 1), (0.8, 0))]),
            "c": (0.9, [cung(0.45, 0.5, 0.4, 0.5, 45, 315)]),
            "e": (0.95, [d((0.08, 0.5), (0.82, 0.5)) + cung(0.45, 0.5, 0.38, 0.5, 0, 310)]),
            "d": (1.05, [buouO, d((0.8, 1.8), (0.8, 0))]),
            "đ": (1.1, [buouO, d((0.8, 1.8), (0.8, 0)), d((0.55, 1.45), (1.05, 1.45))]),
            "g": (1.0, [buouO, d((0.8, 1), (0.8, -0.45)) + cung(0.45, -0.45, 0.35, 0.3, 0, -160)]),
            "h": (0.95, [d((0.1, 1.8), (0.1, 0)), buouH]),
            "n": (0.95, [d((0.1, 1), (0.1, 0)), buouH]),
            "m": (1.3, [d((0.1, 1), (0.1, 0)),
                        d((0.1, 0.55)) + cung(0.35, 0.55, 0.25, 0.45, 180, 0) + d((0.6, 0)),
                        d((0.6, 0.55)) + cung(0.85, 0.55, 0.25, 0.45, 180, 0) + d((1.1, 0))]),
            "i": (0.45, [d((0.15, 1), (0.15, 0)), cung(0.15, 1.42, 0.06, 0.06, 0, 360)]),
            "l": (0.5, [d((0.15, 1.8), (0.15, 0.12)) + cung(0.3, 0.12, 0.15, 0.12, 180, 270)]),
            "t": (0.7, [d((0.3, 1.5), (0.3, 0.12)) + cung(0.45, 0.12, 0.15, 0.12, 180, 270),
                        d((0.05, 1), (0.6, 1))]),
            "u": (1.0, [d((0.1, 1), (0.1, 0.4)) + cung(0.43, 0.4, 0.33, 0.4, 180, 360) + d((0.76, 1)),
                        d((0.8, 1), (0.8, 0))]),
            "y": (0.95, [d((0.05, 1), (0.45, 0.05)), d((0.85, 1), (0.25, -0.8))]),
            "k": (0.9, [d((0.1, 1.8), (0.1, 0)), d((0.7, 1), (0.12, 0.45), (0.75, 0))]),
            "v": (0.85, [d((0.05, 1), (0.4, 0), (0.75, 1))]),
            "s": (0.8, [cung(0.4, 0.75, 0.3, 0.25, 30, 270) + cung(0.4, 0.25, 0.3, 0.25, 90, -150)]),
            "r": (0.7, [d((0.1, 1), (0.1, 0)), d((0.1, 0.55)) + cung(0.4, 0.55, 0.3, 0.4, 180, 60)]),
            "x": (0.8, [d((0.05, 1), (0.7, 0)), d((0.7, 1), (0.05, 0))]),
        ]
    }()

    /// Dấu phụ, đặt theo tâm chữ `cx`, độ cao `y0` (chữ cao ⇒ dấu cao theo).
    private static func dau(_ ma: Unicode.Scalar, cx: CGFloat, rong: CGFloat, tang: CGFloat) -> [[CGPoint]] {
        switch ma.value {
        case 0x0301: return [d((cx - 0.08, 1.25 + tang), (cx + 0.17, 1.6 + tang))]            // sắc
        case 0x0300: return [d((cx - 0.17, 1.6 + tang), (cx + 0.08, 1.25 + tang))]            // huyền
        case 0x0309: return [cung(cx, 1.48 + tang, 0.14, 0.11, 160, -60) + d((cx, 1.22 + tang))] // hỏi
        case 0x0303: return [(0...10).map { i in                                               // ngã
            let t = CGFloat(i) / 10
            return CGPoint(x: cx - 0.3 + 0.6 * t, y: 1.4 + tang + 0.08 * sin(t * 2 * .pi)) }]
        case 0x0323: return [cung(cx, -0.33, 0.06, 0.06, 0, 360)]                              // nặng
        case 0x0302: return [d((cx - 0.3, 1.2), (cx, 1.48), (cx + 0.3, 1.2))]                  // mũ
        case 0x0306: return [cung(cx, 1.42, 0.27, 0.2, 195, 345)]                              // trăng
        case 0x031B: return [d((rong * 0.8, 0.95), (rong * 0.95, 1.12), (rong * 1.0, 1.25))]   // móc ơ ư
        default: return []
        }
    }

    // MARK: Bút giả

    struct NetGia {
        var net: PKStroke
        var sach: [CGPoint]      // đường KHÔNG run, để đo độ mượt
        var laDau = false
        var chu = -1             // chỉ số nét chủ (nếu là dấu)
        var dong = -1
    }

    struct Khung {
        var nets: [NetGia] = []
        var drawing: PKDrawing { PKDrawing(strokes: nets.map(\.net)) }
    }

    static func netRun(_ duong: [CGPoint], rng: inout NgauNhien, run: CGFloat = 0.38,
                       day: CGFloat = 2.2, mau: MauMuc = .black) -> PKStroke {
        // Bàn thử máy ảo đổi được khoảng cách điểm / loại bút qua biến môi
        // trường, không phải dựng lại app (CT_LAMGON_BUOC, CT_LAMGON_BUT).
        let env = ProcessInfo.processInfo.environment
        let buoc = CGFloat(Double(env["CT_LAMGON_BUOC"] ?? "") ?? 0.7)
        let runNhan = CGFloat(Double(env["CT_LAMGON_RUN"] ?? "") ?? 1)
        let p = HinhHoc.mauDeu(duong, n: max(2, Int(HinhHoc.doDai(duong) / buoc)))
        let ph1 = rng.so(0, 6.3), ph2 = rng.so(0, 6.3), w0 = day * rng.so(0.85, 1.2)
        var s: CGFloat = 0
        var ds: [PKStrokePoint] = []
        for i in p.indices {
            if i > 0 { s += hypot(p[i].x - p[i - 1].x, p[i].y - p[i - 1].y) }
            let a = p[max(0, i - 1)], b = p[min(p.count - 1, i + 1)]
            let L = max(hypot(b.x - a.x, b.y - a.y), 0.001)
            let nx = -(b.y - a.y) / L, ny = (b.x - a.x) / L
            let e = runNhan * run * (sin(2 * .pi * s / 2.8 + ph1) + 0.6 * sin(2 * .pi * s / 1.7 + ph2)) + rng.chuan(0.08)
            // Nét thật từ Apple Pencil: `size` = bề rộng bút, gần như KHÔNG đổi
            // trong nét; lực nhấn nằm ở `force`. Cho `size` dao động mạnh thì
            // PencilKit vẽ thành từng đoạn thoi đứt quãng (đo trên máy ảo 28/09).
            let w = w0
            ds.append(PKStrokePoint(location: CGPoint(x: p[i].x + nx * e, y: p[i].y + ny * e),
                                    timeOffset: Double(i) * 0.011 * Double(buoc), size: CGSize(width: w, height: w),
                                    opacity: 1, force: 0.7 + 0.3 * sin(s / 5 + ph1),
                                    azimuth: 0.8, altitude: 1.1))
        }
        let loai: PKInk.InkType = env["CT_LAMGON_BUT"] == "mono" ? .monoline
            : env["CT_LAMGON_BUT"] == "fountain" ? .fountainPen : .pen
        return PKStroke(ink: PKInk(loai, color: mau), path: PKStrokePath(controlPoints: ds, creationDate: Date()))
    }

    /// Viết một dòng chữ cẩu thả. `goc`: đầu đường chân chữ; `nghieng` độ.
    static func vietDong(_ chu: String, goc: CGPoint, u: CGFloat, nghieng: CGFloat,
                         rng: inout NgauNhien, vao k: inout Khung, dong: Int,
                         nhay: CGFloat = 0.2, loanCo: CGFloat = 0.18) {
        let g = nghieng * .pi / 180
        let ux = CGVector(dx: cos(g), dy: sin(g)), uy = CGVector(dx: sin(g), dy: -cos(g)) // uy: "lên"
        var x: CGFloat = 0
        for tu in chu.split(separator: " ") {
            let lechTu = rng.chuan(nhay) * u
            let coTu = 1 + rng.so(-loanCo, loanCo)
            for ch in tu {
                let tach = String(ch).decomposedStringWithCanonicalMapping.unicodeScalars
                let goc0: Character = ch == "đ" ? "đ" : Character(tach.first!)
                guard let (rong, nets) = phong[goc0] else { x += 0.6 * u; continue }
                let s = u * coTu * (1 + rng.chuan(0.05))
                let yChu = lechTu + rng.chuan(0.06) * u
                let xoay = rng.chuan(2.5) * .pi / 180
                func ra(_ q: CGPoint) -> CGPoint {
                    let qx = q.x * cos(xoay) - q.y * sin(xoay), qy = q.x * sin(xoay) + q.y * cos(xoay)
                    let bx = x + qx * s, by = yChu + qy * s
                    return CGPoint(x: goc.x + ux.dx * bx + uy.dx * by, y: goc.y + ux.dy * bx + uy.dy * by)
                }
                let chuDau = k.nets.count
                for n in nets {
                    let sach = n.map(ra)
                    k.nets.append(NetGia(net: netRun(sach, rng: &rng), sach: sach, dong: dong))
                }
                var tang: CGFloat = 0
                let cao = nets.flatMap { $0 }.map(\.y).max() ?? 1
                if cao > 1.3 { tang = cao - 1 }
                for ma in tach.dropFirst() {
                    for n in dau(ma, cx: rong * 0.45, rong: rong, tang: tang) {
                        let sach = n.map(ra)
                        k.nets.append(NetGia(net: netRun(sach, rng: &rng, run: 0.2), sach: sach,
                                             laDau: true, chu: chuDau, dong: dong))
                    }
                    if ma.value == 0x0302 || ma.value == 0x0306 { tang += 0.35 }
                }
                x += (rong + 0.18) * s
            }
            x += 0.75 * u
        }
    }

    // MARK: Trang mẫu

    struct TrangMau {
        var k = Khung()
        var dongKe: [CGFloat] = []
        var soDongChu = 0
        var bangNet: [Int] = []          // chỉ số các nét kẻ bảng
        var bangDoc: [Int] = []          // … trong đó nét dọc
        var bangChu: [Int] = []          // chữ trong ô
        var tron = -1, chuNhat = -1, tamGiac = -1, muiTen = -1
        var runThu = -1                  // một nét cong run tay có bản sạch để so
    }

    /// Đường chân chữ của giấy kẻ ngang — y hệt `GiayNenView.veKeNgang`.
    static func dongKeNgang(cao: CGFloat = 841.89) -> [CGFloat] {
        let cd: CGFloat = 8 / 25.4 * 72
        var ds: [CGFloat] = []
        var y = cd * 3
        while y < cao - cd { ds.append(y); y += cd }
        return ds
    }

    static func trangMau(hat: UInt64 = 7) -> TrangMau {
        var rng = NgauNhien(s: hat)
        var t = TrangMau()
        t.dongKe = dongKeNgang()
        let u: CGFloat = 8.5
        let cau = ["hôm nay học toán", "tiếng việt có dấu", "ghi chú môn sử kỳ này"]
        let nghieng: [CGFloat] = [5, -4, 6]
        for (i, c) in cau.enumerated() {
            let dk = t.dongKe[2 + i * 2]
            vietDong(c, goc: CGPoint(x: 80, y: dk + rng.so(-7, 7)), u: u, nghieng: nghieng[i],
                     rng: &rng, vao: &t.k, dong: i)
        }
        t.soDongChu = cau.count

        // Bảng 3×3 kẻ lệch.
        let x0: CGFloat = 90, y0: CGFloat = 330, cw: CGFloat = 110, ch: CGFloat = 42
        for i in 0...3 {
            let y = y0 + CGFloat(i) * ch + rng.so(-4, 4)
            let a = CGPoint(x: x0 + rng.so(-8, 6), y: y + rng.so(-3, 3))
            let b = CGPoint(x: x0 + 3 * cw + rng.so(-6, 9), y: y + rng.so(-4, 4))
            t.bangNet.append(t.k.nets.count)
            t.k.nets.append(NetGia(net: netRun([a, b], rng: &rng), sach: [a, b]))
        }
        for i in 0...3 {
            let x = x0 + CGFloat(i) * cw + rng.so(-5, 5)
            let a = CGPoint(x: x + rng.so(-3, 3), y: y0 + rng.so(-7, 5))
            let b = CGPoint(x: x + rng.so(-5, 5), y: y0 + 3 * ch + rng.so(-5, 8))
            t.bangNet.append(t.k.nets.count); t.bangDoc.append(t.k.nets.count)
            t.k.nets.append(NetGia(net: netRun([a, b], rng: &rng), sach: [a, b]))
        }
        let oChu = ["an", "to", "đi", "ca", "kê", "mơ", "sữa", "vở", "hè"]
        for (j, w) in oChu.enumerated() {
            let r = j / 3, c = j % 3
            let tu = t.k.nets.count
            vietDong(w, goc: CGPoint(x: x0 + CGFloat(c) * cw + rng.so(8, 45),
                                     y: y0 + CGFloat(r) * ch + rng.so(22, 34)),
                     u: 7.5, nghieng: rng.so(-6, 6), rng: &rng, vao: &t.k, dong: -1)
            t.bangChu += Array(tu..<t.k.nets.count)
        }

        // Hình: tròn méo, chữ nhật, tam giác, mũi tên một nét.
        let tam = CGPoint(x: 150, y: 600), R: CGFloat = 45
        let a0 = rng.so(0, 6)
        let tron = (0...80).map { i -> CGPoint in
            let a = a0 + CGFloat(i) / 72 * 2 * .pi
            let r = R * (1 + 0.06 * sin(3 * a + 1) + 0.03 * sin(5 * a))
            return CGPoint(x: tam.x + r * cos(a), y: tam.y + 0.95 * r * sin(a))
        }
        t.tron = t.k.nets.count
        t.k.nets.append(NetGia(net: netRun(tron, rng: &rng), sach: tron))
        let cn = [CGPoint(x: 262, y: 562), CGPoint(x: 385, y: 568), CGPoint(x: 381, y: 640),
                  CGPoint(x: 258, y: 634), CGPoint(x: 263, y: 566)]
        t.chuNhat = t.k.nets.count
        t.k.nets.append(NetGia(net: netRun(cn, rng: &rng), sach: cn))
        let tg = [CGPoint(x: 470, y: 560), CGPoint(x: 525, y: 648), CGPoint(x: 418, y: 642), CGPoint(x: 468, y: 563)]
        t.tamGiac = t.k.nets.count
        t.k.nets.append(NetGia(net: netRun(tg, rng: &rng), sach: tg))
        let mt = [CGPoint(x: 100, y: 735), CGPoint(x: 330, y: 722), CGPoint(x: 312, y: 710),
                  CGPoint(x: 331, y: 723), CGPoint(x: 314, y: 737)]
        t.muiTen = t.k.nets.count
        t.k.nets.append(NetGia(net: netRun(mt, rng: &rng), sach: mt))
        // Một đường cong dài run tay.
        let cong = (0...60).map { i -> CGPoint in
            let x = 380 + CGFloat(i) * 2.5
            return CGPoint(x: x, y: 760 + 18 * sin(CGFloat(i) / 60 * 2 * .pi))
        }
        t.runThu = t.k.nets.count
        t.k.nets.append(NetGia(net: netRun(cong, rng: &rng, run: 0.5), sach: cong))
        return t
    }

    // MARK: Đo

    private static func diem(_ s: PKStroke) -> [CGPoint] {
        s.path.interpolatedPoints(by: .distance(1)).map { $0.location.applying(s.transform) }
    }

    private static func dong(_ nets: [PKStroke], _ chiSo: [Int], dk: [CGFloat], k: CGFloat)
        -> (goc: Double, lechChan: Double, cachDongKe: Double) {
        let ks = chiSo.map { HinhHoc.khung(diem(nets[$0])) }
        let xs = ks.map(\.midX), ys = ks.map(\.maxY)
        let doc = HinhHoc.theilSen(xs, ys)
        let x0 = HinhHoc.trungVi(xs)
        let du = zip(xs, ys).map { $1 - doc * ($0 - x0) }
        let chan = HinhHoc.chanChu(du, k: k)
        let gan = du.filter { abs($0 - chan) < 0.6 * k }
        let sd = sqrt(gan.map { ($0 - chan) * ($0 - chan) }.reduce(0, +) / CGFloat(max(1, gan.count)))
        let kc = HinhHoc.ganNhat(dk, chan).map { abs($0 - chan) } ?? -1
        return (Double(atan(doc) * 180 / .pi), Double(sd), Double(kc))
    }

    private static func rmsDenDuong(_ p: [CGPoint], _ sach: [CGPoint]) -> Double {
        var t: CGFloat = 0
        for q in p {
            var m = CGFloat.infinity
            for i in sach.indices.dropFirst() { m = min(m, HinhHoc.kcDenDoan(q, sach[i - 1], sach[i])) }
            t += m * m
        }
        return Double(sqrt(t / CGFloat(max(1, p.count))))
    }

    /// So hai nét theo NỘI DUNG. `PKDrawing.dataRepresentation()` KHÔNG ổn
    /// định từng byte (hai lần tuần tự hoá cùng một bản vẽ ra hai chuỗi khác)
    /// nên không dùng nó để so được.
    static func giongHet(_ a: PKStroke, _ b: PKStroke) -> Bool {
        guard a.transform == b.transform, a.ink.inkType == b.ink.inkType,
              a.path.count == b.path.count else { return false }
        return zip(a.path, b.path).allSatisfy { $0.location == $1.location && $0.size == $1.size && $0.force == $1.force }
    }

    static func f(_ x: Double, _ n: Int = 2) -> String { String(format: "%.\(n)f", x) }

    /// Chạy hết, trả về từng dòng "✅/❌ …" kèm số đo.
    static func chayHet(hat: UInt64 = 7) -> [String] {
        var kq: [String] = []
        func kiem(_ ten: String, _ dung: Bool, _ chiTiet: String = "") {
            kq.append((dung ? "✅ " : "❌ ") + ten + (chiTiet.isEmpty ? "" : " — " + chiTiet))
        }
        let t = trangMau(hat: hat)
        let truoc = t.k.nets.map(\.net)
        let r = LamGonChu.lamGon(t.k.drawing, tuyChon: TuyChonLamGon(), dongKe: t.dongKe)
        let sau = r.drawing.strokes
        kiem("giữ nguyên SỐ NÉT (mốc ghi âm không lệch)", sau.count == truoc.count, "\(truoc.count) → \(sau.count)")
        kq.append("   các dòng: " + r.chiTietDong.joined(separator: " | "))
        kq.append("   trang mẫu: \(truoc.count) nét · \(f(r.mili, 1)) ms · đổi \(r.soNetDoi) · dòng \(r.soDong) · bảng \(r.soBang) · hình \(r.soHinh) · thẳng \(r.soNetThang)")

        // 1. Dòng chữ: góc nghiêng, chữ nhảy, khoảng cách tới dòng kẻ.
        let k: CGFloat = 8.5
        for d in 0..<t.soDongChu {
            let chinh = t.k.nets.indices.filter { t.k.nets[$0].dong == d && !t.k.nets[$0].laDau }
            let a = dong(truoc, chinh, dk: t.dongKe, k: k), b = dong(sau, chinh, dk: t.dongKe, k: k)
            kiem("dòng \(d + 1): thẳng lại", abs(b.goc) < 0.8 && abs(b.goc) < abs(a.goc),
                 "nghiêng \(f(a.goc))° → \(f(b.goc))°")
            kiem("dòng \(d + 1): chữ bớt nhảy", b.lechChan < a.lechChan,
                 "lệch chân σ \(f(a.lechChan))pt → \(f(b.lechChan))pt")
            kiem("dòng \(d + 1): ngồi lên dòng kẻ", b.cachDongKe < 1.5,
                 "cách dòng kẻ \(f(a.cachDongKe))pt → \(f(b.cachDongKe))pt")
        }
        // 2. Dấu tiếng Việt đi theo chữ.
        var loiDau: [Double] = [], dauRoi = 0
        for (i, n) in t.k.nets.enumerated() where n.laDau && n.chu >= 0 {
            let kd0 = HinhHoc.khung(diem(truoc[i])), kc0 = HinhHoc.khung(diem(truoc[n.chu]))
            let kd1 = HinhHoc.khung(diem(sau[i])), kc1 = HinhHoc.khung(diem(sau[n.chu]))
            let v0 = CGVector(dx: kd0.midX - kc0.midX, dy: kd0.midY - kc0.midY)
            let v1 = CGVector(dx: kd1.midX - kc1.midX, dy: kd1.midY - kc1.midY)
            let e = abs(hypot(v1.dx, v1.dy) - hypot(v0.dx, v0.dy))
            loiDau.append(Double(e))
            // Dấu phải vẫn ở ĐÚNG PHÍA của chữ (trên vẫn trên, dưới vẫn dưới).
            if (v0.dy < 0) != (v1.dy < 0) || e > 3 { dauRoi += 1 }
        }
        let tbDau = loiDau.reduce(0, +) / Double(max(1, loiDau.count))
        kiem("dấu thanh/dấu mũ đi theo chữ", dauRoi == 0,
             "\(loiDau.count) dấu · lệch khoảng cách TB \(f(tbDau))pt · rơi khỏi chữ: \(dauRoi)")
        kiem("dấu không tách thành dòng riêng", r.soDong <= t.soDongChu + 1, "đếm \(r.soDong) dòng (đúng \(t.soDongChu))")

        // 3. Bảng.
        func lechTruc(_ s: PKStroke, doc: Bool) -> Double {
            let p = diem(s)
            let v = p.map { doc ? $0.x : $0.y }
            return Double((v.max() ?? 0) - (v.min() ?? 0))
        }
        let ngangIdx = t.bangNet.filter { !t.bangDoc.contains($0) }
        let lechNgang0 = ngangIdx.map { lechTruc(truoc[$0], doc: false) }.max() ?? 0
        let lechNgang1 = ngangIdx.map { lechTruc(sau[$0], doc: false) }.max() ?? 0
        let lechDoc0 = t.bangDoc.map { lechTruc(truoc[$0], doc: true) }.max() ?? 0
        let lechDoc1 = t.bangDoc.map { lechTruc(sau[$0], doc: true) }.max() ?? 0
        kiem("bảng: đường ngang thẳng tuyệt đối", lechNgang1 < 0.05, "lệch y tối đa \(f(lechNgang0))pt → \(f(lechNgang1, 3))pt")
        kiem("bảng: đường dọc thẳng tuyệt đối", lechDoc1 < 0.05, "lệch x tối đa \(f(lechDoc0))pt → \(f(lechDoc1, 3))pt")
        // Đầu mút: đường ngang phải bắt đúng x của đường dọc ngoài cùng.
        func dauMut(_ ds: [PKStroke]) -> Double {
            let xs = t.bangDoc.map { i in HinhHoc.khung(diem(ds[i])).midX }.sorted()
            var m: Double = 0
            for i in ngangIdx {
                let r = HinhHoc.khung(diem(ds[i]))
                m = max(m, Double(abs(r.minX - xs.first!)), Double(abs(r.maxX - xs.last!)))
            }
            return m
        }
        kiem("bảng: đầu mút khít vào khung", dauMut(sau) < 0.6, "hở/lố tối đa \(f(dauMut(truoc)))pt → \(f(dauMut(sau)))pt")
        // Chữ trong ô: độ lệch tâm so với tâm ô.
        func lechO(_ ds: [PKStroke]) -> Double {
            let xs = t.bangDoc.map { HinhHoc.khung(diem(ds[$0])).midX }.sorted()
            let ys = ngangIdx.map { HinhHoc.khung(diem(ds[$0])).midY }.sorted()
            var theoO: [Int: CGRect] = [:]
            for i in t.bangChu {
                let r = HinhHoc.khung(diem(ds[i]))
                guard let c = xs.lastIndex(where: { $0 < r.midX }), let h = ys.lastIndex(where: { $0 < r.midY }) else { continue }
                theoO[h * 10 + c] = (theoO[h * 10 + c] ?? .null).union(r)
            }
            var m: Double = 0
            for (ma, r) in theoO where ma / 10 < 3 && ma % 10 < 3 {
                let cx = (xs[ma % 10] + xs[ma % 10 + 1]) / 2, cy = (ys[ma / 10] + ys[ma / 10 + 1]) / 2
                m = max(m, Double(hypot(r.midX - cx, r.midY - cy)))
            }
            return m
        }
        kiem("bảng: chữ canh giữa ô", lechO(sau) < 1.5, "lệch tâm ô tối đa \(f(lechO(truoc)))pt → \(f(lechO(sau)))pt")

        // 4. Hình.
        func doTron(_ s: PKStroke) -> Double {
            let p = diem(s)
            let c = CGPoint(x: p.map(\.x).reduce(0, +) / CGFloat(p.count), y: p.map(\.y).reduce(0, +) / CGFloat(p.count))
            let rs = p.map { hypot($0.x - c.x, $0.y - c.y) }
            let m = rs.reduce(0, +) / CGFloat(rs.count)
            return Double(sqrt(rs.map { ($0 - m) * ($0 - m) }.reduce(0, +) / CGFloat(rs.count)) / m)
        }
        kiem("vòng tròn méo → tròn", doTron(sau[t.tron]) < 0.01, "σ bán kính/R \(f(doTron(truoc[t.tron]) * 100, 1))% → \(f(doTron(sau[t.tron]) * 100, 2))%")
        let cn = HinhHoc.khung(diem(sau[t.chuNhat]))
        let canhCN = diem(sau[t.chuNhat]).map { q in
            min(abs(q.x - cn.minX), abs(q.x - cn.maxX), abs(q.y - cn.minY), abs(q.y - cn.maxY)) }.max() ?? 99
        kiem("chữ nhật lệch → chữ nhật thẳng trục", canhCN < 0.05, "điểm xa cạnh nhất \(f(Double(canhCN), 3))pt")
        let dpTG = HinhHoc.dp(diem(sau[t.tamGiac]), eps: 0.8).count
        kiem("tam giác → 3 cạnh thẳng", dpTG == 4, "số đỉnh (kể cả điểm khép) \(dpTG)")
        let dpMT = HinhHoc.dp(diem(sau[t.muiTen]), eps: 0.8).count
        let mtK = HinhHoc.khung(diem(sau[t.muiTen]).prefix(40).map { $0 })
        kiem("mũi tên → thân thẳng + hai cánh", dpMT == 5, "đỉnh \(dpMT) · thân lệch y \(f(Double(mtK.height), 2))pt")

        // 5. Làm mượt.
        let sachCong = t.k.nets[t.runThu].sach
        let run0 = rmsDenDuong(diem(truoc[t.runThu]), sachCong)
        let run1 = rmsDenDuong(diem(sau[t.runThu]), sachCong)
        kiem("run tay giảm", run1 < run0 * 0.6, "RMS lệch khỏi đường thật \(f(run0, 3))pt → \(f(run1, 3))pt")
        // Góc gãy của chữ k/v: đỉnh gãy vẫn còn sắc.
        let tuong = LamGonChu.lamGon(t.k.drawing, tuyChon: TuyChonLamGon(lamMuot: true, thangHang: false, nanBang: false, nanHinh: false))
        var gocGay: [Double] = []
        for (i, n) in t.k.nets.enumerated() where n.sach.count == 3 && !n.laDau {
            // Nét 3 đỉnh (v, cánh của k): khoảng cách đỉnh gãy thật tới nét ra.
            let dinh = n.sach[1]
            let p = diem(tuong.drawing.strokes[i])
            gocGay.append(Double(p.map { hypot($0.x - dinh.x, $0.y - dinh.y) }.min() ?? 99))
        }
        let tbGay = gocGay.reduce(0, +) / Double(max(1, gocGay.count))
        kiem("góc gãy (k, v) KHÔNG bị bo tròn", (gocGay.max() ?? 0) < 1.5,
             "\(gocGay.count) góc · đỉnh cách nét TB \(f(tbGay))pt, xa nhất \(f(gocGay.max() ?? 0))pt")
        // Run tay trên CHỮ: so với đường sạch.
        var r0: Double = 0, r1: Double = 0, dem = 0
        for (i, n) in t.k.nets.enumerated() where n.dong >= 0 && !n.laDau && n.sach.count > 6 {
            r0 += rmsDenDuong(diem(truoc[i]), n.sach)
            r1 += rmsDenDuong(diem(tuong.drawing.strokes[i]), n.sach); dem += 1
        }
        kiem("run tay trên chữ giảm", r1 < r0, "RMS TB \(dem) nét: \(f(r0 / Double(dem), 3))pt → \(f(r1 / Double(dem), 3))pt")
        // Đều độ dày.
        func dayCV(_ s: PKStroke) -> Double {
            // Độ đậm của bút thật nằm ở LỰC nhấn (`size` gần như cố định).
            let w = s.path.map { Double($0.force) }
            let m = w.reduce(0, +) / Double(w.count)
            return sqrt(w.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(w.count)) / m
        }
        let cv0 = truoc.map(dayCV).reduce(0, +) / Double(truoc.count)
        let cv1 = tuong.drawing.strokes.map(dayCV).reduce(0, +) / Double(truoc.count)
        kiem("lực nhấn (độ đậm) trong nét đều hơn, không phẳng hẳn", cv1 < cv0 && cv1 > 0.02,
             "hệ số biến thiên TB \(f(cv0 * 100, 1))% → \(f(cv1 * 100, 1))%")

        // 6. Chỉ vùng khoanh: nét ngoài vùng giữ NGUYÊN từng byte.
        let vung = CGRect(x: 0, y: 0, width: 595, height: 200)
        let rv = LamGonChu.lamGon(t.k.drawing, tuyChon: TuyChonLamGon(), vung: vung, dongKe: t.dongKe)
        var ngoaiY = true, trongDoi = 0
        for i in truoc.indices {
            let tamN = HinhHoc.khung(diem(truoc[i]))
            let giong = giongHet(truoc[i], rv.drawing.strokes[i])
            if vung.contains(CGPoint(x: tamN.midX, y: tamN.midY)) { if !giong { trongDoi += 1 } } else if !giong { ngoaiY = false }
        }
        kiem("khoanh vùng: nét NGOÀI vùng y nguyên", ngoaiY, "nét trong vùng đã đổi: \(trongDoi)")

        // 7. Tắt hết ⇒ ra y nguyên.
        let rTat = LamGonChu.lamGon(t.k.drawing, tuyChon: TuyChonLamGon(lamMuot: false, thangHang: false, nanBang: false, nanHinh: false))
        kiem("tắt mọi phép ⇒ trang y nguyên", zip(rTat.drawing.strokes, truoc).allSatisfy { giongHet($0, $1) })

        // 8. Tốc độ: trang dày ~2000 nét.
        var rng = NgauNhien(s: 99)
        var day = Khung()
        let cau = "hôm nay học toán tiếng việt có dấu ghi chú"
        var dno = 0
        for (i, y) in dongKeNgang().enumerated() where i >= 1 {
            vietDong(cau, goc: CGPoint(x: 40, y: y + rng.so(-4, 4)), u: 7, nghieng: rng.so(-5, 5),
                     rng: &rng, vao: &day, dong: dno)
            dno += 1
            if day.nets.count >= 2000 { break }
        }
        let rd = LamGonChu.lamGon(day.drawing, tuyChon: TuyChonLamGon(), dongKe: dongKeNgang())
        kiem("trang dày \(day.nets.count) nét < 1 giây", rd.mili < 1000, "\(f(rd.mili, 0)) ms · \(rd.soDong) dòng (viết \(dno))")
        let kb0 = day.drawing.dataRepresentation().count, kb1 = rd.drawing.dataRepresentation().count
        kq.append("   dung lượng nét: \(kb0 / 1024) KB → \(kb1 / 1024) KB")

        let hong = kq.filter { $0.hasPrefix("❌") }.count
        let dat = kq.filter { $0.hasPrefix("✅") }.count
        kq.append("KẾT QUẢ: \(dat)/\(dat + hong) đạt")
        return kq
    }
}
#endif
