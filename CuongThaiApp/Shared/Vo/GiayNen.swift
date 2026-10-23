#if os(iOS)
import UIKit

/// Nền giấy vẽ bằng Core Graphics.
///
/// ⚠️ Vì sao KHÔNG dùng `UIColor(patternImage:)` cho dòng kẻ: pattern là màu
/// nền, nó lát gạch theo toạ độ MÀN HÌNH và không co giãn khi người dùng
/// phóng to. Chữ to gấp ba mà dòng kẻ giữ nguyên là thứ nhìn một giây đã
/// thấy sai. Ở đây nền nhận `tyLe` và tự vẽ lại — vài chục đường thẳng, rẻ
/// hơn nhiều so với việc nó sai.
final class GiayNenView: UIView {

    var giay: LoaiGiay = .keNgang { didSet { setNeedsDisplay() } }
    /// Khổ trang theo point, KHÔNG nhân tỷ lệ phóng.
    var khoTrang: CGSize = HuongGiay.doc.khoA4 { didSet { setNeedsDisplay() } }
    /// Chiều cao GỐC của trang (chưa nối dài). `nil` = bằng `khoTrang.height`.
    /// Giấy có bố cục theo cả trang (Cornell: dải tóm tắt ở đáy; 原稿用紙: cỡ
    /// ô) cần biết số này để phần nối dài là "thêm hàng", không phải kéo
    /// giãn cả bố cục.
    var caoGoc: CGFloat? { didSet { setNeedsDisplay() } }
    /// Tỷ lệ phóng hiện tại của khung vẽ.
    var tyLe: CGFloat = 1 { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        isUserInteractionEnabled = false
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) chưa dùng tới") }

    // MARK: Hằng số đo đạc (mm → point)

    nonisolated static func mm(_ x: CGFloat) -> CGFloat { x / 25.4 * 72 }
    nonisolated static let caoDong  = mm(8)    // vở kẻ ngang phổ thông
    nonisolated static let oLy      = mm(5)
    nonisolated static let leTrai   = mm(25)

    // MARK: Đường chân chữ (cho "Làm gọn chữ")

    /// Toạ độ y (toạ độ TRANG) của các đường chữ đứng lên, theo loại giấy.
    /// "Làm gọn chữ" đặt mỗi dòng chữ lên đường gần nhất.
    ///
    /// ⚠️ Phải khớp TỪNG SỐ với các hàm `ve…` bên dưới — đổi khoảng cách dòng
    /// ở đó mà quên ở đây thì chữ được "làm gọn" nằm lơ lửng giữa hai dòng kẻ.
    /// Giấy không có đường chân (trắng, 原稿用紙, khuông nhạc) trả rỗng: khi đó
    /// chỉ nắn dòng cho thẳng, không dời lên xuống.
    nonisolated static func dongChanChu(giay: LoaiGiay, khoTrang: CGSize, caoGoc: CGFloat? = nil) -> [CGFloat] {
        let h = khoTrang.height
        let hGoc = min(caoGoc ?? h, h)
        var ds: [CGFloat] = []
        switch giay {
        case .keNgang:
            var y = caoDong * 3
            while y < h - caoDong { ds.append(y); y += caoDong }
        case .cornell:
            var y = caoDong * 2
            while y < yTomTatCornell(h: h, hGoc: hGoc) { ds.append(y); y += caoDong }
        case .oLy, .cham:
            var y = oLy
            while y < h { ds.append(y); y += oLy }
        case .bonDong:
            // Chữ đứng lên dòng CHÂN (dòng thứ ba của mỗi hàng 4 dòng).
            let tang = mm(4.5), cachHang = mm(7)
            var y = mm(22)
            while y + tang * 3 < h - mm(12) { ds.append(y + tang * 2); y += tang * 3 + cachHang }
        case .luoiCode:
            let cao = mm(7)
            var y = mm(18)
            while y + cao <= h - mm(10) { ds.append(y + cao); y += cao }
        case .tuVung3Cot:
            // Chữ đứng lên đường kẻ dưới của mỗi hàng.
            var y = yBangTuVung + caoHangTuVung
            while y <= h - mm(10) { ds.append(y); y += caoHangTuVung }
        case .trang, .genkou, .nhacLy, .soDoTuDuy, .bangSoSanh:
            break
        }
        return ds
    }

    // Hằng số của mẫu trang — dùng chung cho bộ vẽ và `dongChanChu`.
    nonisolated static let yBangTuVung = mm(24)          // hết hàng tiêu đề cột
    nonisolated static let caoHangTuVung = mm(10)

    /// Mép trên dải tóm tắt Cornell: 20% chiều cao GỐC tính từ đáy — trang
    /// nối dài thì vùng ghi chép dài ra, dải tóm tắt giữ nguyên bề cao.
    nonisolated static func yTomTatCornell(h: CGFloat, hGoc: CGFloat) -> CGFloat {
        h - hGoc * 0.20
    }

    // MARK: Vẽ

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        VeGiay(giay: giay, khoTrang: khoTrang, caoGoc: caoGoc, tyLe: tyLe).ve(ctx, khung: bounds)
    }

    /// Vẽ giấy vào một context BẤT KỲ, không cần dựng `UIView` — dùng được ở
    /// luồng nền (ảnh thu nhỏ dựng trong `Task.detached`). Toạ độ TRANG, tỉ lệ 1.
    nonisolated static func ve(_ ctx: CGContext, giay: LoaiGiay, khoTrang: CGSize, caoGoc: CGFloat? = nil) {
        VeGiay(giay: giay, khoTrang: khoTrang, caoGoc: caoGoc, tyLe: 1)
            .ve(ctx, khung: CGRect(origin: .zero, size: khoTrang))
    }
}

/// Bộ vẽ giấy — tách khỏi `GiayNenView` (23/10/2026) để ảnh thu nhỏ / xuất
/// PDF vẽ được MẪU TRANG ở luồng nền mà không phải dựng một `UIView`.
/// Màu là `UIColor` động: gọi trong `UITraitCollection(...).performAsCurrent`
/// để ép chế độ sáng.
struct VeGiay {
    typealias G = GiayNenView
    let giay: LoaiGiay
    let khoTrang: CGSize
    let caoGoc: CGFloat?
    let tyLe: CGFloat

    // MARK: Màu

    /// Giấy ở chế độ tối KHÔNG phải là giấy trắng đảo màu — nó là mặt bảng
    /// tối, còn mực thì PencilKit tự đảo sang sáng. Để nền trắng ở chế độ tối
    /// là chói mắt trong lớp học buổi tối, đúng lúc người ta ghi nhiều nhất.
    private var mauNen: UIColor {
        UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1)
            : UIColor(red: 1.00, green: 0.995, blue: 0.98, alpha: 1) }
    }
    private var mauKe: UIColor {
        UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.14)
            : UIColor(red: 0.42, green: 0.55, blue: 0.75, alpha: 0.38) }
    }
    private var mauKeNhat: UIColor {
        UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.07)
            : UIColor(red: 0.42, green: 0.55, blue: 0.75, alpha: 0.18) }
    }
    private var mauLe: UIColor {
        UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(red: 0.85, green: 0.35, blue: 0.40, alpha: 0.38)
            : UIColor(red: 0.85, green: 0.30, blue: 0.35, alpha: 0.45) }
    }

    func ve(_ ctx: CGContext, khung bounds: CGRect) {

        mauNen.setFill()
        ctx.fill(bounds)

        ctx.saveGState()
        ctx.scaleBy(x: tyLe, y: tyLe)   // từ đây vẽ theo toạ độ TRANG
        defer { ctx.restoreGState() }

        // Nét mảnh dần khi phóng to thì dòng kẻ biến mất ở 5×; nét cố định
        // theo màn hình thì ở mức thu nhỏ nó dày thành một mảng xám. Chặn hai
        // đầu là đủ cho cả dải 0,5×–5×.
        let dayNet = max(0.35, min(1.2, 0.8 / tyLe))
        ctx.setLineWidth(dayNet)

        switch giay {
        case .trang:   break
        case .keNgang: veKeNgang(ctx, dayNet)
        case .oLy:     veLuoi(ctx)
        case .cham:    veCham(ctx)
        case .cornell: veCornell(ctx, dayNet)
        case .genkou:  veGenkou(ctx)
        case .nhacLy:  veNhacLy(ctx)
        case .bonDong: veBonDong(ctx, dayNet)
        case .luoiCode: veLuoiCode(ctx, dayNet)
        case .tuVung3Cot: veTuVung3Cot(ctx, dayNet)
        case .soDoTuDuy: veSoDoTuDuy(ctx, dayNet)
        case .bangSoSanh: veBangSoSanh(ctx, dayNet)
        }
    }

    // MARK: Nhãn của mẫu trang

    /// Nhãn nhỏ in hoa của mẫu trang ("GHI CHÉP", "NGHĨA"…). Vẽ bằng màu dòng
    /// kẻ — đủ đọc để biết vùng nào ghi gì, không tranh với chữ viết tay.
    private func nhan(_ s: String, _ p: CGPoint, canGiua: CGFloat? = nil, co: CGFloat = 7.5) {
        let chu: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: co, weight: .semibold),
            .foregroundColor: mauNhan,
            .kern: 0.8,
        ]
        let ns = s.uppercased() as NSString
        var o = p
        if let rong = canGiua {
            let kt = ns.size(withAttributes: chu)
            o.x = p.x + (rong - kt.width) / 2
        }
        ns.draw(at: o, withAttributes: chu)
    }

    private var mauNhan: UIColor {
        UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.34)
            : UIColor(red: 0.36, green: 0.47, blue: 0.66, alpha: 0.78) }
    }
    private var mauToNhat: UIColor {
        UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.035)
            : UIColor(red: 0.42, green: 0.55, blue: 0.75, alpha: 0.07) }
    }

    /// Từ vựng 3 cột: Từ / thuật ngữ · Nghĩa · Ví dụ. Hàng 10mm (đủ cho một
    /// từ kèm phiên âm nhỏ), hai vạch dọc chia cột, hàng tiêu đề có nền nhạt.
    /// Ôn bằng cách lấy tay/tờ giấy che một cột — đúng lối học từ của sinh viên.
    private func veTuVung3Cot(_ ctx: CGContext, _ dayNet: CGFloat) {
        let w = khoTrang.width, h = khoTrang.height
        let x0 = G.mm(10), x1 = w - G.mm(10)
        let xA = x0 + (x1 - x0) * 0.30, xB = x0 + (x1 - x0) * 0.64
        let yDau = G.mm(14), yBang = G.yBangTuVung, cao = G.caoHangTuVung
        var yCuoi = yBang
        while yCuoi + cao <= h - G.mm(10) { yCuoi += cao }

        mauToNhat.setFill()
        ctx.fill(CGRect(x: x0, y: yDau, width: x1 - x0, height: yBang - yDau))
        nhan(T("Từ / thuật ngữ"), CGPoint(x: x0, y: yDau + G.mm(3)), canGiua: xA - x0)
        nhan(T("Nghĩa"), CGPoint(x: xA, y: yDau + G.mm(3)), canGiua: xB - xA)
        nhan(T("Ví dụ"), CGPoint(x: xB, y: yDau + G.mm(3)), canGiua: x1 - xB)

        mauKe.setStroke()
        ctx.setLineWidth(dayNet)
        var y = yBang + cao
        while y <= yCuoi + 0.5 {
            ctx.move(to: CGPoint(x: x0, y: y)); ctx.addLine(to: CGPoint(x: x1, y: y))
            y += cao
        }
        for x in [xA, xB] {
            ctx.move(to: CGPoint(x: x, y: yDau)); ctx.addLine(to: CGPoint(x: x, y: yCuoi))
        }
        ctx.strokePath()

        mauLe.setStroke()
        ctx.setLineWidth(dayNet * 1.4)
        ctx.move(to: CGPoint(x: x0, y: yBang)); ctx.addLine(to: CGPoint(x: x1, y: yBang))
        ctx.strokePath()
    }

    /// Bảng so sánh: dòng chủ đề · bảng Tiêu chí | A | B (hàng 16mm, đủ hai
    /// dòng chữ) · dải KẾT LUẬN neo ở đáy (trang nối dài thì bảng dài ra, dải
    /// kết luận vẫn ở đáy — như Cornell).
    private func veBangSoSanh(_ ctx: CGContext, _ dayNet: CGFloat) {
        let w = khoTrang.width, h = khoTrang.height
        let x0 = G.mm(10), x1 = w - G.mm(10)
        let xTC = x0 + (x1 - x0) * 0.26, xGiua = xTC + (x1 - xTC) / 2
        let yChuDe = G.mm(17)
        let yBang = G.mm(24), caoTieuDe = G.mm(10), caoHang = G.mm(16)
        let yKetLuan = h - G.mm(30)
        var yCuoi = yBang + caoTieuDe
        while yCuoi + caoHang <= yKetLuan - G.mm(4) { yCuoi += caoHang }

        // Chủ đề
        nhan(T("So sánh"), CGPoint(x: x0, y: yChuDe - G.mm(4.5)))
        mauKeNhat.setStroke()
        ctx.setLineWidth(dayNet)
        ctx.move(to: CGPoint(x: x0 + G.mm(17), y: yChuDe)); ctx.addLine(to: CGPoint(x: x1, y: yChuDe))
        ctx.strokePath()

        // Hàng tiêu đề cột
        mauToNhat.setFill()
        ctx.fill(CGRect(x: x0, y: yBang, width: x1 - x0, height: caoTieuDe))
        ctx.fill(CGRect(x: x0, y: yBang + caoTieuDe, width: xTC - x0, height: yCuoi - yBang - caoTieuDe))
        nhan(T("Tiêu chí"), CGPoint(x: x0, y: yBang + G.mm(3)), canGiua: xTC - x0)
        nhan("A", CGPoint(x: xTC, y: yBang + G.mm(2.6)), canGiua: xGiua - xTC, co: 9)
        nhan("B", CGPoint(x: xGiua, y: yBang + G.mm(2.6)), canGiua: x1 - xGiua, co: 9)

        // Lưới
        mauKe.setStroke()
        ctx.setLineWidth(dayNet)
        var y = yBang + caoTieuDe + caoHang
        while y < yCuoi - 0.5 {
            ctx.move(to: CGPoint(x: x0, y: y)); ctx.addLine(to: CGPoint(x: x1, y: y))
            y += caoHang
        }
        for x in [xTC, xGiua] {
            ctx.move(to: CGPoint(x: x, y: yBang)); ctx.addLine(to: CGPoint(x: x, y: yCuoi))
        }
        ctx.strokePath()
        ctx.setLineWidth(dayNet * 1.2)
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: x0, y: yBang, width: x1 - x0, height: yCuoi - yBang),
                                 cornerRadius: G.mm(1.5)).cgPath)
        ctx.strokePath()
        mauLe.setStroke()
        ctx.setLineWidth(dayNet * 1.4)
        ctx.move(to: CGPoint(x: x0, y: yBang + caoTieuDe)); ctx.addLine(to: CGPoint(x: x1, y: yBang + caoTieuDe))
        ctx.strokePath()

        // Kết luận
        nhan(T("Kết luận"), CGPoint(x: x0, y: yKetLuan))
        mauKeNhat.setStroke()
        ctx.setLineWidth(dayNet)
        for i in 1...2 {
            let yy = yKetLuan + G.mm(4) + CGFloat(i) * G.mm(8)
            ctx.move(to: CGPoint(x: x0, y: yy)); ctx.addLine(to: CGPoint(x: x1, y: yy))
        }
        ctx.strokePath()
    }

    /// Sơ đồ tư duy: nền chấm thưa · nút CHỦ ĐỀ ở giữa khổ GỐC · 6 nhánh nét
    /// đứt tới 6 ô gợi ý. Tất cả nhạt — chỉ là khung để đặt ý, người viết vẫn
    /// tự do vẽ nhánh con ra ngoài.
    private func veSoDoTuDuy(_ ctx: CGContext, _ dayNet: CGFloat) {
        let w = khoTrang.width, h = khoTrang.height
        let hGoc = min(caoGoc ?? h, h)
        // Nền chấm thưa 6mm.
        mauKeNhat.setFill()
        let b = G.mm(6), r = max(0.45, min(1.1, 0.75 / tyLe))
        var yc = b
        while yc < h {
            var xc = b
            while xc < w { ctx.fillEllipse(in: CGRect(x: xc - r, y: yc - r, width: r * 2, height: r * 2)); xc += b }
            yc += b
        }

        let tam = CGPoint(x: w / 2, y: hGoc * 0.48)
        let rx = w * 0.15, ry = G.mm(13)
        let oTam = CGRect(x: tam.x - rx, y: tam.y - ry, width: rx * 2, height: ry * 2)
        let rongVe = w * 0.23, caoVe = G.mm(15)
        let banKinhX = w * 0.33, banKinhY = hGoc * 0.30
        let goc: [CGFloat] = [-150, -90, -30, 30, 90, 150].map { $0 * .pi / 180 }

        // Nhánh: đường cong nét đứt từ mép nút giữa ra ô gợi ý.
        mauKe.setStroke()
        ctx.setLineWidth(dayNet * 1.1)
        ctx.setLineDash(phase: 0, lengths: [G.mm(1.4), G.mm(1.2)])
        var oVe: [CGRect] = []
        for g in goc {
            let c = CGPoint(x: tam.x + cos(g) * banKinhX, y: tam.y + sin(g) * banKinhY)
            let o = CGRect(x: c.x - rongVe / 2, y: c.y - caoVe / 2, width: rongVe, height: caoVe)
            oVe.append(o)
            let tu = CGPoint(x: tam.x + cos(g) * rx, y: tam.y + sin(g) * ry)
            let toi = CGPoint(x: c.x - cos(g) * rongVe * 0.5, y: c.y - sin(g) * caoVe * 0.5)
            let dk = CGPoint(x: (tu.x + toi.x) / 2 + sin(g) * G.mm(6), y: (tu.y + toi.y) / 2)
            ctx.move(to: tu); ctx.addQuadCurve(to: toi, control: dk)
        }
        ctx.strokePath()
        // Ô gợi ý
        ctx.setLineDash(phase: 0, lengths: [G.mm(1), G.mm(1)])
        mauKeNhat.setStroke()
        for o in oVe {
            ctx.addPath(UIBezierPath(roundedRect: o, cornerRadius: caoVe / 2).cgPath)
        }
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        // Nút trung tâm
        mauToNhat.setFill()
        ctx.fillEllipse(in: oTam)
        mauLe.setStroke()
        ctx.setLineWidth(dayNet * 1.5)
        ctx.strokeEllipse(in: oTam)
        nhan(T("Chủ đề"), CGPoint(x: oTam.minX, y: oTam.minY + G.mm(2.2)), canGiua: oTam.width)
        nhan(T("Sơ đồ tư duy"), CGPoint(x: G.mm(10), y: G.mm(8)))
    }

    private func veKeNgang(_ ctx: CGContext, _ dayNet: CGFloat) {
        let w = khoTrang.width, h = khoTrang.height
        mauKe.setStroke()
        var y = G.caoDong * 3          // chừa đầu trang cho tiêu đề
        while y < h - G.caoDong {
            ctx.move(to: CGPoint(x: G.mm(12), y: y))
            ctx.addLine(to: CGPoint(x: w - G.mm(12), y: y))
            y += G.caoDong
        }
        ctx.strokePath()

        mauLe.setStroke()
        ctx.setLineWidth(dayNet * 1.3)
        ctx.move(to: CGPoint(x: G.leTrai, y: 0))
        ctx.addLine(to: CGPoint(x: G.leTrai, y: h))
        ctx.strokePath()
    }

    private func veLuoi(_ ctx: CGContext) {
        let w = khoTrang.width, h = khoTrang.height, b = G.oLy
        mauKeNhat.setStroke()
        var x: CGFloat = 0
        while x <= w { ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: h)); x += b }
        var y: CGFloat = 0
        while y <= h { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: w, y: y)); y += b }
        ctx.strokePath()

        // Mỗi 5 ô một đường đậm — mắt bám vào đó để đếm, đúng như giấy kẻ ô
        // thật. Thiếu nó thì lưới thành một mảng xám đều không định vị được.
        mauKe.setStroke()
        x = 0
        while x <= w { ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: h)); x += b * 5 }
        y = 0
        while y <= h { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: w, y: y)); y += b * 5 }
        ctx.strokePath()
    }

    private func veCham(_ ctx: CGContext) {
        let w = khoTrang.width, h = khoTrang.height, b = G.oLy
        mauKe.setFill()
        let r = max(0.5, min(1.4, 0.9 / tyLe))
        var y = b
        while y < h {
            var x = b
            while x < w {
                ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                x += b
            }
            y += b
        }
    }

    private func veCornell(_ ctx: CGContext, _ dayNet: CGFloat) {
        let w = khoTrang.width, h = khoTrang.height
        let xTuKhoa = w * 0.30            // cột trái: từ khoá / câu hỏi
        let yTomTat = G.yTomTatCornell(h: h, hGoc: min(caoGoc ?? h, h))   // dải dưới: tóm tắt

        mauKe.setStroke()
        var y = G.caoDong * 2
        while y < yTomTat {
            ctx.move(to: CGPoint(x: xTuKhoa + G.mm(3), y: y))
            ctx.addLine(to: CGPoint(x: w - G.mm(12), y: y))
            y += G.caoDong
        }
        ctx.strokePath()

        mauLe.setStroke()
        ctx.setLineWidth(dayNet * 1.4)
        ctx.move(to: CGPoint(x: xTuKhoa, y: 0))
        ctx.addLine(to: CGPoint(x: xTuKhoa, y: yTomTat))
        ctx.move(to: CGPoint(x: 0, y: yTomTat))
        ctx.addLine(to: CGPoint(x: w, y: yTomTat))
        ctx.strokePath()

        // Nhãn ba vùng (23/10/2026) — người mới dùng Cornell không phải đoán
        // cột trái để làm gì.
        nhan(T("Gợi ý · Câu hỏi"), CGPoint(x: G.mm(5), y: G.mm(6)))
        nhan(T("Ghi chép"), CGPoint(x: xTuKhoa + G.mm(4), y: G.mm(6)))
        nhan(T("Tóm tắt"), CGPoint(x: G.mm(5), y: yTomTat + G.mm(2.5)))
    }

    /// 原稿用紙 — giấy ô vuông của người Nhật. 20 cột × 20 hàng, mỗi ô có
    /// đường chữ thập mờ ở giữa để canh nét kanji vào đúng tâm. Đây là thứ
    /// khiến tập viết kanji ra đúng dáng chữ thay vì méo dần về bên phải.
    private func veGenkou(_ ctx: CGContext) {
        let w = khoTrang.width, h = khoTrang.height
        // 20×20 = 400 ô, đúng khuôn 原稿用紙 chuẩn. Cạnh ô lấy theo chiều
        // NGẮN hơn của hai ràng buộc để ô vuông thật sự vuông — trước đó tôi
        // chia theo bề ngang rồi lấp đầy chiều cao, ra 28 hàng và mất luôn
        // cái làm nên tờ giấy này.
        let le = G.mm(12)
        let hGoc = min(caoGoc ?? h, h)
        let soCot = 20
        // Cỡ ô tính theo khổ GỐC (20×20). Trang nối dài thì THÊM HÀNG cùng cỡ
        // ô xuống dưới — tính theo cả chiều cao đã nối thì ô vẫn như cũ (bề
        // ngang chặn), nhưng lưới 20 hàng lại trôi ra giữa phần nối.
        let canh = min((w - le * 2) / CGFloat(soCot), (hGoc - le * 2) / 20)
        let yGoc = (hGoc - canh * 20) / 2
        let soHang = 20 + max(0, Int(((h - hGoc) / canh).rounded(.down)))
        let rongThat = canh * CGFloat(soCot)
        let caoThat = canh * CGFloat(soHang)
        let xGoc = (w - rongThat) / 2

        // Chữ thập mờ trong từng ô — vẽ TRƯỚC để khung đè lên trên.
        mauKeNhat.setStroke()
        for hang in 0..<soHang {
            for cot in 0..<soCot {
                let x = xGoc + CGFloat(cot) * canh, y = yGoc + CGFloat(hang) * canh
                ctx.move(to: CGPoint(x: x + canh / 2, y: y + canh * 0.12))
                ctx.addLine(to: CGPoint(x: x + canh / 2, y: y + canh * 0.88))
                ctx.move(to: CGPoint(x: x + canh * 0.12, y: y + canh / 2))
                ctx.addLine(to: CGPoint(x: x + canh * 0.88, y: y + canh / 2))
            }
        }
        ctx.strokePath()

        mauKe.setStroke()
        for cot in 0...soCot {
            let x = xGoc + CGFloat(cot) * canh
            ctx.move(to: CGPoint(x: x, y: yGoc))
            ctx.addLine(to: CGPoint(x: x, y: yGoc + caoThat))
        }
        for hang in 0...soHang {
            let y = yGoc + CGFloat(hang) * canh
            ctx.move(to: CGPoint(x: xGoc, y: y))
            ctx.addLine(to: CGPoint(x: xGoc + rongThat, y: y))
        }
        ctx.strokePath()
    }

    /// Giấy tập viết tiếng Anh kiểu trường tiểu học: mỗi hàng 4 dòng.
    ///
    /// Từ trên xuống: đỉnh chữ hoa/chữ cao (b, d, h) · đường GIỮA nét đứt
    /// (đỉnh chữ thường a, c, e) · dòng CHÂN đậm hơn (mọi chữ đứng lên đây)
    /// · dòng ĐUÔI (g, j, p, q, y thò xuống). Thiếu đường giữa thì người mới
    /// tập viết chữ thường to nhỏ lung tung — đó là lý do giấy này tồn tại.
    private func veBonDong(_ ctx: CGContext, _ dayNet: CGFloat) {
        let w = khoTrang.width, h = khoTrang.height
        let x0 = G.mm(12), x1 = w - G.mm(12)
        let tang = G.mm(4.5)            // khoảng giữa hai dòng liền nhau
        let cachHang = G.mm(7)           // khoảng trống giữa hai hàng 4 dòng
        var y = G.mm(22)
        while y + tang * 3 < h - G.mm(12) {
            // Đỉnh + đuôi: nhạt.
            mauKeNhat.setStroke()
            ctx.setLineWidth(dayNet)
            ctx.setLineDash(phase: 0, lengths: [])
            for dy in [0, tang * 3] {
                ctx.move(to: CGPoint(x: x0, y: y + dy)); ctx.addLine(to: CGPoint(x: x1, y: y + dy))
            }
            ctx.strokePath()
            // Đường giữa: nét đứt.
            mauKe.setStroke()
            ctx.setLineDash(phase: 0, lengths: [G.mm(1.6), G.mm(1.2)])
            ctx.move(to: CGPoint(x: x0, y: y + tang)); ctx.addLine(to: CGPoint(x: x1, y: y + tang))
            ctx.strokePath()
            // Dòng chân: đậm nhất.
            ctx.setLineDash(phase: 0, lengths: [])
            mauLe.setStroke()
            ctx.setLineWidth(dayNet * 1.3)
            ctx.move(to: CGPoint(x: x0, y: y + tang * 2)); ctx.addLine(to: CGPoint(x: x1, y: y + tang * 2))
            ctx.strokePath()
            y += tang * 3 + cachHang
        }
        ctx.setLineDash(phase: 0, lengths: [])
    }

    /// Lưới viết code tay: cột số dòng bên trái, mỗi dòng mã cao 7mm chia ô
    /// 3,5mm để canh ký tự, và vạch thụt lề nhạt mỗi 4 ô (≈ một cấp thụt lề).
    private func veLuoiCode(_ ctx: CGContext, _ dayNet: CGFloat) {
        let w = khoTrang.width, h = khoTrang.height
        let cao = G.mm(7), o = G.mm(3.5)
        let xLe = G.mm(16)              // hết cột số dòng
        let yDau = G.mm(18)

        // Ô nhỏ: rất nhạt, chỉ để canh.
        mauKeNhat.setStroke()
        ctx.setLineWidth(dayNet * 0.8)
        var x = xLe + o
        while x < w - G.mm(8) {
            ctx.move(to: CGPoint(x: x, y: yDau)); ctx.addLine(to: CGPoint(x: x, y: h - G.mm(10)))
            x += o
        }
        ctx.strokePath()

        // Vạch thụt lề mỗi 4 ô.
        mauKe.setStroke()
        ctx.setLineDash(phase: 0, lengths: [G.mm(1), G.mm(1.5)])
        x = xLe + o * 4
        while x < w - G.mm(8) {
            ctx.move(to: CGPoint(x: x, y: yDau)); ctx.addLine(to: CGPoint(x: x, y: h - G.mm(10)))
            x += o * 4
        }
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        // Dòng + số dòng.
        mauKe.setStroke()
        ctx.setLineWidth(dayNet)
        let chu: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 7, weight: .regular),
            .foregroundColor: mauKe,
        ]
        var y = yDau
        while y + cao <= h - G.mm(10) {
            ctx.move(to: CGPoint(x: xLe, y: y + cao)); ctx.addLine(to: CGPoint(x: w - G.mm(8), y: y + cao))
            y += cao
        }
        ctx.strokePath()
        // Số dòng vẽ SAU khi đã nét xong đường kẻ: vẽ chữ giữa lúc đang gom
        // path thì path đang dở có thể bị bỏ.
        y = yDau
        var so = 1
        while y + cao <= h - G.mm(10) {
            let s = "\(so)" as NSString
            let kt = s.size(withAttributes: chu)
            s.draw(at: CGPoint(x: xLe - G.mm(2) - kt.width, y: y + cao - kt.height - 1), withAttributes: chu)
            y += cao; so += 1
        }

        // Mép cột số dòng.
        mauLe.setStroke()
        ctx.setLineWidth(dayNet * 1.3)
        ctx.move(to: CGPoint(x: xLe, y: 0)); ctx.addLine(to: CGPoint(x: xLe, y: h))
        ctx.strokePath()
    }

    private func veNhacLy(_ ctx: CGContext) {
        let w = khoTrang.width, h = khoTrang.height
        let cachDong = G.mm(2.2)        // khoảng cách 5 dòng trong một khuông
        let cachKhuong = G.mm(20)
        mauKe.setStroke()
        var yKhuong = G.mm(20)
        while yKhuong + cachDong * 4 < h - G.mm(15) {
            for i in 0..<5 {
                let y = yKhuong + CGFloat(i) * cachDong
                ctx.move(to: CGPoint(x: G.mm(12), y: y))
                ctx.addLine(to: CGPoint(x: w - G.mm(12), y: y))
            }
            yKhuong += cachKhuong
        }
        ctx.strokePath()
    }}
#endif
