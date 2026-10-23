import SwiftUI

// ════════════════════════════════════════════════════════════════
// THỨ TỰ NÉT (KanjiVG) — bản native của `KhungNet`/`StrokePlayer` (web
// WriteBlock.tsx · KanjiSheet.tsx). Dữ liệu: `net.json` của khoá (tập con
// public/kanjivg/strokes.json, KanjiVG © Ulrich Apel, CC BY-SA 3.0).
//
// Mỗi nét là MỘT đường TIM (không khép kín) trong hệ 109×109, gốc trên-trái
// (KHÔNG lật trục như dữ liệu hanzi-writer ở NetChu.swift). Lệnh dùng: M m C c
// S s (đo 23/10 trên 974 chữ) — bộ đọc dưới đây nhận thêm L l H h V v Z z cho
// chắc. ⚠️ Vẽ bằng `.stroke`, KHÔNG `.fill` (fill một đường hở là tô kín ruột).
// ════════════════════════════════════════════════════════════════

enum DuongKVG {
    static let KHUNG: CGFloat = 109

    nonisolated(unsafe) private static var dem: [String: Path] = [:]
    private static let khoa = NSLock()

    /// Đường của một nét (hệ 109) — đệm theo chuỗi `d` (Shape có thể gọi ngoài luồng chính ⇒ có khoá).
    static func path(_ d: String) -> Path {
        khoa.lock(); defer { khoa.unlock() }
        if let p = dem[d] { return p }
        let p = doc(d)
        if dem.count > 4000 { dem.removeAll() }
        dem[d] = p
        return p
    }

    /// Điểm bắt đầu của nét (lệnh M đầu) — chỗ đặt số thứ tự.
    static func dau(_ d: String) -> CGPoint {
        let so = tachSo(String(d.drop { $0 != "M" && $0 != "m" }.dropFirst()).prefix(40).description)
        return so.count >= 2 ? CGPoint(x: so[0], y: so[1]) : .zero
    }

    private static func tachSo(_ s: String) -> [CGFloat] {
        var out: [CGFloat] = []
        var cur = ""
        func chot() { if let v = Double(cur) { out.append(CGFloat(v)) }; cur = "" }
        for c in s {
            if c.isLetter && c != "e" { break }
            if c == "-" { chot(); cur = "-" }
            else if c == "." && cur.contains(".") { chot(); cur = "." }
            else if c.isNumber || c == "." || c == "e" { cur.append(c) }
            else { chot() }
        }
        chot()
        return out
    }

    /// Bộ đọc đường SVG tối giản (tuyệt đối + tương đối, lệnh lặp ngầm).
    static func doc(_ d: String) -> Path {
        var p = Path()
        var lenh: Character = "M"
        var so: [CGFloat] = []
        var cur = CGPoint.zero, dauNet = CGPoint.zero
        var ctrlCuoi: CGPoint?

        func chay() {
            let rel = lenh.isLowercase
            let L = Character(lenh.uppercased())
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y) }
            var i = 0
            switch L {
            case "M":
                var dau = true
                while i + 1 < so.count {
                    let q = pt(so[i], so[i + 1])
                    if dau { p.move(to: q); dauNet = q; dau = false } else { p.addLine(to: q) }
                    cur = q; i += 2
                }
                ctrlCuoi = nil
            case "L":
                while i + 1 < so.count { let q = pt(so[i], so[i + 1]); p.addLine(to: q); cur = q; i += 2 }
                ctrlCuoi = nil
            case "H":
                while i < so.count { let q = CGPoint(x: rel ? cur.x + so[i] : so[i], y: cur.y); p.addLine(to: q); cur = q; i += 1 }
                ctrlCuoi = nil
            case "V":
                while i < so.count { let q = CGPoint(x: cur.x, y: rel ? cur.y + so[i] : so[i]); p.addLine(to: q); cur = q; i += 1 }
                ctrlCuoi = nil
            case "C":
                while i + 5 < so.count {
                    let c1 = pt(so[i], so[i + 1]), c2 = pt(so[i + 2], so[i + 3]), q = pt(so[i + 4], so[i + 5])
                    p.addCurve(to: q, control1: c1, control2: c2)
                    ctrlCuoi = c2; cur = q; i += 6
                }
            case "S":
                while i + 3 < so.count {
                    let c1 = ctrlCuoi.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                    let c2 = pt(so[i], so[i + 1]), q = pt(so[i + 2], so[i + 3])
                    p.addCurve(to: q, control1: c1, control2: c2)
                    ctrlCuoi = c2; cur = q; i += 4
                }
            case "Z":
                p.closeSubpath(); cur = dauNet; ctrlCuoi = nil
            default: break
            }
            so.removeAll(keepingCapacity: true)
        }

        var soDang = ""
        func chotSo() { if let v = Double(soDang) { so.append(CGFloat(v)) }; soDang = "" }
        for c in d {
            if c.isLetter && c != "e" {
                chotSo(); chay(); lenh = c
            } else if c == "-" {
                if soDang.last == "e" { soDang.append(c) } else { chotSo(); soDang = "-" }
            } else if c == "." && soDang.contains(".") {
                chotSo(); soDang = "."
            } else if c.isNumber || c == "." || c == "e" {
                soDang.append(c)
            } else {
                chotSo()
            }
        }
        chotSo(); chay()
        return p
    }
}

/// Một nét KanjiVG, co theo khung vẽ.
struct NetKVG: Shape {
    let d: String
    func path(in r: CGRect) -> Path {
        let k = min(r.width, r.height) / DuongKVG.KHUNG
        return DuongKVG.path(d)
            .applying(CGAffineTransform(scaleX: k, y: k).translatedBy(x: r.minX / k, y: r.minY / k))
    }
}

/// Cả chữ (mọi nét) — vẽ chữ mờ, chữ mẫu tĩnh.
struct ChuKVG: Shape {
    let paths: [String]
    func path(in r: CGRect) -> Path {
        var p = Path()
        for d in paths { p.addPath(NetKVG(d: d).path(in: r)) }
        return p
    }
}

/// Bề dày nét theo cạnh khung (KanjiVG vẽ nét 3/109).
func beDayKVG(_ canh: CGFloat) -> CGFloat { max(2.4, canh * 0.034) }

// MARK: - Khung chạy thứ tự nét

/// Trạng thái phát của một khung nét — ngoài view để nút bên ngoài điều khiển được.
@MainActor
final class PhatNetSH: ObservableObject {
    /// Số nét đã hiện đủ (đứng yên).
    @Published var hienDen: Int
    /// Đang chạy: từ nét `tu`, bắt đầu lúc `luc`; `mot` = chỉ chạy một nét (nút "nét tiếp").
    @Published private(set) var chay: (tu: Int, luc: Date, mot: Bool)?
    @Published var cham = false
    let soNet: Int
    private var luot = 0

    init(soNet: Int, hienDu: Bool = true) {
        self.soNet = soNet
        hienDen = hienDu ? soNet : 0
    }

    var dangChay: Bool { chay != nil }
    var thoiGianNet: Double { cham ? 1.4 : 0.7 }

    func phat(tu: Int? = nil, mot: Bool = false) {
        guard soNet > 0 else { return }
        let bd = tu ?? (hienDen >= soNet ? 0 : hienDen)
        luot += 1
        let my = luot
        hienDen = bd
        chay = (bd, Date(), mot)
        let soLuot = mot ? 1 : soNet - bd
        let tg = thoiGianNet * Double(soLuot)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((tg + 0.05) * 1_000_000_000))
            guard let self, self.luot == my else { return }
            self.hienDen = min(self.soNet, bd + soLuot)
            self.chay = nil
        }
    }

    func dung() { luot += 1; if let c = chay { hienDen = min(soNet, c.tu + Int(Date().timeIntervalSince(c.luc) / thoiGianNet)) }; chay = nil }
    func den(_ n: Int) { luot += 1; chay = nil; hienDen = max(0, min(soNet, n)) }
}

/// Khung vẽ chữ theo KanjiVG: đứng yên (đủ nét) hoặc chạy lần lượt từng nét, có số thứ tự.
struct KhungNetSH: View {
    let chu: String
    let paths: [String]?
    @ObservedObject var phat: PhatNetSH
    /// Chỉ số (toàn cục) của nét đầu chữ này — một TỪ nhiều chữ dùng chung một `PhatNetSH`, chạy lần lượt từng chữ.
    var bu: Int = 0
    var hienSo = true
    var luoi = true

    var body: some View {
        GeometryReader { g in
            let canh = min(g.size.width, g.size.height)
            ZStack(alignment: .topLeading) {
                if luoi { LuoiDienSH(canh: canh) }
                if let paths, !paths.isEmpty {
                    TimelineView(.animation(paused: !phat.dangChay)) { tl in
                        noiDung(paths, canh: canh, bayGio: tl.date)
                    }
                } else {
                    Text(chu).font(.system(size: canh * 0.7, weight: .regular, design: .serif))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: canh, height: canh)
                }
            }
            .frame(width: canh, height: canh)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// MỘT `Canvas` vẽ cả chữ: nét mờ, nét đã hiện, nét đang chạy, số thứ tự. Đo 23/10 (bài Chữ Hán,
    /// iPad Pro 11" ảo): bản cũ mỗi nét một Shape + một Text định vị (chữ 10 nét ≈ 25 view) ⇒ mỗi hàng
    /// của khối viết dựng ~25–35 ms ⇒ giật khi cuộn tới. Canvas: một view, vẽ lại theo TimelineView.
    private func noiDung(_ paths: [String], canh: CGFloat, bayGio: Date) -> some View {
        let n = paths.count
        let tt = trangThai(n, bayGio)
        let w = beDayKVG(canh)
        let mauMo = AppColors.textTertiary.opacity(0.28)
        let mauCur = MauChuSH.mau(0xDC2626).color
        let mauChu = AppColors.textPrimary
        let mauSo = AppColors.accent
        let hienSo = hienSo
        return Canvas { ctx, _ in
            let k = canh / DuongKVG.KHUNG
            let co = CGAffineTransform(scaleX: k, y: k)
            let kieu = StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
            if tt.daHien < n || tt.dang != nil {
                var mo = Path()
                for d in paths { mo.addPath(DuongKVG.path(d), transform: co) }
                ctx.stroke(mo, with: .color(mauMo), style: kieu)
            }
            for i in 0..<n {
                if i < tt.daHien {
                    let laCuoi = i == tt.daHien - 1 && tt.daHien < n && tt.dang == nil
                    ctx.stroke(DuongKVG.path(paths[i]).applying(co), with: .color(laCuoi ? mauCur : mauChu), style: kieu)
                } else if i == tt.dang {
                    ctx.stroke(DuongKVG.path(paths[i]).trimmedPath(from: 0, to: tt.phan).applying(co), with: .color(mauCur), style: kieu)
                }
            }
            guard hienSo else { return }
            for i in 0..<min(n, max(tt.daHien, (tt.dang ?? -1) + 1)) {
                let p = DuongKVG.dau(paths[i])
                let noi = i == tt.dang || (tt.dang == nil && i == tt.daHien - 1 && tt.daHien < n)
                ctx.draw(Text("\(i + 1)").font(.system(size: max(8, canh * 0.075), weight: .bold).monospacedDigit()).foregroundColor(noi ? mauCur : mauSo),
                         at: CGPoint(x: max(6, (p.x - 4) * k), y: max(6, (p.y - 4) * k)))
            }
        }
        .frame(width: canh, height: canh, alignment: .topLeading)
    }

    /// Trạng thái CỦA CHỮ NÀY (đổi chỉ số toàn cục ⇒ chỉ số trong chữ bằng `bu`).
    private func trangThai(_ n: Int, _ bayGio: Date) -> (daHien: Int, dang: Int?, phan: CGFloat) {
        let (g, dangG, phan): (Int, Int?, CGFloat) = {
            guard let c = phat.chay else { return (phat.hienDen, nil, 0) }
            let el = bayGio.timeIntervalSince(c.luc) / phat.thoiGianNet
            let i = c.tu + Int(el)
            let gioiHan = c.mot ? c.tu + 1 : phat.soNet
            if i >= gioiHan { return (gioiHan, nil, 0) }
            return (i, i, CGFloat(el - floor(el)))
        }()
        let daHien = max(0, min(n, g - bu))
        let dang = dangG.flatMap { $0 - bu >= 0 && $0 - bu < n ? $0 - bu : nil }
        return (daHien, dang, phan)
    }
}

/// Ô vuông có chữ thập nét đứt (như vở tập viết).
struct LuoiDienSH: View {
    let canh: CGFloat
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: canh / 2, y: 2)); p.addLine(to: CGPoint(x: canh / 2, y: canh - 2))
            p.move(to: CGPoint(x: 2, y: canh / 2)); p.addLine(to: CGPoint(x: canh - 2, y: canh / 2))
        }
        .stroke(AppColors.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .frame(width: canh, height: canh)
    }
}

/// Trình phát thứ tự nét đầy đủ (thẻ chữ Hán): khung lớn + Phát/Dừng, lùi/tiến từng nét, chậm, số nét.
struct TrinhPhatNetSH: View {
    let chu: String
    let paths: [String]?
    @StateObject private var phat: PhatNetSH
    @State private var hienSo = true

    init(chu: String, paths: [String]?) {
        self.chu = chu
        self.paths = paths
        _phat = StateObject(wrappedValue: PhatNetSH(soNet: paths?.count ?? 0, hienDu: false))
    }

    var body: some View {
        let n = paths?.count ?? 0
        VStack(spacing: 8) {
            KhungNetSH(chu: chu, paths: paths, phat: phat, hienSo: hienSo)
                .frame(width: 190, height: 190)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.backgroundCard))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AppColors.border, lineWidth: 1))
            if n == 0 {
                Text("Chưa có dữ liệu thứ tự nét cho chữ này.").font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary)
            } else {
                Text(phat.dangChay ? "Đang viết…" : "Nét \(phat.hienDen)/\(n)").font(.system(size: 12.5, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                HStack(spacing: 6) {
                    nut("backward.end.fill", "Về đầu") { phat.den(0) }
                    nut("chevron.left", "Lùi một nét") { phat.den(phat.hienDen - 1) }.disabled(phat.hienDen == 0)
                    Button {
                        if phat.dangChay { phat.dung() } else { phat.phat() }
                    } label: {
                        Label(phat.dangChay ? "Dừng" : (phat.hienDen >= n ? "Phát lại" : "Phát"), systemImage: phat.dangChay ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundColor(.white)
                            .background(Capsule().fill(AppColors.primary))
                    }
                    .buttonStyle(.plain)
                    nut("chevron.right", "Nét tiếp theo") { phat.phat(tu: phat.hienDen, mot: true) }.disabled(phat.hienDen >= n || phat.dangChay)
                    nut("forward.end.fill", "Hiện đủ nét") { phat.den(n) }
                }
                HStack(spacing: 8) {
                    Toggle("Chậm", isOn: $phat.cham).toggleStyle(.button).font(.system(size: 12.5))
                    Toggle("Số nét", isOn: $hienSo).toggleStyle(.button).font(.system(size: 12.5))
                }
            }
        }
        .onAppear { if n > 0 { phat.phat(tu: 0) } }
    }

    private func nut(_ bt: String, _ ten: String, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Image(systemName: bt).font(.system(size: 13, weight: .bold))
                .frame(width: 32, height: 32)
                .background(Circle().fill(AppColors.backgroundTertiary))
                .foregroundColor(AppColors.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ten)
    }
}
