#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// NỀN GIẤY — trắng · ô vuông · ca-rô · chấm bi · kẻ dòng · tam giác
//
// Dạy toán trên giấy TRẮNG là canh mọi thứ bằng mắt: trục toạ độ lệch,
// hình học không đều, bảng biểu xiêu. Giấy có lưới giải đúng việc đó, và
// nó là thứ người dạy mở ra dùng ngay chứ không phải trang trí.
//
// Vẽ bằng `Canvas` chứ không xếp hàng nghìn `Divider`: bảng giảng 6000×4000
// với bước 20 là 500 đường dọc + 300 đường ngang — dựng ngần ấy View là
// đứng máy. `Canvas` vẽ thẳng vào ngữ cảnh đồ hoạ, không tạo View nào.
// ════════════════════════════════════════════════════════════════

struct GiayLuoi: View {
    let kieu: KieuGiay
    let buoc: Double
    let co: CGSize
    var mau: Color = Color.black.opacity(0.10)
    var mauDam: Color = Color.black.opacity(0.22)

    var body: some View {
        Canvas { ctx, kt in
            guard kieu != .trang, buoc >= 4 else { return }
            switch kieu {
            case .trang:
                break

            case .oVuong, .caRo:
                // Cứ 5 ô một đường ĐẬM: không có mốc đậm thì đếm ô trên
                // lưới dày là việc bất khả, mắt trôi ngay sau ô thứ tư.
                ve(ctx, kt, buoc: buoc, damMoi: 5)

            case .chamBi:
                var y = 0.0
                while y <= kt.height {
                    var x = 0.0
                    while x <= kt.width {
                        let r = 1.6
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                                        width: r * 2, height: r * 2)),
                                 with: .color(mauDam))
                        x += buoc
                    }
                    y += buoc
                }

            case .keDong:
                var y = buoc
                while y <= kt.height {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: kt.width, y: y))
                    ctx.stroke(p, with: .color(mau), lineWidth: 1)
                    y += buoc
                }
                // Lề trái như vở học trò.
                var le = Path()
                le.move(to: CGPoint(x: buoc * 2, y: 0))
                le.addLine(to: CGPoint(x: buoc * 2, y: kt.height))
                ctx.stroke(le, with: .color(.red.opacity(0.28)), lineWidth: 1)

            case .tamGiac:
                // Lưới tam giác đều: dùng vẽ phối cảnh đều và hình học
                // không gian, thứ giấy ô vuông không làm được.
                let cao = buoc * 0.8660254        // √3/2
                var y = 0.0, hang = 0
                while y <= kt.height {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: kt.width, y: y))
                    ctx.stroke(p, with: .color(mau), lineWidth: 0.8)
                    y += cao; hang += 1
                }
                let lech = buoc / 2
                var x = -kt.height / 1.7
                while x <= kt.width + kt.height / 1.7 {
                    for huong in [1.0, -1.0] {
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x + huong * kt.height / 1.7320508, y: kt.height))
                        ctx.stroke(p, with: .color(mau), lineWidth: 0.8)
                    }
                    x += lech * 2
                }
            }
        }
        .frame(width: co.width, height: co.height)
        .allowsHitTesting(false)
    }

    private func ve(_ ctx: GraphicsContext, _ kt: CGSize, buoc: Double, damMoi: Int) {
        var i = 0
        var x = 0.0
        while x <= kt.width {
            var p = Path()
            p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: kt.height))
            ctx.stroke(p, with: .color(i % damMoi == 0 ? mauDam : mau),
                       lineWidth: i % damMoi == 0 ? 1 : 0.7)
            x += buoc; i += 1
        }
        i = 0
        var y = 0.0
        while y <= kt.height {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: kt.width, y: y))
            ctx.stroke(p, with: .color(i % damMoi == 0 ? mauDam : mau),
                       lineWidth: i % damMoi == 0 ? 1 : 0.7)
            y += buoc; i += 1
        }
    }
}
#endif
