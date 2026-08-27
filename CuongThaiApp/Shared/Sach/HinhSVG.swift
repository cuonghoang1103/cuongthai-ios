import SwiftUI

// ════════════════════════════════════════════════════════════════
// ĐỌC CHUỖI `d` CỦA SVG THÀNH `Path`
//
// ⚠️ Tên là `HinhSVG` chứ KHÔNG phải `DuongSVG` — `NetChu.swift` đã có một
// `enum DuongSVG` riêng cho nét chữ Nhật/Trung (chỉ M/L/C/Z tuyệt đối, kèm
// phép lật toạ độ của KanjiVG). Hai thứ khác hẳn nhau, đừng gộp.
//
// Chỉ đủ dùng cho bộ logo Simple Icons trên bìa sách. Đo trên 21 logo
// (25/08/2026) thì tập lệnh đúng bằng: M/m · L/l · H/h · V/v · C/c · S/s ·
// A/a · Z/z. KHÔNG có Q/T, nên không cài đặt hai lệnh đó — thà không hỗ trợ
// còn hơn cài đặt sai rồi vẽ méo mà không ai biết.
//
// ⚠️ Cung ellipse (`a`, 156 lệnh trong bộ này) là chỗ dễ sai nhất. `Path` chỉ
// có `addArc` HÌNH TRÒN, nên phải đổi cung ellipse sang các đoạn Bézier bậc ba
// theo cách chuẩn (endpoint → center parameterization của đặc tả SVG). Làm tắt
// bằng cách coi nó là cung tròn là logo méo ở đúng chỗ bo góc.
// ════════════════════════════════════════════════════════════════

struct HinhSVG: Shape {
    let d: String
    /// Kích thước hệ toạ độ gốc của SVG (Simple Icons luôn 24×24).
    var goc: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        var p = Self.doc(d)
        // Vừa khít và giữ tỉ lệ, canh giữa.
        let ti = min(rect.width, rect.height) / goc
        let dx = (rect.width - goc * ti) / 2
        let dy = (rect.height - goc * ti) / 2
        p = p.applying(CGAffineTransform(scaleX: ti, y: ti)
            .concatenating(CGAffineTransform(translationX: rect.minX + dx, y: rect.minY + dy)))
        return p
    }

    // MARK: Bộ đọc

    static func doc(_ d: String) -> Path {
        var p = Path()
        var i = d.startIndex
        var cur = CGPoint.zero          // điểm hiện tại
        var dau = CGPoint.zero          // điểm bắt đầu contour (cho Z)
        var lenh: Character = "M"
        var dieuKhienTruoc: CGPoint?    // điểm điều khiển thứ 2 của C/S trước đó

        func boTrang() {
            while i < d.endIndex, d[i] == " " || d[i] == "," || d[i] == "\n" || d[i] == "\t" { i = d.index(after: i) }
        }
        func so() -> CGFloat? {
            boTrang()
            var s = ""
            if i < d.endIndex, d[i] == "-" || d[i] == "+" { s.append(d[i]); i = d.index(after: i) }
            var coCham = false, coSo = false
            while i < d.endIndex {
                let c = d[i]
                if c.isNumber { s.append(c); coSo = true; i = d.index(after: i) }
                else if c == "." && !coCham { coCham = true; s.append(c); i = d.index(after: i) }
                else if (c == "e" || c == "E"), coSo {
                    s.append(c); i = d.index(after: i)
                    if i < d.endIndex, d[i] == "-" || d[i] == "+" { s.append(d[i]); i = d.index(after: i) }
                } else { break }
            }
            return coSo ? CGFloat(Double(s) ?? 0) : nil
        }
        /// Cờ của lệnh A là MỘT chữ số, có thể dính liền số kế tiếp ("1 0 1")
        /// nên không được đọc bằng `so()`.
        func co() -> CGFloat {
            boTrang()
            guard i < d.endIndex else { return 0 }
            let c = d[i]; i = d.index(after: i)
            return c == "1" ? 1 : 0
        }

        while i < d.endIndex {
            boTrang()
            guard i < d.endIndex else { break }
            if d[i].isLetter { lenh = d[i]; i = d.index(after: i) }
            let tuongDoi = lenh.isLowercase
            let L = Character(lenh.uppercased())

            switch L {
            case "M":
                guard let x = so(), let y = so() else { return p }
                cur = tuongDoi ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                p.move(to: cur); dau = cur; dieuKhienTruoc = nil
                // Cặp số tiếp theo sau M là L (theo đặc tả SVG).
                lenh = tuongDoi ? "l" : "L"
            case "L":
                guard let x = so(), let y = so() else { return p }
                cur = tuongDoi ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                p.addLine(to: cur); dieuKhienTruoc = nil
            case "H":
                guard let x = so() else { return p }
                cur = CGPoint(x: tuongDoi ? cur.x + x : x, y: cur.y)
                p.addLine(to: cur); dieuKhienTruoc = nil
            case "V":
                guard let y = so() else { return p }
                cur = CGPoint(x: cur.x, y: tuongDoi ? cur.y + y : y)
                p.addLine(to: cur); dieuKhienTruoc = nil
            case "C":
                guard let x1 = so(), let y1 = so(), let x2 = so(), let y2 = so(),
                      let x = so(), let y = so() else { return p }
                let c1 = tuongDoi ? CGPoint(x: cur.x + x1, y: cur.y + y1) : CGPoint(x: x1, y: y1)
                let c2 = tuongDoi ? CGPoint(x: cur.x + x2, y: cur.y + y2) : CGPoint(x: x2, y: y2)
                cur = tuongDoi ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                p.addCurve(to: cur, control1: c1, control2: c2)
                dieuKhienTruoc = c2
            case "S":
                guard let x2 = so(), let y2 = so(), let x = so(), let y = so() else { return p }
                // Điểm điều khiển đầu là ẢNH ĐỐI XỨNG của điểm điều khiển sau
                // của lệnh C/S liền trước — bỏ qua chỗ này là đường gãy góc.
                let c1 = dieuKhienTruoc.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = tuongDoi ? CGPoint(x: cur.x + x2, y: cur.y + y2) : CGPoint(x: x2, y: y2)
                cur = tuongDoi ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                p.addCurve(to: cur, control1: c1, control2: c2)
                dieuKhienTruoc = c2
            case "A":
                guard let rx = so(), let ry = so(), let xoay = so() else { return p }
                let cungLon = co(), thuan = co()
                guard let x = so(), let y = so() else { return p }
                let den = tuongDoi ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                themCung(&p, tu: cur, den: den, rx: rx, ry: ry,
                         xoayDo: xoay, cungLon: cungLon == 1, thuanChieu: thuan == 1)
                cur = den; dieuKhienTruoc = nil
            case "Z":
                p.closeSubpath(); cur = dau; dieuKhienTruoc = nil
            default:
                // Lệnh lạ (Q/T…): dừng hẳn thay vì vẽ bậy. Bộ logo hiện tại
                // không có, nếu sau này có thì logo mất chứ không méo.
                return p
            }
        }
        return p
    }

    /// Cung ellipse → chuỗi Bézier bậc ba. Theo phụ lục F.6 của đặc tả SVG:
    /// đổi từ "endpoint parameterization" sang "center parameterization" rồi
    /// cắt cung thành các đoạn ≤ 90° cho sai số đủ nhỏ.
    private static func themCung(_ p: inout Path, tu: CGPoint, den: CGPoint,
                                 rx rx0: CGFloat, ry ry0: CGFloat,
                                 xoayDo: CGFloat, cungLon: Bool, thuanChieu: Bool) {
        // Bán kính 0 hoặc hai đầu trùng nhau ⇒ đặc tả bảo vẽ đoạn thẳng.
        if rx0 == 0 || ry0 == 0 || (tu.x == den.x && tu.y == den.y) {
            p.addLine(to: den); return
        }
        var rx = abs(rx0), ry = abs(ry0)
        let goc = xoayDo * .pi / 180
        let cosG = cos(goc), sinG = sin(goc)

        let dx2 = (tu.x - den.x) / 2, dy2 = (tu.y - den.y) / 2
        let x1 =  cosG * dx2 + sinG * dy2
        let y1 = -sinG * dx2 + cosG * dy2

        // Bán kính quá nhỏ để nối hai đầu ⇒ nong ra, đúng đặc tả.
        let kt = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if kt > 1 { let s = sqrt(kt); rx *= s; ry *= s }

        let tren = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let duoi = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var he = duoi == 0 ? 0 : sqrt(max(0, tren / duoi))
        if cungLon == thuanChieu { he = -he }

        let cx1 =  he * rx * y1 / ry
        let cy1 = -he * ry * x1 / rx
        let cx = cosG * cx1 - sinG * cy1 + (tu.x + den.x) / 2
        let cy = sinG * cx1 + cosG * cy1 + (tu.y + den.y) / 2

        func gocGiua(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dau: CGFloat = (ux * vy - uy * vx) < 0 ? -1 : 1
            let t = (ux * vx + uy * vy) / (sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy))
            return dau * acos(min(1, max(-1, t)))
        }
        let bd = gocGiua(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var quet = gocGiua((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !thuanChieu && quet > 0 { quet -= 2 * .pi }
        if thuanChieu && quet < 0 { quet += 2 * .pi }

        // Cắt thành đoạn ≤ 90°: xấp xỉ Bézier chỉ đủ chính xác trong tầm đó.
        let soDoan = Int(ceil(abs(quet) / (.pi / 2)))
        let moiDoan = quet / CGFloat(max(soDoan, 1))
        let k = 4.0 / 3.0 * tan(moiDoan / 4)
        var g = bd
        for _ in 0..<max(soDoan, 1) {
            let g2 = g + moiDoan
            let c1 = CGPoint(x: cos(g) - k * sin(g), y: sin(g) + k * cos(g))
            let c2 = CGPoint(x: cos(g2) + k * sin(g2), y: sin(g2) - k * cos(g2))
            let e  = CGPoint(x: cos(g2), y: sin(g2))
            func doi(_ q: CGPoint) -> CGPoint {
                let ex = q.x * rx, ey = q.y * ry
                return CGPoint(x: cosG * ex - sinG * ey + cx, y: sinG * ex + cosG * ey + cy)
            }
            p.addCurve(to: doi(e), control1: doi(c1), control2: doi(c2))
            g = g2
        }
    }
}
