import SwiftUI

// ════════════════════════════════════════════════════════════════
// BỘ VẼ SÁU LOẠI TRACER
//
// Bảng màu giữ ĐÚNG ý nghĩa của web: xanh dương = đang xét (`select`),
// vàng/cam = đang đánh dấu (`patch`), xanh lá = đã đi qua (`visited`).
// Đổi nghĩa màu là người học đọc sai thuật toán.
// ════════════════════════════════════════════════════════════════

enum MauTracer {
    static let thuong = Color(hex: 0x475569)
    static let dangXet = Color(hex: 0x3B82F6)   // select
    static let danhDau = Color(hex: 0xF59E0B)   // patch
    static let daQua = Color(hex: 0x22C55E)     // visited
    static let tuong = Color(hex: 0x1E293B)     // wall
    static let duong = Color(hex: 0xA855F7)     // path
    static let bienGioi = Color(hex: 0x06B6D4)  // frontier
}

struct VeTracer: View {
    let tt: TrangThaiTracer

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let t = tt.title, !t.isEmpty {
                Text(t.uppercased())
                    .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                    .foregroundColor(AppColors.textTertiary)
            }
            switch tt.kind {
            case "array1d": VeMang1D(tt: tt)
            case "chart":   VeBieuDo(tt: tt)
            case "log":     VeNhatKy(tt: tt)
            case "graph":   VeDoThi(tt: tt)
            case "array2d": VeMang2D(tt: tt)
            case "grid":    VeLuoi(tt: tt)
            default:        EmptyView()
            }
        }
        .padding(Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }
}

// MARK: - Mảng 1 chiều

private struct VeMang1D: View {
    let tt: TrangThaiTracer

    var body: some View {
        let d = tt.data ?? []
        let sel = Set(tt.selected ?? [])
        let pat = Set(tt.patched ?? [])
        let rong = max(16.0, min(38.0, 330.0 / Double(max(d.count, 1))))
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(Array(d.enumerated()), id: \.offset) { i, v in
                    let m = pat.contains(i) ? MauTracer.danhDau
                          : sel.contains(i) ? MauTracer.dangXet : MauTracer.thuong
                    let noi = pat.contains(i) || sel.contains(i)
                    VStack(spacing: 2) {
                        Text(so(v))
                            .font(.system(size: rong > 26 ? 12.5 : 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .frame(width: rong, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    // Gradient dọc thay vì một màu phẳng — ô có
                                    // khối, đọc nhanh hơn hẳn khi cả hàng cùng màu.
                                    .fill(LinearGradient(colors: [m.opacity(0.95), m.opacity(0.62)],
                                                         startPoint: .top, endPoint: .bottom))
                            )
                            .overlay(RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(noi ? m.opacity(0.9) : .clear, lineWidth: 1.4))
                            // Quầng sáng CHỈ ở ô đang được thuật toán đụng tới.
                            .shadow(color: noi ? m.opacity(0.75) : .clear, radius: 7)
                        // Chỉ số — thiếu nó thì không đối chiếu được với dòng
                        // mã đang chạy ("swap D[3] ↔ D[4]").
                        Text("\(i)")
                            .font(.system(size: 8, design: .monospaced).monospacedDigit())
                            .foregroundColor(noi ? m : AppColors.textTertiary.opacity(0.65))
                    }
                }
            }
            .padding(.vertical, 3)
        }
    }
}

// MARK: - Biểu đồ cột

private struct VeBieuDo: View {
    let tt: TrangThaiTracer

    var body: some View {
        let d = tt.data ?? []
        let sel = Set(tt.selected ?? [])
        let pat = Set(tt.patched ?? [])
        let lonNhat = max(d.max() ?? 1, 1)
        GeometryReader { g in
            let w = max(2.0, (g.size.width - Double(max(d.count - 1, 0)) * 2) / Double(max(d.count, 1)))
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(d.enumerated()), id: \.offset) { i, v in
                    let m = pat.contains(i) ? MauTracer.danhDau
                          : sel.contains(i) ? MauTracer.dangXet : MauTracer.thuong
                    let noi = pat.contains(i) || sel.contains(i)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [m, m.opacity(0.45)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: w, height: max(3, g.size.height * (v / lonNhat)))
                        .shadow(color: noi ? m.opacity(0.8) : .clear, radius: 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 150)
    }
}

// MARK: - Nhật ký

private struct VeNhatKy: View {
    let tt: TrangThaiTracer

    var body: some View {
        let ls = tt.lines ?? []
        VStack(alignment: .leading, spacing: 2) {
            // Chỉ giữ 40 dòng cuối: có thuật toán in hàng nghìn dòng, dựng
            // hết là khựng mà người đọc cũng chỉ nhìn phần mới nhất.
            ForEach(Array(ls.suffix(40).enumerated()), id: \.offset) { _, l in
                Text(l)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if ls.isEmpty {
                Text("—").font(.system(size: 11.5)).foregroundColor(AppColors.textTertiary)
            }
        }
    }
}

// MARK: - Đồ thị

private struct VeDoThi: View {
    let tt: TrangThaiTracer

    var body: some View {
        let ns = tt.nodes ?? []
        let es = tt.edges ?? []
        Canvas { ctx, size in
            let toa = viTri(ns, size)
            for e in es {
                guard let a = toa[e.source], let b = toa[e.target] else { continue }
                var p = Path(); p.move(to: a); p.addLine(to: b)
                let m = e.selected ? MauTracer.dangXet
                      : e.visited ? MauTracer.daQua : MauTracer.thuong.opacity(0.45)
                if e.selected || e.visited {
                    // Cạnh đã đi qua phát sáng — nhìn ra CÂY duyệt ngay lập tức,
                    // không phải dò từng nét.
                    var g = ctx
                    g.addFilter(.blur(radius: 4))
                    g.stroke(p, with: .color(m.opacity(0.7)), lineWidth: 5)
                }
                ctx.stroke(p, with: .color(m),
                           lineWidth: e.selected || e.visited ? 2.6 : 1.2)
                if let w = e.weight {
                    let giua = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                    ctx.draw(Text(so(w)).font(.system(size: 9, design: .monospaced))
                                .foregroundColor(AppColors.textTertiary), at: giua)
                }
            }
            for n in ns {
                guard let p = toa[n.id] else { continue }
                let r: CGFloat = 16
                let o = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                let m = n.selected ? MauTracer.dangXet
                      : n.visited ? MauTracer.daQua : MauTracer.thuong
                if n.selected || n.visited {
                    var g = ctx
                    g.addFilter(.blur(radius: 7))
                    g.fill(o, with: .color(m.opacity(0.65)))
                }
                ctx.fill(o, with: .radialGradient(
                    Gradient(colors: [m, m.opacity(0.6)]),
                    center: CGPoint(x: p.x - r * 0.3, y: p.y - r * 0.3),
                    startRadius: 1, endRadius: r * 1.6))
                ctx.stroke(o, with: .color(.white.opacity(n.selected ? 0.85 : 0.18)), lineWidth: 1.4)
                ctx.draw(Text(n.id).font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white), at: p)
                if let w = n.weight {
                    ctx.draw(Text(so(w)).font(.system(size: 8.5, design: .monospaced))
                                .foregroundColor(MauTracer.danhDau),
                             at: CGPoint(x: p.x, y: p.y + r + 7))
                }
            }
        }
        .frame(height: 250)
    }

    /// Nút nào có sẵn `x`/`y` thì dùng (thuật toán hình học đặt toạ độ thật),
    /// còn lại rải đều trên vòng tròn — đó là cách web làm.
    private func viTri(_ ns: [NutDoThi], _ size: CGSize) -> [String: CGPoint] {
        let m = CGFloat(26)
        var ra: [String: CGPoint] = [:]
        let coToa = ns.contains { $0.x != nil && $0.y != nil }
        if coToa {
            let xs = ns.compactMap { $0.x }, ys = ns.compactMap { $0.y }
            let x0 = xs.min() ?? 0, x1 = xs.max() ?? 1
            let y0 = ys.min() ?? 0, y1 = ys.max() ?? 1
            let dx = max(x1 - x0, 0.0001), dy = max(y1 - y0, 0.0001)
            for n in ns {
                let px = m + CGFloat(((n.x ?? 0) - x0) / dx) * (size.width - m * 2)
                let py = m + CGFloat(((n.y ?? 0) - y0) / dy) * (size.height - m * 2)
                ra[n.id] = CGPoint(x: px, y: py)
            }
        } else {
            let r = min(size.width, size.height) / 2 - m
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            for (i, n) in ns.enumerated() {
                let a: CGFloat = 2 * .pi * CGFloat(i) / CGFloat(max(ns.count, 1)) - .pi / 2
                ra[n.id] = CGPoint(x: c.x + r * CoreGraphics.cos(a),
                                   y: c.y + r * CoreGraphics.sin(a))
            }
        }
        return ra
    }
}

// MARK: - Mảng 2 chiều

private struct VeMang2D: View {
    let tt: TrangThaiTracer

    var body: some View {
        let m = tt.data2 ?? []
        let sel = Set(tt.selectedKeys ?? [])
        let pat = Set(tt.patchedKeys ?? [])
        let cot = m.first?.count ?? 0
        let o = max(15.0, min(34.0, 330.0 / Double(max(cot, 1))))
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(Array(m.enumerated()), id: \.offset) { r, hang in
                    HStack(spacing: 2) {
                        ForEach(Array(hang.enumerated()), id: \.offset) { c, v in
                            let k = "\(r),\(c)"
                            Text(so(v))
                                .font(.system(size: o > 24 ? 10.5 : 8, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1).minimumScaleFactor(0.5)
                                .frame(width: o, height: o)
                                .background(RoundedRectangle(cornerRadius: 4)
                                    .fill(pat.contains(k) ? MauTracer.danhDau
                                          : sel.contains(k) ? MauTracer.dangXet : MauTracer.thuong))
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 300)
    }
}

// MARK: - Lưới tìm đường

private struct VeLuoi: View {
    let tt: TrangThaiTracer

    var body: some View {
        let r = tt.rows ?? 0, c = tt.cols ?? 0
        let walls = tt.walls ?? [], states = tt.states ?? []
        GeometryReader { g in
            let o = min(g.size.width / Double(max(c, 1)), 20.0)
            VStack(spacing: 1) {
                ForEach(0..<max(r, 0), id: \.self) { i in
                    HStack(spacing: 1) {
                        ForEach(0..<max(c, 0), id: \.self) { j in
                            let k = i * c + j
                            let key = "\(i),\(j)"
                            RoundedRectangle(cornerRadius: 2)
                                .fill(mau(k, key, walls, states))
                                .frame(width: o - 1, height: o - 1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: Double(max(tt.rows ?? 0, 1)) * 20)
    }

    private func mau(_ k: Int, _ key: String, _ walls: [Bool], _ states: [String]) -> Color {
        if key == tt.start { return MauTracer.daQua }
        if key == tt.goal { return MauTracer.danhDau }
        if k < walls.count, walls[k] { return MauTracer.tuong }
        switch k < states.count ? states[k] : "" {
        case "path": return MauTracer.duong
        case "visited": return MauTracer.dangXet.opacity(0.55)
        case "frontier": return MauTracer.bienGioi.opacity(0.7)
        default: return AppColors.backgroundTertiary
        }
    }
}

/// Số nguyên thì bỏ đuôi `.0` — cột `[5.0, 2.0]` đọc rất khó chịu.
func so(_ v: Double) -> String {
    v == v.rounded() && abs(v) < 1e9 ? String(Int(v)) : String(format: "%.2f", v)
}
