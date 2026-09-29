import CoreGraphics
import Foundation

// ════════════════════════════════════════════════════════════════
// PHÔNG NÉT ĐƠN — viết chữ bằng NÉT BÚT (không phải chữ in)
//
// Sơ đồ khối trên vở phải có chữ ("Controller", "Cơ sở dữ liệu"…), và chữ đó
// phải là PKStroke như mọi nét khác: tẩy được, lasso dời được, không phải ảnh
// dán. Phông thường (TrueType) là ĐƯỜNG VIỀN — vẽ viền thì ra chữ rỗng ruột.
// Cần phông NÉT ĐƠN: mỗi nét là một đường bút đi qua giữa nét chữ.
//
// Nguồn: Hershey "Roman Simplex" (`futural`), xuất bằng gói PyPI
// `Hershey-Fonts` 2.1.0 (MIT) ra đúng định dạng mã hoá gốc của Hershey:
// mỗi toạ độ là một ký tự, giá trị = mã ký tự − 'R'; " R" = nhấc bút; hai ký
// tự đầu là lề trái / lề phải. 95 ký tự ASCII 32…126, dòng thứ i = ký tự 32+i.
//
// Giấy phép dữ liệu (phải đi kèm dữ liệu — điều kiện của bản phân phối):
//   The Hershey Fonts were originally created by Dr. A. V. Hershey while
//   working at the U. S. National Bureau of Standards.
//   The format of the Font data in this distribution was originally created
//   by James Hurt, Cognition, Inc., 900 Technology Park Drive, Billerica,
//   MA 01821.
// Dữ liệu Hershey thuộc phạm vi công cộng; bản phân phối trên cho dùng vào mọi
// mục đích (kể cả thương mại) miễn giữ hai dòng ghi công này và không đổi sang
// đúng định dạng của NTIS.
//
// DẤU TIẾNG VIỆT tự dựng: tách ký tự theo NFD (ế = e + ◌̂ + ◌́) rồi ghép dấu
// bằng nét lên chữ gốc — Hershey chỉ có ASCII. `đ/Đ` không tách được theo
// NFD nên xử lý riêng (gạch ngang qua thân).
//
// Hệ toạ độ Hershey: y hướng XUỐNG, đường chân chữ y = 9, đỉnh chữ hoa y = −12
// (cao 21 đơn vị), đỉnh chữ thường y = −5.
//
// Thuần CoreGraphics + Foundation (không UIKit) để dựng thử được trên macOS.
// ════════════════════════════════════════════════════════════════

enum PhongNetDon {
    struct KyTu {
        let trai: CGFloat
        let phai: CGFloat
        let net: [[CGPoint]]
    }

    /// Một dòng chữ đã dựng: nét ở toạ độ pt, gốc (0,0) là ĐỈNH CHỮ HOA bên
    /// trái; đường chân chữ ở y = `co`.
    struct Dong {
        let net: [[CGPoint]]
        let rong: CGFloat
    }

    static let CHAN: CGFloat = 9
    static let DINH_HOA: CGFloat = -12
    static let DINH_THUONG: CGFloat = -5
    static let CAO_HOA: CGFloat = 21

    // MARK: Đọc dữ liệu

    private static let bang: [KyTu] = {
        DU_LIEU.split(separator: "\n", omittingEmptySubsequences: false).map { dong in
            let c = Array(dong.unicodeScalars).map { CGFloat(Int($0.value) - 82) }  // 'R' = 82
            guard c.count >= 2 else { return KyTu(trai: -8, phai: 8, net: []) }
            var net: [[CGPoint]] = []
            var cur: [CGPoint] = []
            var i = 2
            let goc = Array(dong.unicodeScalars)
            while i + 1 < goc.count {
                if goc[i] == " " && goc[i + 1] == "R" {
                    if cur.count > 1 { net.append(cur) }
                    cur = []
                } else {
                    cur.append(CGPoint(x: c[i], y: c[i + 1]))
                }
                i += 2
            }
            if cur.count > 1 { net.append(cur) }
            return KyTu(trai: c[0], phai: c[1], net: net)
        }
    }()

    static func kyTu(_ s: Unicode.Scalar) -> KyTu? {
        let v = Int(s.value)
        guard v >= 32, v - 32 < bang.count else { return nil }
        return bang[v - 32]
    }

    // MARK: Dấu tiếng Việt

    private enum Dau { case sac, huyen, hoi, nga, nang, mu, trang, moc }

    private static func dau(_ s: Unicode.Scalar) -> Dau? {
        switch s.value {
        case 0x0301: return .sac
        case 0x0300: return .huyen
        case 0x0309: return .hoi
        case 0x0303: return .nga
        case 0x0323: return .nang
        case 0x0302: return .mu
        case 0x0306: return .trang
        case 0x031B: return .moc
        default: return nil
        }
    }

    /// Nét của một dấu, đáy dấu ở `yDay` (y xuống), tâm ngang `cx`. Đơn vị Hershey.
    ///
    /// Dấu to hơn dấu in thường một chút: ở cỡ 9–10pt, nét bút ~1pt làm dấu
    /// nhỏ nhoè thành chấm — đo bằng mắt trên ảnh dựng thử.
    private static func netDau(_ d: Dau, cx: CGFloat, yDay: CGFloat) -> [[CGPoint]] {
        func p(_ a: [(CGFloat, CGFloat)]) -> [CGPoint] { a.map { CGPoint(x: cx + $0.0, y: yDay + $0.1) } }
        switch d {
        case .sac:   return [p([(-1.6, 0), (2.4, -5)])]
        case .huyen: return [p([(1.6, 0), (-2.4, -5)])]
        case .hoi:   return [p([(-2, -4), (-0.6, -5.2), (1.4, -5), (2, -3.6), (0.6, -2.4), (0, -1.2), (0, 0)])]
        case .nga:   return [p([(-3.4, -1), (-2.2, -3), (-0.8, -3.2), (0.8, -1.6), (2.2, -1.2), (3.4, -3.4)])]
        case .mu:    return [p([(-3.6, 0), (0, -3.8), (3.6, 0)])]
        case .trang: return [p([(-3.4, -3.6), (-2.6, -1), (0, 0), (2.6, -1), (3.4, -3.6)])]
        case .nang:  return [p([(0, 0), (0.5, 0.9)])]
        case .moc:   return []
        }
    }

    /// Dựng một ký tự (có thể mang dấu). Trả nét (đơn vị Hershey, gốc x = 0 ở
    /// lề trái ký tự) và bề rộng tiến.
    private static func dung(_ ch: Character) -> ([[CGPoint]], CGFloat) {
        var cacMa = Array(String(ch).decomposedStringWithCanonicalMapping.unicodeScalars)
        var gachD = false
        if cacMa.first?.value == 0x0111 { cacMa[0] = "d"; gachD = true }       // đ
        else if cacMa.first?.value == 0x0110 { cacMa[0] = "D"; gachD = true }  // Đ
        guard let goc = cacMa.first else { return ([], 0) }
        let cacDau = cacMa.dropFirst().compactMap(dau)
        guard let k = kyTu(goc) ?? kyTu("?") else { return ([], 0) }

        var net = k.net
        let laHoa = CharacterSet.uppercaseLetters.contains(goc)
        // i/j có dấu thì bỏ chấm (nét ngắn nằm cao hơn đỉnh chữ thường).
        if (goc == "i" || goc == "j") && !cacDau.isEmpty {
            net.removeAll { n in n.allSatisfy { $0.y < DINH_THUONG - 1 } }
        }
        let xs = net.flatMap { $0.map(\.x) }
        let xMin = xs.min() ?? 0, xMax = xs.max() ?? 0
        var cx = (xMin + xMax) / 2
        var phaiThem: CGFloat = 0

        if cacDau.contains(.moc) && (goc == "o" || goc == "u" || goc == "O" || goc == "U") {
            // Móc: nét cong nhỏ bám góc trên-phải (ơ, ư).
            let dinh = laHoa ? DINH_HOA : DINH_THUONG
            let x0 = goc == "u" || goc == "U" ? xMax : xMax - 1
            net.append([CGPoint(x: x0, y: dinh + 1.4), CGPoint(x: x0 + 2.2, y: dinh - 0.6),
                        CGPoint(x: x0 + 2.6, y: dinh - 3)])
            phaiThem = 2
            cx = (xMin + xMax) / 2 - 0.5
        }
        if gachD {
            if goc == "d" {
                // thân d ở bên PHẢI (nét dọc x lớn nhất, cao tới đỉnh chữ hoa)
                net.append([CGPoint(x: xMax - 3.5, y: -8), CGPoint(x: xMax + 3, y: -8)])
                phaiThem = max(phaiThem, 2)
            } else {
                net.append([CGPoint(x: xMin - 2.5, y: -1.5), CGPoint(x: xMin + 5, y: -1.5)])
            }
        }

        // Dấu trên xếp tầng: mũ/trăng sát chữ, dấu thanh trên cùng.
        var tang = (laHoa ? DINH_HOA : DINH_THUONG) - 2.2
        for d in cacDau where d == .mu || d == .trang {
            net += netDau(d, cx: cx, yDay: tang)
            tang -= 5
        }
        for d in cacDau where [.sac, .huyen, .hoi, .nga].contains(d) {
            // Có mũ thì dấu thanh lệch phải một chút (kiểu chữ viết tay Việt).
            let lech: CGFloat = cacDau.contains(.mu) ? 2.4 : 0
            net += netDau(d, cx: cx + lech, yDay: tang + (cacDau.contains(.mu) ? 1.2 : 0))
        }
        if cacDau.contains(.nang) { net += netDau(.nang, cx: cx, yDay: CHAN + 3.4) }

        let dich = -k.trai
        let doi = net.map { $0.map { CGPoint(x: $0.x + dich, y: $0.y) } }
        return (doi, k.phai - k.trai + phaiThem)
    }

    // MARK: Dựng dòng

    /// Bề rộng (pt) của `s` ở cỡ `co` (co = chiều cao CHỮ HOA, pt).
    static func doRong(_ s: String, co: CGFloat) -> CGFloat {
        let ty = co / CAO_HOA
        return s.reduce(0) { $0 + dung($1).1 } * ty * GIAN
    }

    /// Hệ số giãn ngang: Hershey Simplex hơi chật khi nét bút dày ~1pt.
    static let GIAN: CGFloat = 1.06

    /// Một dòng chữ ở cỡ `co`: gốc (0,0) = đỉnh chữ hoa bên trái.
    static func dong(_ s: String, co: CGFloat) -> Dong {
        let ty = co / CAO_HOA
        var x: CGFloat = 0
        var ra: [[CGPoint]] = []
        for ch in s {
            let (net, rong) = dung(ch)
            for n in net {
                ra.append(n.map { CGPoint(x: x + $0.x * ty * GIAN, y: ($0.y - DINH_HOA) * ty) })
            }
            x += rong * ty * GIAN
        }
        return Dong(net: ra, rong: x)
    }

    /// Ngắt `s` thành các dòng rộng không quá `rongToiDa` (ngắt ở dấu cách;
    /// từ dài hơn cả dòng thì để nguyên, không cắt giữa từ).
    static func ngatDong(_ s: String, co: CGFloat, rongToiDa: CGFloat) -> [String] {
        let tu = s.split(separator: " ").map(String.init)
        var dongs: [String] = []
        var cur = ""
        for t in tu {
            let thu = cur.isEmpty ? t : cur + " " + t
            if cur.isEmpty || doRong(thu, co: co) <= rongToiDa { cur = thu } else { dongs.append(cur); cur = t }
        }
        if !cur.isEmpty { dongs.append(cur) }
        return dongs.isEmpty ? [""] : dongs
    }

    /// Khoảng cách giữa hai đường chân chữ liền nhau — chừa chỗ cho dấu tầng
    /// hai (ế, ỗ) phía trên và dấu nặng / chân chữ g, y phía dưới.
    static func buocDong(co: CGFloat) -> CGFloat { co * 1.78 }

    /// Khối chữ nhiều dòng, căn GIỮA theo chiều ngang quanh x = 0, đỉnh khối ở
    /// y = 0 (tính cả chỗ cho dấu tầng hai). Trả nét + kích thước khối.
    static func khoi(_ dongs: [String], co: CGFloat) -> (net: [[CGPoint]], rong: CGFloat, cao: CGFloat) {
        let tren = co * 0.5            // chỗ cho dấu phía trên chữ hoa
        let buoc = buocDong(co: co)
        var ra: [[CGPoint]] = []
        var rongMax: CGFloat = 0
        for (i, s) in dongs.enumerated() {
            let d = dong(s, co: co)
            rongMax = max(rongMax, d.rong)
            let y0 = tren + CGFloat(i) * buoc
            ra += d.net.map { $0.map { CGPoint(x: $0.x - d.rong / 2, y: $0.y + y0) } }
        }
        let cao = tren + CGFloat(max(dongs.count - 1, 0)) * buoc + co * 1.42
        return (ra, rongMax, cao)
    }

    // MARK: Dữ liệu Hershey futural (ASCII 32…126)

    private static let DU_LIEU = ##"""
JZ
MWRFRT RRYQZR[SZRY
JZNFNM RVFVM
H]SBLb RYBRb RLOZO RKUYU
H\PBP_ RTBT_ RYIWGTFPFMGKIKKLMMNOOUQWRXSYUYXWZT[P[MZKX
F^[FI[ RNFPHPJOLMMKMIKIIJGLFNFPGSHVHYG[F RWTUUTWTYV[X[ZZ[X[VYTWT
E_\O\N[MZMYNXPVUTXRZP[L[JZIYHWHUISJRQNRMSKSIRGPFNGMIMKNNPQUXWZY[[[\Z\Y
MWRHQGRFSGSIRKQL
KYVBTDRGPKOPOTPYR]T`Vb
KYNBPDRGTKUPUTTYR]P`Nb
JZRLRX RMOWU RWOMU
E_RIR[ RIR[R
NVSWRXQWRVSWSYQ[
E_IR[R
NVRVQWRXSWRV
G][BIb
H\QFNGLJKOKRLWNZQ[S[VZXWYRYOXJVGSFQF
H\NJPISFS[
H\LKLJMHNGPFTFVGWHXJXLWNUQK[Y[
H\MFXFRNUNWOXPYSYUXXVZS[P[MZLYKW
H\UFKTZT RUFU[
H\WFMFLOMNPMSMVNXPYSYUXXVZS[P[MZLYKW
H\XIWGTFRFOGMJLOLTMXOZR[S[VZXXYUYTXQVOSNRNOOMQLT
H\YFO[ RKFYF
H\PFMGLILKMMONSOVPXRYTYWXYWZT[P[MZLYKWKTLRNPQOUNWMXKXIWGTFPF
H\XMWPURRSQSNRLPKMKLLINGQFRFUGWIXMXRWWUZR[P[MZLX
NVROQPRQSPRO RRVQWRXSWRV
NVROQPRQSPRO RSWRXQWRVSWSYQ[
F^ZIJRZ[
E_IO[O RIU[U
F^JIZRJ[
I[LKLJMHNGPFTFVGWHXJXLWNVORQRT RRYQZR[SZRY
E`WNVLTKQKOLNMMPMSNUPVSVUUVS RQKOMNPNSOUPV RWKVSVUXVZV\T]Q]O\L[JYHWGTFQFNGLHJJILHOHRIUJWLYNZQ[T[WZYYZX RXKWSWUXV
I[RFJ[ RRFZ[ RMTWT
G\KFK[ RKFTFWGXHYJYLXNWOTP RKPTPWQXRYTYWXYWZT[K[
H]ZKYIWGUFQFOGMILKKNKSLVMXOZQ[U[WZYXZV
G\KFK[ RKFRFUGWIXKYNYSXVWXUZR[K[
H[LFL[ RLFYF RLPTP RL[Y[
HZLFL[ RLFYF RLPTP
H]ZKYIWGUFQFOGMILKKNKSLVMXOZQ[U[WZYXZVZS RUSZS
G]KFK[ RYFY[ RKPYP
NVRFR[
JZVFVVUYTZR[P[NZMYLVLT
G\KFK[ RYFKT RPOY[
HYLFL[ RL[X[
F^JFJ[ RJFR[ RZFR[ RZFZ[
G]KFK[ RKFY[ RYFY[
G]PFNGLIKKJNJSKVLXNZP[T[VZXXYVZSZNYKXIVGTFPF
G\KFK[ RKFTFWGXHYJYMXOWPTQKQ
G]PFNGLIKKJNJSKVLXNZP[T[VZXXYVZSZNYKXIVGTFPF RSWY]
G\KFK[ RKFTFWGXHYJYLXNWOTPKP RRPY[
H\YIWGTFPFMGKIKKLMMNOOUQWRXSYUYXWZT[P[MZKX
JZRFR[ RKFYF
G]KFKULXNZQ[S[VZXXYUYF
I[JFR[ RZFR[
F^HFM[ RRFM[ RRFW[ R\FW[
H\KFY[ RYFK[
I[JFRPR[ RZFRP
H\YFK[ RKFYF RK[Y[
KYOBOb RPBPb ROBVB RObVb
KYKFY^
KYTBTb RUBUb RNBUB RNbUb
JZRDJR RRDZR
I[Ib[b
NVSKQMQORPSORNQO
I\XMX[ RXPVNTMQMONMPLSLUMXOZQ[T[VZXX
H[LFL[ RLPNNPMSMUNWPXSXUWXUZS[P[NZLX
I[XPVNTMQMONMPLSLUMXOZQ[T[VZXX
I\XFX[ RXPVNTMQMONMPLSLUMXOZQ[T[VZXX
I[LSXSXQWOVNTMQMONMPLSLUMXOZQ[T[VZXX
MYWFUFSGRJR[ ROMVM
I\XMX]W`VaTbQbOa RXPVNTMQMONMPLSLUMXOZQ[T[VZXX
I\MFM[ RMQPNRMUMWNXQX[
NVQFRGSFREQF RRMR[
MWRFSGTFSERF RSMS^RaPbNb
IZMFM[ RWMMW RQSX[
NVRFR[
CaGMG[ RGQJNLMOMQNRQR[ RRQUNWMZM\N]Q][
I\MMM[ RMQPNRMUMWNXQX[
I\QMONMPLSLUMXOZQ[T[VZXXYUYSXPVNTMQM
H[LMLb RLPNNPMSMUNWPXSXUWXUZS[P[NZLX
I\XMXb RXPVNTMQMONMPLSLUMXOZQ[T[VZXX
KXOMO[ ROSPPRNTMWM
J[XPWNTMQMNNMPNRPSUTWUXWXXWZT[Q[NZMX
MYRFRWSZU[W[ ROMVM
I\MMMWNZP[S[UZXW RXMX[
JZLMR[ RXMR[
G]JMN[ RRMN[ RRMV[ RZMV[
J[MMX[ RXMM[
JZLMR[ RXMR[P_NaLbKb
J[XMM[ RMMXM RM[X[
KYTBRCQDPFPHQJRKSMSOQQ RRCQEQGRISJTLTNSPORSTTVTXSZR[Q]Q_Ra RQSSUSWRYQZP\P^Q`RaTb
NVRBRb
KYPBRCSDTFTHSJRKQMQOSQ RRCSESGRIQJPLPNQPURQTPVPXQZR[S]S_Ra RSSQUQWRYSZT\T^S`RaPb
F^IUISJPLONOPPTSVTXTZS[Q RISJQLPNPPQTTVUXUZT[Q[O
"""##
}
