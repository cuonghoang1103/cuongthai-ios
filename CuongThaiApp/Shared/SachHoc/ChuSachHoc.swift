import SwiftUI
#if canImport(UIKit)
import UIKit
import CoreText
#endif

// ════════════════════════════════════════════════════════════════
// CHỮ TRONG BÀI — cú pháp nhỏ của web (`Inline` trong Blocks.tsx):
//   **đậm** · *nghiêng* · ==dạ quang== · ~~gạch (câu sai)~~ · {漢字|かんじ} → chữ có furigana
// (lồng được: **{私|わたし}は** …). Furigana vẽ bằng CTRubyAnnotation của
// CoreText trong một UILabel — SwiftUI `Text` KHÔNG có ruby. Câu không có
// furigana (hoặc người học tắt furigana) đi `Text` thường cho nhẹ.
//
// Màu chữ: UIColor ĐỘNG (theo trait của chính view) — đừng truyền cờ sáng/tối
// từ ngoài vào (bài học 2026-09: hai đường xác định chế độ màu lệch nhau).
// ════════════════════════════════════════════════════════════════

/// Cài đặt đọc dùng chung mọi khoá kiểu sách (nhớ trên máy).
enum CaiDatDocSH {
    static let furigana = "sachhoc.furigana"
    static let romaji = "sachhoc.romaji"
    static let coChu = "sachhoc.coChu"
    static let tocDo = "sachhoc.tocDo"
}

struct DoanChuSH {
    var text: String
    var dam = false
    var nghieng = false
    var gach = false
    var to = false
    var ruby: String?
}

enum PhanTichChuSH {
    /// *nghiêng* (romaji *shuumatsu*, câu ví dụ IELTS): ~630 cặp trong dữ liệu, trước 23/10 hiện nguyên
    /// dấu sao. Cặp nghiêng chứa được **đậm**; dấu * dính chữ hai bên (5*3, péngyou*) giữ nguyên.
    /// Cùng luật với `INLINE_RE` của web (Blocks.tsx).
    private static let re = try! NSRegularExpression(pattern: #"(\*\*[^*]+\*\*|(?<![*\w])\*(?=[^\s*])(?:[^*\n]|\*\*[^*\n]+\*\*)+?(?<=\S)\*(?![*\w])|~~[^~]+~~|==[^=]+==|\{[^|}]+\|[^}]+\})"#)

    static func tach(_ s: String, dam: Bool = false, nghieng: Bool = false, gach: Bool = false, to: Bool = false) -> [DoanChuSH] {
        var out: [DoanChuSH] = []
        let ns = s as NSString
        var dau = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > dau {
                out.append(DoanChuSH(text: ns.substring(with: NSRange(location: dau, length: m.range.location - dau)), dam: dam, nghieng: nghieng, gach: gach, to: to))
            }
            let p = ns.substring(with: m.range)
            let trong = String(p.dropFirst(2).dropLast(2))
            if p.hasPrefix("**") { out += tach(trong, dam: true, nghieng: nghieng, gach: gach, to: to) }
            else if p.hasPrefix("*") { out += tach(String(p.dropFirst().dropLast()), dam: dam, nghieng: true, gach: gach, to: to) }
            else if p.hasPrefix("~~") { out += tach(trong, dam: dam, nghieng: nghieng, gach: true, to: to) }
            else if p.hasPrefix("==") { out += tach(trong, dam: dam, nghieng: nghieng, gach: gach, to: true) }
            else if let gach2 = p.firstIndex(of: "|") {
                let goc = String(p[p.index(after: p.startIndex)..<gach2])
                let doc = String(p[p.index(after: gach2)..<p.index(before: p.endIndex)])
                out.append(DoanChuSH(text: goc, dam: dam, nghieng: nghieng, gach: gach, to: to, ruby: doc))
            }
            dau = m.range.location + m.range.length
        }
        if dau < ns.length { out.append(DoanChuSH(text: ns.substring(from: dau), dam: dam, nghieng: nghieng, gach: gach, to: to)) }
        return out
    }

    /// Chữ trơn (bỏ markup, chữ Hán giữ gốc) — để tìm, so đáp án.
    static func tron(_ s: String) -> String { tach(s).map(\.text).joined() }

    /// Chữ đưa cho giọng đọc — như `clean` trong audio.ts: {漢字|かな} → 漢字, trừ cụm có CHỮ SỐ
    /// ({1日|ついたち}) thì đọc theo furigana (máy đọc "1日" dễ ra いちにち).
    static func choGiong(_ s: String) -> String {
        tach(s).map { d in
            if let r = d.ruby, d.text.contains(where: \.isNumber),
               r.unicodeScalars.allSatisfy({ (0x3040...0x30FF).contains($0.value) }) { return r }
            return d.text
        }.joined()
    }
}

// MARK: - Màu

enum MauChuSH {
    case chinh, phu, mo, nhan, tot, sai, mau(UInt32)

    #if canImport(UIKit)
    var ui: UIColor {
        switch self {
        case .chinh: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.97, alpha: 1) : UIColor(hex: 0x14141C) }
        case .phu: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xB4B4C2) : UIColor(hex: 0x4A4A55) }
        case .mo: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x8E8E9C) : UIColor(hex: 0x6A6A75) }
        case .nhan: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xA673FF) : UIColor(hex: 0x6535D0) }
        case .tot: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x33C759) : UIColor(hex: 0x157A33) }
        case .sai: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xEE4444) : UIColor(hex: 0xD32F2F) }
        case .mau(let h): return UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: h).sangHon(0.35) : UIColor(hex: h) }
        }
    }
    var color: Color { Color(ui) }
    #else
    var color: Color {
        switch self {
        case .chinh: return AppColors.textPrimary
        case .phu: return AppColors.textSecondary
        case .mo: return AppColors.textTertiary
        case .nhan: return AppColors.primary
        case .tot: return AppColors.success
        case .sai: return AppColors.error
        case .mau(let h): return Color(hex: h)
        }
    }
    #endif
}

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    /// Pha về phía trắng — màu loại bài của web (#b45309…) quá tối trên nền đen.
    func sangHon(_ t: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r + (1 - r) * t, green: g + (1 - g) * t, blue: b + (1 - b) * t, alpha: a)
    }
}
#endif

/// `#b45309` → 0xB45309 (màu loại bài trong index.json).
func hexSH(_ s: String?) -> UInt32 {
    guard let s else { return 0x6366F1 }
    return UInt32(s.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x6366F1
}

/// Nền dạ quang của `==…==`.
private let NEN_DA_QUANG = Color.theoCheDo(sang: Color(hex: 0xFDE68A), toi: Color(hex: 0x854D0E))

// MARK: - View chữ

/// Một đoạn chữ của bài (có markup). `co` là cỡ GỐC, nhân với cỡ chữ người học chọn.
struct ChuSH: View {
    let text: String
    var co: CGFloat = 17
    var dam: Bool = false
    var mau: MauChuSH = .chinh
    var nghieng: Bool = false
    var giua: Bool = false
    /// Ép bỏ furigana (đề đọc chữ Hán không furigana).
    var khongFurigana = false

    @AppStorage(CaiDatDocSH.furigana) private var furi = true
    @AppStorage(CaiDatDocSH.coChu) private var tiLe = 1.0
    /// Màn bài có thẻ chữ Hán ⇒ chạm một chữ Hán trong đoạn là mở thẻ của chữ đó (KanjiSheet của web).
    @Environment(\.moChuHanSH) private var moChuHan

    var body: some View {
        let doan = PhanTichChuSH.tach(text)
        let size = (co * tiLe).rounded()
        #if canImport(UIKit)
        let coRuby = furi && !khongFurigana && doan.contains(where: { $0.ruby != nil })
        // Chữ Hán chạm được cần UILabel (SwiftUI `Text` không biết chạm vào ký tự nào).
        let chamHan = moChuHan != nil && doan.contains { $0.text.contains(where: ChuHanTienIchSH.laHan) }
        if coRuby || chamHan {
            NhanRubySH(chu: Self.dungNS(doan, co: size, dam: dam, mau: mau, nghieng: nghieng, giua: giua, ruby: coRuby),
                       tren: coRuby ? size * 0.62 : 0,
                       cham: chamHan ? moChuHan : nil)
        } else {
            text(doan, size)
        }
        #else
        text(doan, size)
        #endif
    }

    private func text(_ doan: [DoanChuSH], _ size: CGFloat) -> some View {
        Text(Self.dungAttr(doan, co: size, dam: dam, nghieng: nghieng))
            .foregroundColor(mau.color)
            .multilineTextAlignment(giua ? .center : .leading)
            .lineSpacing(size * 0.18)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func dungAttr(_ doan: [DoanChuSH], co: CGFloat, dam: Bool, nghieng: Bool) -> AttributedString {
        var out = AttributedString()
        for d in doan {
            var a = AttributedString(d.text)
            var f = Font.system(size: co, weight: (d.dam || dam) ? .bold : .regular)
            if nghieng || d.nghieng { f = f.italic() }
            a.font = f
            if d.gach { a.strikethroughStyle = .single }
            if d.to { a.backgroundColor = NEN_DA_QUANG }
            out += a
        }
        return out
    }

    #if canImport(UIKit)
    static func dungNS(_ doan: [DoanChuSH], co: CGFloat, dam: Bool, mau: MauChuSH, nghieng: Bool, giua: Bool, ruby coRuby: Bool = true) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let ps = NSMutableParagraphStyle()
        // Chừa chỗ cho hàng furigana phía trên mỗi dòng — UILabel không tự nới dòng cho ruby.
        ps.lineSpacing = co * (coRuby ? 0.42 : 0.18)
        ps.alignment = giua ? .center : .natural
        ps.lineBreakMode = .byWordWrapping
        ps.lineBreakStrategy = .standard
        for d in doan {
            var font = UIFont.systemFont(ofSize: co, weight: (d.dam || dam) ? .bold : .regular)
            if nghieng || d.nghieng, let fd = font.fontDescriptor.withSymbolicTraits(.traitItalic) { font = UIFont(descriptor: fd, size: co) }
            var attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: mau.ui, .paragraphStyle: ps]
            if d.gach { attr[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            if d.to { attr[.backgroundColor] = UIColor(NEN_DA_QUANG) }
            if coRuby, let r = d.ruby {
                let ruby = CTRubyAnnotationCreateWithAttributes(
                    .auto, .auto, .before, r as CFString,
                    [kCTRubyAnnotationSizeFactorAttributeName: 0.5] as CFDictionary)
                attr[NSAttributedString.Key(kCTRubyAnnotationAttributeName as String)] = ruby
            }
            out.append(NSAttributedString(string: d.text, attributes: attr))
        }
        return out
    }
    #endif
}

#if canImport(UIKit)
/// UILabel vẽ chữ chừa một dải `tren` ở đỉnh: ruby của DÒNG ĐẦU nằm ngoài khung chữ
/// UILabel tự đo, nên không chừa là furigana dòng đầu bị cắt mất nửa (đo thật 23/10 — chỉ
/// còn mấy chấm trên 新宿). Các dòng sau đã có `lineSpacing` chừa chỗ.
final class NhanRubyUI: UILabel {
    var tren: CGFloat = 0
    override func drawText(in rect: CGRect) {
        let r = rect.inset(by: UIEdgeInsets(top: tren, left: 0, bottom: 0, right: 0))
        let h = super.sizeThatFits(CGSize(width: r.width, height: .greatestFiniteMagnitude)).height
        super.drawText(in: CGRect(x: r.minX, y: r.minY, width: r.width, height: min(r.height, ceil(h) + 1)))
    }
}

/// UILabel nhiều dòng vẽ được ruby; tự đo chiều cao theo bề ngang SwiftUI đề xuất.
struct NhanRubySH: UIViewRepresentable {
    let chu: NSAttributedString
    var tren: CGFloat = 0
    /// Chạm một chữ Hán ⇒ gọi với chữ đó. Chạm chỗ khác thì cử chỉ KHÔNG nhận (chạm đi tiếp như thường).
    var cham: ((String) -> Void)? = nil

    func makeCoordinator() -> ChamChuHanUI { ChamChuHanUI() }

    func makeUIView(context: Context) -> NhanRubyUI {
        let l = NhanRubyUI()
        l.numberOfLines = 0
        l.lineBreakMode = .byWordWrapping
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        l.setContentHuggingPriority(.defaultHigh, for: .vertical)
        let g = UITapGestureRecognizer(target: context.coordinator, action: #selector(ChamChuHanUI.bam(_:)))
        g.delegate = context.coordinator
        l.addGestureRecognizer(g)
        return l
    }

    func updateUIView(_ l: NhanRubyUI, context: Context) {
        context.coordinator.cham = cham
        l.isUserInteractionEnabled = cham != nil
        if l.tren != tren { l.tren = tren; l.setNeedsDisplay() }
        if l.attributedText != chu { l.attributedText = chu }
    }

    /// Bề ngang khi SwiftUI hỏi cỡ LÝ TƯỞNG (đề xuất `nil` — ô bảng trong ScrollView ngang +
    /// `fixedSize`). Trả cỡ một dòng 4000pt thì khung ngoài kẹp về 300pt nhưng giữ chiều cao một
    /// dòng ⇒ chữ xuống dòng tràn đè hàng dưới (ảnh iPad 23/10, bảng slide Bài 5).
    static let rongLyTuong: CGFloat = 300

    func sizeThatFits(_ de: ProposedViewSize, uiView l: NhanRubyUI, context: Context) -> CGSize? {
        let w = de.width.map { max(1, $0) } ?? Self.rongLyTuong
        l.preferredMaxLayoutWidth = w
        let s = l.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
        return CGSize(width: min(w, ceil(s.width)), height: ceil(s.height) + 2 + tren)
    }
}

/// Tìm chữ Hán dưới ngón tay bằng CoreText (cùng chuỗi có ruby mà UILabel vẽ, chừa dải `tren`).
/// Gần đúng theo dòng gần nhất — đủ để chạm trúng một chữ cỡ 17pt trở lên.
final class ChamChuHanUI: NSObject, UIGestureRecognizerDelegate {
    var cham: ((String) -> Void)?

    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard cham != nil, let l = g.view as? NhanRubyUI else { return false }
        return chuTai(g.location(in: l), l) != nil
    }

    @objc func bam(_ g: UITapGestureRecognizer) {
        guard let l = g.view as? NhanRubyUI, let c = chuTai(g.location(in: l), l) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        cham?(c)
    }

    private func chuTai(_ p: CGPoint, _ l: NhanRubyUI) -> String? {
        guard let at = l.attributedText, at.length > 0 else { return nil }
        let rong = l.bounds.width
        let cao: CGFloat = 100_000
        let fs = CTFramesetterCreateWithAttributedString(at)
        let khung = CTFramesetterCreateFrame(fs, CFRange(location: 0, length: 0), CGPath(rect: CGRect(x: 0, y: 0, width: rong, height: cao), transform: nil), nil)
        guard let dong = CTFrameGetLines(khung) as? [CTLine], !dong.isEmpty else { return nil }
        var goc = [CGPoint](repeating: .zero, count: dong.count)
        CTFrameGetLineOrigins(khung, CFRange(location: 0, length: 0), &goc)
        let y = p.y - l.tren
        var tot: (i: Int, kc: CGFloat)?
        for (i, d) in dong.enumerated() {
            var len: CGFloat = 0, xuong: CGFloat = 0, dem: CGFloat = 0
            CTLineGetTypographicBounds(d, &len, &xuong, &dem)
            let chan = cao - goc[i].y
            let tren = chan - len, duoi = chan + xuong
            let kc = y < tren ? tren - y : y > duoi ? y - duoi : 0
            if tot == nil || kc < tot!.kc { tot = (i, kc) }
        }
        guard let t = tot, t.kc < 14 else { return nil }
        let d = dong[t.i]
        let x = p.x - goc[t.i].x
        let ns = at.string as NSString
        let idx = CTLineGetStringIndexForPosition(d, CGPoint(x: x, y: 0))
        for i in [idx - 1, idx] where i >= 0 && i < ns.length {
            let r = ns.rangeOfComposedCharacterSequence(at: i)
            let x0 = CTLineGetOffsetForStringIndex(d, r.location, nil)
            let x1 = CTLineGetOffsetForStringIndex(d, r.location + r.length, nil)
            let c = ns.substring(with: r)
            if x >= min(x0, x1) - 2, x <= max(x0, x1) + 2, let k = c.first, ChuHanTienIchSH.laHan(k) { return c }
        }
        return nil
    }
}
#endif
