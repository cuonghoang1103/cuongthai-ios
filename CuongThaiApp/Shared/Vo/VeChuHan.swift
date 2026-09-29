import CoreGraphics
import Foundation

// ════════════════════════════════════════════════════════════════
// VẼ CHỮ HÁN bằng NÉT CHUẨN — không để AI tự vẽ
//
// Nét lấy từ `GET /my-language/hanzi-stroke/:char` (hanzi-writer-data cho
// kanji, KanjiVG cho kana): `medians` = đường TIM từng nét, đúng THỨ TỰ và
// CHIỀU viết. AI tự vẽ chữ Hán thì sai số nét, sai thứ tự — dạy sai còn tệ
// hơn không dạy. AI chỉ được TRA chữ (xem `voHan.service.ts` ở backend).
//
// Hệ toạ độ dữ liệu: 1024×1024, trục y LẬT, y' = 900 − y (xem `NetChu`).
//
// Tuỳ chọn: cỡ ô (nhỏ/vừa/lớn), số thứ tự nét đỏ ở đầu mỗi nét, ô 田 mờ.
// Nhiều chữ thì xếp ngang. Kana có số nét máy chủ lệch bảng chuẩn
// (`SoNetChuan`) thì KHÔNG đánh số — thứ tự sai còn hại hơn không có số.
//
// Thuần CoreGraphics + Foundation để dựng thử được trên macOS.
// ════════════════════════════════════════════════════════════════

enum VeChuHan {
    enum Co: String, CaseIterable, Identifiable {
        case nho, vua, lon
        var id: String { rawValue }
        /// Cạnh ô (pt trên trang). Trang A4 dọc rộng ~595pt.
        var canh: CGFloat {
            switch self {
            case .nho: return 64
            case .vua: return 96
            case .lon: return 140
            }
        }
    }

    struct Chu {
        let chu: String
        /// Đường tim từng nét, toạ độ gốc của dữ liệu (1024, y lật).
        let medians: [[[Double]]]
        /// `false` = dữ liệu thứ tự nét không đáng tin (kana lệch bảng) ⇒ không đánh số.
        let danhSo: Bool
    }

    static let KHUNG: CGFloat = 1024
    static let GOC_Y: CGFloat = 900

    static func dung(_ ds: [Chu], canh: CGFloat, soThuTu: Bool, oDien: Bool) -> BanVeNet {
        var ban = BanVeNet()
        let khe: CGFloat = oDien ? 6 : canh * 0.06
        let k = canh / KHUNG
        let coSo = min(10, max(5.5, canh * 0.075))
        for (i, c) in ds.enumerated() {
            let x0 = CGFloat(i) * (canh + khe)
            let o = CGRect(x: x0, y: 0, width: canh, height: canh)
            if oDien {
                ban.them([CGPoint(x: o.minX, y: o.minY), CGPoint(x: o.maxX, y: o.minY), CGPoint(x: o.maxX, y: o.maxY),
                          CGPoint(x: o.minX, y: o.maxY), CGPoint(x: o.minX, y: o.minY)], .mo)
                let dut = max(3, canh * 0.035)
                ban.them(HinhNet.dut(CGPoint(x: o.midX, y: o.minY + 2), CGPoint(x: o.midX, y: o.maxY - 2), gach: dut, ho: dut * 0.8), .mo)
                ban.them(HinhNet.dut(CGPoint(x: o.minX + 2, y: o.midY), CGPoint(x: o.maxX - 2, y: o.midY), gach: dut, ho: dut * 0.8), .mo)
            }
            // Nét chữ trước, số sau: vẽ dần thì người xem thấy chữ thành hình
            // theo đúng thứ tự, rồi các con số hiện lên.
            var dauNet: [(CGPoint, CGPoint)] = []
            for m in c.medians {
                let d = m.compactMap { p -> CGPoint? in
                    p.count >= 2 ? CGPoint(x: x0 + CGFloat(p[0]) * k, y: (GOC_Y - CGFloat(p[1])) * k) : nil
                }
                guard d.count >= 2 else { continue }
                let muot = catmullRom(d)
                ban.them(muot, .chinh)
                let huong = CGPoint(x: muot[min(3, muot.count - 1)].x - muot[0].x, y: muot[min(3, muot.count - 1)].y - muot[0].y)
                dauNet.append((muot[0], huong))
            }
            guard soThuTu && c.danhSo else { continue }
            // Chỗ đặt số: thử quanh đầu nét (ưu tiên phía NGƯỢC chiều viết), chấm
            // điểm theo số điểm nét bị đè + số đã đặt + ra ngoài ô. Đặt thẳng ở
            // một hướng cố định thì chữ nhiều nét (語 14 nét) số đè số, đè nét.
            let mau = ban.net.indices.filter { ban.loai[$0] == .chinh }.flatMap { ban.net[$0] }
                .filter { $0.x >= o.minX && $0.x <= o.maxX }
            let beDay = canh * 0.02
            var daDat: [CGRect] = []
            for (j, (p0, h)) in dauNet.enumerated() {
                let dai = max(0.001, hypot(h.x, h.y))
                let goc0 = atan2(-h.y / dai, -h.x / dai)
                let so = PhongNetDon.dong("\(j + 1)", co: coSo)
                let w = so.rong + 1.5, hh = coSo + 1.5
                var tot: (CGRect, CGFloat)?
                for (kg, lech) in [0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, 2.5, -2.5, .pi].enumerated() {
                    for (kd, xa) in [0.85, 1.25, 1.7].enumerated() {
                        let g = goc0 + CGFloat(lech)
                        let r0 = CGFloat(xa) * coSo
                        let tam = CGPoint(x: p0.x + cos(g) * r0, y: p0.y + sin(g) * r0)
                        let r = CGRect(x: tam.x - w / 2, y: tam.y - hh / 2, width: w, height: hh)
                        var diem = CGFloat(kg) * 1.2 + CGFloat(kd) * 2
                        if !o.insetBy(dx: 1, dy: 1).contains(r) { diem += 60 }
                        let noRa = r.insetBy(dx: -beDay, dy: -beDay)
                        diem += CGFloat(mau.filter { noRa.contains($0) }.count) * 4
                        for d in daDat where d.intersects(r.insetBy(dx: -1, dy: -1)) { diem += 80 }
                        if tot == nil || diem < tot!.1 { tot = (r, diem) }
                    }
                }
                guard let r = tot?.0 else { continue }
                daDat.append(r)
                ban.them(so.net.map { $0.map { CGPoint(x: $0.x + r.midX - so.rong / 2, y: $0.y + r.midY - coSo / 2) } }, .so)
            }
        }
        ban.chotKhung(le: 2)
        // Chữ Hán là nét CHÍNH, cỡ theo ô — KHÔNG theo bút người dùng: bút dày
        // (cỡ điểm ~6) làm chữ 96pt đặc như bút dạ (đo máy ảo iPadOS 27, 29/09).
        ban.coNetCoDinh = max(2.6, canh * 0.045)
        return ban
    }

    /// Làm mượt đường tim thưa (hanzi-writer: 2–6 điểm/nét) bằng Catmull-Rom,
    /// giữ nguyên điểm đầu/cuối — đầu nét là thứ đang dạy.
    static func catmullRom(_ d: [CGPoint], chia: Int = 6) -> [CGPoint] {
        guard d.count >= 3 else { return d }
        var ra: [CGPoint] = [d[0]]
        for i in 0..<(d.count - 1) {
            let p0 = d[max(i - 1, 0)], p1 = d[i], p2 = d[i + 1], p3 = d[min(i + 2, d.count - 1)]
            for s in 1...chia {
                let t = CGFloat(s) / CGFloat(chia), t2 = t * t, t3 = t2 * t
                func f(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ e: CGFloat) -> CGFloat {
                    0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - e) * t2 + (-a + 3 * b - 3 * c + e) * t3)
                }
                ra.append(CGPoint(x: f(p0.x, p1.x, p2.x, p3.x), y: f(p0.y, p1.y, p2.y, p3.y)))
            }
        }
        return ra
    }
}
