import CoreGraphics
import Foundation

// ════════════════════════════════════════════════════════════════
// SƠ ĐỒ KHỐI / LUỒNG — tự DÀN BỐ CỤC rồi xuất NÉT BÚT
//
// Máy chủ (`/vo/so-do/viec`) chỉ trả CẤU TRÚC: nút (nhãn, loại hộp, nhóm) và
// cạnh (từ, tới, nhãn). Hình học làm ở đây, vì model vẽ hộp lệch, mũi tên chéo
// đè chữ — còn mã thì căn thẳng hàng được.
//
// Hai dạng:
//   · `luong`   — sơ đồ khối / kiến trúc / flowchart, dàn theo TẦNG
//     (Sugiyama rút gọn): chia tầng theo cạnh xuôi → chèn nút ảo cho cạnh
//     dài → xếp thứ tự trong tầng bằng trọng tâm → canh toạ độ bằng hồi quy
//     đơn điệu (PAVA) → mũi tên gấp khúc vuông góc.
//   · `tuan_tu` — sơ đồ tuần tự: các bên xếp ngang, đường đời đứt nét, thông
//     điệp là mũi tên ngang đánh số theo thời gian.
//
// Cạnh "ngược" (tới nút đứng TRƯỚC trong danh sách model trả — thường là
// đường trả lời: Model → Controller) được đảo chiều để chia tầng, rồi vẽ lại
// đúng chiều. Cặp đi–về giữa hai nút thành hai mũi tên song song.
//
// Thuần CoreGraphics + Foundation để dựng thử được trên macOS.
// ════════════════════════════════════════════════════════════════

/// Vai trò của từng nét — quyết định mực và cỡ khi đặt lên trang.
enum VaiTroNet: Int {
    /// Nét chính (khung hộp, mũi tên, nét chữ Hán) — bút người dùng đang cầm.
    case chinh
    /// Chữ viết bằng phông nét đơn — luôn mảnh, bút to thì chữ nhoè thành cục.
    case chu
    /// Nét mờ làm khung (ô 田) — xám nhạt, mảnh.
    case mo
    /// Số thứ tự nét — đỏ như lời thầy ghi chú.
    case so
    /// Nét phụ mảnh (khối bao nhóm, đường đời tuần tự) — màu bút, nhạt.
    case phu
}

/// Một bản vẽ bằng nét, toạ độ pt (gốc trên-trái), kèm vai trò từng nét.
struct BanVeNet {
    var net: [[CGPoint]] = []
    var loai: [VaiTroNet] = []
    var rong: CGFloat = 0
    var cao: CGFloat = 0
    /// Cỡ ĐIỂM tối thiểu cho nét `.chinh` (pt). Chữ Hán ô lớn cần nét đậm theo
    /// cỡ ô, bút mảnh của người dùng làm chữ gầy như que.
    var coNetChinh: CGFloat?
    /// Cỡ ĐIỂM CỐ ĐỊNH cho nét `.chinh` (bỏ qua bút người dùng). Sơ đồ khối
    /// dùng: bút dày của người dùng (cỡ điểm ~6) biến mũi tên thành cục mực
    /// và hình người thành vết đen — đo trên máy ảo iPadOS 27, 29/09.
    var coNetCoDinh: CGFloat?

    mutating func them(_ n: [CGPoint], _ l: VaiTroNet) {
        guard !n.isEmpty else { return }
        net.append(n); loai.append(l)
    }
    mutating func them(_ ns: [[CGPoint]], _ l: VaiTroNet) { for n in ns { them(n, l) } }

    /// Dời mọi nét để khung bao bắt đầu ở (le, le); đặt `rong`/`cao`.
    mutating func chotKhung(le: CGFloat) {
        var r = CGRect.null
        for n in net { for p in n { r = r.union(CGRect(x: p.x, y: p.y, width: 0.01, height: 0.01)) } }
        guard !r.isNull else { return }
        let dx = le - r.minX, dy = le - r.minY
        net = net.map { $0.map { CGPoint(x: $0.x + dx, y: $0.y + dy) } }
        rong = r.width + 2 * le
        cao = r.height + 2 * le
    }
}

/// Đồ thị máy chủ trả. Mọi trường `var` + optional (C4 trong CLAUDE.md iOS).
struct DoThiKhoi: Codable {
    var tieuDe: String?
    var dang: String?
    var huong: String?
    var nut: [Nut]?
    var nhom: [Nhom]?
    var canh: [Canh]?
    var model: String?
    var xong: Bool?

    struct Nut: Codable { var id: String?; var nhan: String?; var loai: String?; var nhom: String? }
    struct Nhom: Codable { var id: String?; var nhan: String? }
    struct Canh: Codable { var tu: String?; var toi: String?; var nhan: String? }
}

// MARK: - Hình cơ bản bằng nét

enum HinhNet {
    static func cung(_ c: CGPoint, rx: CGFloat, ry: CGFloat, tu: CGFloat, den: CGFloat, n: Int = 24) -> [CGPoint] {
        (0...n).map { i in
            let a = tu + (den - tu) * CGFloat(i) / CGFloat(n)
            return CGPoint(x: c.x + cos(a) * rx, y: c.y + sin(a) * ry)
        }
    }

    /// Hộp bo góc — MỘT nét liền, bắt đầu ở cạnh trên (như tay vẽ).
    static func hopBo(_ r: CGRect, bo: CGFloat = 6) -> [CGPoint] {
        let b = min(bo, r.width / 2, r.height / 2)
        var d: [CGPoint] = [CGPoint(x: r.minX + b, y: r.minY), CGPoint(x: r.maxX - b, y: r.minY)]
        d += cung(CGPoint(x: r.maxX - b, y: r.minY + b), rx: b, ry: b, tu: -.pi / 2, den: 0, n: 5).dropFirst()
        d.append(CGPoint(x: r.maxX, y: r.maxY - b))
        d += cung(CGPoint(x: r.maxX - b, y: r.maxY - b), rx: b, ry: b, tu: 0, den: .pi / 2, n: 5).dropFirst()
        d.append(CGPoint(x: r.minX + b, y: r.maxY))
        d += cung(CGPoint(x: r.minX + b, y: r.maxY - b), rx: b, ry: b, tu: .pi / 2, den: .pi, n: 5).dropFirst()
        d.append(CGPoint(x: r.minX, y: r.minY + b))
        d += cung(CGPoint(x: r.minX + b, y: r.minY + b), rx: b, ry: b, tu: .pi, den: 1.5 * .pi, n: 5).dropFirst()
        return d
    }

    static func thoi(_ r: CGRect) -> [CGPoint] {
        [CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.maxX, y: r.midY), CGPoint(x: r.midX, y: r.maxY),
         CGPoint(x: r.minX, y: r.midY), CGPoint(x: r.midX, y: r.minY)]
    }

    static let RY_TRU: CGFloat = 6

    /// Trụ CSDL: nắp elip đủ vòng + thân (hai cạnh + đáy nửa elip phía trước).
    static func tru(_ r: CGRect) -> [[CGPoint]] {
        let ry = RY_TRU, rx = r.width / 2
        let nap = cung(CGPoint(x: r.midX, y: r.minY + ry), rx: rx, ry: ry, tu: 0, den: 2 * .pi, n: 32)
        var than: [CGPoint] = [CGPoint(x: r.minX, y: r.minY + ry)]
        // y hướng xuống: góc π → 0 đi qua sin > 0 ⇒ nửa DƯỚI elip (mặt trước của đáy).
        than += cung(CGPoint(x: r.midX, y: r.maxY - ry), rx: rx, ry: ry, tu: .pi, den: 0, n: 20)
        than.append(CGPoint(x: r.maxX, y: r.minY + ry))
        return [nap, than]
    }

    /// Hình con người que, đỉnh đầu ở `dinh`, cao `cao`.
    static func nguoi(dinh: CGPoint, cao: CGFloat) -> [[CGPoint]] {
        let rDau = cao * 0.17
        let dau = cung(CGPoint(x: dinh.x, y: dinh.y + rDau), rx: rDau, ry: rDau, tu: -.pi / 2, den: 1.5 * .pi, n: 20)
        let co = CGPoint(x: dinh.x, y: dinh.y + 2 * rDau)
        let hong = CGPoint(x: dinh.x, y: dinh.y + cao * 0.66)
        let than = [co, hong]
        let tay = [CGPoint(x: dinh.x - cao * 0.3, y: dinh.y + cao * 0.46), CGPoint(x: dinh.x, y: dinh.y + cao * 0.4),
                   CGPoint(x: dinh.x + cao * 0.3, y: dinh.y + cao * 0.46)]
        let chan = [CGPoint(x: dinh.x - cao * 0.24, y: dinh.y + cao), hong, CGPoint(x: dinh.x + cao * 0.24, y: dinh.y + cao)]
        return [dau, than, tay, chan]
    }

    /// Đầu mũi tên ở cuối `d` (một nét: cánh – mũi – cánh).
    static func dauMuiTen(_ d: [CGPoint], dai: CGFloat = 7.5) -> [CGPoint] {
        guard d.count >= 2 else { return [] }
        let b = d[d.count - 1]
        var a = d[d.count - 2]
        var i = d.count - 2
        while hypot(b.x - a.x, b.y - a.y) < 0.5 && i > 0 { i -= 1; a = d[i] }
        let g = atan2(b.y - a.y, b.x - a.x)
        let m: CGFloat = 0.47
        return [CGPoint(x: b.x - dai * cos(g - m), y: b.y - dai * sin(g - m)), b,
                CGPoint(x: b.x - dai * cos(g + m), y: b.y - dai * sin(g + m))]
    }

    /// Đường đứt nét (mỗi gạch là một nét riêng).
    static func dut(_ a: CGPoint, _ b: CGPoint, gach: CGFloat = 6, ho: CGFloat = 4) -> [[CGPoint]] {
        let dai = hypot(b.x - a.x, b.y - a.y)
        guard dai > 0.5 else { return [] }
        var ra: [[CGPoint]] = []
        var t: CGFloat = 0
        while t < dai {
            let t2 = min(dai, t + gach)
            ra.append([CGPoint(x: a.x + (b.x - a.x) * t / dai, y: a.y + (b.y - a.y) * t / dai),
                       CGPoint(x: a.x + (b.x - a.x) * t2 / dai, y: a.y + (b.y - a.y) * t2 / dai)])
            t = t2 + ho
        }
        return ra
    }

    static func dutKhung(_ r: CGRect) -> [[CGPoint]] {
        let g = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                 CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
        return (0..<4).flatMap { dut(g[$0], g[($0 + 1) % 4]) }
    }
}

// MARK: - Dàn bố cục

enum SoDoKhoi {
    /// Chiều cao CHỮ HOA (pt) của nhãn hộp và nhãn cạnh. ~13pt / ~11pt cỡ chữ in.
    static let CO_NUT: CGFloat = 9
    static let CO_CANH: CGFloat = 7.5
    static let RONG_CHU_NUT: CGFloat = 116
    static let RONG_CHU_CANH: CGFloat = 104

    private enum Hinh: String { case hop, quyet_dinh, csdl, nguoi, tron }

    private struct Nut {
        let id: String
        let hinh: Hinh
        let dong: [String]
        let nhom: String?
        let chuRong: CGFloat
        let chuCao: CGFloat
        var w: CGFloat
        var h: CGFloat
        var ao = false
        // toạ độ tâm (khung TB)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var tang = 0
    }

    private struct Canh {
        var tu: Int
        var toi: Int
        let nhan: String?
        let nguoc: Bool
        var chuoi: [Int] = []  // tu … nút ảo … toi (khung đã đảo)
    }

    /// Khối chữ (đã ngắt dòng) — kích thước.
    private static func doKhoi(_ dong: [String], co: CGFloat) -> CGSize {
        let k = PhongNetDon.khoi(dong, co: co)
        return CGSize(width: k.rong, height: k.cao)
    }

    static func dung(_ g: DoThiKhoi) -> BanVeNet? {
        let nuts = (g.nut ?? []).compactMap { n -> (String, String, String, String?)? in
            guard let id = n.id, !id.isEmpty else { return nil }
            return (id, n.nhan ?? id, n.loai ?? "hop", n.nhom)
        }
        guard nuts.count >= 2 else { return nil }
        if g.dang == "tuan_tu" { return tuanTu(g, nuts) }
        return luong(g, nuts)
    }

    // MARK: Dạng luồng

    private static func taoNut(id: String, nhan: String, loai: String, nhom: String?, doiChieu: Bool) -> Nut {
        let hinh = Hinh(rawValue: loai) ?? .hop
        let rongChu = RONG_CHU_NUT
        let dong = PhongNetDon.ngatDong(nhan, co: CO_NUT, rongToiDa: rongChu)
        let k = doKhoi(dong, co: CO_NUT)
        var w: CGFloat, h: CGFloat
        switch hinh {
        case .hop:  w = max(k.width + 26, 66); h = max(k.height + 14, 34)
        case .tron: h = max(k.height + 12, 30); w = max(k.width + h, 70)
        case .quyet_dinh:
            w = max(k.width * 1.75 + 24, 96)
            h = max(k.height / max(0.2, 1 - (k.width + 8) / w) + 10, 50)
        case .csdl: w = max(k.width + 24, 72); h = max(k.height + 14, 34) + 2 * HinhNet.RY_TRU
        case .nguoi: w = max(k.width + 6, 34); h = 34 + 6 + k.height
        }
        if doiChieu { swap(&w, &h) }
        return Nut(id: id, hinh: hinh, dong: dong, nhom: nhom, chuRong: k.width, chuCao: k.height, w: w, h: h)
    }

    private static func luong(_ g: DoThiKhoi, _ tho: [(String, String, String, String?)]) -> BanVeNet? {
        let lr = g.huong == "LR"
        var nut = tho.map { taoNut(id: $0.0, nhan: $0.1, loai: $0.2, nhom: $0.3, doiChieu: lr) }
        let chiSo = Dictionary(nut.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })

        // 1) Cạnh: ngược (tới nút đứng trước) thì đảo để chia tầng.
        var canh: [Canh] = []
        for c in g.canh ?? [] {
            guard let a = c.tu.flatMap({ chiSo[$0] }), let b = c.toi.flatMap({ chiSo[$0] }), a != b else { continue }
            let nhan = (c.nhan?.isEmpty == false) ? c.nhan : nil
            canh.append(a < b ? Canh(tu: a, toi: b, nhan: nhan, nguoc: false)
                              : Canh(tu: b, toi: a, nhan: nhan, nguoc: true))
        }

        // 2) Chia tầng — thứ tự danh sách là thứ tự tô-pô của cạnh xuôi.
        let soThat = nut.count
        for v in 0..<soThat {
            for c in canh where c.toi == v { nut[v].tang = max(nut[v].tang, nut[c.tu].tang + 1) }
        }
        // Nguồn treo cao (chỉ có cạnh ra, đích ở tầng sâu) thì kéo xuống sát đích.
        for v in 0..<soThat where !canh.contains(where: { $0.toi == v }) {
            let dich = canh.filter { $0.tu == v }.map { nut[$0.toi].tang }
            if let m = dich.min(), m - 1 > nut[v].tang { nut[v].tang = m - 1 }
        }

        // 3) Nút ảo cho cạnh vượt nhiều tầng.
        for i in canh.indices {
            var chuoi = [canh[i].tu]
            let t0 = nut[canh[i].tu].tang, t1 = nut[canh[i].toi].tang
            if t1 - t0 > 1 {
                for t in (t0 + 1)..<t1 {
                    var a = Nut(id: "~\(i)-\(t)", hinh: .hop, dong: [], nhom: nil, chuRong: 0, chuCao: 0, w: 14, h: 0)
                    a.ao = true; a.tang = t
                    nut.append(a); chuoi.append(nut.count - 1)
                }
            }
            chuoi.append(canh[i].toi)
            canh[i].chuoi = chuoi
        }

        // 4) Thứ tự trong tầng: trọng tâm, giữ nhóm liền nhau.
        let soTang = (nut.map(\.tang).max() ?? 0) + 1
        var tang: [[Int]] = Array(repeating: [], count: soTang)
        for v in nut.indices { tang[nut[v].tang].append(v) }
        var truoc: [Int: [Int]] = [:], sau: [Int: [Int]] = [:]
        for c in canh { for (a, b) in zip(c.chuoi, c.chuoi.dropFirst()) { sau[a, default: []].append(b); truoc[b, default: []].append(a) } }
        func viTri() -> [Int: CGFloat] {
            var p: [Int: CGFloat] = [:]
            for l in tang { for (i, v) in l.enumerated() { p[v] = CGFloat(i) } }
            return p
        }
        func sapXep(_ l: [Int], khoa: [Int: CGFloat]) -> [Int] {
            // Khoá nhóm = trung bình khoá các thành viên cùng nhóm trong tầng.
            var tbNhom: [String: CGFloat] = [:]
            for n in Set(l.compactMap { nut[$0].nhom }) {
                let ds = l.filter { nut[$0].nhom == n }.compactMap { khoa[$0] }
                tbNhom[n] = ds.reduce(0, +) / CGFloat(max(ds.count, 1))
            }
            return l.sorted { a, b in
                let ka = nut[a].nhom.flatMap { tbNhom[$0] } ?? khoa[a] ?? 0
                let kb = nut[b].nhom.flatMap { tbNhom[$0] } ?? khoa[b] ?? 0
                if abs(ka - kb) > 0.001 { return ka < kb }
                return (khoa[a] ?? 0) < (khoa[b] ?? 0)
            }
        }
        for vong in 0..<6 {
            let xuong = vong % 2 == 0
            let thuTu = xuong ? Array(1..<max(soTang, 1)) : Array((0..<max(soTang - 1, 0)).reversed())
            for t in thuTu {
                let p = viTri()
                var khoa: [Int: CGFloat] = [:]
                for v in tang[t] {
                    let ke = (xuong ? truoc[v] : sau[v]) ?? []
                    khoa[v] = ke.isEmpty ? (p[v] ?? 0) : ke.compactMap { p[$0] }.reduce(0, +) / CGFloat(ke.count)
                }
                tang[t] = sapXep(tang[t], khoa: khoa)
            }
        }

        // 5) Toạ độ trục tầng (y trong khung TB).
        let khoangTang: CGFloat = {
            if !lr { return 62 }
            // LR: nhãn cạnh nằm TRÊN đoạn ngang giữa hai tầng ⇒ khoảng đủ rộng cho nhãn.
            let rong = canh.compactMap { $0.nhan }.map {
                PhongNetDon.ngatDong($0, co: CO_CANH, rongToiDa: RONG_CHU_CANH).map { PhongNetDon.doRong($0, co: CO_CANH) }.max() ?? 0
            }.max() ?? 0
            return min(max(80, rong + 64), RONG_CHU_CANH + 64)
        }()
        var yTang: [CGFloat] = []
        var caoTang: [CGFloat] = []
        var y: CGFloat = 0
        for (t, l) in tang.enumerated() {
            let h = l.map { nut[$0].h }.max() ?? 0
            yTang.append(y + h / 2); caoTang.append(h)
            y += h + khoangTang
            // Ranh giới nhóm nằm giữa hai tầng ⇒ chừa thêm chỗ cho viền + tên nhóm.
            if t + 1 < tang.count {
                let a = Set(l.compactMap { nut[$0].nhom }), b = Set(tang[t + 1].compactMap { nut[$0].nhom })
                if a != b { y += 24 }
            }
        }
        for v in nut.indices { nut[v].y = yTang[nut[v].tang] }

        // 6) Toạ độ trục ngang: PAVA về phía trung bình hàng xóm.
        let khe: CGFloat = 34
        func tach(_ a: Int, _ b: Int) -> CGFloat {
            var s = nut[a].w / 2 + nut[b].w / 2 + (nut[a].ao || nut[b].ao ? 10 : khe)
            if nut[a].nhom != nut[b].nhom { s += 18 }
            return s
        }
        for l in tang {
            var x: CGFloat = 0
            for (i, v) in l.enumerated() {
                if i > 0 { x += tach(l[i - 1], v) }
                nut[v].x = x
            }
            let giua = x / 2
            for v in l { nut[v].x -= giua }
        }
        for vong in 0..<10 {
            let xuong = vong % 2 == 0
            let thuTu = xuong ? Array(0..<soTang) : Array((0..<soTang).reversed())
            for t in thuTu {
                let l = tang[t]
                guard !l.isEmpty else { continue }
                let muon: [CGFloat] = l.map { v in
                    let ke = (truoc[v] ?? []) + (sau[v] ?? [])
                    guard !ke.isEmpty else { return nut[v].x }
                    return ke.map { nut[$0].x }.reduce(0, +) / CGFloat(ke.count)
                }
                // x_i = y_i + c_i với c_i cộng dồn khoảng tách ⇒ ràng buộc y không giảm.
                var c: [CGFloat] = [0]
                for i in 1..<l.count { c.append(c[i - 1] + tach(l[i - 1], l[i])) }
                let yy = pava(zip(muon, c).map { $0 - $1 })
                for (i, v) in l.enumerated() { nut[v].x = yy[i] + c[i] }
            }
        }

        // 7) Cổng: cạnh ra ở đáy, cạnh vào ở đỉnh; nhiều cạnh cùng mặt thì rải đều.
        var raCua: [Int: [(Int, Int)]] = [:]   // nút → [(chỉ số cạnh, bước kế)]
        var vaoCua: [Int: [(Int, Int)]] = [:]
        for (i, c) in canh.enumerated() {
            let ch = c.chuoi
            for k in 0..<(ch.count - 1) {
                raCua[ch[k], default: []].append((i, ch[k + 1]))
                vaoCua[ch[k + 1], default: []].append((i, ch[k]))
            }
        }
        func cong(_ v: Int, canh i: Int, ra: Bool) -> CGPoint {
            let n = nut[v]
            if n.ao { return CGPoint(x: n.x, y: n.y) }
            let ds = ((ra ? raCua[v] : vaoCua[v]) ?? []).sorted {
                nut[$0.1].x != nut[$1.1].x ? nut[$0.1].x < nut[$1.1].x : $0.0 < $1.0
            }
            let k = ds.firstIndex { $0.0 == i } ?? 0
            let rongDung = n.hinh == .quyet_dinh ? n.w * 0.34 : n.w * 0.62
            let buoc = ds.count > 1 ? min(20, rongDung / CGFloat(ds.count - 1)) : 0
            let dx = (CGFloat(k) - CGFloat(ds.count - 1) / 2) * buoc
            var dy = n.h / 2
            if n.hinh == .quyet_dinh { dy = n.h / 2 * (1 - abs(dx) / (n.w / 2)) }
            return CGPoint(x: n.x + dx, y: n.y + (ra ? dy : -dy))
        }

        // 8) Đường đi: gấp khúc vuông góc giữa hai tầng liền nhau.
        var soNgangTrongKhe: [Int: Int] = [:]
        var duong: [[CGPoint]] = []
        for (i, c) in canh.enumerated() {
            var d: [CGPoint] = []
            // Chuỗi nút ảo: kéo thẳng về một cột (PAVA để lại vài pt lệch giữa
            // các tầng ⇒ mũi tên dài có những bậc thang nhỏ xấu mắt).
            let ao = c.chuoi.filter { nut[$0].ao }
            if ao.count > 1 {
                let xs = ao.map { nut[$0].x }.sorted()
                let giua = xs[xs.count / 2]
                if xs.last! - xs.first! < 40 { for v in ao { nut[v].x = giua } }
            }
            for k in 0..<(c.chuoi.count - 1) {
                let a = cong(c.chuoi[k], canh: i, ra: true)
                let b = cong(c.chuoi[k + 1], canh: i, ra: false)
                if d.isEmpty { d.append(a) } else if hypot(d.last!.x - a.x, d.last!.y - a.y) > 0.5 { d.append(a) }
                if abs(a.x - b.x) < 1.5 {
                    d.append(CGPoint(x: a.x, y: b.y))
                } else {
                    let t = nut[c.chuoi[k]].tang
                    let so = soNgangTrongKhe[t, default: 0]
                    soNgangTrongKhe[t] = so + 1
                    let dayTang = yTang[t] + caoTang[t] / 2
                    let dinhSau = yTang[t + 1] - caoTang[t + 1] / 2
                    let lech = CGFloat(so % 3 - 1) * 7
                    let ym = (dayTang + dinhSau) / 2 + lech
                    d += [CGPoint(x: a.x, y: ym), CGPoint(x: b.x, y: ym), b]
                }
            }
            duong.append(gonDuong(c.nguoc ? d.reversed() : d))
        }

        // 9) Đổi sang khung thật (LR = chuyển vị) rồi vẽ.
        func doi(_ p: CGPoint) -> CGPoint { lr ? CGPoint(x: p.y, y: p.x) : p }
        var ban = BanVeNet()
        var vat: [CGRect] = []   // vùng đã có chữ/hộp — để nhãn cạnh né
        var hopNut: [Int: CGRect] = [:]
        for v in 0..<soThat {
            let n = nut[v]
            let c = doi(CGPoint(x: n.x, y: n.y))
            let (w, h) = lr ? (n.h, n.w) : (n.w, n.h)
            let r = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
            hopNut[v] = r
            vat.append(r)
            var tamChu = CGPoint(x: r.midX, y: r.midY)
            switch n.hinh {
            case .hop: ban.them(HinhNet.hopBo(r), .chinh)
            case .tron: ban.them(HinhNet.hopBo(r, bo: r.height / 2), .chinh)
            case .quyet_dinh: ban.them(HinhNet.thoi(r), .chinh)
            case .csdl:
                ban.them(HinhNet.tru(r), .chinh)
                tamChu.y += HinhNet.RY_TRU * 0.9
            case .nguoi:
                ban.them(HinhNet.nguoi(dinh: CGPoint(x: r.midX, y: r.minY), cao: 34), .chinh)
                tamChu.y = r.minY + 40 + n.chuCao / 2
            }
            let k = PhongNetDon.khoi(n.dong, co: CO_NUT)
            ban.them(k.net.map { $0.map { CGPoint(x: $0.x + tamChu.x, y: $0.y + tamChu.y - k.cao / 2) } }, .chu)
        }

        var cacDuong = duong.map { $0.map(doi) }
        for d in cacDuong where d.count >= 2 {
            ban.them(d, .chinh)
            ban.them(HinhNet.dauMuiTen(d), .chinh)
        }
        // Nhãn cạnh: thử nhiều chỗ, chọn chỗ ít đè nhất. Đặt TRƯỚC khối nhóm để
        // khối nhóm nới ra bao cả nhãn của cạnh nằm trong nhóm.
        var hopNhan: [Int: CGRect] = [:]
        for (i, c) in canh.enumerated() {
            guard let nhan = c.nhan else { continue }
            let dong = PhongNetDon.ngatDong(nhan, co: CO_CANH, rongToiDa: RONG_CHU_CANH)
            let k = PhongNetDon.khoi(dong, co: CO_CANH)
            guard let r = datNhan(cacDuong[i], rong: k.rong, cao: k.cao, vat: vat,
                                  duongKhac: cacDuong, cuaMinh: i) else { continue }
            vat.append(r)
            hopNhan[i] = r
            ban.them(k.net.map { $0.map { CGPoint(x: $0.x + r.midX, y: $0.y + r.minY) } }, .chu)
        }

        // Khối bao nhóm (đứt nét) + tên nhóm ở góc trên không đè mũi tên.
        for gr in g.nhom ?? [] {
            guard let id = gr.id else { continue }
            let tv = (0..<soThat).filter { nut[$0].nhom == id }
            guard !tv.isEmpty else { continue }
            var r = tv.compactMap { hopNut[$0] }.reduce(CGRect.null) { $0.union($1) }
            for (i, c) in canh.enumerated() where nut[c.tu].nhom == id && nut[c.toi].nhom == id {
                if let h = hopNhan[i] { r = r.union(h) }
            }
            r = r.insetBy(dx: -12, dy: -10)
            let ten = gr.nhan ?? ""
            let coTen: CGFloat = 7
            if !ten.isEmpty { r.origin.y -= 15; r.size.height += 15 }
            ban.them(HinhNet.dutKhung(r), .phu)
            if !ten.isEmpty {
                let d = PhongNetDon.dong(ten, co: coTen)
                let trai = CGRect(x: r.minX + 6, y: r.minY + 4, width: d.rong, height: coTen + 3)
                let phai = CGRect(x: r.maxX - 6 - d.rong, y: r.minY + 4, width: d.rong, height: coTen + 3)
                let dung = cacDuong.contains { dk in (0..<max(dk.count - 1, 0)).contains { catHop(dk[$0], dk[$0 + 1], trai) } }
                    && !cacDuong.contains { dk in (0..<max(dk.count - 1, 0)).contains { catHop(dk[$0], dk[$0 + 1], phai) } }
                    ? phai : trai
                ban.them(d.net.map { $0.map { CGPoint(x: $0.x + dung.minX, y: $0.y + dung.minY) } }, .chu)
            }
        }
        cacDuong.removeAll()
        ban.chotKhung(le: 10)
        ban.coNetCoDinh = 3.4
        return ban
    }

    /// Bỏ điểm trùng / thẳng hàng.
    private static func gonDuong(_ d: [CGPoint]) -> [CGPoint] {
        var r: [CGPoint] = []
        for p in d {
            if let l = r.last, hypot(l.x - p.x, l.y - p.y) < 0.5 { continue }
            if r.count >= 2 {
                let a = r[r.count - 2], b = r[r.count - 1]
                let cheo = (b.x - a.x) * (p.y - b.y) - (b.y - a.y) * (p.x - b.x)
                if abs(cheo) < 0.5 { r[r.count - 1] = p; continue }
            }
            r.append(p)
        }
        return r
    }

    /// Hồi quy đơn điệu (không giảm) — Pool Adjacent Violators.
    private static func pava(_ v: [CGFloat]) -> [CGFloat] {
        var khoi: [(tong: CGFloat, dem: Int)] = []
        for x in v {
            khoi.append((x, 1))
            while khoi.count >= 2 {
                let b = khoi[khoi.count - 1], a = khoi[khoi.count - 2]
                if a.tong / CGFloat(a.dem) <= b.tong / CGFloat(b.dem) { break }
                khoi.removeLast(2)
                khoi.append((a.tong + b.tong, a.dem + b.dem))
            }
        }
        return khoi.flatMap { Array(repeating: $0.tong / CGFloat($0.dem), count: $0.dem) }
    }

    /// Chỗ đặt nhãn cạnh: cạnh đoạn dài nhất (bên phải/trái đoạn dọc, trên/dưới
    /// đoạn ngang), chấm điểm theo số vật bị đè.
    private static func datNhan(_ d: [CGPoint], rong: CGFloat, cao: CGFloat, vat: [CGRect],
                                duongKhac: [[CGPoint]], cuaMinh: Int) -> CGRect? {
        guard d.count >= 2 else { return nil }
        var ung: [(CGRect, CGFloat)] = []
        for i in 0..<(d.count - 1) {
            let a = d[i], b = d[i + 1]
            let dai = hypot(b.x - a.x, b.y - a.y)
            guard dai > 8 else { continue }
            let m = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            if abs(a.x - b.x) < 1 {
                ung.append((CGRect(x: m.x + 5, y: m.y - cao / 2, width: rong, height: cao), -dai))
                ung.append((CGRect(x: m.x - 5 - rong, y: m.y - cao / 2, width: rong, height: cao), -dai + 3))
            } else {
                ung.append((CGRect(x: m.x - rong / 2, y: m.y - cao - 1, width: rong, height: cao), -dai))
                ung.append((CGRect(x: m.x - rong / 2, y: m.y + 3, width: rong, height: cao), -dai + 3))
            }
        }
        func diem(_ r: CGRect) -> CGFloat {
            var s: CGFloat = 0
            for v0 in vat where v0.insetBy(dx: -3, dy: -3).intersects(r) {
                let v = v0.insetBy(dx: -3, dy: -3)
                s += 1000 * (v.intersection(r).width * v.intersection(r).height) / max(1, r.width * r.height) + 100 }
            for (j, dk) in duongKhac.enumerated() {
                for k in 0..<max(dk.count - 1, 0) where catHop(dk[k], dk[k + 1], r.insetBy(dx: 1, dy: 1)) {
                    s += j == cuaMinh ? 400 : 250
                }
            }
            return s
        }
        return ung.min { diem($0.0) + $0.1 * 0.5 < diem($1.0) + $1.1 * 0.5 }?.0
    }

    /// Đoạn thẳng (vuông góc hoặc không) có cắt hình chữ nhật không.
    private static func catHop(_ a: CGPoint, _ b: CGPoint, _ r: CGRect) -> Bool {
        let n = max(2, Int(hypot(b.x - a.x, b.y - a.y) / 3))
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            if r.contains(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)) { return true }
        }
        return false
    }

    // MARK: Dạng tuần tự

    private static func tuanTu(_ g: DoThiKhoi, _ tho: [(String, String, String, String?)]) -> BanVeNet? {
        var ben = tho.map { taoNut(id: $0.0, nhan: $0.1, loai: $0.2, nhom: nil, doiChieu: false) }
        let chiSo = Dictionary(ben.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        struct TD { let a: Int; let b: Int; let dong: [String]; let k: (net: [[CGPoint]], rong: CGFloat, cao: CGFloat) }
        var td: [TD] = []
        for (i, c) in (g.canh ?? []).enumerated() {
            guard let a = c.tu.flatMap({ chiSo[$0] }), let b = c.toi.flatMap({ chiSo[$0] }) else { continue }
            let chu = "\(td.count + 1). " + (c.nhan ?? "")
            let dong = PhongNetDon.ngatDong(chu, co: CO_CANH, rongToiDa: 190)
            td.append(TD(a: a, b: b, dong: dong, k: PhongNetDon.khoi(dong, co: CO_CANH)))
            _ = i
        }
        guard !td.isEmpty else { return nil }

        // Khoảng giữa hai bên liền nhau: đủ cho hộp đầu và nhãn thông điệp.
        // Nhãn thông điệp đặt SÁT BÊN GỬI (không căn giữa mũi tên): căn giữa thì
        // mũi tên vượt nhiều cột đẩy nhãn đè lên đường đời ở giữa. Nên khoảng
        // giữa cột gửi và cột KỀ theo hướng gửi phải đủ chứa nhãn.
        var x: [CGFloat] = [0]
        for i in 1..<ben.count {
            var can = ben[i - 1].w / 2 + ben[i].w / 2 + 36
            for t in td where t.a != t.b {
                let ke = t.a + (t.b > t.a ? 1 : -1)
                if Set([t.a, ke]) == Set([i - 1, i]) { can = max(can, t.k.rong + 26) }
            }
            x.append(x[i - 1] + can)
        }
        for i in ben.indices { ben[i].x = x[i] }
        let dauCao = ben.map(\.h).max() ?? 34

        var ban = BanVeNet()
        for n in ben {
            let r = CGRect(x: n.x - n.w / 2, y: dauCao - n.h, width: n.w, height: n.h)
            var tamChu = CGPoint(x: r.midX, y: r.midY)
            switch n.hinh {
            case .csdl: ban.them(HinhNet.tru(r), .chinh); tamChu.y += HinhNet.RY_TRU * 0.9
            case .nguoi:
                ban.them(HinhNet.nguoi(dinh: CGPoint(x: r.midX, y: r.minY), cao: 34), .chinh)
                tamChu.y = r.minY + 40 + n.chuCao / 2
            default: ban.them(HinhNet.hopBo(r), .chinh)
            }
            let k = PhongNetDon.khoi(n.dong, co: CO_NUT)
            ban.them(k.net.map { $0.map { CGPoint(x: $0.x + tamChu.x, y: $0.y + tamChu.y - k.cao / 2) } }, .chu)
        }

        var y = dauCao + 14
        for t in td {
            y += t.k.cao + 2
            let xa = x[t.a], xb = x[t.b]
            if t.a == t.b {
                let d = [CGPoint(x: xa, y: y), CGPoint(x: xa + 28, y: y), CGPoint(x: xa + 28, y: y + 16), CGPoint(x: xa + 2, y: y + 16)]
                ban.them(d, .chinh); ban.them(HinhNet.dauMuiTen(d), .chinh)
                ban.them(t.k.net.map { $0.map { CGPoint(x: $0.x + xa + 34 + t.k.rong / 2, y: $0.y + y - t.k.cao + 4) } }, .chu)
                y += 30
            } else {
                let d = [CGPoint(x: xa, y: y), CGPoint(x: xb, y: y)]
                ban.them(d, .chinh); ban.them(HinhNet.dauMuiTen(d), .chinh)
                let cx = xb > xa ? xa + 10 + t.k.rong / 2 : xa - 10 - t.k.rong / 2
                ban.them(t.k.net.map { $0.map { CGPoint(x: $0.x + cx, y: $0.y + y - t.k.cao - 1) } }, .chu)
                y += 12
            }
        }
        // Đường đời đứt nét, vẽ SAU để biết độ dài; nằm dưới các mũi tên về thứ tự không quan trọng.
        for n in ben { ban.them(HinhNet.dut(CGPoint(x: n.x, y: dauCao + 3), CGPoint(x: n.x, y: y + 10)), .phu) }
        ban.chotKhung(le: 10)
        ban.coNetCoDinh = 3.4
        return ban
    }
}
