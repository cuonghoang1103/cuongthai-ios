import SwiftUI

// MARK: - Gantt (cột tên cố định + trục ngày cuộn ngang)
//
// Bố cục: MỘT ScrollView dọc bọc [cột tên | ScrollView ngang]; hai bên cùng chiều cao hàng nên
// cuộn dọc luôn khớp. Lưới, thước và mũi tên phụ thuộc vẽ bằng `Canvas` (rẻ với vài trăm hàng);
// thanh là `NavigationLink` thật để chạm/VoiceOver hoạt động.

struct GanttTLCTW: View {
    let pid: Int
    let du: TLDuLieuCTW
    let ds: [TLMucCTW]
    let thanh: [Int: TLThanhCTW]
    let moc: TLMocCTW
    let khoangSprint: TLBoDungCTW.Khoang
    let cfg: CTWProjectConfig?
    let zoom: TLZoomCTW
    let anKhongLich: Bool
    /// iPad — cột tên rộng hơn.
    let rong: Bool

    private let hHang: CGFloat = 40
    private let hThuoc: CGFloat = 40
    private var rongTrai: CGFloat { rong ? 280 : 136 }

    private var hang: [TLHangCTW] {
        TLBoDungCTW.hang(ds, anKhongLich: anKhongLich, coThanh: Set(thanh.keys))
    }

    private var hinh: TLHinhHocCTW {
        let mocNgay = (moc.versions ?? []).compactMap { NgayCTW.ngay($0.release) }
        let thanhHien = ds.compactMap { thanh[$0.id] }
        let p = TLBoDungCTW.phamVi(thanhHien, them: mocNgay, homNay: Date())
        return TLHinhHocCTW(goc: p.goc, soNgay: p.soNgay, rongNgay: zoom.rongNgay)
    }

    /// Các làn mốc: sprint · stage · version (làn rỗng bị bỏ).
    private var lanMoc: [String] {
        var l: [String] = []
        if !khoangSprint.isEmpty { l.append("sprint") }
        if !(moc.stages ?? []).isEmpty { l.append("stage") }
        if !(moc.versions ?? []).filter({ $0.release != nil }).isEmpty { l.append("version") }
        return l
    }
    private var hMoc: CGFloat { lanMoc.isEmpty ? 0 : CGFloat(lanMoc.count) * 18 + 6 }

    var body: some View {
        let hang = self.hang
        let hinh = self.hinh
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                cotTen(hang)
                    .frame(width: rongTrai)
                    .background(AppColors.backgroundCard)
                    .overlay(alignment: .trailing) { Rectangle().fill(AppColors.border).frame(width: 0.5) }
                    .zIndex(1)
                ScrollViewReader { cuon in
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            ThuocTLCTW(hinh: hinh, zoom: zoom).frame(width: hinh.rongTong, height: hThuoc)
                            if !lanMoc.isEmpty { hangMoc(hinh).frame(width: hinh.rongTong, height: hMoc) }
                            vungThanh(hang, hinh)
                        }
                        .overlay(alignment: .topLeading) { duongHomNay(hinh, cao: hThuoc + hMoc + CGFloat(hang.count) * hHang) }
                        .overlay(alignment: .topLeading) {
                            Color.clear.frame(width: 1, height: 1)
                                .padding(.leading, max(hinh.x(Date()) - 1, 0))
                                .id("homnay")
                        }
                    }
                    .onAppear { cuon.scrollTo("homnay", anchor: UnitPoint(x: 0.3, y: 0)) }
                    .onChange(of: zoom) { _, _ in
                        DispatchQueue.main.async { cuon.scrollTo("homnay", anchor: UnitPoint(x: 0.3, y: 0)) }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(AppColors.backgroundPrimary)
    }

    // MARK: Cột tên

    private func cotTen(_ hang: [TLHangCTW]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Issue").font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: hThuoc + hMoc, maxHeight: hThuoc + hMoc, alignment: .bottomLeading)
                .padding(.bottom, 0)
            ForEach(hang) { h in
                switch h {
                case .nhom(let t):
                    Text(t.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: hHang, maxHeight: hHang, alignment: .bottomLeading)
                        .padding(.bottom, 0)
                case .muc(let m, let thut):
                    NavigationLink(value: CTWRoute.the(pid: pid, so: m.number)) {
                        HStack(spacing: 6) {
                            CTWTypeIcon(type: m.typeId.flatMap { cfg?.loai($0) }, size: 11)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.title).font(.system(size: 12, weight: m.laEpic ? .semibold : .regular))
                                    .foregroundColor(AppColors.textPrimary).lineLimit(1)
                                Text("\(cfg?.key ?? "#")-\(m.number)").font(.system(size: 10).monospaced())
                                    .foregroundColor(AppColors.textTertiary).strikethrough(m.done == true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, thut ? 22 : 10).padding(.trailing, 6)
                        .frame(height: hHang)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) { Rectangle().fill(AppColors.divider).frame(height: 0.5) }
                    .accessibilityLabel("\(cfg?.key ?? "")-\(m.number) \(m.title)")
                }
            }
        }
    }

    // MARK: Mốc

    private func hangMoc(_ hinh: TLHinhHocCTW) -> some View {
        Canvas { ctx, size in
            for (i, lan) in lanMoc.enumerated() {
                let y = 3 + CGFloat(i) * 18
                switch lan {
                case "sprint":
                    for (id, k) in khoangSprint {
                        let f = hinh.khung(TLThanhCTW(batDau: k.0, ketThuc: k.1, kieu: .day))
                        let r = CGRect(x: f.x + 1, y: y, width: max(f.rong - 2, 4), height: 15)
                        let dangChay = (cfg?.sprints ?? []).first { $0.id == id }?.state == "ACTIVE"
                        ctx.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(AppColors.primary.opacity(dangChay ? 0.28 : 0.13)))
                        let ten = (cfg?.sprints ?? []).first { $0.id == id }?.name ?? (moc.sprints ?? []).first { $0.id == id }?.name ?? "Sprint"
                        ctx.drawLayer { c in
                            c.clip(to: Path(r))
                            c.draw(Text(ten).font(.system(size: 10, weight: .semibold)).foregroundColor(AppColors.textPrimary),
                                   at: CGPoint(x: r.minX + 5, y: r.midY), anchor: .leading)
                        }
                    }
                case "stage":
                    for s in moc.stages ?? [] {
                        guard let a = NgayCTW.ngay(s.start) else { continue }
                        let b = NgayCTW.ngay(s.end) ?? Date()
                        let f = hinh.khung(TLThanhCTW(batDau: a, ketThuc: max(a, b), kieu: .day))
                        let r = CGRect(x: f.x + 1, y: y, width: max(f.rong - 2, 4), height: 15)
                        ctx.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(CTWMauChuoi.mau(2).opacity(s.status == "DONE" ? 0.18 : 0.32)))
                        ctx.drawLayer { c in
                            c.clip(to: Path(r))
                            c.draw(Text("\(s.n ?? 0). \(s.name ?? "Stage")").font(.system(size: 10, weight: .semibold)).foregroundColor(AppColors.textPrimary),
                                   at: CGPoint(x: r.minX + 5, y: r.midY), anchor: .leading)
                        }
                    }
                default:
                    for v in moc.versions ?? [] {
                        guard let d = NgayCTW.ngay(v.release) else { continue }
                        let x = hinh.x(d) + hinh.rongNgay / 2
                        let mau = v.status == "RELEASED" ? AppColors.success : CTWMauChuoi.mau(1)
                        ctx.fill(Path(CGRect(x: x - 0.75, y: y, width: 1.5, height: 15)), with: .color(mau))
                        var co = Path()
                        co.move(to: CGPoint(x: x, y: y)); co.addLine(to: CGPoint(x: x + 9, y: y + 4)); co.addLine(to: CGPoint(x: x, y: y + 8))
                        ctx.fill(co, with: .color(mau))
                        ctx.draw(Text(v.name ?? "").font(.system(size: 10, weight: .semibold)).foregroundColor(AppColors.textSecondary),
                                 at: CGPoint(x: x + 12, y: y + 7), anchor: .leading)
                    }
                }
            }
            ctx.fill(Path(CGRect(x: 0, y: size.height - 0.5, width: size.width, height: 0.5)), with: .color(AppColors.divider))
        }
        .accessibilityElement()
        .accessibilityLabel("Sprints, stages and release dates")
    }

    // MARK: Thanh + mũi tên

    private func vungThanh(_ hang: [TLHangCTW], _ hinh: TLHinhHocCTW) -> some View {
        let cao = CGFloat(hang.count) * hHang
        let viTri: [Int: Int] = Dictionary(hang.enumerated().compactMap { i, h in h.muc.map { ($0.id, i) } }, uniquingKeysWith: { a, _ in a })
        return ZStack(alignment: .topLeading) {
            LuoiTLCTW(hinh: hinh, zoom: zoom, soHang: hang.count, hHang: hHang)
                .frame(width: hinh.rongTong, height: cao)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(hang) { h in
                    ZStack(alignment: .leading) {
                        if let m = h.muc, let t = thanh[m.id] {
                            let f = hinh.khung(t)
                            NavigationLink(value: CTWRoute.the(pid: pid, so: m.number)) {
                                ThanhTLCTW(muc: m, thanh: t, rong: f.rong, mau: mauThanh(m), nhan: "\(cfg?.key ?? "#")-\(m.number)")
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, f.x)
                            .accessibilityLabel("\(cfg?.key ?? "")-\(m.number) \(m.title), \(NgayCTW.ngan(t.batDau)) to \(NgayCTW.ngan(t.ketThuc))")
                        }
                    }
                    .frame(width: hinh.rongTong, height: hHang, alignment: .leading)
                }
            }
            MuiTenTLCTW(canh: du.dependencies ?? [], xungDot: Set((du.conflicts ?? []).map { "\($0.from)-\($0.to)" }),
                        duongGang: duongGang, viTri: viTri, thanh: thanh, hinh: hinh, hHang: hHang)
                .frame(width: hinh.rongTong, height: cao)
                .allowsHitTesting(false)
        }
        .frame(width: hinh.rongTong, height: cao)
    }

    /// Các cạnh thuộc đường găng (cặp kề nhau trong `criticalPath`).
    private var duongGang: Set<String> {
        let p = du.criticalPath ?? []
        guard p.count >= 2 else { return [] }
        return Set(zip(p, p.dropFirst()).map { "\($0)-\($1)" })
    }

    private func mauThanh(_ m: TLMucCTW) -> Color {
        if m.done == true { return AppColors.success }
        if m.laEpic { return CTWMauChuoi.mau(6) }
        return CTW.mau(m.typeId.flatMap { cfg?.loai($0)?.color }, macDinh: CTWMauChuoi.mau(0))
    }

    private func duongHomNay(_ hinh: TLHinhHocCTW, cao: CGFloat) -> some View {
        let x = hinh.x(Date()) + hinh.rongNgay / 2
        return ZStack(alignment: .top) {
            Rectangle().fill(AppColors.error.opacity(0.75)).frame(width: 1.5, height: cao)
            Text("Today").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Capsule().fill(AppColors.error))
                .fixedSize()
        }
        .padding(.leading, max(x - 14, 0))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Một thanh Gantt: nền nhạt, phần đã xong tô đậm theo `progress`, nhãn mã thẻ.
struct ThanhTLCTW: View {
    let muc: TLMucCTW
    let thanh: TLThanhCTW
    let rong: CGFloat
    let mau: Color
    let nhan: String

    private var quaHan: Bool {
        guard !(muc.done ?? false), let d = NgayCTW.ngay(muc.due) else { return false }
        return NgayCTW.soNgay(d, Date()) > 0
    }

    var body: some View {
        let h: CGFloat = muc.laEpic ? 14 : 22
        let tien = min(max(muc.progress ?? (muc.done == true ? 1 : 0), 0), 1)
        HStack(spacing: 4) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(thanh.kieu == .suyRa ? Color.clear : mau.opacity(0.22))
                if thanh.kieu != .suyRa && tien > 0 {
                    RoundedRectangle(cornerRadius: 5, style: .continuous).fill(mau)
                        .frame(width: max(rong * tien, 4))
                }
                if thanh.kieu == .suyRa {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(mau.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                }
                if quaHan {
                    RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(AppColors.error, lineWidth: 1.5)
                }
                if !muc.laEpic && rong >= 54 {
                    Text(nhan).font(.system(size: 10, weight: .semibold).monospaced())
                        .foregroundColor(tien > 0.45 && thanh.kieu != .suyRa ? .white : AppColors.textPrimary)
                        .padding(.leading, 5).lineLimit(1).fixedSize()
                }
            }
            .frame(width: rong, height: h)
            .mask {
                if thanh.kieu == .moDuoi {
                    LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .black.opacity(0.15), location: 1)],
                                   startPoint: .leading, endPoint: .trailing)
                } else { Rectangle() }
            }
            Text(muc.title).font(.system(size: 11, weight: muc.laEpic ? .semibold : .regular))
                .foregroundColor(AppColors.textSecondary).lineLimit(1).fixedSize()
        }
        .frame(height: 40)
        .contentShape(Rectangle())
    }
}

/// Thước hai tầng: tháng ở trên; ngày (Week) / thứ Hai đầu tuần (Month) / tháng (Quarter) ở dưới.
struct ThuocTLCTW: View {
    let hinh: TLHinhHocCTW
    let zoom: TLZoomCTW

    var body: some View {
        Canvas { ctx, size in
            let l = NgayCTW.lichVN
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(AppColors.backgroundCard))
            var thangTruoc = -1
            for i in 0..<hinh.soNgay {
                let d = hinh.ngay(i)
                let x = CGFloat(i) * hinh.rongNgay
                let c = l.dateComponents([.year, .month, .day, .weekday], from: d)
                // Tầng trên: đầu tháng.
                if c.month != thangTruoc {
                    thangTruoc = c.month ?? 0
                    ctx.fill(Path(CGRect(x: x, y: 0, width: 0.5, height: size.height)), with: .color(AppColors.border))
                    let chu = zoom == .quy ? (c.month == 1 || i == 0 ? "\(c.year ?? 0)" : "") : NgayCTW.thang(d)
                    if !chu.isEmpty {
                        ctx.draw(Text(chu).font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textPrimary),
                                 at: CGPoint(x: x + 5, y: 11), anchor: .leading)
                    }
                    if zoom == .quy {
                        ctx.draw(Text(NgayCTW.ngan(d).prefix(3)).font(.system(size: 10)).foregroundColor(AppColors.textSecondary),
                                 at: CGPoint(x: x + 4, y: 29), anchor: .leading)
                    }
                }
                switch zoom {
                case .tuan:
                    let cuoiTuan = c.weekday == 1 || c.weekday == 7
                    if cuoiTuan { ctx.fill(Path(CGRect(x: x, y: 20, width: hinh.rongNgay, height: size.height - 20)), with: .color(AppColors.backgroundTertiary.opacity(0.6))) }
                    ctx.draw(Text("\(c.day ?? 0)").font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundColor(cuoiTuan ? AppColors.textTertiary : AppColors.textSecondary),
                             at: CGPoint(x: x + hinh.rongNgay / 2, y: 30))
                case .thang:
                    if c.weekday == 2 {
                        ctx.fill(Path(CGRect(x: x, y: 20, width: 0.5, height: size.height - 20)), with: .color(AppColors.divider))
                        ctx.draw(Text("\(c.day ?? 0)").font(.system(size: 10).monospacedDigit()).foregroundColor(AppColors.textSecondary),
                                 at: CGPoint(x: x + 3, y: 30), anchor: .leading)
                    }
                case .quy: break
                }
            }
            ctx.fill(Path(CGRect(x: 0, y: size.height - 0.5, width: size.width, height: 0.5)), with: .color(AppColors.border))
        }
        .accessibilityHidden(true)
    }
}

/// Lưới nền: cuối tuần (Week), vạch đầu tuần/đầu tháng, kẻ hàng.
struct LuoiTLCTW: View {
    let hinh: TLHinhHocCTW
    let zoom: TLZoomCTW
    let soHang: Int
    let hHang: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let l = NgayCTW.lichVN
            for i in 0..<hinh.soNgay {
                let d = hinh.ngay(i)
                let x = CGFloat(i) * hinh.rongNgay
                let c = l.dateComponents([.day, .weekday], from: d)
                if zoom == .tuan && (c.weekday == 1 || c.weekday == 7) {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: hinh.rongNgay, height: size.height)), with: .color(AppColors.backgroundTertiary.opacity(0.45)))
                }
                let vach = zoom == .quy ? c.day == 1 : c.weekday == 2
                if vach { ctx.fill(Path(CGRect(x: x, y: 0, width: 0.5, height: size.height)), with: .color(AppColors.divider)) }
            }
            for r in 1...max(soHang, 1) {
                ctx.fill(Path(CGRect(x: 0, y: CGFloat(r) * hHang - 0.5, width: size.width, height: 0.5)), with: .color(AppColors.divider.opacity(0.6)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Mũi tên phụ thuộc (blocker ⇒ blocked): gấp khúc từ đuôi thanh trước tới đầu thanh sau.
/// Đỏ = xung đột lịch (blocked bắt đầu trước khi blocker xong); cam = đường găng.
struct MuiTenTLCTW: View {
    let canh: [TLCanhCTW]
    let xungDot: Set<String>
    let duongGang: Set<String>
    let viTri: [Int: Int]
    let thanh: [Int: TLThanhCTW]
    let hinh: TLHinhHocCTW
    let hHang: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            for c in canh {
                guard let ra = viTri[c.from], let vao = viTri[c.to], let a = thanh[c.from], let b = thanh[c.to] else { continue }
                let fa = hinh.khung(a), fb = hinh.khung(b)
                let p1 = CGPoint(x: fa.x + fa.rong, y: CGFloat(ra) * hHang + hHang / 2)
                let p2 = CGPoint(x: fb.x, y: CGFloat(vao) * hHang + hHang / 2)
                var p = Path()
                p.move(to: p1)
                if p2.x - 8 >= p1.x + 8 {
                    p.addLine(to: CGPoint(x: p1.x + 8, y: p1.y))
                    p.addLine(to: CGPoint(x: p1.x + 8, y: p2.y))
                } else {
                    let giua = p1.y + (p2.y > p1.y ? hHang / 2 : -hHang / 2)
                    p.addLine(to: CGPoint(x: p1.x + 8, y: p1.y))
                    p.addLine(to: CGPoint(x: p1.x + 8, y: giua))
                    p.addLine(to: CGPoint(x: p2.x - 10, y: giua))
                    p.addLine(to: CGPoint(x: p2.x - 10, y: p2.y))
                }
                p.addLine(to: CGPoint(x: p2.x - 1, y: p2.y))
                let khoa = "\(c.from)-\(c.to)"
                let mau: Color = xungDot.contains(khoa) ? AppColors.error : (duongGang.contains(khoa) ? AppColors.accent : AppColors.textTertiary)
                ctx.stroke(p, with: .color(mau), style: StrokeStyle(lineWidth: xungDot.contains(khoa) ? 1.8 : 1.3, lineCap: .round, lineJoin: .round))
                var dau = Path()
                dau.move(to: CGPoint(x: p2.x - 1, y: p2.y))
                dau.addLine(to: CGPoint(x: p2.x - 7, y: p2.y - 4))
                dau.addLine(to: CGPoint(x: p2.x - 7, y: p2.y + 4))
                dau.closeSubpath()
                ctx.fill(dau, with: .color(mau))
            }
        }
        .accessibilityHidden(true)
    }
}
