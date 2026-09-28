#if os(iOS)
import PencilKit
import SwiftUI
import UIKit

// ════════════════════════════════════════════════════════════════
// ĐẶT HÌNH AI VẼ LÊN TRANG
//
// `HinhVeAI` (toạ độ trong khung `rong × cao`, cạnh dài = 1000) → `[PKStroke]`
// ở TOẠ ĐỘ TRANG, đặt vào vùng trống lớn nhất mà người dùng ĐANG NHÌN.
//
// Nét ra là `PKStroke` thật, cùng mực/màu/độ dày với bút đang cầm ⇒ tẩy,
// lasso chọn–dời–phóng, đổi màu như nét tự viết. Không có "đối tượng hình"
// riêng nào: đó là lý do không cần tự viết công cụ dời/phóng.
// ════════════════════════════════════════════════════════════════

enum VeLenTrang {

    /// Tìm khung đặt hình: trong `vungNhin` (toạ độ trang), bề rộng ~45–60%
    /// bề rộng trang, giữ tỉ lệ `tiLe` (rộng / cao), tránh đè `netCo`.
    ///
    /// Thử ba cỡ từ to tới nhỏ; mỗi cỡ quét lưới trong vùng nhìn, lấy chỗ
    /// KHÔNG đè nét nào gần tâm vùng nhìn nhất. Không cỡ nào trống ⇒ đặt
    /// giữa vùng nhìn ở cỡ vừa (người dùng dời bằng lasso được).
    static func timCho(vungNhin v: CGRect, trang: CGSize, tiLe: CGFloat,
                       netCo: [CGRect]) -> CGRect {
        let le: CGFloat = 16
        let nhin = v.insetBy(dx: min(le, v.width * 0.05), dy: min(le, v.height * 0.05))
        guard nhin.width > 40, nhin.height > 40, tiLe > 0 else {
            return CGRect(x: v.midX - 50, y: v.midY - 50, width: 100, height: 100)
        }
        let tam = CGPoint(x: nhin.midX, y: nhin.midY)
        // Nét cũ nở thêm 10pt: sát rạt nét chữ thì hình và chữ dính vào nhau.
        let vat = netCo.map { $0.insetBy(dx: -10, dy: -10) }

        func khung(rong: CGFloat) -> CGSize {
            var w = min(rong, nhin.width)
            var h = w / tiLe
            if h > nhin.height { h = nhin.height; w = h * tiLe }
            return CGSize(width: w, height: h)
        }

        let coThu: [CGFloat] = [0.6, 0.52, 0.45].map { trang.width * $0 }
        for rong in coThu {
            let k = khung(rong: rong)
            // Cỡ đã bị vùng nhìn ép nhỏ hơn 30% trang thì thôi, sang cỡ sau
            // cũng vậy — dùng luôn phương án giữa màn.
            if k.width < trang.width * 0.3 && k.height < nhin.height { continue }
            let buoc: CGFloat = 12
            var tot: (CGRect, CGFloat)?
            var y = nhin.minY
            while y + k.height <= nhin.maxY + 0.5 {
                var x = nhin.minX
                while x + k.width <= nhin.maxX + 0.5 {
                    let r = CGRect(x: x, y: y, width: k.width, height: k.height)
                    if !vat.contains(where: { $0.intersects(r) }) {
                        let d = hypot(r.midX - tam.x, r.midY - tam.y)
                        if tot == nil || d < tot!.1 { tot = (r, d) }
                    }
                    x += buoc
                }
                y += buoc
            }
            if let tot { return tot.0 }
        }
        let k = khung(rong: trang.width * 0.5)
        return CGRect(x: tam.x - k.width / 2, y: tam.y - k.height / 2, width: k.width, height: k.height)
    }

    /// Bút dùng cho nét AI: đúng bút đang cầm nếu là bút mực; đang cầm tẩy
    /// / lasso / thước thì bút mực xanh đậm 2,5pt.
    static func butChoAI(_ dangCam: PKInkingTool?) -> (PKInk, CGFloat) {
        if let b = dangCam {
            // Bút đánh dấu (marker) trong suốt và to — hình vẽ bằng nó thành
            // một mảng nhoè. Giữ màu, đổi sang bút mực.
            if b.inkType == .marker {
                return (PKInk(.pen, color: b.color.withAlphaComponent(1)), 2.5)
            }
            return (b.ink, min(max(b.width, 1.2), 8))
        }
        return (PKInk(.pen, color: UIColor(red: 0.09, green: 0.14, blue: 0.32, alpha: 1)), 2.5)
    }

    /// Đổi hình AI thành nét PencilKit ở toạ độ trang, co vừa `khung`.
    ///
    /// ⚠️ Điểm AI trả là ĐƯỜNG GẤP KHÚC thưa (tai mèo = 3 điểm). `PKStrokePath`
    /// coi điểm là điểm điều khiển của đường cong B-spline, nên với điểm thưa
    /// nó bo tròn góc, cắt cụt đầu mút. Rải thêm điểm mỗi ~4pt thì đường cong
    /// ôm sát đường gấp khúc — góc vẫn sắc, nét tròn vẫn tròn.
    static func taoNet(_ hinh: HinhVeAI, vao khung: CGRect, ink: PKInk, doDay: CGFloat,
                       mau: PKStrokePoint? = nil) -> [PKStroke] {
        let ty = min(khung.width / max(hinh.rong, 1), khung.height / max(hinh.cao, 1))
        let goc = CGPoint(x: khung.midX - hinh.rong * ty / 2, y: khung.midY - hinh.cao * ty / 2)
        let tocDo: CGFloat = 320   // pt/giây — nhịp tay viết bình thường
        // ⚠️ `size` của ĐIỂM không phải bề rộng của BÚT. Bút mảnh nhất người
        // dùng chọn (width 0,88) cho ra điểm cỡ ~2,6pt trong nét thật; điểm
        // 1,2pt với mực `.pen` thì PencilKit trên iPad thật KHÔNG vẽ ra gì —
        // nét nằm trong bản vẽ mà vô hình (đo 28/09/2026, iPad M5). Lấy cỡ
        // điểm của nét mẫu người dùng, và không bao giờ dưới 2,4pt.
        let co = max(mau?.size.width ?? 0, doDay * 2.2, 2.4)
        let batDau = Date()
        var ra: [PKStroke] = []
        for (i, n) in hinh.net.enumerated() {
            var d = n.map { CGPoint(x: goc.x + $0.x * ty, y: goc.y + $0.y * ty) }
            guard !d.isEmpty else { continue }
            // Một điểm (chấm mắt) ⇒ một nét cực ngắn cho PencilKit vẽ ra chấm.
            if d.count == 1 { d.append(CGPoint(x: d[0].x + 0.6, y: d[0].y + 0.3)) }
            let day = raiDiem(d, cachToiDa: 4)
            var t: TimeInterval = 0
            var diem: [PKStrokePoint] = []
            diem.reserveCapacity(day.count)
            for (j, p) in day.enumerated() {
                if j > 0 { t += Double(hypot(p.x - day[j - 1].x, p.y - day[j - 1].y) / tocDo) }
                // ⚠️ Khai ĐỦ `secondaryScale` + `threshold`. Init ngắn (không có
                // hai tham số này) cho ra nét VÔ HÌNH trên iPadOS 27: nét vẫn
                // vào bản vẽ (109 → 131 nét) nhưng không có một điểm mực nào,
                // kể cả khi dựng ảnh riêng — đo thật trên iPad M5 28/09/2026.
                // Máy ảo iOS 26 thì vẫn hiện, nên bàn thử không bắt được.
                // Có nét mẫu của chính người dùng thì chép luôn các thông số
                // đó — PencilKit của máy này chắc chắn vẽ được chúng.
                diem.append(PKStrokePoint.dayDu(location: p, timeOffset: t,
                                          size: CGSize(width: co, height: co),
                                          opacity: mau?.opacity ?? 1,
                                          force: mau?.force ?? 1,
                                          azimuth: mau?.azimuth ?? 0,
                                          altitude: mau?.altitude ?? .pi / 2,
                                          secondaryScale: mau?.secondaryScale ?? 1,
                                          threshold: mau?.nguong ?? 0))
            }
            let path = PKStrokePath(controlPoints: diem,
                                    creationDate: batDau.addingTimeInterval(Double(i) * 0.3))
            ra.append(PKStroke(ink: ink, path: path))
        }
        // Số nhãn ①②③ ở đúng chỗ AI chỉ, màu đỏ như lời thầy ghi chú: người
        // học viết tên nhãn cạnh số, đối chiếu với thẻ nhãn gợi ý. Cỡ cố định
        // theo trang (không co theo hình) để hình nhỏ vẫn đọc được số.
        let mucDo = PKInk(.pen, color: UIColor(red: 0.86, green: 0.16, blue: 0.2, alpha: 1))
        for n in hinh.nhanViTri {
            let tam = CGPoint(x: goc.x + n.diem.x * ty, y: goc.y + n.diem.y * ty)
            for (k, d) in SoNet.so(n.so, tam: tam, cao: 13).enumerated() {
                let day = raiDiem(d, cachToiDa: 2)
                var t: TimeInterval = 0
                let diem: [PKStrokePoint] = day.enumerated().map { j, p in
                    if j > 0 { t += Double(hypot(p.x - day[j - 1].x, p.y - day[j - 1].y) / tocDo) }
                    // Nét số cố định 2,4pt (mức thấp nhất PencilKit trên iPad thật
                    // còn vẽ ra — xem `co` ở trên): lấy cỡ bút người dùng thì
                    // bút to biến số thành một cục mực.
                    return PKStrokePoint.dayDu(location: p, timeOffset: t, size: CGSize(width: 2.4, height: 2.4),
                                               opacity: mau?.opacity ?? 1, force: mau?.force ?? 1,
                                               azimuth: mau?.azimuth ?? 0, altitude: mau?.altitude ?? .pi / 2,
                                               secondaryScale: mau?.secondaryScale ?? 1, threshold: mau?.nguong ?? 0)
                }
                let path = PKStrokePath(controlPoints: diem,
                                        creationDate: batDau.addingTimeInterval(Double(ra.count + k) * 0.3))
                ra.append(PKStroke(ink: mucDo, path: path))
            }
        }
        return ra
    }

    /// Rải điểm dọc đường gấp khúc sao cho hai điểm liền nhau cách ≤ `cachToiDa`.
    static func raiDiem(_ d: [CGPoint], cachToiDa: CGFloat) -> [CGPoint] {
        guard d.count > 1 else { return d }
        var ra: [CGPoint] = [d[0]]
        for i in 1..<d.count {
            let a = d[i - 1], b = d[i]
            let dai = hypot(b.x - a.x, b.y - a.y)
            let n = max(1, Int((dai / cachToiDa).rounded(.up)))
            for k in 1...n {
                let u = CGFloat(k) / CGFloat(n)
                ra.append(CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u))
            }
        }
        return ra
    }

    /// Thời gian vẽ dần: 2–4 giây, hình nhiều nét thì lâu hơn chút.
    static func thoiGianVeDan(soNet: Int) -> TimeInterval {
        min(4, max(2, 1.4 + Double(soNet) * 0.09))
    }
}

// MARK: - Chữ số bằng nét (cho số nhãn)

/// Chữ số 0–9 bằng nét đơn trong ô 0…1 (rộng 0,6), khoanh trong một vòng tròn.
enum SoNet {
    private static let mau: [Character: [[CGPoint]]] = {
        func p(_ a: [(CGFloat, CGFloat)]) -> [CGPoint] { a.map { CGPoint(x: $0.0, y: $0.1) } }
        return [
            "0": [p([(0.3, 0), (0.05, 0.2), (0, 0.5), (0.05, 0.8), (0.3, 1), (0.55, 0.8), (0.6, 0.5), (0.55, 0.2), (0.3, 0)])],
            "1": [p([(0.12, 0.2), (0.35, 0), (0.35, 1)])],
            "2": [p([(0.03, 0.22), (0.2, 0.02), (0.45, 0.02), (0.58, 0.22), (0.5, 0.45), (0, 1), (0.6, 1)])],
            "3": [p([(0.03, 0.08), (0.3, 0), (0.55, 0.15), (0.5, 0.4), (0.25, 0.48), (0.55, 0.6), (0.58, 0.85), (0.3, 1), (0.02, 0.92)])],
            "4": [p([(0.45, 1), (0.45, 0), (0, 0.7), (0.6, 0.7)])],
            "5": [p([(0.55, 0), (0.08, 0), (0.03, 0.45), (0.35, 0.4), (0.58, 0.6), (0.55, 0.88), (0.3, 1), (0.02, 0.9)])],
            "6": [p([(0.52, 0.05), (0.25, 0.05), (0.05, 0.35), (0.02, 0.75), (0.25, 1), (0.52, 0.9), (0.58, 0.65), (0.35, 0.48), (0.05, 0.6)])],
            "7": [p([(0, 0), (0.6, 0), (0.22, 1)])],
            "8": [p([(0.3, 0.48), (0.05, 0.25), (0.3, 0), (0.55, 0.25), (0.3, 0.48), (0.02, 0.73), (0.3, 1), (0.58, 0.73), (0.3, 0.48)])],
            "9": [p([(0.55, 0.4), (0.3, 0.52), (0.05, 0.35), (0.1, 0.08), (0.35, 0), (0.58, 0.2), (0.55, 0.65), (0.35, 1), (0.08, 0.95)])],
        ]
    }()

    /// Các nét của số `n` (chữ số cao `cao` pt) đặt giữa `tam`, kèm vòng tròn bao quanh.
    static func so(_ n: Int, tam: CGPoint, cao: CGFloat) -> [[CGPoint]] {
        let chu = Array(String(n))
        let rongMot = cao * 0.6, khe = cao * 0.2
        let rong = CGFloat(chu.count) * rongMot + CGFloat(max(0, chu.count - 1)) * khe
        var ra: [[CGPoint]] = []
        for (i, c) in chu.enumerated() {
            let x0 = tam.x - rong / 2 + CGFloat(i) * (rongMot + khe)
            let y0 = tam.y - cao / 2
            for net in mau[c] ?? [] {
                ra.append(net.map { CGPoint(x: x0 + $0.x * cao, y: y0 + $0.y * cao) })
            }
        }
        let r = max(cao * 0.95, rong / 2 + cao * 0.4)
        ra.append((0...36).map { k in
            let g = CGFloat(k) / 36 * 2 * .pi - .pi / 2
            return CGPoint(x: tam.x + r * cos(g), y: tam.y + r * sin(g))
        })
        return ra
    }
}

// MARK: - Tạo điểm nét an toàn cho mọi bản iOS

extension PKStrokePoint {
    /// `threshold` của điểm (iOS 26+), bản cũ không có thì 0.
    var nguong: CGFloat {
        if #available(iOS 26.0, *) { return threshold }
        return 0
    }

    /// Tạo điểm với ĐỦ thông số. ⚠️ Trên iPadOS 26+ PHẢI dùng init có
    /// `secondaryScale` + `threshold`: init ngắn cho ra nét VÔ HÌNH (nét vẫn
    /// nằm trong bản vẽ nhưng không có một điểm mực nào — đo thật trên iPad M5
    /// iPadOS 27, 28/09/2026: AI vẽ 22 nét, 109 → 131 nét, trang trống trơn).
    /// Máy ảo iOS 26 lại hiện bình thường nên bàn thử không bắt được.
    static func dayDu(location: CGPoint, timeOffset: TimeInterval, size: CGSize,
                      opacity: CGFloat, force: CGFloat, azimuth: CGFloat, altitude: CGFloat,
                      secondaryScale: CGFloat, threshold: CGFloat) -> PKStrokePoint {
        if #available(iOS 26.0, *) {
            return PKStrokePoint(location: location, timeOffset: timeOffset, size: size,
                                 opacity: opacity, force: force, azimuth: azimuth, altitude: altitude,
                                 secondaryScale: secondaryScale, threshold: threshold)
        }
        return PKStrokePoint(location: location, timeOffset: timeOffset, size: size,
                             opacity: opacity, force: force, azimuth: azimuth, altitude: altitude)
    }
}

// MARK: - Lớp xem trước "vẽ dần"

/// Lớp phủ tạm trên khung vẽ: hiện nét DẦN theo thời gian, như có người
/// đang cầm bút. Dùng `PKDrawing.image` nên mực y hệt nét thật sẽ ghi vào.
///
/// Không phải bản vẽ thật: không lưu, không hoàn tác. Hết giờ thì màn ngoài
/// gỡ lớp này và ghi cả cụm bằng `chenNet` (một bước ↶).
final class LopVeDan: UIView {
    private let net: [PKStroke]
    private let thoiGian: TimeInterval
    /// Độ dài (pt) từng nét và tổng — tiến độ chia theo QUÃNG ĐƯỜNG bút đi,
    /// không chia đều theo nét: nét dài vẽ lâu hơn nét ngắn, đúng như tay thật.
    private let doDai: [CGFloat]
    private let tong: CGFloat
    private let anh = UIImageView()
    private var dongHo: CADisplayLink?
    private var batDauLuc: CFTimeInterval = 0
    private var xong: (() -> Void)?
    /// Vùng bao cả hình (toạ độ trang) — chỉ dựng ảnh trong vùng này.
    private let vung: CGRect
    var tyLe: CGFloat = 1 { didSet { setNeedsLayout() } }

    init(net: [PKStroke], thoiGian: TimeInterval) {
        self.net = net
        self.thoiGian = max(0.3, thoiGian)
        doDai = net.map { s in
            let d = s.path.map(\.location)
            return zip(d, d.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) } + 1
        }
        tong = doDai.reduce(0, +)
        vung = net.reduce(CGRect.null) { $0.union($1.renderBounds) }.insetBy(dx: -4, dy: -4)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        anh.contentMode = .scaleToFill
        addSubview(anh)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) chưa dùng tới") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !vung.isNull else { return }
        anh.frame = CGRect(x: vung.minX * tyLe, y: vung.minY * tyLe,
                           width: vung.width * tyLe, height: vung.height * tyLe)
    }

    func batDau(xong: @escaping () -> Void) {
        self.xong = xong
        batDauLuc = CACurrentMediaTime()
        let d = CADisplayLink(target: self, selector: #selector(nhip))
        d.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
        d.add(to: .main, forMode: .common)
        dongHo = d
    }

    func dung() {
        dongHo?.invalidate()
        dongHo = nil
    }

    @objc private func nhip() {
        let u = min(1, (CACurrentMediaTime() - batDauLuc) / thoiGian)
        ve(tien: CGFloat(u))
        if u >= 1 {
            dung()
            let x = xong
            xong = nil
            x?()
        }
    }

    private func ve(tien: CGFloat) {
        guard !vung.isNull else { return }
        var conLai = tien * tong
        var ds: [PKStroke] = []
        for (i, s) in net.enumerated() {
            if conLai >= doDai[i] { ds.append(s); conLai -= doDai[i]; continue }
            // Nét đang vẽ dở: cắt theo quãng đường còn lại.
            let pts = Array(s.path)
            var da: CGFloat = 0
            var k = 1
            while k < pts.count {
                da += hypot(pts[k].location.x - pts[k - 1].location.x,
                            pts[k].location.y - pts[k - 1].location.y)
                if da > conLai { break }
                k += 1
            }
            if k >= 2 {
                let p = PKStrokePath(controlPoints: Array(pts.prefix(k)), creationDate: s.path.creationDate)
                ds.append(PKStroke(ink: s.ink, path: p, transform: s.transform))
            }
            break
        }
        let ty = tyLe * (window?.screen.scale ?? 2)
        anh.image = PKDrawing(strokes: ds).image(from: vung, scale: max(0.5, min(ty, 4)))
    }
}
// MARK: - Thẻ nhãn gợi ý

/// Thẻ nổi góc trên-trái màn viết: các nhãn của sơ đồ AI vừa vẽ — người học
/// TỰ viết nhãn vào hình (AI không viết chữ hộ, viết tay mới nhớ).
struct TheNhanGoiY: View {
    let nhan: [String]
    let dong: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "pencil.and.list.clipboard")
                    .foregroundStyle(AppColors.primary)
                Text(T("Tự viết nhãn vào hình"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer(minLength: 8)
                Button(action: dong) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(T("Đóng nhãn gợi ý"))
            }
            ForEach(Array(nhan.enumerated()), id: \.offset) { i, n in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(i + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.onPrimary)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(AppColors.secondary))
                    Text(n)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 280, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(AppColors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
#endif
