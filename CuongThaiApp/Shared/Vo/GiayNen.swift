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
    /// Tỷ lệ phóng hiện tại của khung vẽ.
    var tyLe: CGFloat = 1 { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        isUserInteractionEnabled = false
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) chưa dùng tới") }

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

    // MARK: Hằng số đo đạc (mm → point)

    private static func mm(_ x: CGFloat) -> CGFloat { x / 25.4 * 72 }
    private static let caoDong  = mm(8)    // vở kẻ ngang phổ thông
    private static let oLy      = mm(5)
    private static let leTrai   = mm(25)

    // MARK: Vẽ

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

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
        }
    }

    private func veKeNgang(_ ctx: CGContext, _ dayNet: CGFloat) {
        let w = khoTrang.width, h = khoTrang.height
        mauKe.setStroke()
        var y = Self.caoDong * 3          // chừa đầu trang cho tiêu đề
        while y < h - Self.caoDong {
            ctx.move(to: CGPoint(x: Self.mm(12), y: y))
            ctx.addLine(to: CGPoint(x: w - Self.mm(12), y: y))
            y += Self.caoDong
        }
        ctx.strokePath()

        mauLe.setStroke()
        ctx.setLineWidth(dayNet * 1.3)
        ctx.move(to: CGPoint(x: Self.leTrai, y: 0))
        ctx.addLine(to: CGPoint(x: Self.leTrai, y: h))
        ctx.strokePath()
    }

    private func veLuoi(_ ctx: CGContext) {
        let w = khoTrang.width, h = khoTrang.height, b = Self.oLy
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
        let w = khoTrang.width, h = khoTrang.height, b = Self.oLy
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
        let yTomTat = h * 0.80            // dải dưới: tóm tắt

        mauKe.setStroke()
        var y = Self.caoDong * 2
        while y < yTomTat {
            ctx.move(to: CGPoint(x: xTuKhoa + Self.mm(3), y: y))
            ctx.addLine(to: CGPoint(x: w - Self.mm(12), y: y))
            y += Self.caoDong
        }
        ctx.strokePath()

        mauLe.setStroke()
        ctx.setLineWidth(dayNet * 1.4)
        ctx.move(to: CGPoint(x: xTuKhoa, y: 0))
        ctx.addLine(to: CGPoint(x: xTuKhoa, y: yTomTat))
        ctx.move(to: CGPoint(x: 0, y: yTomTat))
        ctx.addLine(to: CGPoint(x: w, y: yTomTat))
        ctx.strokePath()
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
        let le = Self.mm(12)
        let soCot = 20, soHang = 20
        let canh = min((w - le * 2) / CGFloat(soCot), (h - le * 2) / CGFloat(soHang))
        let rongThat = canh * CGFloat(soCot)
        let caoThat = canh * CGFloat(soHang)
        let xGoc = (w - rongThat) / 2
        let yGoc = (h - caoThat) / 2

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

    private func veNhacLy(_ ctx: CGContext) {
        let w = khoTrang.width, h = khoTrang.height
        let cachDong = Self.mm(2.2)        // khoảng cách 5 dòng trong một khuông
        let cachKhuong = Self.mm(20)
        mauKe.setStroke()
        var yKhuong = Self.mm(20)
        while yKhuong + cachDong * 4 < h - Self.mm(15) {
            for i in 0..<5 {
                let y = yKhuong + CGFloat(i) * cachDong
                ctx.move(to: CGPoint(x: Self.mm(12), y: y))
                ctx.addLine(to: CGPoint(x: w - Self.mm(12), y: y))
            }
            yKhuong += cachKhuong
        }
        ctx.strokePath()
    }
}
#endif
