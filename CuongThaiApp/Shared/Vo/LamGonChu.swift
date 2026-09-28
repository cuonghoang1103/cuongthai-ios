#if os(iOS) || LAMGON_MAC
import CoreGraphics
import Foundation
import PencilKit

// ════════════════════════════════════════════════════════════════
// LÀM GỌN CHỮ — giữ NÉT TAY của người dùng, chỉ sửa chỗ cẩu thả
//
// Người dùng 28/09/2026: "viết xong muốn nó format lại chữ cho đẹp hơn (vẫn
// nét chữ của con người), sắp xếp, hàng cột nếu có… nhiều lúc tôi viết chữ
// xấu, cẩu thả." ⇒ KHÔNG thay chữ bằng phông, KHÔNG gửi AI. Chạy trọn trên
// máy, mỗi nét ra vẫn là nét của chính người viết, chỉ:
//
//   1. Làm mượt   — khử run tay, GIỮ góc gãy (k, z, v, kana/kanji), đều độ dày
//   2. Thẳng hàng — gom nét thành dòng, nắn dòng nghiêng về ngang, đặt lên
//                   dòng kẻ gần nhất, từng từ về đúng đường chân, đều cỡ vừa phải
//   3. Nắn bảng   — nét gần thẳng → thẳng; gần ngang/dọc → ngang/dọc tuyệt đối;
//                   đường của một bảng gióng cùng toạ độ; chữ trong ô canh giữa ô
//   4. Nắn hình   — tròn/elip/chữ nhật/tam giác/mũi tên → hình chuẩn
//
// ⚠️ Bất biến quan trọng nhất: SỐ NÉT và THỨ TỰ NÉT giữ nguyên, nét thứ i ra
// là nét thứ i vào. `TrangVo.mocNet` (ghi âm buổi học) đi song song với mảng
// nét — gộp/tách nét là mọi mốc "chạm chữ để nghe" lệch hết.
//
// Tệp này KHÔNG phụ thuộc UIKit để chạy được bộ kiểm trên macOS (`swiftc
// -D LAMGON_MAC`) — nhanh hơn dựng app lên máy ảo cả trăm lần.
// ════════════════════════════════════════════════════════════════

struct TuyChonLamGon: Equatable, Sendable {
    var lamMuot = true
    var thangHang = true
    var nanBang = true
    var nanHinh = true
    var coPhepNao: Bool { lamMuot || thangHang || nanBang || nanHinh }
}

struct KetQuaLamGon {
    var drawing: PKDrawing
    var soNetDoi = 0
    var soDong = 0
    var soBang = 0
    var soHinh = 0
    var soNetThang = 0
    /// Thời gian chạy, mili giây.
    var mili: Double = 0
    /// Góc nghiêng từng dòng TRƯỚC khi nắn (độ) — cho bộ kiểm in số đo.
    var gocDongTruoc: [Double] = []
    /// Mỗi dòng gom được bao nhiêu nét chính, từ trái sang (chẩn đoán).
    var chiTietDong: [String] = []
}

enum LamGonChu {

    /// Làm gọn một trang. Trả về bản MỚI — không đụng vào `goc`.
    ///
    /// - `vung`: chỉ làm các nét có tâm nằm trong vùng này (toạ độ trang);
    ///   `nil` = cả trang. Nét ngoài vùng ra y nguyên.
    /// - `dongKe`: toạ độ y các đường chân chữ của giấy (`GiayNenView.dongChanChu`).
    ///   Rỗng = giấy trắng, chỉ nắn thẳng mà không đặt lên dòng.
    static func lamGon(_ goc: PKDrawing, tuyChon: TuyChonLamGon,
                       vung: CGRect? = nil, dongKe: [CGFloat] = []) -> KetQuaLamGon {
        let batDau = Date()
        var bo = BoLamGon(strokes: goc.strokes, tuyChon: tuyChon, vung: vung,
                          dongKe: dongKe.sorted())
        bo.chay()
        var kq = KetQuaLamGon(drawing: PKDrawing(strokes: bo.ketQua))
        kq.soNetDoi = bo.soNetDoi
        kq.soDong = bo.soDong
        kq.soBang = bo.soBang
        kq.soHinh = bo.soHinh
        kq.soNetThang = bo.soNetThang
        kq.gocDongTruoc = bo.gocDongTruoc
        kq.chiTietDong = bo.chiTietDong
        kq.mili = Date().timeIntervalSince(batDau) * 1000
        return kq
    }
}

// MARK: - Một nét trong lúc làm

private enum LoaiNet { case chu, nho, thang, hinh, khac }

private enum HinhNhanRa {
    case elip(tam: CGPoint, a: CGFloat, b: CGFloat, goc: CGFloat)
    /// Chữ nhật thẳng trục — tách riêng vì cạnh của nó gióng được với bảng.
    case chuNhat(CGRect)
    case daGiac([CGPoint])
    /// Mũi tên MỘT nét: thân a→mũi, rồi cánh 1, quay về mũi, cánh 2.
    case muiTen(duoi: CGPoint, mui: CGPoint, canh: CGFloat, nuaGoc: CGFloat, canhTruocBenTrai: Bool)
    /// Đầu mũi tên chữ V vẽ RIÊNG, gắn vào đầu một nét thẳng (chỉ số nét thân).
    case dauV(than: Int, dauCuoi: Bool, canh: CGFloat, nuaGoc: CGFloat, canhTruocBenTrai: Bool)
}

private final class NetLG {
    let goc: PKStroke
    let coMask: Bool
    /// Điểm dày (~1pt một điểm), TOẠ ĐỘ TRANG (đã tính `transform` của nét).
    var diem: [PKStrokePoint]
    var xy: [CGPoint]
    var khung: CGRect
    var trongPham = true
    var loai: LoaiNet = .khac
    /// Phép dời thêm do xếp dòng / canh ô (toạ độ trang).
    var bienDoi: CGAffineTransform = .identity
    var hinh: HinhNhanRa?
    /// Đoạn thẳng ĐÃ nắn (toạ độ trang, sau `bienDoi`).
    var doan: (CGPoint, CGPoint)?
    /// Đoạn thẳng thuộc một bảng: toạ độ đã gióng, không đi theo dòng chữ.
    var laDuongBang = false
    var dong = -1

    init(_ s: PKStroke) {
        goc = s
        coMask = s.mask != nil
        let t = s.transform
        // Nét bị kéo giãn bằng lasso thì `transform` có tỉ lệ ≠ 1: nhân vào
        // cỡ bút để nét dựng lại không mảnh/đậm hơn bản đang hiện.
        let tl = sqrt(abs(t.a * t.d - t.b * t.c))
        let giu = abs(tl - 1) < 0.001
        var ds: [PKStrokePoint] = []
        for p in s.path.interpolatedPoints(by: .distance(1.0)) {
            ds.append(PKStrokePoint.dayDu(location: p.location.applying(t), timeOffset: p.timeOffset,
                                    size: giu ? p.size : CGSize(width: p.size.width * tl,
                                                                height: p.size.height * tl),
                                    opacity: p.opacity, force: p.force,
                                    azimuth: p.azimuth, altitude: p.altitude,
                                    secondaryScale: p.secondaryScale, threshold: p.nguong))
        }
        if ds.isEmpty {
            // Nét một chấm: `interpolatedPoints` có thể trả rỗng.
            ds = s.path.map { p in
                PKStrokePoint.dayDu(location: p.location.applying(t), timeOffset: p.timeOffset,
                              size: p.size, opacity: p.opacity, force: p.force,
                              azimuth: p.azimuth, altitude: p.altitude,
                              secondaryScale: p.secondaryScale, threshold: p.nguong)
            }
        }
        diem = ds
        xy = ds.map(\.location)
        khung = HinhHoc.khung(xy)
    }

    var tam: CGPoint { CGPoint(x: khung.midX, y: khung.midY) }
    var coLon: CGFloat { max(khung.width, khung.height) }
}

// MARK: - Bộ làm

private struct BoLamGon {
    /// In chi tiết từng dòng vào `chiTietDong` (chỉ bản DEBUG / bộ kiểm macOS).
    #if DEBUG || LAMGON_MAC
    static let chanDoan = ProcessInfo.processInfo.environment["LAMGON_GO"] != nil
    #else
    static let chanDoan = false
    #endif
    let tuyChon: TuyChonLamGon
    let vung: CGRect?
    let dongKe: [CGFloat]
    var nets: [NetLG]
    var ketQua: [PKStroke] = []
    var soNetDoi = 0, soDong = 0, soBang = 0, soHinh = 0, soNetThang = 0
    var gocDongTruoc: [Double] = []
    var chiTietDong: [String] = []
    /// Cỡ chữ điển hình của trang (point) — mọi ngưỡng tính theo nó, để
    /// người viết chữ to và người viết chữ li ti đều ra đúng.
    var k: CGFloat = 10

    init(strokes: [PKStroke], tuyChon: TuyChonLamGon, vung: CGRect?, dongKe: [CGFloat]) {
        self.tuyChon = tuyChon
        self.vung = vung
        self.dongKe = dongKe
        nets = strokes.map(NetLG.init)
        if let vung {
            for n in nets { n.trongPham = vung.contains(n.tam) }
        }
    }

    private var trong: [NetLG] { nets.filter(\.trongPham) }

    mutating func chay() {
        guard tuyChon.coPhepNao, !trong.isEmpty else {
            ketQua = nets.map(\.goc)
            return
        }
        uocLuongCoChu()
        phanLoai()
        if tuyChon.nanHinh || tuyChon.nanBang { nhanHinh() }
        if tuyChon.nanBang { gionBang() }
        if tuyChon.nanHinh { timDauMuiTenRoi() }
        if tuyChon.thangHang { xepDong() }
        dungKetQua()
    }

    // MARK: 0. Cỡ chữ điển hình

    private mutating func uocLuongCoChu() {
        let ds = trong.filter { $0.coLon > 0.5 }
        guard !ds.isEmpty else { return }
        let m = HinhHoc.trungVi(ds.map(\.coLon))
        let chu = ds.filter { $0.coLon >= 0.3 * m && $0.coLon <= 3 * m }.map(\.khung.height)
        k = max(4, HinhHoc.trungVi(chu.isEmpty ? [m] : chu))
    }

    // MARK: 1. Phân loại

    private mutating func phanLoai() {
        for n in trong {
            let w = n.khung.width, h = n.khung.height
            // Ngưỡng dài ≥ 3,2 cỡ chữ: thân chữ cao (l, h, k, d) viết to tay dài
            // tới ~2,3 cỡ chữ và thẳng tăm tắp — coi nó là "nét thẳng" là nó rời
            // khỏi dòng chữ, bị bỏ lại khi cả dòng được nắn (đo 28/09).
            if n.coLon >= max(3.2 * k, 22), laThang(n.xy) {
                n.loai = .thang
            } else if h > 3.2 * k {
                n.loai = .khac          // hình vẽ tự do, ngoặc lớn — để yên
            } else if h < 0.55 * k && w < 1.0 * k {
                n.loai = .nho           // dấu thanh, dấu mũ, chấm i, gạch t
            } else {
                n.loai = .chu
            }
        }
    }

    /// Nét gần thẳng: lệch vuông góc nhỏ so với chiều dài, không đi đi lại lại,
    /// không khép kín.
    private func laThang(_ p: [CGPoint]) -> Bool {
        guard p.count >= 2, let a = p.first, let b = p.last else { return false }
        let (tam, huong, _, _) = HinhHoc.pca(p)
        var lo = CGFloat.infinity, hi = -CGFloat.infinity, lech: CGFloat = 0, tong: CGFloat = 0
        for q in p {
            let d = CGPoint(x: q.x - tam.x, y: q.y - tam.y)
            let t = d.x * huong.dx + d.y * huong.dy
            let v = abs(-d.x * huong.dy + d.y * huong.dx)
            lo = min(lo, t); hi = max(hi, t); lech = max(lech, v); tong += v * v
        }
        let dai = hi - lo
        guard dai > 1 else { return false }
        let rms = sqrt(tong / CGFloat(p.count))
        let dauCuoi = hypot(b.x - a.x, b.y - a.y)
        return dauCuoi > 0.8 * dai
            && HinhHoc.doDai(p) < 1.18 * dai
            && rms <= 0.035 * dai + 0.3
            && lech <= 0.08 * dai + 0.8
    }

    // MARK: 2. Nhận hình

    private mutating func nhanHinh() {
        for n in trong where n.loai != .thang && n.loai != .nho && !n.coMask
            && n.coLon >= max(2.4 * k, 18) {
            if let h = HinhHoc.nhanHinhKhep(n.xy) {
                n.hinh = h; n.loai = .hinh
            } else if let h = HinhHoc.nhanMuiTenMotNet(n.xy) {
                n.hinh = h; n.loai = .hinh
            }
        }
    }

    // MARK: 3. Bảng

    private struct DoanTruc {
        var net: Int            // chỉ số trong `nets`
        var ngang: Bool
        var toaDo: CGFloat      // y nếu ngang, x nếu dọc
        var tu: CGFloat, den: CGFloat
        var canh: Int = -1      // cạnh chữ nhật: 0 trái 1 phải 2 trên 3 dưới; -1 = nét thẳng
    }

    private mutating func gionBang() {
        let dungSai = max(5, 0.45 * k)
        // Đầu mút kẻ bảng tay lố/hụt tới 1,5 cỡ chữ là thường (kẻ nhanh).
        let dungSaiDau = max(16, 1.5 * k)
        let nguongTruc = 7.0 * CGFloat.pi / 180

        // 3a. Nắn mọi nét thẳng: ngang/dọc gần đúng thì thành đúng.
        var doans: [DoanTruc] = []
        for (i, n) in nets.enumerated() where n.trongPham && n.loai == .thang {
            var (a, b) = HinhHoc.doanKhop(n.xy)
            let g = atan2(b.y - a.y, b.x - a.x)
            let lechNgang = abs(sin(g)), lechDoc = abs(cos(g))
            if lechNgang < sin(nguongTruc) {
                let y = (a.y + b.y) / 2
                a.y = y; b.y = y
                doans.append(DoanTruc(net: i, ngang: true, toaDo: y,
                                      tu: min(a.x, b.x), den: max(a.x, b.x)))
            } else if lechDoc < sin(nguongTruc) {
                let x = (a.x + b.x) / 2
                a.x = x; b.x = x
                doans.append(DoanTruc(net: i, ngang: false, toaDo: x,
                                      tu: min(a.y, b.y), den: max(a.y, b.y)))
            }
            n.doan = (a, b)
        }
        for (i, n) in nets.enumerated() where n.trongPham {
            if case .chuNhat(let r)? = n.hinh {
                doans.append(DoanTruc(net: i, ngang: false, toaDo: r.minX, tu: r.minY, den: r.maxY, canh: 0))
                doans.append(DoanTruc(net: i, ngang: false, toaDo: r.maxX, tu: r.minY, den: r.maxY, canh: 1))
                doans.append(DoanTruc(net: i, ngang: true, toaDo: r.minY, tu: r.minX, den: r.maxX, canh: 2))
                doans.append(DoanTruc(net: i, ngang: true, toaDo: r.maxY, tu: r.minX, den: r.maxX, canh: 3))
            }
        }
        guard doans.count >= 4 else { return }

        // 3b. Nhóm các đường ngang theo y, đường dọc theo x ⇒ cùng một giá trị.
        func gom(_ ngang: Bool) {
            let chiSo = doans.indices.filter { doans[$0].ngang == ngang }
                .sorted { doans[$0].toaDo < doans[$1].toaDo }
            var nhom: [[Int]] = []
            for i in chiSo {
                if let cuoi = nhom.last?.last, doans[i].toaDo - doans[cuoi].toaDo <= dungSai {
                    nhom[nhom.count - 1].append(i)
                } else { nhom.append([i]) }
            }
            for g in nhom where g.count > 1 {
                // Trọng số theo độ dài: đường dài vẽ chính xác hơn đường ngắn.
                var tong: CGFloat = 0, w: CGFloat = 0
                for i in g { let d = doans[i].den - doans[i].tu; tong += doans[i].toaDo * d; w += d }
                let v = tong / max(w, 0.001)
                for i in g { doans[i].toaDo = v }
            }
        }
        gom(true); gom(false)

        // 3c. Đầu mút chạm (hoặc gần chạm) một đường vuông góc ⇒ kéo/cắt vừa khít.
        func giaTri(_ ngang: Bool) -> [(CGFloat, CGFloat, CGFloat)] {
            doans.filter { $0.ngang == ngang }.map { ($0.toaDo, $0.tu, $0.den) }
        }
        let doc = giaTri(false), ngang = giaTri(true)
        for i in doans.indices where doans[i].canh < 0 {
            let vuong = doans[i].ngang ? doc : ngang
            let td = doans[i].toaDo
            func hut(_ v: CGFloat) -> CGFloat {
                var tot = v, kc = dungSaiDau
                for (x, a, b) in vuong where td >= a - dungSaiDau && td <= b + dungSaiDau {
                    if abs(x - v) < kc { kc = abs(x - v); tot = x }
                }
                return tot
            }
            doans[i].tu = hut(doans[i].tu)
            doans[i].den = hut(doans[i].den)
        }

        // Ghi lại vào nét.
        var canhChuNhat: [Int: [Int: CGFloat]] = [:]
        for d in doans {
            let n = nets[d.net]
            if d.canh >= 0 {
                canhChuNhat[d.net, default: [:]][d.canh] = d.toaDo
                continue
            }
            guard let (a, b) = n.doan else { continue }
            // Giữ CHIỀU vẽ gốc (từ a sang b).
            if d.ngang {
                let xuoi = a.x <= b.x
                n.doan = (CGPoint(x: xuoi ? d.tu : d.den, y: d.toaDo),
                          CGPoint(x: xuoi ? d.den : d.tu, y: d.toaDo))
            } else {
                let xuoi = a.y <= b.y
                n.doan = (CGPoint(x: d.toaDo, y: xuoi ? d.tu : d.den),
                          CGPoint(x: d.toaDo, y: xuoi ? d.den : d.tu))
            }
        }
        for (i, c) in canhChuNhat {
            if let t = c[0], let p = c[1], let tr = c[2], let du = c[3] {
                nets[i].hinh = .chuNhat(CGRect(x: t, y: tr, width: p - t, height: du - tr))
            }
        }

        // 3d. Tìm bảng: các đường ngang/dọc cắt nhau thành một cụm có ≥2×2.
        let ds = doans
        var cha = Array(ds.indices)
        func goc(_ i: Int) -> Int { var i = i; while cha[i] != i { cha[i] = cha[cha[i]]; i = cha[i] }; return i }
        for i in ds.indices where ds[i].ngang {
            for j in ds.indices where !ds[j].ngang {
                let h = ds[i], v = ds[j]
                if h.toaDo >= v.tu - dungSaiDau && h.toaDo <= v.den + dungSaiDau
                    && v.toaDo >= h.tu - dungSaiDau && v.toaDo <= h.den + dungSaiDau {
                    cha[goc(i)] = goc(j)
                }
            }
            // Các cạnh của cùng một chữ nhật luôn chung cụm.
        }
        for i in ds.indices { for j in ds.indices where j > i && ds[i].net == ds[j].net { cha[goc(i)] = goc(j) } }
        var cum: [Int: [Int]] = [:]
        for i in ds.indices { cum[goc(i), default: []].append(i) }

        for (_, thanh) in cum {
            let ys = Array(Set(thanh.filter { ds[$0].ngang }.map { ds[$0].toaDo })).sorted()
            let xs = Array(Set(thanh.filter { !ds[$0].ngang }.map { ds[$0].toaDo })).sorted()
            guard ys.count >= 2, xs.count >= 2 else { continue }
            soBang += 1
            for i in thanh { nets[ds[i].net].laDuongBang = true }
            canhChuTrongO(xs: xs, ys: ys)
        }
    }

    /// Chữ trong ô bảng: dời vào GIỮA ô, thu nhỏ nếu tràn. Các nét này thôi
    /// không tham gia xếp dòng (hàng của bảng không phải dòng kẻ).
    private mutating func canhChuTrongO(xs: [CGFloat], ys: [CGFloat]) {
        var theoO: [Int: [NetLG]] = [:]
        for n in nets where n.trongPham && (n.loai == .chu || n.loai == .nho) && !n.laDuongBang {
            let c = n.tam
            guard c.x > xs[0], c.x < xs[xs.count - 1], c.y > ys[0], c.y < ys[ys.count - 1],
                  let cot = xs.lastIndex(where: { $0 < c.x }),
                  let hang = ys.lastIndex(where: { $0 < c.y }) else { continue }
            theoO[hang * 1000 + cot, default: []].append(n)
        }
        for (ma, ds) in theoO {
            let hang = ma / 1000, cot = ma % 1000
            let o = CGRect(x: xs[cot], y: ys[hang], width: xs[cot + 1] - xs[cot],
                           height: ys[hang + 1] - ys[hang])
            let dem = min(max(2, 0.12 * o.height), 6)
            let trongO = o.insetBy(dx: dem, dy: dem)
            guard trongO.width > 2, trongO.height > 2 else { continue }
            let b = ds.map(\.khung).reduce(CGRect.null) { $0.union($1) }
            let s = min(1, trongO.width / max(b.width, 0.1), trongO.height / max(b.height, 0.1))
            let t = CGAffineTransform(translationX: -b.midX, y: -b.midY)
                .concatenating(CGAffineTransform(scaleX: s, y: s))
                .concatenating(CGAffineTransform(translationX: trongO.midX, y: trongO.midY))
            for n in ds { n.bienDoi = t; n.dong = -2 }
        }
    }

    // MARK: 3e. Đầu mũi tên vẽ rời (nét thân thẳng + nét chữ V)

    private mutating func timDauMuiTenRoi() {
        for (i, than) in nets.enumerated() where than.trongPham && than.loai == .thang && !than.laDuongBang {
            let (a, b) = than.doan ?? HinhHoc.doanKhop(than.xy)
            let dai = hypot(b.x - a.x, b.y - a.y)
            guard dai > 3 * k else { continue }
            for (dauCuoi, mui, duoi) in [(true, b, a), (false, a, b)] {
                let huong = CGVector(dx: (mui.x - duoi.x) / dai, dy: (mui.y - duoi.y) / dai)
                for n in nets where n.trongPham && n !== than && n.hinh == nil && !n.coMask
                    && (n.loai == .chu || n.loai == .nho || n.loai == .khac)
                    && n.coLon < 0.6 * dai && n.coLon > 0.5 * k {
                    guard n.khung.insetBy(dx: -0.5 * k, dy: -0.5 * k).contains(mui),
                          let v = HinhHoc.nhanChuV(n.xy, mui: mui, huong: huong) else { continue }
                    n.hinh = .dauV(than: i, dauCuoi: dauCuoi, canh: v.canh, nuaGoc: v.nuaGoc,
                                   canhTruocBenTrai: v.traiTruoc)
                    n.loai = .hinh
                    break
                }
            }
        }
    }

    // MARK: 4. Xếp dòng

    private final class Dong {
        let k: CGFloat
        init(k: CGFloat) { self.k = k }
        var chinh: [NetLG] = []
        var tamX: [CGFloat] = [], tamY: [CGFloat] = [], chan: [CGFloat] = []
        var maxX: CGFloat = -.infinity, minX: CGFloat = .infinity
        /// Mô hình đường chân (hệ số góc, chân tại `xMoc`) — tính lại sau mỗi nét.
        private var doc: CGFloat = 0, chanMoc: CGFloat = 0, xMoc: CGFloat = 0
        func them(_ n: NetLG) {
            chinh.append(n); tamX.append(n.tam.x); tamY.append(n.tam.y); chan.append(n.khung.maxY)
            moHinhDay = nil
            maxX = max(maxX, n.khung.maxX); minX = min(minX, n.khung.minX)
            // Đường chân từ ~12 nét gần nhất: Theil–Sen trên chân nét (chữ có
            // đuôi là thiểu số), độ dốc chặn ±8° — chưa đủ dài thì coi là ngang.
            let m = min(12, chan.count)
            let xs = Array(tamX.suffix(m)), ys = Array(chan.suffix(m))
            let rong = (xs.max() ?? 0) - (xs.min() ?? 0)
            doc = (m >= 4 && rong > 3 * k) ? max(-0.14, min(0.14, HinhHoc.theilSen(xs, ys))) : 0
            xMoc = xs[m - 1]
            chanMoc = HinhHoc.chanChu(zip(xs, ys).map { $1 - doc * ($0 - xMoc) }, k: k)
        }
        /// Nuốt một mảnh dòng khác (xây lại mô hình theo thứ tự trái → phải).
        func gop(_ khac: Dong) {
            let ds = (chinh + khac.chinh).sorted { $0.khung.minX < $1.khung.minX }
            chinh = []; tamX = []; tamY = []; chan = []; maxX = -.infinity; minX = .infinity
            for n in ds { them(n) }
        }
        /// Đường chân dự đoán ở hoành độ x (mô hình CỤC BỘ — dùng lúc gom nét).
        func chanTai(_ x: CGFloat) -> CGFloat { chanMoc + doc * (x - xMoc) }
        /// Đường chân theo TOÀN dòng. Dùng khi ghép mảnh: suy ngược 150pt từ
        /// mô hình 12 nét cuối thì sai số độ dốc nhân lên thành cả nửa cỡ chữ.
        func chanToanDong(_ x: CGFloat) -> CGFloat {
            if moHinhDay == nil {
                let rong = maxX - minX
                let d = (chan.count >= 4 && rong > 3 * k) ? max(-0.21, min(0.21, HinhHoc.theilSen(tamX, chan))) : 0
                let x0 = (minX + maxX) / 2
                moHinhDay = (d, HinhHoc.chanChu(zip(tamX, chan).map { $1 - d * ($0 - x0) }, k: k), x0)
            }
            let (d, c, x0) = moHinhDay!
            return c + d * (x - x0)
        }
        private var moHinhDay: (CGFloat, CGFloat, CGFloat)?
        /// Tâm dải lõi (giữa chân và đỉnh chữ thường) ở hoành độ x.
        func duDoanY(_ x: CGFloat) -> CGFloat { chanTai(x) - 0.5 * k }
    }

    private mutating func xepDong() {
        let chinh = nets.filter { $0.trongPham && $0.loai == .chu && $0.dong == -1 }
            .sorted { $0.khung.minX < $1.khung.minX }
        var dongs: [Dong] = []
        // Nhận vào dòng theo độ CHỒNG DỌC với dải lõi dự đoán của dòng, không
        // theo tâm: tâm nét "h" (cao 1,8 lần) và nét "a" lệch nhau gần nửa cỡ
        // chữ, cộng thêm chữ nhảy là một dòng bị băm thành ba (đo 28/09).
        for n in chinh {
            var tot: Dong?, diem = CGFloat(0)
            for d in dongs where n.khung.minX - d.maxX < 3.5 * k {
                let y = d.duDoanY(n.tam.x)
                let chong = min(n.khung.maxY, y + 0.45 * k) - max(n.khung.minY, y - 0.45 * k)
                let tiLe = chong / max(1, min(n.khung.height, 0.9 * k))
                let e = abs(y - n.tam.y)
                let d2 = tiLe - e / (4 * k)
                if tiLe >= 0.45 && e < 1.1 * k && d2 > diem { diem = d2; tot = d }
            }
            if let tot { tot.them(n) } else { let d = Dong(k: k); d.them(n); dongs.append(d) }
        }
        // Ghép mảnh: dòng mở đầu bằng một chữ có đuôi (g, y) lấy chân ĐUÔI làm
        // chân dòng, và mấy nét đầu tách thành dòng riêng (đo 28/09: "ghi"
        // rời khỏi "chú môn sử"). Hai mảnh sát nhau theo chiều ngang mà chân
        // chữ khớp nhau thì là một dòng.
        var gopDuoc = true
        while gopDuoc {
            gopDuoc = false
            dongs.sort { $0.chinh.count > $1.chinh.count }
            outer: for i in dongs.indices {
                for j in dongs.indices where j > i {
                    let L = dongs[i], S = dongs[j]
                    let khe = max(L.minX, S.minX) - min(L.maxX, S.maxX)
                    guard khe < 3.5 * k else { continue }
                    let lech = HinhHoc.chanChu(zip(S.tamX, S.chan).map { $1 - L.chanToanDong($0) }, k: k)
                    // Chồng ngang nhiều thì phải khớp chặt hơn (hai dòng sát nhau).
                    let nguong = khe < -2 * k ? 0.4 * k : 0.8 * k
                    // Mảnh 1–2 nét (nét đuôi chữ g mở đầu dòng): chân nó là chân
                    // ĐUÔI, không so chân được — hỏi nó có chạm dải lõi của dòng.
                    let manhNho = S.chinh.count <= 2 && S.chinh.allSatisfy { n in
                        let c = L.chanToanDong(n.tam.x)
                        return min(n.khung.maxY, c) - max(n.khung.minY, c - k) >= 0.3 * k
                    }
                    if abs(lech) < nguong || manhNho {
                        L.gop(S); dongs.remove(at: j); gopDuoc = true
                        break outer
                    }
                }
            }
        }

        // "Dòng" chỉ gồm 1–2 nét thấp tè (dấu mũ ^ viết to, dấu ngã dài) thật ra
        // là dấu của dòng bên dưới — trả về làm dấu nhỏ để nó đi theo chữ chủ.
        // Để nguyên thì nó thành dòng riêng, bị nắn/đặt lên dòng kẻ riêng và
        // bay khỏi chữ cả chục point (đo 28/09, dấu ^ của "việt").
        dongs.removeAll { d in
            guard d.chinh.count <= 2, d.chinh.allSatisfy({ $0.khung.height < 0.6 * k }) else { return false }
            for n in d.chinh { n.loai = .nho }
            return true
        }

        // Dòng chỉ có một nét lẻ (một chữ số, một ký hiệu) thì không đủ căn cứ
        // để nắn — nhưng vẫn là một dòng để dấu của nó đi theo.
        for (i, d) in dongs.enumerated() { for n in d.chinh { n.dong = i } }

        // Dấu nhỏ ĐI THEO chữ của nó: tìm nét chính chồng ngang gần nhất.
        var chuCuaDau: [ObjectIdentifier: NetLG] = [:]
        let chinhCon = chinh.filter { $0.loai == .chu }
        // Dấu nằm TRÊN chữ là thường (sắc, huyền, hỏi, ngã, mũ, chấm i); dấu
        // DƯỚI chữ chỉ có dấu nặng. Nên chữ nằm TRÊN dấu bị phạt nửa cỡ chữ —
        // không thì dấu sắc kẹp giữa đuôi chữ "y" của dòng trên và chữ "ê" của
        // nó bị gán cho chữ "y" (khe hẹp hơn), rồi bay theo dòng trên (đo 28/09).
        func diemChu(_ s: NetLG, _ m: NetLG) -> CGFloat? {
            let mo = m.khung.insetBy(dx: -0.25 * k, dy: 0)
            guard s.tam.x >= mo.minX && s.tam.x <= mo.maxX else { return nil }
            let tren = m.khung.minY - s.khung.maxY      // dấu ở trên chữ
            let duoi = s.khung.minY - m.khung.maxY      // dấu ở dưới chữ
            return max(0, tren, duoi) + (duoi > tren ? 0.5 * k : 0)
        }
        var choSau: [NetLG] = []
        var dauCoChu: [(NetLG, NetLG)] = []
        for s in nets where s.trongPham && s.loai == .nho && s.dong == -1 {
            var tot: NetLG?, kc = 1.0 * k
            for m in chinhCon {
                if let g = diemChu(s, m), g < kc { kc = g; tot = m }
            }
            if let tot, kc < 0.5 * k {
                s.dong = tot.dong; chuCuaDau[ObjectIdentifier(s)] = tot; dauCoChu.append((s, tot)); continue
            }
            choSau.append(s)
        }
        // Dấu chồng dấu (ế, ể, ẫ…): dấu thanh nằm trên dấu mũ, xa chữ gốc —
        // bám vào dấu đã có chủ ngay dưới nó.
        for s in choSau {
            var tot: NetLG?, kc = 1.0 * k
            for m in chinhCon { if let g = diemChu(s, m), g < kc { kc = g; tot = m } }
            for (d, chu) in dauCoChu {
                guard let g = diemChu(s, d), g < 0.5 * k, g < kc else { continue }
                kc = g; tot = chu
            }
            if let tot { s.dong = tot.dong; chuCuaDau[ObjectIdentifier(s)] = tot; continue }
            if BoLamGon.chanDoan {
                chiTietDong.append("  dấu mồ côi \(s.khung.integral) k=\(String(format: "%.1f", k))")
            }
            // Không có chữ nào ngay trên/dưới (dấu chấm câu, dấu phẩy): về dòng
            // có tâm dự đoán gần nhất.
            var lech = 1.0 * k
            for (i, d) in dongs.enumerated()
            where s.tam.x > d.minX - 2 * k && s.tam.x < d.maxX + 2 * k {
                let e = abs(d.duDoanY(s.tam.x) - s.tam.y)
                if e < lech { lech = e; s.dong = i }
            }
        }

        // Gạch chân / gạch ngang / bút dạ quang ngay dưới-trên một dòng chữ.
        var kem: [Int: [NetLG]] = [:]
        for n in nets where n.trongPham && !n.laDuongBang && n.dong == -1
            && (n.loai == .thang || n.goc.ink.inkType == .marker) {
            let g = n.khung.width > 0 ? atan2(n.khung.height, n.khung.width) : .pi / 2
            guard g < 0.2 || n.goc.ink.inkType == .marker else { continue }
            for (i, d) in dongs.enumerated() {
                let chong = min(n.khung.maxX, d.maxX) - max(n.khung.minX, d.minX)
                guard chong > 0.5 * n.khung.width else { continue }
                let y = d.duDoanY(n.tam.x)
                if n.tam.y > y - 1.4 * k && n.tam.y < y + 1.3 * k { kem[i, default: []].append(n); n.dong = i; break }
            }
        }

        // Nắn từng dòng.
        var dongDaDung: [(y: CGFloat, tu: CGFloat, den: CGFloat)] = []
        // Dòng DÀI chọn dòng kẻ trước: một mảnh lẻ giành mất dòng kẻ thì cả
        // dòng chữ thật bị chặn không đặt xuống được.
        let thuTu = dongs.indices.sorted { dongs[$0].chinh.count > dongs[$1].chinh.count }
        for i in thuTu {
            let d = dongs[i]
            let rong = d.maxX - d.minX
            if BoLamGon.chanDoan { chiTietDong.append(d.chinh.map { "[\(Int($0.khung.minX)),\(Int($0.khung.minY))-\(Int($0.khung.maxY))]" }.joined()) }
            chiTietDong.append("\(d.chinh.count) nét x\(Int(d.minX))–\(Int(d.maxX)) y≈\(Int(d.tamY.reduce(0, +) / CGFloat(d.tamY.count)))")
            // Góc nghiêng: Theil–Sen trên (tâm x, CHÂN nét) — bền với chữ có
            // đuôi (g, y, p) vì chúng là thiểu số.
            var doc: CGFloat = 0
            if d.chinh.count >= 3 && rong >= 3 * k {
                doc = HinhHoc.theilSen(d.chinh.map(\.tam.x), d.chinh.map(\.khung.maxY))
            }
            var goc = atan(doc)
            gocDongTruoc.append(Double(goc * 180 / .pi))
            if abs(goc) > 12 * .pi / 180 { goc = 0 }  // nghiêng quá nhiều là cố ý
            let chanTho = d.chinh.map(\.khung.maxY)
            let xGiua = (d.minX + d.maxX) / 2
            let yGiua = HinhHoc.trungVi(zip(d.chinh, chanTho).map { n, y in y - doc * (n.tam.x - xGiua) })
            let tam = CGPoint(x: xGiua, y: yGiua)
            let xoay = CGAffineTransform(translationX: -tam.x, y: -tam.y)
                .concatenating(CGAffineTransform(rotationAngle: -goc))
                .concatenating(CGAffineTransform(translationX: tam.x, y: tam.y))

            // Chân chữ sau khi xoay.
            let chanXoay = d.chinh.map { n in n.xy.map { $0.applying(xoay).y }.max() ?? n.khung.maxY }
            let chan = HinhHoc.chanChu(chanXoay, k: k)

            // Đặt lên dòng kẻ gần nhất — trừ khi dòng kẻ đó đã có một dòng chữ
            // khác chồng ngang (hai dòng chữ dồn vào một dòng kẻ là đè nhau).
            var dy: CGFloat = 0
            if d.chinh.count >= 3, let dk = HinhHoc.ganNhat(dongKe, chan) {
                let cachDong = dongKe.count > 1 ? HinhHoc.trungVi(zip(dongKe.dropFirst(), dongKe).map { $0 - $1 }) : 3 * k
                let bi = dongDaDung.contains { abs($0.y - dk) < 0.5 && $0.tu < d.maxX && $0.den > d.minX }
                if !bi && abs(dk - chan) < 0.6 * cachDong {
                    dy = dk - chan
                    dongDaDung.append((dk, d.minX, d.maxX))
                }
            }
            if BoLamGon.chanDoan {
                chiTietDong.append("  góc \(String(format: "%.2f", goc * 180 / .pi))° chân \(String(format: "%.1f", chan)) → dời \(String(format: "%.1f", dy))")
            }
            let tDong = xoay.concatenating(CGAffineTransform(translationX: 0, y: dy))
            let chanMoi = chan + dy
            if abs(goc) > 0.001 || abs(dy) > 0.01 { soDong += 1 } else if d.chinh.count >= 3 { soDong += 1 }

            // Từng TỪ: về đúng đường chân, đều cỡ vừa phải.
            let tuTrongDong = chiaTu(d.chinh, bienDoi: tDong)
            var bienDoiTu: [ObjectIdentifier: CGAffineTransform] = [:]
            let coTu = tuTrongDong.filter { $0.nets.count >= 3 }.map(\.co)
            let coChuan = coTu.isEmpty ? 0 : HinhHoc.trungVi(coTu)
            for (j, t) in tuTrongDong.enumerated() {
                var lechChan = chanMoi - t.chan
                lechChan = abs(lechChan) <= 0.6 * k ? lechChan * 0.85 : 0
                var s: CGFloat = 1
                if coChuan > 0 && t.nets.count >= 3 && t.co > 0 {
                    s = max(0.88, min(1.14, sqrt(coChuan / t.co)))
                    if abs(s - 1) < 0.04 { s = 1 }
                    if s > 1 {
                        // Phóng to không được lấn sang từ bên cạnh.
                        let trai = j > 0 ? t.minX - tuTrongDong[j - 1].maxX : 2 * k
                        let phai = j + 1 < tuTrongDong.count ? tuTrongDong[j + 1].minX - t.maxX : 2 * k
                        let choPhep = 0.35 * max(0, min(trai, phai))
                        let nua = (t.maxX - t.minX) / 2
                        if nua > 0 { s = min(s, 1 + choPhep / nua) }
                    }
                }
                let cx = (t.minX + t.maxX) / 2
                let tTu = CGAffineTransform(translationX: -cx, y: -chanMoi)
                    .concatenating(CGAffineTransform(scaleX: s, y: s))
                    .concatenating(CGAffineTransform(translationX: cx, y: chanMoi + lechChan))
                for n in t.nets { bienDoiTu[ObjectIdentifier(n)] = tTu }
            }
            for n in d.chinh { n.bienDoi = tDong.concatenating(bienDoiTu[ObjectIdentifier(n)] ?? .identity) }
            for s in nets where s.trongPham && s.loai == .nho && s.dong == i {
                if let chu = chuCuaDau[ObjectIdentifier(s)] { s.bienDoi = chu.bienDoi } else { s.bienDoi = tDong }
            }
            for n in kem[i] ?? [] {
                n.bienDoi = tDong
                // Nét thẳng đã nắn ở bước bảng thì phải nắn LẠI sau khi dời.
                if n.loai == .thang { n.doan = nil }
            }
        }
    }

    private struct Tu { var nets: [NetLG]; var minX: CGFloat; var maxX: CGFloat; var chan: CGFloat; var co: CGFloat }

    private func chiaTu(_ ds: [NetLG], bienDoi t: CGAffineTransform) -> [Tu] {
        let khung = ds.map { n in (n, HinhHoc.khung(n.xy.map { $0.applying(t) })) }
            .sorted { $0.1.minX < $1.1.minX }
        var nhom: [[(NetLG, CGRect)]] = []
        var phai = -CGFloat.infinity
        for (n, r) in khung {
            if !nhom.isEmpty && r.minX <= phai + 0.5 * k {
                nhom[nhom.count - 1].append((n, r))
            } else { nhom.append([(n, r)]) }
            phai = max(phai, r.maxX)
        }
        return nhom.map { g in
            let hs = g.map(\.1.height).sorted()
            return Tu(nets: g.map(\.0), minX: g.map(\.1.minX).min()!, maxX: g.map(\.1.maxX).max()!,
                      chan: HinhHoc.chanChu(g.map(\.1.maxY), k: k),
                      co: hs[Int(Double(hs.count - 1) * 0.4)])
        }
    }

    // MARK: 5. Dựng nét ra

    private mutating func dungKetQua() {
        let sigma = max(0.5, min(1.5, 0.07 * k))
        // Đầu mũi tên chữ V cần đoạn thân ĐÃ nắn xong — dựng thân trước.
        var doanDaDung: [Int: (CGPoint, CGPoint)] = [:]
        var ra = [PKStroke?](repeating: nil, count: nets.count)

        func vietDoan(_ i: Int) -> (CGPoint, CGPoint)? {
            let n = nets[i]
            if let d = doanDaDung[i] { return d }
            guard tuyChon.nanBang else { return nil }
            var d: (CGPoint, CGPoint)
            if let s = n.doan, (n.laDuongBang || n.bienDoi.isIdentity) {
                d = s
            } else {
                d = HinhHoc.doanKhop(n.xy.map { $0.applying(n.bienDoi) })
                d = HinhHoc.batTruc(d, nguong: 7 * .pi / 180)
            }
            doanDaDung[i] = d
            return d
        }

        for (i, n) in nets.enumerated() {
            guard n.trongPham else { ra[i] = n.goc; continue }
            if n.coMask {
                // Nét đã bị tẩy một phần: mặt nạ nằm trong hệ toạ độ của nét,
                // dựng lại điểm là mặt nạ lệch khỏi chỗ đã tẩy. Chỉ dời nguyên khối.
                var s = n.goc
                if !n.bienDoi.isIdentity { s.transform = s.transform.concatenating(n.bienDoi); soNetDoi += 1 }
                ra[i] = s
                continue
            }
            var moi: [PKStrokePoint]?
            if n.loai == .thang, tuyChon.nanBang, let (a, b) = vietDoan(i) {
                moi = DungNet.doanThang(tu: a, den: b, mau: n.diem)
                soNetThang += 1
            } else if let h = n.hinh, case .dauV = h {
                if tuyChon.nanHinh { moi = dungHinh(h, mau: n.diem, vietDoan: vietDoan) }
            } else if let h = n.hinh {
                let chuNhatBang: Bool = { if case .chuNhat = h { return n.laDuongBang } else { return false } }()
                if tuyChon.nanHinh || (tuyChon.nanBang && chuNhatBang) {
                    moi = dungHinh(h, mau: n.diem, vietDoan: vietDoan)
                }
            }
            if moi != nil { soHinh += (n.loai == .hinh ? 1 : 0) }
            if moi == nil {
                if tuyChon.lamMuot {
                    moi = DungNet.lamMuot(n.diem, sigma: sigma).map { $0.doi(n.bienDoi) }
                } else if !n.bienDoi.isIdentity {
                    moi = n.diem.map { $0.doi(n.bienDoi) }
                }
            }
            guard var ds = moi, ds.count >= 1 else { ra[i] = n.goc; continue }
            if tuyChon.lamMuot { ds = DungNet.deuDoDay(ds) }
            ra[i] = DungNet.netMoi(tu: n.goc, diem: ds)
            soNetDoi += 1
        }
        ketQua = ra.enumerated().map { $1 ?? nets[$0].goc }
    }

    private func dungHinh(_ h: HinhNhanRa, mau: [PKStrokePoint],
                          vietDoan: (Int) -> (CGPoint, CGPoint)?) -> [PKStrokePoint]? {
        let dauGoc = mau.first?.location ?? .zero
        let chieuKim = HinhHoc.dienTichCoDau(mau.map(\.location)) > 0
        switch h {
        case .elip(let tam, let a, let b, let g):
            return DungNet.elip(tam: tam, a: a, b: b, goc: g, batDauGan: dauGoc, xuoi: chieuKim, mau: mau)
        case .chuNhat(let r):
            let d = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                     CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
            return DungNet.daGiac(d, batDauGan: dauGoc, xuoi: chieuKim, mau: mau)
        case .daGiac(let d):
            return DungNet.daGiac(d, batDauGan: dauGoc, xuoi: chieuKim, mau: mau)
        case .muiTen(let duoi, var mui, let canh, let nua, let trai):
            var duoiMoi = duoi
            (duoiMoi, mui) = HinhHoc.batTruc((duoi, mui), nguong: 6 * .pi / 180)
            return DungNet.muiTen(duoi: duoiMoi, mui: mui, canh: canh, nuaGoc: nua, traiTruoc: trai, mau: mau)
        case .dauV(let than, let dauCuoi, let canh, let nua, let trai):
            guard let (a, b) = vietDoan(than) else { return nil }
            let (mui, duoi) = dauCuoi ? (b, a) : (a, b)
            return DungNet.dauV(mui: mui, tuDuoi: duoi, canh: canh, nuaGoc: nua, traiTruoc: trai, mau: mau)
        }
    }
}

// MARK: - Hình học

enum HinhHoc {
    static func khung(_ p: [CGPoint]) -> CGRect {
        guard let f = p.first else { return .zero }
        var a = f.x, b = f.x, c = f.y, d = f.y
        for q in p { a = min(a, q.x); b = max(b, q.x); c = min(c, q.y); d = max(d, q.y) }
        return CGRect(x: a, y: c, width: b - a, height: d - c)
    }

    static func trungVi(_ v: [CGFloat]) -> CGFloat {
        guard !v.isEmpty else { return 0 }
        let s = v.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    static func doDai(_ p: [CGPoint]) -> CGFloat {
        var t: CGFloat = 0
        for i in p.indices.dropFirst() { t += hypot(p[i].x - p[i - 1].x, p[i].y - p[i - 1].y) }
        return t
    }

    static func ganNhat(_ ds: [CGFloat], _ v: CGFloat) -> CGFloat? {
        ds.min { abs($0 - v) < abs($1 - v) }
    }

    /// Tâm, hướng chính (vector đơn vị), hai trị riêng λ1 ≥ λ2.
    static func pca(_ p: [CGPoint]) -> (CGPoint, CGVector, CGFloat, CGFloat) {
        let n = CGFloat(max(p.count, 1))
        let mx = p.reduce(0) { $0 + $1.x } / n, my = p.reduce(0) { $0 + $1.y } / n
        var sxx: CGFloat = 0, syy: CGFloat = 0, sxy: CGFloat = 0
        for q in p { let dx = q.x - mx, dy = q.y - my; sxx += dx * dx; syy += dy * dy; sxy += dx * dy }
        sxx /= n; syy /= n; sxy /= n
        let g = 0.5 * atan2(2 * sxy, sxx - syy)
        let tr = sxx + syy, det = sxx * syy - sxy * sxy
        let r = sqrt(max(0, tr * tr / 4 - det))
        return (CGPoint(x: mx, y: my), CGVector(dx: cos(g), dy: sin(g)), tr / 2 + r, max(0, tr / 2 - r))
    }

    /// Đoạn thẳng khớp nhất với các điểm, giữ chiều vẽ (đầu gần điểm đầu).
    static func doanKhop(_ p: [CGPoint]) -> (CGPoint, CGPoint) {
        let (tam, h, _, _) = pca(p)
        var lo = CGFloat.infinity, hi = -CGFloat.infinity
        for q in p { let t = (q.x - tam.x) * h.dx + (q.y - tam.y) * h.dy; lo = min(lo, t); hi = max(hi, t) }
        var a = CGPoint(x: tam.x + h.dx * lo, y: tam.y + h.dy * lo)
        var b = CGPoint(x: tam.x + h.dx * hi, y: tam.y + h.dy * hi)
        if let f = p.first, hypot(f.x - a.x, f.y - a.y) > hypot(f.x - b.x, f.y - b.y) { swap(&a, &b) }
        return (a, b)
    }

    /// Gần ngang/dọc (trong `nguong` radian) thì thành ngang/dọc tuyệt đối.
    static func batTruc(_ d: (CGPoint, CGPoint), nguong: CGFloat) -> (CGPoint, CGPoint) {
        var (a, b) = d
        let g = atan2(b.y - a.y, b.x - a.x)
        if abs(sin(g)) < sin(nguong) { let y = (a.y + b.y) / 2; a.y = y; b.y = y }
        else if abs(cos(g)) < sin(nguong) { let x = (a.x + b.x) / 2; a.x = x; b.x = x }
        return (a, b)
    }

    static func hoiQuy(_ xs: [CGFloat], _ ys: [CGFloat]) -> (CGFloat, CGFloat)? {
        let n = CGFloat(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        var sxx: CGFloat = 0, sxy: CGFloat = 0
        for i in xs.indices { sxx += (xs[i] - mx) * (xs[i] - mx); sxy += (xs[i] - mx) * (ys[i] - my) }
        guard sxx > 1 else { return nil }
        let a = sxy / sxx
        return (a, my - a * mx)
    }

    /// Hệ số góc Theil–Sen: trung vị hệ số góc của mọi cặp điểm.
    static func theilSen(_ xs: [CGFloat], _ ys: [CGFloat]) -> CGFloat {
        var s: [CGFloat] = []
        let n = xs.count
        let buoc = max(1, n / 60)   // dòng rất dài: lấy mẫu cho khỏi O(n²)
        var i = 0
        while i < n {
            var j = i + 1
            while j < n {
                let dx = xs[j] - xs[i]
                if abs(dx) > 1 { s.append((ys[j] - ys[i]) / dx) }
                j += buoc
            }
            i += buoc
        }
        return trungVi(s)
    }

    /// Đường chân chữ từ chân các nét: lấy CỤM đông nhất (chữ có đuôi g/y/p
    /// nằm thấp hơn cả nửa cỡ chữ, chữ nhảy cao là thiểu số), trung vị cụm đó.
    static func chanChu(_ chan: [CGFloat], k: CGFloat) -> CGFloat {
        guard !chan.isEmpty else { return 0 }
        let r = 0.25 * k
        var tot = chan[0], dem = -1
        for c in chan {
            let n = chan.filter { abs($0 - c) <= r }.count
            if n > dem || (n == dem && c < tot) { dem = n; tot = c }
        }
        return trungVi(chan.filter { abs($0 - tot) <= r })
    }

    /// > 0 nếu điểm đi CÙNG chiều kim đồng hồ trên màn (y hướng xuống).
    static func dienTichCoDau(_ p: [CGPoint]) -> CGFloat {
        var s: CGFloat = 0
        for i in p.indices { let a = p[i], b = p[(i + 1) % p.count]; s += a.x * b.y - b.x * a.y }
        return s / 2
    }

    /// Lấy `n` điểm cách đều theo độ dài.
    static func mauDeu(_ p: [CGPoint], n: Int) -> [CGPoint] {
        guard p.count >= 2, n >= 2 else { return p }
        let L = doDai(p)
        guard L > 0 else { return Array(repeating: p[0], count: n) }
        var ra: [CGPoint] = [p[0]]
        let buoc = L / CGFloat(n - 1)
        var dich = buoc, daDi: CGFloat = 0
        for i in 1..<p.count {
            let a = p[i - 1], b = p[i]
            let d = hypot(b.x - a.x, b.y - a.y)
            while d > 0 && daDi + d >= dich && ra.count < n {
                let t = (dich - daDi) / d
                ra.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                dich += buoc
            }
            daDi += d
        }
        while ra.count < n { ra.append(p[p.count - 1]) }
        return ra
    }

    static func goc(_ u: CGVector, _ v: CGVector) -> CGFloat {
        let a = hypot(u.dx, u.dy), b = hypot(v.dx, v.dy)
        guard a > 0, b > 0 else { return 0 }
        return acos(max(-1, min(1, (u.dx * v.dx + u.dy * v.dy) / (a * b))))
    }

    /// Douglas–Peucker, trả về CHỈ SỐ các đỉnh giữ lại.
    static func dp(_ p: [CGPoint], eps: CGFloat) -> [Int] {
        guard p.count > 2 else { return Array(p.indices) }
        var giu = [Bool](repeating: false, count: p.count)
        giu[0] = true; giu[p.count - 1] = true
        var ngan: [(Int, Int)] = [(0, p.count - 1)]
        while let (a, b) = ngan.popLast() {
            guard b > a + 1 else { continue }
            let A = p[a], B = p[b]
            let L = max(hypot(B.x - A.x, B.y - A.y), 0.0001)
            var xa: CGFloat = -1, im = -1
            for i in (a + 1)..<b {
                let d = hypot(B.x - A.x, B.y - A.y) < 0.0001
                    ? hypot(p[i].x - A.x, p[i].y - A.y)
                    : abs((B.x - A.x) * (A.y - p[i].y) - (A.x - p[i].x) * (B.y - A.y)) / L
                if d > xa { xa = d; im = i }
            }
            if xa > eps { giu[im] = true; ngan.append((a, im)); ngan.append((im, b)) }
        }
        return p.indices.filter { giu[$0] }
    }

    static func kcDenDoan(_ q: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let L2 = dx * dx + dy * dy
        guard L2 > 0 else { return hypot(q.x - a.x, q.y - a.y) }
        let t = max(0, min(1, ((q.x - a.x) * dx + (q.y - a.y) * dy) / L2))
        return hypot(q.x - a.x - t * dx, q.y - a.y - t * dy)
    }

    // MARK: Nhận hình khép kín

    fileprivate static func nhanHinhKhep(_ goc: [CGPoint]) -> HinhNhanRa? {
        guard goc.count >= 8 else { return nil }
        let r = khung(goc)
        let co = max(r.width, r.height)
        guard co > 0, min(r.width, r.height) > 0.12 * co else { return nil }
        // Cắt phần vẽ LỐ qua điểm đầu (vòng tròn tay thường khép chồng lên).
        var p = goc
        let dau = p[0]
        var catTai = p.count - 1, kcMin = CGFloat.infinity
        let tu = Int(Double(p.count) * 0.7)
        for i in tu..<p.count {
            let d = hypot(p[i].x - dau.x, p[i].y - dau.y)
            if d < kcMin { kcMin = d; catTai = i }
        }
        guard kcMin <= 0.22 * co else { return nil }
        p = Array(p[0...catTai])
        let N = 96
        let v = mauDeu(p, n: N)
        let chuVi = doDai(p) + kcMin
        guard chuVi > 2.4 * co else { return nil }   // không phải một vòng

        // Góc: độ quẹo ở thang ~6% chu vi, cực đại cục bộ.
        let buoc = max(2, Int(Double(N) * 0.06))
        var quep = [CGFloat](repeating: 0, count: N)
        for i in 0..<N {
            let a = v[(i - buoc + N) % N], b = v[i], c = v[(i + buoc) % N]
            quep[i] = HinhHoc.goc(CGVector(dx: b.x - a.x, dy: b.y - a.y), CGVector(dx: c.x - b.x, dy: c.y - b.y))
        }
        var dinh: [Int] = []
        for i in 0..<N where quep[i] > 0.9 {
            var laMax = true
            for d in 1...buoc where quep[(i + d) % N] > quep[i] || quep[(i - d + N) % N] >= quep[i] { laMax = false }
            if laMax { dinh.append(i) }
        }
        let cheo = hypot(r.width, r.height)
        func loiDaGiac(_ d: [CGPoint]) -> CGFloat {
            var t: CGFloat = 0
            for q in v {
                var m = CGFloat.infinity
                for i in d.indices { m = min(m, kcDenDoan(q, d[i], d[(i + 1) % d.count])) }
                t += m
            }
            return t / CGFloat(v.count) / cheo
        }
        // Elip theo mô-men (điểm cách đều ⇒ σ trục = a/√2).
        let (tam, h, l1, l2) = pca(v)
        let a = sqrt(2 * l1), b = sqrt(2 * l2)
        var loiElip: CGFloat = 0
        for q in v {
            let dx = q.x - tam.x, dy = q.y - tam.y
            let u = dx * h.dx + dy * h.dy, w = -dx * h.dy + dy * h.dx
            loiElip += abs(sqrt((u / a) * (u / a) + (w / b) * (w / b)) - 1)
        }
        loiElip /= CGFloat(v.count)

        if dinh.count == 4 || dinh.count == 3 {
            let d = dinh.map { v[$0] }
            let e = loiDaGiac(d)
            if dinh.count == 4 {
                var vuong = true
                for i in 0..<4 {
                    let p0 = d[(i + 3) % 4], p1 = d[i], p2 = d[(i + 1) % 4]
                    let g = HinhHoc.goc(CGVector(dx: p0.x - p1.x, dy: p0.y - p1.y), CGVector(dx: p2.x - p1.x, dy: p2.y - p1.y))
                    if abs(g - .pi / 2) > 0.4 { vuong = false }
                }
                if vuong && e < 0.03 && e < loiElip * 0.35 {
                    return chuNhatTu(d)
                }
            } else if e < 0.03 && e < loiElip * 0.45 {
                // Cạnh gần ngang/dọc (đáy tam giác) thì cho ngang/dọc hẳn.
                var dd = d
                for i in 0..<3 {
                    let a = dd[i], b = dd[(i + 1) % 3]
                    let g = atan2(b.y - a.y, b.x - a.x)
                    if abs(sin(g)) < sin(6 * .pi / 180) {
                        let y = (a.y + b.y) / 2; dd[i].y = y; dd[(i + 1) % 3].y = y
                    } else if abs(cos(g)) < sin(6 * .pi / 180) {
                        let x = (a.x + b.x) / 2; dd[i].x = x; dd[(i + 1) % 3].x = x
                    }
                }
                return .daGiac(dd)
            }
        }
        guard loiElip < 0.07, a > 0, b > 0 else { return nil }
        if a / b < 1.15 {
            let rr = (a + b) / 2
            return .elip(tam: tam, a: rr, b: rr, goc: 0)
        }
        var g = atan2(h.dy, h.dx)
        let lech = remainder(g, .pi / 2)
        if abs(lech) < 10 * .pi / 180 { g -= lech }
        return .elip(tam: tam, a: a, b: b, goc: g)
    }

    private static func chuNhatTu(_ d: [CGPoint]) -> HinhNhanRa {
        // Hướng trung bình của 4 cạnh (quy về một góc phần tư).
        var sx: CGFloat = 0, sy: CGFloat = 0
        for i in 0..<4 {
            let a = d[i], b = d[(i + 1) % 4]
            let g = atan2(b.y - a.y, b.x - a.x) * 4
            sx += cos(g); sy += sin(g)
        }
        var g = atan2(sy, sx) / 4
        if abs(g) < 8 * .pi / 180 { g = 0 }
        let c = CGPoint(x: d.reduce(0) { $0 + $1.x } / 4, y: d.reduce(0) { $0 + $1.y } / 4)
        let ux = CGVector(dx: cos(g), dy: sin(g)), uy = CGVector(dx: -sin(g), dy: cos(g))
        var loX = CGFloat.infinity, hiX = -CGFloat.infinity, loY = CGFloat.infinity, hiY = -CGFloat.infinity
        // Cạnh = trung bình hai đỉnh mỗi phía, không phải đỉnh xa nhất.
        let chieu = d.map { p -> (CGFloat, CGFloat) in
            let dx = p.x - c.x, dy = p.y - c.y
            return (dx * ux.dx + dy * ux.dy, dx * uy.dx + dy * uy.dy)
        }
        let xs = chieu.map(\.0).sorted(), ys = chieu.map(\.1).sorted()
        loX = (xs[0] + xs[1]) / 2; hiX = (xs[2] + xs[3]) / 2
        loY = (ys[0] + ys[1]) / 2; hiY = (ys[2] + ys[3]) / 2
        if g == 0 { return .chuNhat(CGRect(x: c.x + loX, y: c.y + loY, width: hiX - loX, height: hiY - loY)) }
        let goc4 = [(loX, loY), (hiX, loY), (hiX, hiY), (loX, hiY)].map { (u, w) in
            CGPoint(x: c.x + u * ux.dx + w * uy.dx, y: c.y + u * ux.dy + w * uy.dy)
        }
        return .daGiac(goc4)
    }

    // MARK: Mũi tên

    /// Một nét: thân → mũi → cánh 1 → về mũi → cánh 2.
    fileprivate static func nhanMuiTenMotNet(_ p: [CGPoint]) -> HinhNhanRa? {
        let r = khung(p)
        let d = dp(p, eps: max(1.5, 0.05 * hypot(r.width, r.height))).map { p[$0] }
        guard d.count == 5 else { return nil }
        let A = d[0], B = d[1], C = d[2], B2 = d[3], D = d[4]
        let than = hypot(B.x - A.x, B.y - A.y)
        let c1 = hypot(C.x - B.x, C.y - B.y), c2 = hypot(D.x - B2.x, D.y - B2.y)
        guard than > 1.8 * max(c1, c2), hypot(B2.x - B.x, B2.y - B.y) < 0.4 * (c1 + c2) / 2,
              min(c1, c2) > 0.3 * max(c1, c2) else { return nil }
        let nguoc = CGVector(dx: A.x - B.x, dy: A.y - B.y)
        let g1 = goc(nguoc, CGVector(dx: C.x - B.x, dy: C.y - B.y))
        let g2 = goc(nguoc, CGVector(dx: D.x - B2.x, dy: D.y - B2.y))
        let cheo1 = nguoc.dx * (C.y - B.y) - nguoc.dy * (C.x - B.x)
        let cheo2 = nguoc.dx * (D.y - B2.y) - nguoc.dy * (D.x - B2.x)
        guard g1 > 0.17, g1 < 1.2, g2 > 0.17, g2 < 1.2, cheo1 * cheo2 < 0 else { return nil }
        return .muiTen(duoi: A, mui: B, canh: (c1 + c2) / 2,
                       nuaGoc: max(0.35, min(0.7, (g1 + g2) / 2)), canhTruocBenTrai: cheo1 > 0)
    }

    /// Nét chữ V có đỉnh sát `mui` và hai cánh chĩa NGƯỢC hướng thân.
    fileprivate static func nhanChuV(_ p: [CGPoint], mui: CGPoint, huong: CGVector)
        -> (canh: CGFloat, nuaGoc: CGFloat, traiTruoc: Bool)? {
        let r = khung(p)
        let d = dp(p, eps: max(1.0, 0.08 * hypot(r.width, r.height))).map { p[$0] }
        guard d.count == 3 else { return nil }
        let C = d[0], B = d[1], D = d[2]
        let c1 = hypot(C.x - B.x, C.y - B.y), c2 = hypot(D.x - B.x, D.y - B.y)
        guard hypot(B.x - mui.x, B.y - mui.y) < 0.45 * max(c1, c2),
              min(c1, c2) > 0.35 * max(c1, c2) else { return nil }
        let nguoc = CGVector(dx: -huong.dx, dy: -huong.dy)
        let g1 = goc(nguoc, CGVector(dx: C.x - B.x, dy: C.y - B.y))
        let g2 = goc(nguoc, CGVector(dx: D.x - B.x, dy: D.y - B.y))
        let cheo1 = nguoc.dx * (C.y - B.y) - nguoc.dy * (C.x - B.x)
        let cheo2 = nguoc.dx * (D.y - B.y) - nguoc.dy * (D.x - B.x)
        guard g1 > 0.17, g1 < 1.15, g2 > 0.17, g2 < 1.15, cheo1 * cheo2 < 0 else { return nil }
        return ((c1 + c2) / 2, max(0.35, min(0.7, (g1 + g2) / 2)), cheo1 > 0)
    }
}

// MARK: - Dựng điểm cho nét mới

enum DungNet {

    /// Khử run tay bằng lọc Gauss theo ĐỘ DÀI CUNG, tách nét tại các góc gãy
    /// để góc không bị bo tròn. Hai đầu mỗi đoạn giữ nguyên chỗ.
    static func lamMuot(_ ds: [PKStrokePoint], sigma: CGFloat) -> [PKStrokePoint] {
        let n = ds.count
        guard n >= 5 else { return ds }
        let p = ds.map(\.location)
        var s = [CGFloat](repeating: 0, count: n)
        for i in 1..<n { s[i] = s[i - 1] + hypot(p[i].x - p[i - 1].x, p[i].y - p[i - 1].y) }

        func gauss(_ vao: [CGPoint], _ sg: CGFloat, tu: Int, den: Int) -> [CGPoint] {
            var ra = vao
            let tam = 3 * sg
            for i in tu...den {
                var sx: CGFloat = 0, sy: CGFloat = 0, sw: CGFloat = 0
                var j = i
                while j >= tu && s[i] - s[j] <= tam { let w = exp(-pow(s[i] - s[j], 2) / (2 * sg * sg)); sx += vao[j].x * w; sy += vao[j].y * w; sw += w; j -= 1 }
                j = i + 1
                while j <= den && s[j] - s[i] <= tam { let w = exp(-pow(s[j] - s[i], 2) / (2 * sg * sg)); sx += vao[j].x * w; sy += vao[j].y * w; sw += w; j += 1 }
                let muot = CGPoint(x: sx / sw, y: sy / sw)
                // Sát hai đầu đoạn thì hoà dần về điểm gốc: cửa sổ bị cụt một
                // bên kéo điểm vào trong, đầu nét co ngắn lại.
                let kc = min(s[i] - s[tu], s[den] - s[i])
                let w = min(1, kc / (2 * sg))
                ra[i] = CGPoint(x: vao[i].x + (muot.x - vao[i].x) * w, y: vao[i].y + (muot.y - vao[i].y) * w)
            }
            return ra
        }

        // Tìm góc trên bản đã làm mượt sơ (run tay không tạo góc giả nữa).
        let so = gauss(p, sigma, tu: 0, den: n - 1)
        let L = max(2.0, 2.5 * sigma)
        var quep = [CGFloat](repeating: 0, count: n)
        var j = 0, k = 0
        for i in 0..<n {
            while j < i && s[i] - s[j + 1] >= L { j += 1 }
            if k < i { k = i }
            while k < n - 1 && s[k] - s[i] < L { k += 1 }
            guard s[i] - s[j] >= L * 0.8, s[k] - s[i] >= L * 0.8 else { continue }
            quep[i] = HinhHoc.goc(CGVector(dx: so[i].x - so[j].x, dy: so[i].y - so[j].y),
                                  CGVector(dx: so[k].x - so[i].x, dy: so[k].y - so[i].y))
        }
        var moc = [0]
        var i = 1
        while i < n - 1 {
            if quep[i] > 1.0 {
                // Cực đại trong cửa sổ ±L.
                var m = i
                var t = i
                while t < n - 1 && s[t] - s[i] <= L { if quep[t] > quep[m] { m = t }; t += 1 }
                if m - moc.last! >= 2 { moc.append(m) }
                i = t
            } else { i += 1 }
        }
        if moc.last! != n - 1 { moc.append(n - 1) }

        var muot = p
        for (a, b) in zip(moc, moc.dropFirst()) where b > a + 1 {
            let d = gauss(p, sigma, tu: a, den: b)
            for t in (a + 1)..<b { muot[t] = d[t] }
        }
        return ds.indices.map { ds[$0].voiViTri(muot[$0]) }
    }

    /// Kéo độ dày trong nét về gần trung vị (giữ 40% dao động, không phẳng
    /// hẳn — nét bút phẳng tuyệt đối nhìn như nét máy).
    static func deuDoDay(_ ds: [PKStrokePoint]) -> [PKStrokePoint] {
        guard ds.count >= 3 else { return ds }
        let w = HinhHoc.trungVi(ds.map(\.size.width)), h = HinhHoc.trungVi(ds.map(\.size.height))
        let f = HinhHoc.trungVi(ds.map(\.force))
        return ds.map { p in
            var ww = w + (p.size.width - w) * 0.4, hh = h + (p.size.height - h) * 0.4
            ww = max(0.7 * w, min(1.4 * w, ww)); hh = max(0.7 * h, min(1.4 * h, hh))
            return PKStrokePoint.dayDu(location: p.location, timeOffset: p.timeOffset,
                                 size: CGSize(width: ww, height: hh), opacity: p.opacity,
                                 force: f + (p.force - f) * 0.4, azimuth: p.azimuth, altitude: p.altitude,
                                 secondaryScale: p.secondaryScale, threshold: p.nguong)
        }
    }

    /// Bớt điểm dày (giữ ~1,5pt một điểm, luôn giữ điểm đầu/cuối và chỗ quẹo
    /// gắt) — điểm dày 1pt làm tệp nét phình gấp mấy lần mà không đẹp hơn.
    static func thuaBot(_ ds: [PKStrokePoint]) -> [PKStrokePoint] {
        guard ds.count > 4 else { return ds }
        var ra = [ds[0]]
        for i in 1..<(ds.count - 1) {
            let a = ra[ra.count - 1].location, b = ds[i].location, c = ds[i + 1].location
            let kc = hypot(b.x - a.x, b.y - a.y)
            let quep = HinhHoc.goc(CGVector(dx: b.x - a.x, dy: b.y - a.y), CGVector(dx: c.x - b.x, dy: c.y - b.y))
            if kc >= 1.0 || quep > 0.5 || kc < 0.001 { ra.append(ds[i]) }
        }
        ra.append(ds[ds.count - 1])
        return ra
    }

    /// Thuộc tính bút (cỡ, lực, thời điểm…) lấy theo TỈ LỆ vị trí trên nét gốc.
    private static func mauTai(_ mau: [PKStrokePoint], _ t: CGFloat) -> PKStrokePoint {
        guard !mau.isEmpty else {
            return PKStrokePoint.dayDu(location: .zero, timeOffset: 0, size: CGSize(width: 3, height: 3),
                                 opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2,
                                 secondaryScale: 1, threshold: 0)
        }
        let i = min(mau.count - 1, max(0, Int((t * CGFloat(mau.count - 1)).rounded())))
        return mau[i]
    }

    private static func theoDuong(_ ds: [CGPoint], mau: [PKStrokePoint]) -> [PKStrokePoint] {
        guard ds.count > 1 else { return ds.map { mauTai(mau, 0).voiViTri($0) } }
        return ds.indices.map { mauTai(mau, CGFloat($0) / CGFloat(ds.count - 1)).voiViTri(ds[$0]) }
    }

    private static func duongGap(_ dinh: [CGPoint], buoc: CGFloat = 1.5) -> [CGPoint] {
        var ra: [CGPoint] = []
        for (a, b) in zip(dinh, dinh.dropFirst()) {
            let n = max(1, Int(hypot(b.x - a.x, b.y - a.y) / buoc))
            // Đỉnh lặp HAI lần: PencilKit nội suy mượt qua các điểm điều khiển,
            // đỉnh đơn thì góc chữ nhật/mũi tên bị bo tròn đi ~0,2pt.
            ra.append(a)
            for i in 0..<n { let t = CGFloat(i) / CGFloat(n); ra.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)) }
        }
        if let c = dinh.last { ra.append(c) }
        return ra
    }

    static func doanThang(tu a: CGPoint, den b: CGPoint, mau: [PKStrokePoint]) -> [PKStrokePoint] {
        theoDuong(duongGap([a, b]), mau: mau)
    }

    static func elip(tam: CGPoint, a: CGFloat, b: CGFloat, goc: CGFloat, batDauGan dau: CGPoint,
                     xuoi: Bool, mau: [PKStrokePoint]) -> [PKStrokePoint] {
        // Bắt đầu ở góc tham số gần điểm đặt bút gốc, đi đúng chiều người vẽ.
        let dx = dau.x - tam.x, dy = dau.y - tam.y
        let u = dx * cos(goc) + dy * sin(goc), w = -dx * sin(goc) + dy * cos(goc)
        let t0 = atan2(w / max(b, 0.01), u / max(a, 0.01))
        let chuVi = 2 * CGFloat.pi * sqrt((a * a + b * b) / 2)
        let n = max(24, Int(chuVi / 1.5))
        var ds: [CGPoint] = []
        for i in 0...n {
            let t = t0 + (xuoi ? 1 : -1) * 2 * .pi * CGFloat(i) / CGFloat(n)
            let x = a * cos(t), y = b * sin(t)
            ds.append(CGPoint(x: tam.x + x * cos(goc) - y * sin(goc), y: tam.y + x * sin(goc) + y * cos(goc)))
        }
        return theoDuong(ds, mau: mau)
    }

    static func daGiac(_ dinh: [CGPoint], batDauGan dau: CGPoint, xuoi: Bool,
                       mau: [PKStrokePoint]) -> [PKStrokePoint] {
        guard !dinh.isEmpty else { return [] }
        let dauXuoi = HinhHoc.dienTichCoDau(dinh) > 0
        var d = dauXuoi == xuoi ? dinh : dinh.reversed()
        let i0 = d.indices.min { hypot(d[$0].x - dau.x, d[$0].y - dau.y) < hypot(d[$1].x - dau.x, d[$1].y - dau.y) } ?? 0
        d = Array(d[i0...] + d[..<i0])
        return theoDuong(duongGap(d + [d[0]]), mau: mau)
    }

    private static func haiCanh(mui: CGPoint, tuDuoi duoi: CGPoint, canh: CGFloat, nuaGoc: CGFloat,
                                traiTruoc: Bool) -> (CGPoint, CGPoint) {
        let g = atan2(duoi.y - mui.y, duoi.x - mui.x)
        let c1 = CGPoint(x: mui.x + canh * cos(g + nuaGoc), y: mui.y + canh * sin(g + nuaGoc))
        let c2 = CGPoint(x: mui.x + canh * cos(g - nuaGoc), y: mui.y + canh * sin(g - nuaGoc))
        // "Bên trái" theo cùng quy ước dấu tích chéo lúc nhận dạng.
        let nguoc = CGVector(dx: duoi.x - mui.x, dy: duoi.y - mui.y)
        let cheo1 = nguoc.dx * (c1.y - mui.y) - nguoc.dy * (c1.x - mui.x)
        return (cheo1 > 0) == traiTruoc ? (c1, c2) : (c2, c1)
    }

    static func muiTen(duoi: CGPoint, mui: CGPoint, canh: CGFloat, nuaGoc: CGFloat, traiTruoc: Bool,
                       mau: [PKStrokePoint]) -> [PKStrokePoint] {
        let dai = hypot(mui.x - duoi.x, mui.y - duoi.y)
        let (c1, c2) = haiCanh(mui: mui, tuDuoi: duoi, canh: min(canh, 0.4 * dai), nuaGoc: nuaGoc, traiTruoc: traiTruoc)
        return theoDuong(duongGap([duoi, mui, c1, mui, c2]), mau: mau)
    }

    static func dauV(mui: CGPoint, tuDuoi duoi: CGPoint, canh: CGFloat, nuaGoc: CGFloat, traiTruoc: Bool,
                     mau: [PKStrokePoint]) -> [PKStrokePoint] {
        let (c1, c2) = haiCanh(mui: mui, tuDuoi: duoi, canh: canh, nuaGoc: nuaGoc, traiTruoc: traiTruoc)
        return theoDuong(duongGap([c1, mui, c2]), mau: mau)
    }

    /// Nét mới mang ĐÚNG bút gốc (loại mực, màu, độ rộng) và hạt nhiễu gốc
    /// (bút chì/bút sáp giữ nguyên vân), toạ độ đã là toạ độ trang.
    static func netMoi(tu goc: PKStroke, diem: [PKStrokePoint]) -> PKStroke {
        let duong = PKStrokePath(controlPoints: diem, creationDate: goc.path.creationDate)
        if #available(iOS 16.0, macOS 13.0, *) {
            return PKStroke(ink: goc.ink, path: duong, transform: .identity, mask: nil,
                            randomSeed: goc.randomSeed)
        }
        return PKStroke(ink: goc.ink, path: duong, transform: .identity, mask: nil)
    }
}

extension PKStrokePoint {
    func voiViTri(_ p: CGPoint) -> PKStrokePoint {
        PKStrokePoint.dayDu(location: p, timeOffset: timeOffset, size: size, opacity: opacity,
                      force: force, azimuth: azimuth, altitude: altitude,
                      secondaryScale: secondaryScale, threshold: nguong)
    }
    fileprivate func doi(_ t: CGAffineTransform) -> PKStrokePoint {
        t.isIdentity ? self : voiViTri(location.applying(t))
    }
}
#endif
