import CoreGraphics
import Foundation

// ════════════════════════════════════════════════════════════════
// SƠ ĐỒ MẠCH / NỐI DÂY — tự DÀN BẬC THANG rồi xuất NÉT BÚT
//
// Máy chủ (`/vo/mach/viec`) chỉ trả CẤU TRÚC: khối (module, bo chính), chân,
// dây (chân nào tới chân nào, màu gì), chân để hở, linh kiện, ghi chú, cảnh
// báo. Model CHÉP NGUYÊN VĂN số chân; hình học làm ở đây.
//
// Vì sao không để model vẽ: đo 01/10/2026, chế độ "Sơ đồ học tập" (model tự
// viết SVG) vẽ đề nối mic + loa thành ESP32 trơ trọi, chân "4 5 5 7 15 15".
// Sơ đồ nối dây mà sai một chữ số là cắm sai một sợi.
//
// Bố cục bậc thang — như bản vẽ tay của kỹ thuật viên:
//   · bo chính (vi điều khiển) là MỘT cột bên phải;
//   · mỗi module nối vào bo chính là một TẦNG bên trái;
//   · mỗi sợi dây một HÀNG NGANG: chân module ở đầu trái, chân bo chính ở đầu
//     phải, cùng độ cao ⇒ không sợi nào cắt sợi nào;
//   · thiết bị chỉ nối vào module (loa vào ampli, động cơ vào driver) treo
//     ngay DƯỚI module đó, dây thả thẳng đứng;
//   · chân để hở: gạch ngắn + X đỏ · dây nối tắt trên cùng một bo (L/R → GND)
//     vòng ngắn bên phải · tụ giữa hai chân đứng giữa hai hàng · điện trở
//     trên một sợi dây nằm giữa sợi đó.
// Thứ gì không xếp được vào khung đó thì KHÔNG vẽ đoán — ghi thành dòng chữ
// "Nối thêm: …" ở cuối, để không sợi nào bị mất.
//
// Thuần CoreGraphics + Foundation (như `SoDoKhoi`) để dựng thử trên macOS.
// ════════════════════════════════════════════════════════════════

/// Sơ đồ mạch máy chủ trả. Mọi trường `var` + optional (C4 trong CLAUDE.md iOS).
struct MachDien: Codable {
    var tieuDe: String?
    var chinh: String?
    var khoi: [Khoi]?
    var day: [Day]?
    var deHo: [ChanNhan]?
    var linhKien: [LinhKien]?
    var ghiChuChan: [ChanNhan]?
    var canhBao: [String]?
    var model: String?
    var xong: Bool?

    struct Khoi: Codable { var id: String?; var ten: String?; var phu: String?; var loai: String?; var chan: [String]? }
    struct Chan: Codable, Hashable { var khoi: String?; var chan: String? }
    struct Day: Codable { var tu: Chan?; var toi: Chan?; var mau: String?; var tenMau: String?; var nhan: String? }
    struct ChanNhan: Codable { var khoi: String?; var chan: String?; var nhan: String? }
    struct LinhKien: Codable { var loai: String?; var giaTri: String?; var a: Chan?; var b: Chan?; var nhan: String? }
}

enum SoDoMach {
    // Cỡ = chiều cao CHỮ HOA (pt) — cùng thang với `SoDoKhoi` (9pt ≈ chữ in 13pt).
    static let CO_TIEU_DE: CGFloat = 11
    static let CO_TEN: CGFloat = 9.5
    static let CO_PHU: CGFloat = 6.5
    static let CO_CHAN: CGFloat = 8
    static let CO_NHO: CGFloat = 6.2
    static let CO_CANH_BAO: CGFloat = 7
    /// Khoảng cách hai hàng chân. Đủ cho nhãn chân + một dòng ghi chú dưới nó.
    static let HANG: CGFloat = 25
    static let R_CHAN: CGFloat = 2.6
    static let DEM: CGFloat = 10
    /// Phần đầu hộp (tên + mô tả) — mọi tầng cùng một cỡ để hàng đầu của tầng
    /// trên cùng không đụng tên bo chính.
    static let DAU_HOP: CGFloat = DEM + CO_TEN + 7 + CO_PHU + 13
    static let CACH_TANG: CGFloat = 28
    static let CACH_DAU_CUOI: CGFloat = 42   // khoảng cách hai cực ở cầu đấu dưới đáy hộp
    static let THA_DAY: CGFloat = 34         // dây thả từ đáy module xuống thiết bị con
    static let CACH_O: CGFloat = 24          // khoảng hở giữa hai ô thiết bị con nằm cạnh nhau

    static let DO = MauNet(r: 0.86, g: 0.15, b: 0.15)
    static let XAM = MauNet(r: 0.42, g: 0.45, b: 0.50)
    static let DEN = MauNet(r: 0.07, g: 0.09, b: 0.15)

    // MARK: Chữ

    private enum Canh { case trai, phai, giua }

    /// Một dòng chữ, `yGiua` = giữa chiều cao chữ hoa.
    private static func viet(_ s: String, x: CGFloat, yGiua: CGFloat, co: CGFloat, canh: Canh = .trai,
                             mau: MauNet? = nil, vao b: inout BanVeNet) {
        guard !s.isEmpty else { return }
        let d = PhongNetDon.dong(s, co: co)
        let x0: CGFloat = canh == .trai ? x : canh == .phai ? x - d.rong : x - d.rong / 2
        let y0 = yGiua - co / 2
        b.them(d.net.map { $0.map { CGPoint(x: $0.x + x0, y: $0.y + y0) } }, .chu, mau: mau)
    }

    /// Chữ trong HÀNH LANG DÂY: ngắt dòng cho vừa `rongToiDa` — chữ dài chạy
    /// lố sang hộp bo chính là đè lên nhãn chân (đo 01/10: "nối sang GND ngay
    /// trên bo - BẮT BUỘC, dây ngắn" cắt ngang mép hộp ESP32). `len = true` thì
    /// các dòng chồng LÊN trên (nhãn nằm trên sợi dây, không được rơi xuống dây).
    private static func vietNgat(_ s: String, x: CGFloat, yGiua: CGFloat, co: CGFloat, rongToiDa: CGFloat,
                                 len: Bool = false, mau: MauNet? = nil, vao b: inout BanVeNet) {
        let dongs = PhongNetDon.ngatDong(s, co: co, rongToiDa: max(rongToiDa, 40))
        let buoc = PhongNetDon.buocDong(co: co)
        for (j, d) in dongs.enumerated() {
            let lech = len ? -CGFloat(dongs.count - 1 - j) * buoc : CGFloat(j) * buoc
            viet(d, x: x, yGiua: yGiua + lech, co: co, mau: mau, vao: &b)
        }
    }

    private static func rong(_ s: String?, _ co: CGFloat) -> CGFloat {
        guard let s, !s.isEmpty else { return 0 }
        return PhongNetDon.doRong(s, co: co)
    }

    // MARK: Hình nhỏ

    private static func tron(_ c: CGPoint, _ r: CGFloat) -> [CGPoint] {
        HinhNet.cung(c, rx: r, ry: r, tu: 0, den: 2 * .pi, n: 12)
    }

    /// Chấm nối (dây rẽ nhánh) — vòng rất nhỏ, nét bút dày tự lấp kín ruột.
    private static func cham(_ c: CGPoint, mau: MauNet?, vao b: inout BanVeNet) {
        b.them(tron(c, 1.4), .chinh, mau: mau)
    }

    /// Ký hiệu linh kiện nằm trên đoạn P → Q (P phía chân `a`). Vẽ cả hai dây
    /// dẫn từ P/Q vào thân ký hiệu. Trả nửa chiều ngang thân (để đặt nhãn).
    @discardableResult
    private static func kyHieu(_ loai: String, tu p: CGPoint, toi q: CGPoint, mau: MauNet?,
                               vao b: inout BanVeNet) -> CGFloat {
        let dx = q.x - p.x, dy = q.y - p.y
        let dai = max(hypot(dx, dy), 1)
        let ux = dx / dai, uy = dy / dai          // dọc trục a → b
        let vx = -uy, vy = ux                     // vuông góc
        let m = CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
        func g(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: m.x + u * ux + v * vx, y: m.y + u * uy + v * vy) }
        let nua: CGFloat
        switch loai {
        case "tu", "tu_hoa": nua = 3
        case "dien_tro": nua = 11
        case "cau_chi": nua = 9
        case "cuon_cam": nua = 12
        case "nut", "cong_tac": nua = 9
        default: nua = 6                            // diode, led
        }
        let nuaDung = min(nua, dai / 2 - 1)
        // Hai dây dẫn — cùng màu sợi dây đang mang linh kiện.
        b.them([p, g(-nuaDung, 0)], .chinh, mau: mau)
        b.them([g(nuaDung, 0), q], .chinh, mau: mau)
        switch loai {
        case "tu":
            b.them([g(-3, -6), g(-3, 6)], .chinh)
            b.them([g(3, -6), g(3, 6)], .chinh)
        case "tu_hoa":
            b.them([g(-3, -6), g(-3, 6)], .chinh)                                     // bản dương (thẳng)
            b.them((0...8).map { i -> CGPoint in                                      // bản âm (cong)
                let v = -6 + 12 * CGFloat(i) / 8
                return g(5 - 2 * (1 - (v / 6) * (v / 6)), v)
            }, .chinh)
            b.them([g(-8.5, -8), g(-5.5, -8)], .chinh)                                // dấu +
            b.them([g(-7, -9.5), g(-7, -6.5)], .chinh)
        case "dien_tro":
            b.them([g(-11, -4), g(11, -4), g(11, 4), g(-11, 4), g(-11, -4)], .chinh)
        case "cau_chi":
            b.them([g(-9, -3.5), g(9, -3.5), g(9, 3.5), g(-9, 3.5), g(-9, -3.5)], .chinh)
            b.them([g(-9, 0), g(9, 0)], .chinh)
        case "diode", "led":
            b.them([g(-6, -5.5), g(-6, 5.5), g(4, 0), g(-6, -5.5)], .chinh)           // tam giác a → b
            b.them([g(4, -5.5), g(4, 5.5)], .chinh)                                   // vạch catot
            if loai == "led" {
                for k: CGFloat in [-2.5, 2] {
                    let a0 = g(k, -7), a1 = g(k + 4, -12)
                    b.them([a0, a1], .chinh)
                    b.them(HinhNet.dauMuiTen([a0, a1], dai: 3), .chinh)
                }
            }
        case "cuon_cam":
            for k in 0..<4 {
                let u0 = -12 + CGFloat(k) * 6
                b.them((0...8).map { i -> CGPoint in
                    let a = CGFloat.pi * CGFloat(i) / 8
                    return g(u0 + 3 - 3 * cos(a), -4 * sin(a))
                }, .chinh)
            }
        case "nut":
            b.them(tron(g(-6, 0), 1.6), .chinh); b.them(tron(g(6, 0), 1.6), .chinh)
            b.them([g(-8, -5), g(8, -5)], .chinh)
            b.them([g(0, -5), g(0, -9)], .chinh)
        default: // cong_tac
            b.them(tron(g(-6, 0), 1.6), .chinh); b.them(tron(g(6, 0), 1.6), .chinh)
            b.them([g(-5, -1), g(6, -7)], .chinh)
        }
        return nuaDung
    }

    // MARK: Biểu tượng trong hộp thiết bị con

    private static func bieuTuong(_ loai: String, tam c: CGPoint, vao b: inout BanVeNet) -> Bool {
        switch loai {
        case "loa":
            b.them([CGPoint(x: c.x - 7, y: c.y - 4), CGPoint(x: c.x - 3, y: c.y - 4), CGPoint(x: c.x - 3, y: c.y + 4),
                    CGPoint(x: c.x - 7, y: c.y + 4), CGPoint(x: c.x - 7, y: c.y - 4)], .chinh)
            b.them([CGPoint(x: c.x - 3, y: c.y - 4), CGPoint(x: c.x + 4, y: c.y - 9), CGPoint(x: c.x + 4, y: c.y + 9),
                    CGPoint(x: c.x - 3, y: c.y + 4)], .chinh)
            return true
        case "dong_co":
            b.them(HinhNet.cung(c, rx: 9, ry: 9, tu: 0, den: 2 * .pi, n: 24), .chinh)
            viet("M", x: c.x, yGiua: c.y, co: 8, canh: .giua, vao: &b)
            return true
        case "pin":
            b.them([CGPoint(x: c.x - 3, y: c.y - 8), CGPoint(x: c.x - 3, y: c.y + 8)], .chinh)
            b.them([CGPoint(x: c.x + 3, y: c.y - 4), CGPoint(x: c.x + 3, y: c.y + 4)], .chinh)
            return true
        default:
            return false
        }
    }

    // MARK: Dàn bố cục

    private struct Khoi {
        let id: String
        let ten: String
        let phu: String
        let loai: String
    }

    private struct Day {
        var tu: MachDien.Chan
        var toi: MachDien.Chan
        let mau: MauNet?
        let tenMau: String
        let nhan: String
    }

    private enum LoaiHang { case day(Int), noiTat(Int), deHo(String), trong }

    private struct Hang {
        let chan: String
        var loai: LoaiHang
        var y: CGFloat = 0
    }

    /// Một thiết bị con treo dưới module: một Ô NGANG riêng, các cực nằm trên
    /// đầu ô, đúng dưới cực tương ứng ở đáy module ⇒ dây thả thẳng đứng.
    private struct OCon {
        let id: String
        let dsDay: [Int]
        let w: CGFloat       // bề rộng hộp
        let rongO: CGFloat   // bề rộng ô — đủ chỗ cho hộp, các cực và chữ màu dây
    }

    static func dung(_ m: MachDien) -> BanVeNet? {
        let khois: [Khoi] = (m.khoi ?? []).compactMap { k in
            guard let id = k.id, !id.isEmpty else { return nil }
            return Khoi(id: id, ten: k.ten ?? id, phu: k.phu ?? "", loai: k.loai ?? "module")
        }
        guard khois.count >= 2 else { return nil }
        let theoId = Dictionary(khois.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let chinh = theoId[m.chinh ?? ""]?.id ?? khois[0].id
        let ten = { (id: String?) -> String in theoId[id ?? ""]?.ten ?? (id ?? "?") }

        var days: [Day] = (m.day ?? []).compactMap { d in
            guard let tu = d.tu, let toi = d.toi, theoId[tu.khoi ?? ""] != nil, theoId[toi.khoi ?? ""] != nil,
                  !(tu.chan ?? "").isEmpty, !(toi.chan ?? "").isEmpty else { return nil }
            return Day(tu: tu, toi: toi, mau: MauNet(hex: d.mau), tenMau: d.tenMau ?? "", nhan: d.nhan ?? "")
        }
        guard !days.isEmpty else { return nil }
        // Đầu bo chính luôn là `toi` (máy chủ đã lật, lật lại cho chắc).
        for i in days.indices where days[i].tu.khoi == chinh && days[i].toi.khoi != chinh {
            let t = days[i].tu
            days[i].tu = days[i].toi
            days[i].toi = t
        }

        // ── Phân loại dây ──
        var dayChinh: [String: [Int]] = [:]     // module → dây vào bo chính
        var noiTat: [String: [Int]] = [:]       // module → dây nối tắt trên chính nó
        var dayCon: [(cha: String, con: String, i: Int)] = []
        var thuTuTang: [String] = []
        var noiThem: [String] = []
        for (i, d) in days.enumerated() {
            let a = d.tu.khoi!, c = d.toi.khoi!
            if c == chinh && a != chinh {
                dayChinh[a, default: []].append(i)
                if !thuTuTang.contains(a) { thuTuTang.append(a) }
            }
        }
        // Giữ thứ tự tầng theo thứ tự khối model liệt kê (thường là thứ tự đề kể).
        thuTuTang.sort { a, b in
            (khois.firstIndex { $0.id == a } ?? 0) < (khois.firstIndex { $0.id == b } ?? 0)
        }
        for (i, d) in days.enumerated() {
            let a = d.tu.khoi!, c = d.toi.khoi!
            if c == chinh && a != chinh { continue }
            if a == c {
                if a == chinh || !thuTuTang.contains(a) {
                    noiThem.append("\(ten(a)) \(d.tu.chan!) -> \(d.toi.chan!)")
                } else {
                    noiTat[a, default: []].append(i)
                }
                continue
            }
            // Dây giữa hai module: treo được nếu đúng MỘT đầu là tầng.
            let aTang = thuTuTang.contains(a), cTang = thuTuTang.contains(c)
            if aTang != cTang {
                dayCon.append(aTang ? (cha: a, con: c, i: i) : (cha: c, con: a, i: i))
            } else {
                noiThem.append("\(ten(a)) \(d.tu.chan!) -> \(ten(c)) \(d.toi.chan!)\(d.tenMau.isEmpty ? "" : " (\(d.tenMau))")")
            }
        }
        // Một thiết bị con chỉ treo dưới MỘT module (module đầu tiên nối tới nó).
        var chaCua: [String: String] = [:]
        dayCon = dayCon.filter { x in
            if let cha = chaCua[x.con], cha != x.cha {
                let d = days[x.i]
                noiThem.append("\(ten(d.tu.khoi)) \(d.tu.chan!) -> \(ten(d.toi.khoi)) \(d.toi.chan!)")
                return false
            }
            chaCua[x.con] = x.cha
            return true
        }
        guard !thuTuTang.isEmpty else { return nil }

        let deHoTheo = Dictionary(grouping: (m.deHo ?? []).filter { $0.khoi != nil && $0.chan != nil }, by: { $0.khoi! })
        let ghiChu: [MachDien.Chan: String] = Dictionary(
            (m.ghiChuChan ?? []).compactMap { g in
                guard let k = g.khoi, let c = g.chan, let n = g.nhan, !n.isEmpty else { return nil }
                return (MachDien.Chan(khoi: k, chan: c), n)
            }, uniquingKeysWith: { a, _ in a })
        let linhKien = m.linhKien ?? []

        // ── Hàng của từng tầng ──
        var hangCua: [String: [Hang]] = [:]
        for k in thuTuTang {
            var hs: [Hang] = (dayChinh[k] ?? []).map { Hang(chan: days[$0].tu.chan!, loai: .day($0)) }
            // Nối tắt: đặt NGAY SAU chân đích, để đoạn vòng không cắt sợi nào.
            for i in noiTat[k] ?? [] {
                var nguon = days[i].tu.chan!, dich = days[i].toi.chan!
                let coDay = { (c: String) in hs.contains { h in if case .day = h.loai { return h.chan == c }; return false } }
                if !coDay(dich) && coDay(nguon) { swap(&nguon, &dich) }
                var d2 = days[i]; d2.tu.chan = nguon; d2.toi.chan = dich; days[i] = d2
                if let j = hs.lastIndex(where: { $0.chan == dich }) {
                    hs.insert(Hang(chan: nguon, loai: .noiTat(i)), at: j + 1)
                } else {
                    hs.append(Hang(chan: dich, loai: .trong))
                    hs.append(Hang(chan: nguon, loai: .noiTat(i)))
                }
            }
            // Linh kiện giữa hai chân CÙNG module: kéo hai hàng sát nhau.
            for l in linhKien where l.a?.khoi == k && l.b?.khoi == k {
                guard let ca = l.a?.chan, let cb = l.b?.chan else { continue }
                if !hs.contains(where: { $0.chan == ca }) { hs.append(Hang(chan: ca, loai: .trong)) }
                if !hs.contains(where: { $0.chan == cb }) { hs.append(Hang(chan: cb, loai: .trong)) }
                guard let ia = hs.firstIndex(where: { $0.chan == ca }),
                      let ib = hs.firstIndex(where: { $0.chan == cb }), abs(ia - ib) > 1 else { continue }
                let h = hs.remove(at: ib)
                let ia2 = hs.firstIndex(where: { $0.chan == ca }) ?? hs.count - 1
                hs.insert(h, at: ib > ia ? ia2 + 1 : ia2)
            }
            for d in deHoTheo[k] ?? [] where !hs.contains(where: { $0.chan == d.chan }) {
                hs.append(Hang(chan: d.chan!, loai: .deHo(d.nhan ?? "")))
            }
            hangCua[k] = hs
        }

        // ── Kích thước ──
        let khoiChinh = theoId[chinh]!
        var rongMod: [String: CGFloat] = [:]
        // Thiết bị con xếp HÀNG NGANG, mỗi con một ô. Đo 01/10 (L298N + hai động
        // cơ + adapter): xếp chồng dọc thì dây của động cơ phải thả xuyên qua
        // hộp động cơ trái nằm ngay trên nó.
        var oConCua: [String: [OCon]] = [:]
        for k in thuTuTang {
            var cacCon: [String] = []
            for x in dayCon where x.cha == k && !cacCon.contains(x.con) { cacCon.append(x.con) }
            oConCua[k] = cacCon.enumerated().map { thu, con in
                let kc = theoId[con]!
                let ds = dayCon.filter { $0.cha == k && $0.con == con }.map(\.i)
                let n = ds.count
                let chanCon = { (i: Int) in days[i].tu.khoi == con ? days[i].tu.chan! : days[i].toi.chan! }
                let coBieu = ["loa", "dong_co", "pin"].contains(kc.loai)
                let rongChan = ds.map { rong(chanCon($0), CO_NHO) }.max() ?? 0
                let w = max(84, max(rong(kc.ten, CO_TEN), rong(kc.phu, CO_PHU)) + 2 * DEM + (coBieu ? 26 : 0),
                            CGFloat(n - 1) * CACH_DAU_CUOI + rongChan + 2 * DEM)
                // Chữ màu dây: sợi đầu ghi bên TRÁI (khi có ≥ 2 sợi), các sợi sau bên phải.
                // Ghi chú dây ("KHÔNG nối GND") của con CUỐI hàng được tràn sang
                // phải — khoảng dưới hành lang dây trống — nên không tính vào ô;
                // tính vào thì hộp ampli phình gấp rưỡi chỉ vì một dòng chữ.
                let laCuoi = thu == cacCon.count - 1
                let trai = n > 1 ? rong(days[ds[0]].tenMau, CO_NHO) + 8 : 0
                let phai = ds.dropFirst(n > 1 ? 1 : 0).map { i -> CGFloat in
                    let d = days[i]
                    return rong(d.tenMau, CO_NHO) + (d.nhan.isEmpty || laCuoi ? 0 : rong("- " + d.nhan, CO_NHO) + 4) + 8
                }.max() ?? 0
                let nhip = CGFloat(n - 1) * CACH_DAU_CUOI
                return OCon(id: con, dsDay: ds, w: w,
                            rongO: max(w, CGFloat(n) * CACH_DAU_CUOI, nhip + 2 * max(trai, phai)))
            }
        }
        let tongO = { (k: String) -> CGFloat in
            let ds = oConCua[k] ?? []
            return ds.reduce(0) { $0 + $1.rongO } + CGFloat(max(ds.count - 1, 0)) * CACH_O
        }
        for k in thuTuTang {
            let kh = theoId[k]!
            var w = max(96, rong(kh.ten, CO_TEN) + 2 * DEM, rong(kh.phu, CO_PHU) + 2 * DEM)
            for h in hangCua[k] ?? [] {
                let ghi = ghiChu[MachDien.Chan(khoi: k, chan: h.chan)]
                w = max(w, rong(h.chan, CO_CHAN) + 2 * DEM + 14, rong(ghi, CO_NHO) + 2 * DEM + 10)
            }
            w = max(w, tongO(k))
            rongMod[k] = w
        }
        let rongModMax = rongMod.values.max() ?? 96

        // Nhãn bên bo chính: chân + ghi chú — lấy đúng chân THẬT SỰ có dây tới.
        var rongChinh = max(96, rong(khoiChinh.ten, CO_TEN) + 2 * DEM, rong(khoiChinh.phu, CO_PHU) + 2 * DEM)
        for (_, ds) in dayChinh {
            for i in ds {
                let c = days[i].toi.chan!
                let ghi = ghiChu[MachDien.Chan(khoi: chinh, chan: c)]
                rongChinh = max(rongChinh, rong(c, CO_CHAN) + 2 * DEM + 12, rong(ghi, CO_NHO) + 2 * DEM + 12)
            }
        }
        // Dây đủ dài cho chữ nằm trên nó: nhãn linh kiện + chữ màu dây ở đầu bo
        // chính. Đo 01/10 (DHT22): "10k - kéo lên trên cảm biến" đè lên "vàng".
        var dayDai: CGFloat = 170
        let rongMauMax = days.map { rong($0.tenMau, CO_NHO) }.max() ?? 0
        var thuSongSong: [String: Int] = [:]
        for l in linhKien {
            let wL = rong([l.giaTri, l.nhan].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - "), CO_NHO)
            if l.a?.khoi == l.b?.khoi {
                let k = l.a?.khoi ?? ""
                let thu = thuSongSong[k, default: 0]
                thuSongSong[k] = thu + 1
                dayDai = max(dayDai, 42 + CGFloat(thu) * 30 + 10 + wL + 16 + rongMauMax + 16)
            } else {
                dayDai = max(dayDai, wL + 2 * (rongMauMax + 24), 60 + 2 * (rongMauMax + 30))
            }
        }
        let xMod: CGFloat = 0
        let xChinh = xMod + rongModMax + dayDai

        var b = BanVeNet()

        // ── Tiêu đề ──
        var y: CGFloat = 0
        if let t = m.tieuDe, !t.isEmpty {
            viet(t, x: xMod, yGiua: y + CO_TIEU_DE / 2, co: CO_TIEU_DE, vao: &b)
            y += CO_TIEU_DE + 20
        }
        let dinhChinh = y
        var dayHangChinh: CGFloat = y

        // ── Từng tầng ──
        for k in thuTuTang {
            let kh = theoId[k]!
            let w = rongMod[k]!
            let xR = xMod + w
            var hs = hangCua[k] ?? []
            let dinh = y
            let y0 = dinh + DAU_HOP + HANG * 0.35
            for i in hs.indices { hs[i].y = y0 + CGFloat(i) * HANG }
            let yCuoiHang = hs.last?.y ?? y0
            let oCon = oConCua[k] ?? []
            // Hàng cuối có ghi chú dưới nhãn thì nới đáy hộp, kẻo chữ chạm mép.
            let ghiCuoi = hs.last.map { ghiChu[MachDien.Chan(khoi: k, chan: $0.chan)] != nil } ?? false
            let day = yCuoiHang + HANG * 0.6 + (ghiCuoi ? 7 : 0) + (oCon.isEmpty ? 0 : 16)

            // Hộp module + tên.
            b.them(HinhNet.hopBo(CGRect(x: xMod, y: dinh, width: w, height: day - dinh), bo: 7), .chinh)
            viet(kh.ten, x: xMod + w / 2, yGiua: dinh + DEM + CO_TEN / 2, co: CO_TEN, canh: .giua, vao: &b)
            viet(kh.phu, x: xMod + w / 2, yGiua: dinh + DEM + CO_TEN + 7 + CO_PHU / 2, co: CO_PHU, canh: .giua,
                 mau: XAM, vao: &b)

            // Hàng: chân bên phải hộp, dây sang bo chính.
            let hangCoDay = Dictionary(hs.compactMap { h -> (String, CGFloat)? in
                if case .day = h.loai { return (h.chan, h.y) }; return nil
            }, uniquingKeysWith: { a, _ in a })
            var soNoiTat = 0
            for h in hs {
                b.them(tron(CGPoint(x: xR, y: h.y), R_CHAN), .chinh)
                viet(h.chan, x: xR - R_CHAN - 7, yGiua: h.y, co: CO_CHAN, canh: .phai, vao: &b)
                if let ghi = ghiChu[MachDien.Chan(khoi: k, chan: h.chan)] {
                    viet(ghi, x: xR - R_CHAN - 7, yGiua: h.y + 10, co: CO_NHO, canh: .phai, mau: XAM, vao: &b)
                }
                switch h.loai {
                case .day(let i):
                    let d = days[i]
                    let p = CGPoint(x: xR + R_CHAN, y: h.y), q = CGPoint(x: xChinh - R_CHAN, y: h.y)
                    // Linh kiện nằm trên sợi này?
                    if let l = linhKien.first(where: { l in
                        let ab = Set([l.a, l.b].compactMap { $0 })
                        return ab == Set([d.tu, d.toi])
                    }) {
                        let giua = CGPoint(x: (p.x + q.x) / 2, y: h.y)
                        let aBenModule = l.a == d.tu
                        let tu = CGPoint(x: giua.x - 30, y: h.y), toi = CGPoint(x: giua.x + 30, y: h.y)
                        b.them([p, tu], .chinh, mau: d.mau)
                        kyHieu(l.loai ?? "dien_tro", tu: aBenModule ? tu : toi, toi: aBenModule ? toi : tu, mau: d.mau, vao: &b)
                        b.them([toi, q], .chinh, mau: d.mau)
                        let nhanLK = [l.giaTri, l.nhan].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - ")
                        viet(nhanLK, x: giua.x, yGiua: h.y - 12, co: CO_NHO, canh: .giua, vao: &b)
                    } else {
                        b.them([p, q], .chinh, mau: d.mau)
                    }
                    if !d.tenMau.isEmpty {
                        viet(d.tenMau, x: xChinh - 12, yGiua: h.y - 7, co: CO_NHO, canh: .phai, mau: d.mau, vao: &b)
                    }
                    if !d.nhan.isEmpty {
                        vietNgat(d.nhan, x: xR + 12, yGiua: h.y - 7, co: CO_NHO,
                                 rongToiDa: xChinh - 24 - rong(d.tenMau, CO_NHO) - (xR + 12), len: true, mau: DO, vao: &b)
                    }
                case .noiTat(let i):
                    let d = days[i]
                    let xVong = xR + 14 + CGFloat(soNoiTat) * 5
                    soNoiTat += 1
                    let dich = d.toi.chan!
                    if let yDich = hangCoDay[dich] {
                        b.them([CGPoint(x: xR + R_CHAN, y: h.y), CGPoint(x: xVong, y: h.y), CGPoint(x: xVong, y: yDich)],
                               .chinh, mau: d.mau ?? DEN)
                        cham(CGPoint(x: xVong, y: yDich), mau: d.mau ?? DEN, vao: &b)
                    } else if let yDich = hs.first(where: { $0.chan == dich })?.y {
                        b.them([CGPoint(x: xR + R_CHAN, y: h.y), CGPoint(x: xVong, y: h.y), CGPoint(x: xVong, y: yDich),
                                CGPoint(x: xR + R_CHAN, y: yDich)], .chinh, mau: d.mau ?? DEN)
                    }
                    let loiGhi = d.nhan.isEmpty ? "nối sang \(dich) ngay trên bo" : "nối sang \(dich) ngay trên bo - \(d.nhan)"
                    vietNgat(loiGhi, x: xVong + 8, yGiua: h.y, co: CO_NHO, rongToiDa: xChinh - 14 - (xVong + 8),
                             mau: d.nhan.isEmpty ? XAM : DO, vao: &b)
                case .deHo(let ghi):
                    b.them([CGPoint(x: xR + R_CHAN, y: h.y), CGPoint(x: xR + 15, y: h.y)], .chinh, mau: XAM)
                    let cx = xR + 22
                    b.them([CGPoint(x: cx - 4.5, y: h.y - 4.5), CGPoint(x: cx + 4.5, y: h.y + 4.5)], .chinh, mau: DO)
                    b.them([CGPoint(x: cx - 4.5, y: h.y + 4.5), CGPoint(x: cx + 4.5, y: h.y - 4.5)], .chinh, mau: DO)
                    viet("để hở", x: cx + 10, yGiua: h.y, co: CO_CHAN, mau: DO, vao: &b)
                    let lyDo = ghi.trimmingCharacters(in: .whitespaces)
                    if !lyDo.isEmpty && lyDo.lowercased() != "để hở" {
                        let xLy = cx + 14 + rong("để hở", CO_CHAN)
                        vietNgat("- " + lyDo, x: xLy, yGiua: h.y, co: CO_NHO, rongToiDa: xChinh - 14 - xLy, mau: XAM, vao: &b)
                    }
                case .trong:
                    break
                }
            }

            // Linh kiện giữa hai chân cùng module: đứng giữa hai hàng.
            var soSongSong = 0
            for l in linhKien where l.a?.khoi == k && l.b?.khoi == k {
                guard let ya = hs.first(where: { $0.chan == l.a?.chan })?.y,
                      let yb = hs.first(where: { $0.chan == l.b?.chan })?.y else { continue }
                let x = xR + 42 + CGFloat(soSongSong) * 30
                soSongSong += 1
                for (c, yy) in [(l.a?.chan ?? "", ya), (l.b?.chan ?? "", yb)] {
                    if hangCoDay[c] != nil { cham(CGPoint(x: x, y: yy), mau: nil, vao: &b) }
                    else { b.them([CGPoint(x: xR + R_CHAN, y: yy), CGPoint(x: x, y: yy)], .chinh) }
                }
                kyHieu(l.loai ?? "tu", tu: CGPoint(x: x, y: ya), toi: CGPoint(x: x, y: yb), mau: nil, vao: &b)
                let nhanLK = [l.giaTri, l.nhan].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - ")
                viet(nhanLK, x: x + 10, yGiua: (ya + yb) / 2, co: CO_NHO, vao: &b)
            }

            // Thiết bị con: mỗi con một ô ngang dưới đáy module.
            var dayTang = day
            if !oCon.isEmpty {
                var xO = xMod + (w - tongO(k)) / 2
                let yCon = day + THA_DAY
                for o in oCon {
                    let kc = theoId[o.id]!
                    let n = o.dsDay.count
                    let xs = (0..<n).map { j in xO + o.rongO / 2 + (CGFloat(j) - CGFloat(n - 1) / 2) * CACH_DAU_CUOI }
                    let coBieu = ["loa", "dong_co", "pin"].contains(kc.loai)
                    let khung = CGRect(x: xO + (o.rongO - o.w) / 2, y: yCon, width: o.w,
                                       height: 26 + CO_TEN + (kc.phu.isEmpty ? 6 : 17))
                    b.them(HinhNet.hopBo(khung, bo: 7), .chinh)
                    for (j, i) in o.dsDay.enumerated() {
                        let d = days[i]
                        let x = xs[j]
                        let chanCha = d.tu.khoi == k ? d.tu.chan! : d.toi.chan!
                        let chanCon = d.tu.khoi == o.id ? d.tu.chan! : d.toi.chan!
                        // Cực ở đáy module (cầu đấu) + tên cực ngay trên nó, trong hộp.
                        b.them([CGPoint(x: x - 3.5, y: day - 2), CGPoint(x: x + 3.5, y: day - 2), CGPoint(x: x + 3.5, y: day + 3),
                                CGPoint(x: x - 3.5, y: day + 3), CGPoint(x: x - 3.5, y: day - 2)], .chinh)
                        viet(chanCha, x: x, yGiua: day - 10, co: CO_NHO, canh: .giua, vao: &b)
                        b.them([CGPoint(x: x, y: day + 3), CGPoint(x: x, y: yCon)], .chinh, mau: d.mau)
                        b.them(tron(CGPoint(x: x, y: yCon), R_CHAN), .chinh)
                        viet(chanCon, x: x, yGiua: yCon + 9, co: CO_NHO, canh: .giua, vao: &b)
                        let giua = day + 3 + (yCon - day - 3) / 2
                        let benTrai = j == 0 && n > 1
                        if !d.tenMau.isEmpty {
                            viet(d.tenMau, x: benTrai ? x - 5 : x + 5, yGiua: giua, co: CO_NHO,
                                 canh: benTrai ? .phai : .trai, mau: d.mau, vao: &b)
                        }
                        if !d.nhan.isEmpty {
                            let xNhan = benTrai ? x - 5 : x + 9 + rong(d.tenMau, CO_NHO)
                            viet((benTrai ? "" : "- ") + d.nhan, x: xNhan, yGiua: benTrai ? giua + 9 : giua, co: CO_NHO,
                                 canh: benTrai ? .phai : .trai, mau: DO, vao: &b)
                        }
                    }
                    let xChu = coBieu ? khung.minX + DEM + 22 : khung.midX
                    let canhChu: Canh = coBieu ? .trai : .giua
                    if coBieu { _ = bieuTuong(kc.loai, tam: CGPoint(x: khung.minX + DEM + 7, y: khung.midY + 5), vao: &b) }
                    viet(kc.ten, x: xChu, yGiua: yCon + 21 + CO_TEN / 2, co: CO_TEN, canh: canhChu, vao: &b)
                    viet(kc.phu, x: xChu, yGiua: yCon + 21 + CO_TEN + 7 + CO_PHU / 2, co: CO_PHU, canh: canhChu,
                         mau: XAM, vao: &b)
                    dayTang = max(dayTang, khung.maxY)
                    xO += o.rongO + CACH_O
                }
            }

            // Bên bo chính: chân + nhãn + ghi chú, đúng độ cao từng hàng có dây.
            for h in hs {
                guard case .day(let i) = h.loai else { continue }
                let c = days[i].toi.chan!
                b.them(tron(CGPoint(x: xChinh, y: h.y), R_CHAN), .chinh)
                viet(c, x: xChinh + R_CHAN + 7, yGiua: h.y, co: CO_CHAN, vao: &b)
                if let ghi = ghiChu[MachDien.Chan(khoi: chinh, chan: c)] {
                    viet(ghi, x: xChinh + R_CHAN + 7, yGiua: h.y + 10, co: CO_NHO, mau: XAM, vao: &b)
                }
                dayHangChinh = max(dayHangChinh, h.y)
            }
            y = max(dayTang, yCuoiHang + HANG * 0.6) + CACH_TANG
        }

        // ── Bo chính: một hộp cao suốt các tầng ──
        let dayChinhHop = dayHangChinh + HANG * 0.6 + 4
        b.them(HinhNet.hopBo(CGRect(x: xChinh, y: dinhChinh, width: rongChinh, height: dayChinhHop - dinhChinh), bo: 7), .chinh)
        viet(khoiChinh.ten, x: xChinh + rongChinh / 2, yGiua: dinhChinh + DEM + CO_TEN / 2, co: CO_TEN, canh: .giua, vao: &b)
        viet(khoiChinh.phu, x: xChinh + rongChinh / 2, yGiua: dinhChinh + DEM + CO_TEN + 7 + CO_PHU / 2, co: CO_PHU,
             canh: .giua, mau: XAM, vao: &b)

        // ── Cuối trang: cảnh báo, nối thêm, chú thích ──
        let rongTong = xChinh + rongChinh - xMod
        y = max(y - CACH_TANG, dayChinhHop) + 22
        let buoc = PhongNetDon.buocDong(co: CO_CANH_BAO)
        for cb in m.canhBao ?? [] where !cb.isEmpty {
            for (j, dong) in PhongNetDon.ngatDong(cb, co: CO_CANH_BAO, rongToiDa: rongTong - 16).enumerated() {
                viet(j == 0 ? "! " + dong : "   " + dong, x: xMod, yGiua: y, co: CO_CANH_BAO, mau: DO, vao: &b)
                y += buoc
            }
        }
        for l in linhKien where l.a?.khoi != l.b?.khoi {
            // Linh kiện giữa hai khối mà không nằm trên sợi nào vẽ được — ghi chữ.
            let ab = Set([l.a, l.b].compactMap { $0 })
            if days.contains(where: { Set([$0.tu, $0.toi]) == ab }) { continue }
            noiThem.append("\(l.loai ?? "linh kiện") \(l.giaTri ?? ""): \(ten(l.a?.khoi)) \(l.a?.chan ?? "") -> \(ten(l.b?.khoi)) \(l.b?.chan ?? "")")
        }
        for (k, ds) in deHoTheo where !thuTuTang.contains(k) {
            for d in ds { noiThem.append("\(ten(k)) \(d.chan ?? ""): để hở") }
        }
        if !noiThem.isEmpty {
            y += 4
            viet("Nối thêm:", x: xMod, yGiua: y, co: CO_CANH_BAO, vao: &b)
            y += buoc
            for s in noiThem {
                for dong in PhongNetDon.ngatDong("- " + s, co: CO_CANH_BAO, rongToiDa: rongTong - 16) {
                    viet(dong, x: xMod + 6, yGiua: y, co: CO_CANH_BAO, vao: &b)
                    y += buoc
                }
            }
        }
        y += 4
        viet("Vị trí chân trên hình là minh hoạ - cắm theo CHỮ in trên bo.", x: xMod, yGiua: y, co: CO_NHO, mau: XAM, vao: &b)

        b.coNetCoDinh = 3.2
        b.chotKhung(le: 12)
        return b
    }

    /// Bản chữ của sơ đồ — gửi kèm khi người dùng báo cáo (admin đọc được ngay
    /// mà không cần dựng lại hình).
    static func tomTat(_ m: MachDien) -> String {
        let ten = Dictionary((m.khoi ?? []).compactMap { k in k.id.map { ($0, k.ten ?? $0) } }, uniquingKeysWith: { a, _ in a })
        var dong: [String] = [m.tieuDe ?? ""]
        for d in m.day ?? [] {
            dong.append("\(ten[d.tu?.khoi ?? ""] ?? "?") \(d.tu?.chan ?? "?") -> \(ten[d.toi?.khoi ?? ""] ?? "?") \(d.toi?.chan ?? "?")"
                        + (d.tenMau.map { " (\($0))" } ?? ""))
        }
        for d in m.deHo ?? [] { dong.append("\(ten[d.khoi ?? ""] ?? "?") \(d.chan ?? "?"): để hở") }
        for l in m.linhKien ?? [] {
            dong.append("\(l.loai ?? "") \(l.giaTri ?? ""): \(l.a?.chan ?? "") - \(l.b?.chan ?? "")")
        }
        dong += m.canhBao ?? []
        return dong.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
