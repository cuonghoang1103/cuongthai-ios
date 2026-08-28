import SwiftUI

// ════════════════════════════════════════════════════════════════
// BỘ VẼ MÔ PHỎNG
//
// Hai chế độ tách hẳn nhau (đo thật: 20 kịch bản sơ đồ, 42 kịch bản panel,
// 0 kịch bản dùng cả hai):
//   · SƠ ĐỒ  — nút + cạnh + viên gói tin chạy trên dây
//   · PANEL  — 10 loại bảng đặt tuyệt đối trong khung 1000 × 560
//
// Cả hai vẽ trong hệ toạ độ 1000 × 560 rồi thu nhỏ vừa màn hình, y như
// `viewBox` của SVG trên web — nhờ vậy toạ độ trong kịch bản dùng được nguyên,
// không phải tính lại cho từng cỡ máy.
// ════════════════════════════════════════════════════════════════

// MARK: - Sơ đồ mạng

struct VeSoDo: View {
    let kb: KichBan
    let buoc: BuocMP?
    /// 0…1 — vị trí viên gói tin trên cạnh của bước hiện tại.
    let tien: Double
    let anh: Bool

    var body: some View {
        // ⚠️ Khung phải ÔM SÁT nội dung: đặt `frame(height: 300)` cố định thì
        // tỉ lệ thu theo BỀ NGANG (390/1000 ≈ 0,39) chỉ dùng 0,39 × 560 ≈
        // 218pt, thừa lại gần một phần ba khung là khoảng trống chết. Buộc
        // theo đúng tỉ lệ của sân khấu.
        Canvas { ctx, size in
            var c = ctx
            let ty = size.width / SAN_KHAU_W
            c.scaleBy(x: ty, y: ty)
            veCanh(&c)
            veNut(&c)
            veGoiTin(&c)
        }
        .aspectRatio(SAN_KHAU_W / SAN_KHAU_H, contentMode: .fit)
    }

    private var viTri: [String: CGPoint] {
        Dictionary(uniqueKeysWithValues: kb.cacNut.map { ($0.id, CGPoint(x: $0.x, y: $0.y)) })
    }

    private func veCanh(_ c: inout GraphicsContext) {
        let vt = viTri
        for e in kb.cacCanh {
            guard let a = vt[e.from], let b = vt[e.to] else { continue }
            let sang = buoc?.edge == e.id
            var p = Path()
            p.move(to: a)
            // `curve` dịch điểm điều khiển Bézier theo phương vuông góc — giữ
            // đúng hình dạng của web, nếu không thì cạnh song song chồng nhau.
            if let k = e.curve, k != 0 {
                let dx = b.x - a.x, dy = b.y - a.y
                let d = max(sqrt(dx * dx + dy * dy), 1)
                let giua = CGPoint(x: (a.x + b.x) / 2 - dy / d * k,
                                   y: (a.y + b.y) / 2 + dx / d * k)
                p.addQuadCurve(to: b, control: giua)
            } else {
                p.addLine(to: b)
            }
            c.stroke(p, with: .color(sang ? (buoc?.mauLuong ?? .blue)
                                          : Color(hex: 0x334155)),
                     style: StrokeStyle(lineWidth: sang ? 3 : 1.6, lineCap: .round))
        }
    }

    private func veNut(_ c: inout GraphicsContext) {
        for n in kb.cacNut {
            let tt = buoc?.nodeStates?[n.id] ?? "idle"
            let m = mauTrangThaiNut(tt)
            let r = CGRect(x: n.x - 46, y: n.y - 26, width: 92, height: 52)
            let hinh = Path(roundedRect: r, cornerRadius: 12)
            c.fill(hinh, with: .color(Color(hex: 0x0F172A)))
            c.stroke(hinh, with: .color(m), lineWidth: tt == "idle" ? 1.2 : 2.4)
            c.draw(Text(n.label).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tt == "idle" ? Color(hex: 0x94A3B8) : .white),
                   at: CGPoint(x: n.x, y: n.y - 5))
            if let s = n.sublabel?.chu(anh), !s.isEmpty {
                c.draw(Text(s).font(.system(size: 9)).foregroundColor(Color(hex: 0x64748B)),
                       at: CGPoint(x: n.x, y: n.y + 12))
            }
            if let b = n.badge, !b.isEmpty {
                c.draw(Text(b).font(.system(size: 8.5, design: .monospaced))
                        .foregroundColor(Color(hex: 0x94A3B8)),
                       at: CGPoint(x: n.x, y: n.y + 36))
            }
        }
    }

    private func veGoiTin(_ c: inout GraphicsContext) {
        guard let b = buoc else { return }
        let vt = viTri
        var tam: CGPoint?
        if let eid = b.edge, let e = kb.cacCanh.first(where: { $0.id == eid }),
           let a = vt[e.from], let z = vt[e.to] {
            let (p0, p1) = (b.reverse == true) ? (z, a) : (a, z)
            tam = CGPoint(x: p0.x + (p1.x - p0.x) * tien,
                          y: p0.y + (p1.y - p0.y) * tien)
        } else if let at = b.at, let p = vt[at] {
            tam = CGPoint(x: p.x, y: p.y - 46)   // xử lý nội bộ: nổi trên nút
        }
        guard let t = tam else { return }
        let nhan = b.packetLabel ?? b.kind ?? ""
        let rong = max(46.0, Double(nhan.count) * 7.5 + 18)
        let r = CGRect(x: t.x - rong / 2, y: t.y - 13, width: rong, height: 26)
        let hinh = Path(roundedRect: r, cornerRadius: 13)
        c.fill(hinh, with: .color(b.mauLuong))
        c.draw(Text(nhan).font(.system(size: 11, weight: .bold)).foregroundColor(.white), at: t)
    }

    private func mauTrangThaiNut(_ s: String) -> Color {
        switch s {
        case "active": return Color(hex: 0x3B82F6)
        case "processing": return Color(hex: 0xF59E0B)
        case "success": return Color(hex: 0x22C55E)
        case "error": return Color(hex: 0xEF4444)
        case "waiting": return Color(hex: 0xA855F7)
        default: return Color(hex: 0x334155)
        }
    }
}

// MARK: - Panel

struct VePanel: View {
    let p: PanelMP
    let tt: TrangThaiPanel
    let anh: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if let t = p.title?.chu(anh), !t.isEmpty {
                    Text(t).font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }
                Spacer(minLength: 0)
                if let f = p.file, !f.isEmpty {
                    Text(f).font(.system(size: 9, design: .monospaced))
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }
            if let h = p.hint?.chu(anh), !h.isEmpty {
                Text(h).font(.system(size: 9.5))
                    .foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            noiDung
        }
        .padding(Spacing.sm + 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard)
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(p.mau.opacity(0.28), lineWidth: 1)))
    }

    @ViewBuilder private var noiDung: some View {
        switch p.kind {
        case "code": veMa
        case "log": veNhatKy
        case "lanes", "membrane": veLan
        case "meter": veDongHo
        case "chart": veBieuDo
        case "table": veBang
        case "stack": veNganXep
        case "tree": veCay
        case "race": veDua
        default: veLan
        }
    }

    private var mucChinh: [MucPanel] { tt.lan["_"] ?? [] }

    // ── code ──
    private var veMa: some View {
        let bd = p.startLine ?? 1
        return VStack(alignment: .leading, spacing: 1) {
            ForEach(Array((p.lines ?? []).enumerated()), id: \.offset) { i, l in
                let so = bd + i
                let sang = tt.dong.contains(so)
                HStack(alignment: .top, spacing: 6) {
                    Text("\(so)")
                        .font(.system(size: 9, design: .monospaced).monospacedDigit())
                        .foregroundColor(AppColors.textTertiary.opacity(0.7))
                        .frame(width: 18, alignment: .trailing)
                    Text(l)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(sang ? .white : AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 0.5).padding(.horizontal, 3)
                .background(sang ? p.mau.opacity(0.22) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }

    // ── log ──
    private var veNhatKy: some View {
        let ds = mucChinh.suffix(p.maxLines ?? 12)
        return VStack(alignment: .leading, spacing: 1.5) {
            ForEach(Array(ds.enumerated()), id: \.offset) { _, m in
                HStack(alignment: .top, spacing: 5) {
                    if let b = m.badge, !b.isEmpty {
                        Text(b).font(.system(size: 8, weight: .bold))
                            .foregroundColor(mauSacThai(m.tone))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(mauSacThai(m.tone).opacity(0.16)))
                    }
                    Text(m.label ?? "")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            if ds.isEmpty { Text("—").font(.system(size: 10)).foregroundColor(AppColors.textTertiary) }
        }
    }

    // ── lanes / membrane ──
    private var veLan: some View {
        let ds = p.lanes ?? p.layers ?? []
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(ds.isEmpty ? [LanMP(id: "_", label: nil, sub: nil, accent: nil, hint: nil)] : ds) { l in
                let sang = tt.dangSang == l.id
                VStack(alignment: .leading, spacing: 2) {
                    if let n = l.label, !n.isEmpty {
                        Text(n).font(.system(size: 9, weight: .bold))
                            .foregroundColor(l.mau ?? AppColors.textTertiary)
                    }
                    HStack(spacing: 3) {
                        ForEach(Array((tt.lan[l.id] ?? []).enumerated()), id: \.offset) { _, m in
                            vien(m)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 5).padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 5)
                    .fill(sang ? p.mau.opacity(0.16) : AppColors.backgroundTertiary.opacity(0.35)))
            }
        }
    }

    // ── stack ──
    private var veNganXep: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Ngăn xếp vẽ NGƯỢC: đỉnh ở trên. Vẽ xuôi là đọc sai hẳn thứ tự
            // gọi hàm — thứ mà cả kịch bản đang dạy.
            ForEach(Array(mucChinh.reversed().enumerated()), id: \.offset) { _, m in
                vien(m).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let f = p.floor?.chu(anh), !f.isEmpty {
                Text(f).font(.system(size: 9)).foregroundColor(AppColors.textTertiary)
            }
        }
    }

    // ── tree ──
    private var veCay: some View {
        VStack(alignment: .leading, spacing: 1.5) {
            ForEach(Array(mucChinh.enumerated()), id: \.offset) { _, m in
                HStack(spacing: 4) {
                    // `depth` là mức lồng — thụt lề theo nó, không có thì cây
                    // dẹt thành danh sách và mất hết ý nghĩa.
                    Spacer().frame(width: Double(m.depth ?? 0) * 14)
                    if (m.depth ?? 0) > 0 {
                        Text("└").font(.system(size: 9, design: .monospaced))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    vien(m)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // ── meter ──
    private var veDongHo: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(p.meters ?? []) { d in
                let v = tt.giaTri[d.id]
                let gt = v?.0 ?? 0
                let tran = max(d.max ?? 100, 1)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(d.label ?? d.id)
                            .font(.system(size: 9.5)).foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text((v?.1) ?? "\(so(gt))\(d.unit ?? "")")
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundColor(v?.2 != nil ? mauSacThai(v?.2) : p.mau)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColors.backgroundTertiary)
                            Capsule().fill(v?.2 != nil ? mauSacThai(v?.2) : p.mau)
                                .frame(width: g.size.width * min(max(gt / tran, 0), 1))
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
    }

    // ── chart ──
    private var veBieuDo: some View {
        let ds = p.series ?? []
        let tran = max(p.max ?? (tt.giaTri.values.map { $0.0 }.max() ?? 1), 0.0001)
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(ds) { s in
                let v = tt.giaTri[s.id]
                HStack(spacing: 5) {
                    Text(s.label ?? s.id)
                        .font(.system(size: 9)).foregroundColor(AppColors.textSecondary)
                        .frame(width: 78, alignment: .leading).lineLimit(1)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(AppColors.backgroundTertiary)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(v?.2 != nil ? mauSacThai(v?.2) : mauHex(s.accent, mac: 0x3B82F6))
                                .frame(width: g.size.width * min(max((v?.0 ?? 0) / tran, 0), 1))
                        }
                    }
                    .frame(height: 13)
                    Text((v?.1) ?? so(v?.0 ?? 0))
                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 52, alignment: .trailing).lineLimit(1)
                }
            }
        }
    }

    // ── race ──
    private var veDua: some View {
        let ds = p.tracks ?? []
        let tran = max(tt.giaTri.values.map { $0.0 }.max() ?? 1, 0.0001)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(ds) { t in
                let v = tt.giaTri[t.id]
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(t.label ?? t.id)
                            .font(.system(size: 9.5)).foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text((v?.1) ?? "\(so(v?.0 ?? 0))\(p.unit ?? "")")
                            .font(.system(size: 10.5, weight: .bold).monospacedDigit())
                            .foregroundColor(t.id == p.better ? Color(hex: 0x22C55E) : AppColors.textPrimary)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColors.backgroundTertiary)
                            Capsule().fill(t.mau ?? p.mau)
                                .frame(width: g.size.width * min(max((v?.0 ?? 0) / tran, 0), 1))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    // ── table ──
    private var veBang: some View {
        let cot = p.columns ?? []
        return VStack(alignment: .leading, spacing: 2) {
            if !cot.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(cot.enumerated()), id: \.offset) { _, c in
                        Text(c.label ?? "")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            ForEach(Array(mucChinh.enumerated()), id: \.offset) { _, m in
                HStack(spacing: 4) {
                    ForEach(Array((m.cells ?? [m.label ?? ""]).enumerated()), id: \.offset) { _, c in
                        Text(c)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(m.tone != nil ? mauSacThai(m.tone) : AppColors.textSecondary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 1.5).padding(.horizontal, 3)
                .background(m.tone != nil ? mauSacThai(m.tone).opacity(0.10) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }

    // ── viên mục dùng chung ──
    private func vien(_ m: MucPanel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 3) {
                Text(m.label ?? "")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.white).lineLimit(1)
                if let b = m.badge, !b.isEmpty {
                    Text(b).font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            if let s = m.sub, !s.isEmpty {
                Text(s).font(.system(size: 7.5))
                    .foregroundColor(.white.opacity(0.7)).lineLimit(1)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 5).fill(mauSacThai(m.tone).opacity(0.85)))
    }
}
