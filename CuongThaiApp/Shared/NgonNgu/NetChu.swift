import Foundation
import SwiftUI

// ════════════════════════════════════════════════════════════════
// NÉT CHỮ — dữ liệu để luyện viết
//
// `GET /my-language/hanzi-stroke/:char?lang=ja|zh` trả về định dạng chuẩn
// của bộ nét chữ Hán:
//   · `strokes` — hình DẠNG từng nét (đường viền, tô đặc)
//   · `medians` — đường TIM từng nét: chuỗi điểm chạy dọc giữa nét, theo
//     đúng thứ tự và chiều viết. Đây mới là thứ dùng để chấm ngón tay.
//
// ⚠️ HAI BẪY, cả hai đều ĐO ra chứ không đọc mã mà biết:
//
// 1. TRỤC Y BỊ LẬT. Hệ toạ độ 1024×1024 nhưng gốc nằm dưới, và y chạy từ
//    -124 tới 900. Vẽ thẳng không lật thì あ ra NGƯỢC ĐẦU và soi gương —
//    tôi đã dựng thử cả hai cách ra ảnh rồi mới chốt. Phép biến đổi đúng:
//    y' = 900 - y.
//
// 2. KHÔNG BỌC ENVELOPE. Mọi endpoint khác trả `{success, data}`, riêng
//    cái này trả thẳng `{character, strokes, medians}` — đưa qua
//    `APIClient.request` là giải mã hỏng.
// ════════════════════════════════════════════════════════════════

struct NetChu: Codable {
    let character: String
    let strokes: [String]
    let medians: [[[Double]]]

    var soNet: Int { strokes.count }

    /// Đường tim nét thứ `i`, đã đưa về khung vuông cạnh `canh`.
    /// Dữ liệu nét có hai loại, và phải VẼ KHÁC NHAU:
    ///
    /// - **Đường viền** (hanzi-writer: mọi kanji, và kana bản cũ) — mỗi nét
    ///   là một hình khép kín, có lệnh `Z`. Vẽ bằng `.fill`.
    /// - **Đường tim** (KanjiVG: kana từ 18/09/2026) — mỗi nét là một đường
    ///   hở chạy giữa nét bút, KHÔNG có `Z`. Vẽ bằng `.stroke`.
    ///
    /// ⚠️ Vẽ nhầm kiểu thì hỏng câm: `.fill` một đường hở khiến SwiftUI tự
    /// khép nó lại và tô đầy ruột — nét vòng của あ phình thành một mảng đặc
    /// như quả trứng, đúng thứ người dùng báo là "nét to nhỏ". Ngược lại
    /// `.stroke` một đường viền thì ra nét đôi rỗng ruột.
    ///
    /// Đo 18/09/2026: kana mới 0/516 nét có `Z`; kanji 113/113 có.
    var laDuongTim: Bool {
        guard let dau = strokes.first else { return false }
        return !dau.contains("Z") && !dau.contains("z")
    }

    /// Bề dày nét khi vẽ kiểu đường tim — theo tỉ lệ khung, không phải số
    /// điểm ảnh cố định, để ô lớn ô nhỏ đều ra nét cân đối.
    func beDayNet(canh: CGFloat) -> CGFloat { max(6, canh * 0.055) }

    func duongTim(_ i: Int, canh: CGFloat) -> [CGPoint] {
        guard i < medians.count else { return [] }
        return medians[i].compactMap { p in
            guard p.count >= 2 else { return nil }
            return Self.doiToaDo(CGPoint(x: p[0], y: p[1]), canh: canh)
        }
    }

    static let KHUNG: CGFloat = 1024
    static let GOC_Y: CGFloat = 900

    static func doiToaDo(_ p: CGPoint, canh: CGFloat) -> CGPoint {
        let k = canh / KHUNG
        return CGPoint(x: p.x * k, y: (GOC_Y - p.y) * k)
    }
}

// ── Vẽ đường SVG ────────────────────────────────────────────────

enum DuongSVG {
    /// Bộ phân tích tối giản cho `M`, `C`, `L`, `Z` — đo thật trên dữ liệu:
    /// あ/ン/你/漢/き chỉ dùng đúng bốn lệnh này, tất cả đều TUYỆT ĐỐI (chữ
    /// hoa). Viết bộ phân tích SVG đầy đủ ở đây là làm thừa.
    static func doi(_ d: String, canh: CGFloat) -> Path {
        var p = Path()
        var so: [Double] = []
        var lenh: Character = " "
        var dau = CGPoint.zero

        func xong() {
            switch lenh {
            case "M":
                guard so.count >= 2 else { break }
                dau = NetChu.doiToaDo(CGPoint(x: so[0], y: so[1]), canh: canh)
                p.move(to: dau)
            case "L":
                var i = 0
                while i + 1 < so.count {
                    p.addLine(to: NetChu.doiToaDo(CGPoint(x: so[i], y: so[i+1]), canh: canh))
                    i += 2
                }
            case "C":
                var i = 0
                while i + 5 < so.count {
                    p.addCurve(
                        to: NetChu.doiToaDo(CGPoint(x: so[i+4], y: so[i+5]), canh: canh),
                        control1: NetChu.doiToaDo(CGPoint(x: so[i],   y: so[i+1]), canh: canh),
                        control2: NetChu.doiToaDo(CGPoint(x: so[i+2], y: so[i+3]), canh: canh))
                    i += 6
                }
            case "Z":
                p.closeSubpath()
            default: break
            }
            so.removeAll(keepingCapacity: true)
        }

        var soDang = ""
        func chotSo() {
            if let v = Double(soDang) { so.append(v) }
            soDang = ""
        }

        for c in d {
            if c.isLetter {
                chotSo(); xong(); lenh = c
            } else if c == "-" && !soDang.isEmpty && soDang.last != "e" {
                // Dấu trừ GIỮA chuỗi là bắt đầu số âm mới, không phải phép
                // trừ: "660,689C637-12" nghĩa là 637 rồi -12.
                chotSo(); soDang = "-"
            } else if c.isNumber || c == "." || c == "-" || c == "e" {
                soDang.append(c)
            } else {
                chotSo()
            }
        }
        chotSo(); xong()
        return p
    }
}

// ── Chấm điểm nét ───────────────────────────────────────────────

enum ChamNet {
    /// Nét vẽ có khớp với đường tim không.
    ///
    /// BỐN phép kiểm, mỗi phép bắt một kiểu sai KHÁC nhau — bỏ bất kỳ cái
    /// nào là lọt một loại lỗi:
    ///
    ///  1. ĐÚNG CHỖ — mọi điểm trên đường tim đều có nét đi ngang qua gần đó.
    ///     Không có phép này thì vẽ một gạch ngắn xíu giữa nét cũng qua.
    ///  2. ĐÚNG CHIỀU — đầu nét gần đầu đường tim, cuối gần cuối. Không có
    ///     phép này thì viết ngược từ dưới lên vẫn tính đúng, mà thứ tự và
    ///     chiều nét chính là thứ đang dạy.
    ///  3. KHÔNG THỪA — nét vẽ không lê ra quá xa khỏi đường tim. Không có
    ///     phép này thì tô nguệch ngoạc kín cả ô cũng qua hết.
    static func dat(nguoiVe: [CGPoint], duongTim: [CGPoint], canh: CGFloat) -> Bool {
        guard nguoiVe.count > 2, duongTim.count > 1 else { return false }
        // Ngưỡng theo cỡ ô, không theo điểm ảnh: đổi máy là ngưỡng đi theo.
        // Ngưỡng chốt bằng cách QUÉT cả vùng tham số trên 90 ca sinh từ dữ
        // liệu thật (あ/き/你/漢, 3 nét mỗi chữ), rồi lấy bộ DỄ NHẤT trong
        // số 51.678 bộ qua sạch. Nới bằng tay thì lần đầu tôi nới quá và
        // ba kiểu viết bậy lọt qua — đừng chỉnh mấy số này bằng cảm tính.
        let gan = canh * 0.24
        // Ngưỡng đầu-cuối CO THEO ĐỘ DÀI NÉT. Chữ 漢 có nét chỉ dài 48pt;
        // để ngưỡng cố định thì cả nét còn ngắn hơn ngưỡng, nên viết NGƯỢC
        // cũng "khớp hai đầu" và lọt.
        let ganDau = min(canh * 0.42, doDai(duongTim) * 0.36)

        // 2. đúng chiều
        guard let d0 = nguoiVe.first, let dN = nguoiVe.last,
              let t0 = duongTim.first, let tN = duongTim.last else { return false }
        if khoangCach(d0, t0) > ganDau { return false }
        if khoangCach(dN, tN) > ganDau { return false }

        // 4. KHÔNG TÔ LOẠN — nét vẽ không được dài gấp mấy lần đường tim.
        //
        // Tín hiệu này ba phép kia KHÔNG có: với nét NGẮN, một đường nguệch
        // ngoạc kín ô vẫn "đi qua gần" nó và vẫn bắt đầu/kết thúc gần hai
        // đầu, nên cả ba phép đều cho qua. Đo ra lúc quét tham số.
        let dTim = doDai(duongTim)
        if dTim > 0 && doDai(nguoiVe) > dTim * 1.6 { return false }

        // 1. đúng chỗ
        for t in duongTim {
            let gapNhat = nguoiVe.map { khoangCach($0, t) }.min() ?? .infinity
            if gapNhat > gan { return false }
        }

        // 3. không thừa
        let lech = nguoiVe.map { d in duongTim.map { khoangCach(d, $0) }.min() ?? .infinity }
        let quaXa = lech.filter { $0 > gan * 1.5 }.count
        if Double(quaXa) / Double(lech.count) > 0.40 { return false }

        return true
    }

    private static func doDai(_ ds: [CGPoint]) -> CGFloat {
        guard ds.count > 1 else { return 0 }
        var t: CGFloat = 0
        for i in 1..<ds.count { t += khoangCach(ds[i-1], ds[i]) }
        return t
    }

    private static func khoangCach(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx*dx + dy*dy).squareRoot()
    }
}
