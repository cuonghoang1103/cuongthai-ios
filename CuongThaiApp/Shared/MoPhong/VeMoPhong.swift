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

/// Vẽ chữ ĐÃ CẮT cho vừa bề rộng, thêm dấu … khi phải cắt.
///
/// ⚠️ `Canvas.draw(Text)` KHÔNG cắt và KHÔNG xuống dòng — nó vẽ tràn ra ngoài
/// hộp và không báo gì. Web có `ellipsize()` dùng `ctx.measureText`; bên này
/// phải tự đo bằng `ctx.resolve(...).measure(in:)`. Thiếu bước này thì
/// "Prisma · connection pool" chạy vượt khỏi khung nút PostgreSQL.
@discardableResult
func veChuCat(_ c: inout GraphicsContext, _ chu: String, font: Font, mau: Color,
              tai: CGPoint, rongToiDa: CGFloat, anchor: UnitPoint = .leading) -> Bool {
    func rong(_ t: String) -> CGFloat {
        c.resolve(Text(t).font(font))
            .measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                height: CGFloat.greatestFiniteMagnitude)).width
    }
    var ra = chu
    var catBot = false
    if rong(ra) > rongToiDa {
        catBot = true
        while ra.count > 1, rong(ra + "…") > rongToiDa { ra.removeLast() }
        ra += "…"
    }
    c.draw(Text(ra).font(font).foregroundColor(mau), at: tai, anchor: anchor)
    return catBot
}

/// Ngắt dòng theo bề rộng THẬT, tối đa `toiDaDong` dòng, dòng cuối cắt bằng …
///
/// Web dùng `wrapText(ctx, sub, box.w - 96, 2)`. Xuống dòng giữ được nhiều
/// chữ hơn hẳn so với cắt cụt trong cùng một bề rộng.
func xuongDong(_ c: inout GraphicsContext, _ chu: String, font: Font,
               rongToiDa: CGFloat, toiDaDong: Int) -> [String] {
    guard !chu.isEmpty else { return [] }
    func rong(_ t: String) -> CGFloat {
        c.resolve(Text(t).font(font))
            .measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                height: CGFloat.greatestFiniteMagnitude)).width
    }
    var ra: [String] = []
    var dong = ""
    for tu in chu.split(separator: " ") {
        let thu = dong.isEmpty ? String(tu) : dong + " " + tu
        if rong(thu) <= rongToiDa { dong = thu; continue }
        if !dong.isEmpty { ra.append(dong) }
        dong = String(tu)
        if ra.count == toiDaDong { break }
    }
    if ra.count < toiDaDong, !dong.isEmpty { ra.append(dong) }
    // Dòng cuối bị tràn thì cắt kèm …
    if var cuoi = ra.last, rong(cuoi) > rongToiDa {
        while cuoi.count > 1, rong(cuoi + "…") > rongToiDa { cuoi.removeLast() }
        ra[ra.count - 1] = cuoi + "…"
    }
    return ra
}

struct VeSoDo: View {
    let kb: KichBan
    let buoc: BuocMP?
    /// 0…1 — vị trí viên gói tin trên cạnh của bước hiện tại.
    let tien: Double
    let anh: Bool

    /// Bề rộng khung vẽ, đặt khi dựng — dùng để tự căn.
    private let veW: Double = 1000
    private let veH: Double = 620

    var body: some View {
        Canvas { ctx, size in
            var c = ctx
            let ty = size.width / veW
            c.scaleBy(x: ty, y: ty)
            let bd = boCuc()
            veNen(&c)
            veCanh(&c, bd)
            veNut(&c, bd)
            veGoiTin(&c, bd)
        }
        .aspectRatio(veW / veH, contentMode: .fit)
        .background(MauSanKhau.nenNgoai)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: Tự căn

    /// Ánh xạ toạ độ kịch bản → khung vẽ.
    ///
    /// ⚠️ KHÔNG ánh xạ cứng cả hệ 1000×560. Kịch bản REST API chỉ trải từ
    /// y=116 tới y=320, ánh xạ cứng là bỏ trống gần nửa khung và mọi thứ nhìn
    /// bé tí. Web lấy HỘP BAO của các nút rồi phóng + căn giữa nó — làm theo.
    ///
    /// ⚠️ Chỉ phóng VỊ TRÍ, còn hộp nút vẽ bằng kích thước CỐ ĐỊNH — nếu
    /// phóng cả hộp thì chữ bị kéo giãn theo và mỗi kịch bản một cỡ chữ.
    private struct BoCuc {
        let ty: Double
        let dx: Double
        let dy: Double
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * ty + dx, y: y * ty + dy) }
        func p(_ q: CGPoint) -> CGPoint { p(q.x, q.y) }
    }

    private func boCuc() -> BoCuc {
        let ns = kb.cacNut
        guard !ns.isEmpty else { return BoCuc(ty: 1, dx: 0, dy: 0) }
        let xs = ns.map(\.x), ys = ns.map(\.y)
        let x0 = xs.min()!, x1 = xs.max()!, y0 = ys.min()!, y1 = ys.max()!
        // Chừa chỗ cho nửa hộp nút + nhãn loại phía trên + badge phía dưới.
        let leD = 100.0, leT = 46.0, leD2 = 34.0
        let rong = max(x1 - x0, 1), cao = max(y1 - y0, 1)
        let ty = min((veW - leD * 2) / rong, (veH - leT - leD2) / cao)
        // Trần 2,2 lần: sơ đồ hai nút mà phóng hết cỡ thì hộp trôi ra mép.
        let t = min(ty, 2.2)
        return BoCuc(ty: t,
                     dx: (veW - rong * t) / 2 - x0 * t,
                     dy: (veH - cao * t) / 2 - y0 * t)
    }

    // MARK: Nền

    private func veNen(_ c: inout GraphicsContext) {
        let r = CGRect(x: 0, y: 0, width: veW, height: veH)
        c.fill(Path(r), with: .radialGradient(
            Gradient(colors: [MauSanKhau.nenTrong, MauSanKhau.nenNgoai]),
            center: CGPoint(x: veW * 0.5, y: veH * 0.34),
            startRadius: 80, endRadius: veW * 0.78))
        for x in stride(from: 0.0, through: veW, by: 60) {
            var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: veH))
            c.stroke(p, with: .color(x.truncatingRemainder(dividingBy: 240) == 0
                                     ? MauSanKhau.luoiChinh : MauSanKhau.luoi), lineWidth: 1)
        }
        for y in stride(from: 0.0, through: veH, by: 60) {
            var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: veW, y: y))
            c.stroke(p, with: .color(y.truncatingRemainder(dividingBy: 240) == 0
                                     ? MauSanKhau.luoiChinh : MauSanKhau.luoi), lineWidth: 1)
        }
        // Bụi sao — vị trí CỐ ĐỊNH theo hash, không random: tua đi tua lại
        // phải thấy đúng một hình.
        for i in 0..<70 {
            let x = bam01(i * 7 + 1) * veW
            let y = bam01(i * 13 + 5) * veH
            let a = 0.10 + 0.16 * bam01(i * 29 + 3)
            c.fill(Path(CGRect(x: x, y: y, width: 2, height: 2)), with: .color(kb.mau.opacity(a)))
        }
    }

    // MARK: Cạnh

    private func veCanh(_ c: inout GraphicsContext, _ bd: BoCuc) {
        let vt = Dictionary(uniqueKeysWithValues: kb.cacNut.map { ($0.id, bd.p($0.x, $0.y)) })
        for e in kb.cacCanh {
            guard let a = vt[e.from], let b = vt[e.to] else { continue }
            let sang = buoc?.edge == e.id
            let kl = MauSanKhau.luong(buoc?.kind)
            var p = Path()
            p.move(to: a)
            if let k = e.curve, k != 0 {
                let dx = b.x - a.x, dy = b.y - a.y
                let d = max(sqrt(dx * dx + dy * dy), 1)
                // Độ cong phải nhân theo hệ số phóng, không thì sơ đồ phóng to
                // mà cạnh vẫn cong theo bán kính cũ ⇒ méo.
                let k2 = k * bd.ty
                p.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2 - dy / d * k2,
                                                       y: (a.y + b.y) / 2 + dx / d * k2))
            } else {
                p.addLine(to: b)
            }
            if sang {
                var g = c
                g.addFilter(.blur(radius: 6))
                g.stroke(p, with: .color(kl.quang.opacity(0.55)),
                         style: StrokeStyle(lineWidth: 8, lineCap: .round))
                c.stroke(p, with: .color(kl.loi),
                         style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                c.stroke(p, with: .color(kl.quang.opacity(0.9)),
                         style: StrokeStyle(lineWidth: 1.8, lineCap: .round,
                                            dash: [16, 22], dashPhase: -tien * 38))
            } else {
                c.stroke(p, with: .color(Color(hex: 0x2A3550)),
                         style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }
    }

    // MARK: Nút

    private func veNut(_ c: inout GraphicsContext, _ bd: BoCuc) {
        for n in kb.cacNut {
            let (mauLoai, nhanLoai) = MauSanKhau.nut(n.kind)
            let tt = buoc?.nodeStates?[n.id] ?? "idle"
            let ngoi = tt != "idle"
            let m = MauSanKhau.trangThai(tt, mac: mauLoai)
            let tam = bd.p(n.x, n.y)
            // Kích thước CỐ ĐỊNH — không nhân theo hệ số phóng, để chữ luôn
            // cùng một cỡ ở mọi kịch bản.
            let w = 186.0, h = 68.0
            let r = CGRect(x: tam.x - w / 2, y: tam.y - h / 2, width: w, height: h)
            let hinh = Path(roundedRect: r, cornerRadius: 16)

            if ngoi {
                var g = c
                g.addFilter(.blur(radius: 14))
                g.fill(hinh, with: .color(m.opacity(0.45)))
            }
            c.fill(hinh, with: .linearGradient(
                Gradient(colors: [ngoi ? m.opacity(0.22) : Color(hex: 0x141A2C).opacity(0.94),
                                  Color(hex: 0x080B16).opacity(0.97)]),
                startPoint: CGPoint(x: r.minX, y: r.minY),
                endPoint: CGPoint(x: r.minX, y: r.maxY)))
            c.stroke(hinh, with: .color(ngoi ? m : mauLoai.opacity(0.34)),
                     lineWidth: ngoi ? 2.8 : 1.6)
            c.fill(Path(roundedRect: CGRect(x: r.minX + 7, y: r.minY + 15,
                                            width: 4.5, height: h - 30), cornerRadius: 2.5),
                   with: .color(m.opacity(ngoi ? 1 : 0.55)))
            let oIcon = CGRect(x: r.minX + 19, y: tam.y - 17, width: 34, height: 34)
            c.fill(Path(roundedRect: oIcon, cornerRadius: 10),
                   with: .color(m.opacity(ngoi ? 0.30 : 0.16)))
            c.draw(Text(Image(systemName: n.bieuTuong))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(m.opacity(ngoi ? 1 : 0.72)),
                   at: CGPoint(x: oIcon.midX, y: oIcon.midY))

            let xChu = r.minX + 62
            let rongChu = r.maxX - xChu - 11
            let phu = n.sublabel?.chu(anh) ?? ""
            // Web xuống DÒNG chữ phụ (tối đa 2 dòng) thay vì cắt — giữ được
            // nhiều chữ hơn hẳn trong cùng bề rộng.
            let dong = xuongDong(&c, phu, font: .system(size: 9.5),
                                 rongToiDa: rongChu, toiDaDong: 2)
            let yTen = tam.y + (dong.isEmpty ? 0 : (dong.count > 1 ? -13 : -8))
            veChuCat(&c, n.label, font: .system(size: 15, weight: .bold),
                     mau: ngoi ? .white : Color(hex: 0xC8D3E6),
                     tai: CGPoint(x: xChu, y: yTen), rongToiDa: rongChu)
            for (k, d) in dong.enumerated() {
                c.draw(Text(d).font(.system(size: 9.5))
                        .foregroundColor(Color(hex: 0x7C8AA3)),
                       at: CGPoint(x: xChu, y: yTen + 13 + Double(k) * 11), anchor: .leading)
            }
            veChuCat(&c, nhanLoai, font: .system(size: 8.5, weight: .heavy, design: .monospaced),
                     mau: mauLoai.opacity(ngoi ? 0.95 : 0.62),
                     tai: CGPoint(x: r.minX + 9, y: r.minY - 10), rongToiDa: w - 14)
            if let b = n.badge, !b.isEmpty {
                veChuCat(&c, b, font: .system(size: 9, design: .monospaced),
                         mau: m.opacity(0.9), tai: CGPoint(x: tam.x, y: r.maxY + 11),
                         rongToiDa: w, anchor: .center)
            }
        }
    }

    // MARK: Gói tin

    private func veGoiTin(_ c: inout GraphicsContext, _ bd: BoCuc) {
        guard let b = buoc else { return }
        let vt = Dictionary(uniqueKeysWithValues: kb.cacNut.map { ($0.id, bd.p($0.x, $0.y)) })
        var tam: CGPoint?
        if let eid = b.edge, let e = kb.cacCanh.first(where: { $0.id == eid }),
           let a = vt[e.from], let z = vt[e.to] {
            let (p0, p1) = (b.reverse == true) ? (z, a) : (a, z)
            // Giảm tốc hai đầu — chuyển động đều nhìn như máy, có gia tốc mới
            // ra cảm giác "gói tin rời đi rồi cập bến".
            let t = tien < 0.5 ? 4 * tien * tien * tien : 1 - pow(-2 * tien + 2, 3) / 2
            tam = CGPoint(x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t)
        } else if let at = b.at, let p = vt[at] {
            tam = CGPoint(x: p.x, y: p.y - 60)
        }
        guard let t = tam else { return }
        let kl = MauSanKhau.luong(b.kind)
        let nhan = b.packetLabel ?? b.kind ?? ""
        let rong = max(58.0, Double(nhan.count) * 7.6 + 24)
        let r = CGRect(x: t.x - rong / 2, y: t.y - 15, width: rong, height: 30)

        c.fill(Path(ellipseIn: CGRect(x: t.x - 50, y: t.y - 50, width: 100, height: 100)),
               with: .radialGradient(
                Gradient(colors: [kl.quang.opacity(0.32), kl.quang.opacity(0)]),
                center: t, startRadius: 0, endRadius: 50))
        var g = c
        g.addFilter(.blur(radius: 9))
        g.fill(Path(roundedRect: r, cornerRadius: 15), with: .color(kl.loi.opacity(0.85)))
        c.fill(Path(roundedRect: r, cornerRadius: 15), with: .linearGradient(
            Gradient(colors: [kl.quang, kl.loi]),
            startPoint: CGPoint(x: r.minX, y: r.minY),
            endPoint: CGPoint(x: r.minX, y: r.maxY)))
        veChuCat(&c, nhan, font: .system(size: 11.5, weight: .heavy),
                 mau: Color(hex: 0x08111F), tai: t, rongToiDa: rong - 12, anchor: .center)
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
