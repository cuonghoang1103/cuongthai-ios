import SwiftUI
#if os(iOS)
import UIKit

// ════════════════════════════════════════════════════════════════
// Ô GÕ MÃ CHO PHÒNG THI — chữ đơn cách, số dòng, thụt lề tự động
//
// `TextEditor` của SwiftUI không tắt được "dấu nháy thông minh" (gõ `"` ra
// `”`) — một dấu như thế là chương trình C không biên dịch nổi, và AI chấm
// sẽ trừ điểm vì một lỗi người học không hề gõ. Nên dùng `UITextView` với
// mọi thứ "thông minh" TẮT.
//
// Không tự cuộn: ô cao theo nội dung và nằm trong `ScrollView` của câu hỏi,
// nên cột số dòng luôn thẳng hàng với dòng chữ mà không phải đồng bộ hai
// thanh cuộn.
// ════════════════════════════════════════════════════════════════

struct TrinhSuaMa: UIViewRepresentable {
    @Binding var ma: String
    @Binding var chieuCao: CGFloat
    var goiY: String = "// Viết code của bạn ở đây…"
    var nhanTroNang: String = "Ô soạn mã"

    func makeUIView(context: Context) -> KhungSuaMa {
        let k = KhungSuaMa()
        k.oChu.delegate = context.coordinator
        k.oChu.text = ma
        k.goiY.text = goiY
        k.goiY.isHidden = !ma.isEmpty
        k.oChu.accessibilityLabel = nhanTroNang
        k.khiDoi = { [weak k] in
            guard let k else { return }
            let h = k.chieuCaoCan()
            if abs(h - chieuCao) > 0.5 {
                DispatchQueue.main.async { chieuCao = h }
            }
        }
        return k
    }

    func updateUIView(_ k: KhungSuaMa, context: Context) {
        context.coordinator.cha = self
        if k.oChu.text != ma {
            k.oChu.text = ma
            k.goiY.isHidden = !ma.isEmpty
            k.veLai()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: KhungSuaMa, context: Context) -> CGSize? {
        let w = proposal.width ?? 320
        return CGSize(width: w, height: max(220, uiView.chieuCaoCan(rong: w)))
    }

    func makeCoordinator() -> Dieu { Dieu(self) }

    final class Dieu: NSObject, UITextViewDelegate {
        var cha: TrinhSuaMa
        init(_ c: TrinhSuaMa) { cha = c }

        func textViewDidChange(_ tv: UITextView) {
            cha.ma = tv.text
            (tv.superview as? KhungSuaMa)?.goiY.isHidden = !tv.text.isEmpty
            (tv.superview as? KhungSuaMa)?.veLai()
        }

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText chu: String) -> Bool {
            // Tab (bàn phím rời của iPad) → 4 dấu cách, không nhảy ra khỏi ô.
            if chu == "\t" {
                chen("    ", vao: tv, thay: range)
                return false
            }
            // Xuống dòng → giữ thụt lề của dòng hiện tại, thêm một bậc sau `{`.
            if chu == "\n" {
                let ns = tv.text as NSString
                let dong = ns.lineRange(for: NSRange(location: range.location, length: 0))
                let dauDong = ns.substring(with: NSRange(location: dong.location,
                                                         length: range.location - dong.location))
                let thut = String(dauDong.prefix { $0 == " " || $0 == "\t" })
                let them = dauDong.trimmingCharacters(in: .whitespaces).hasSuffix("{") ? "    " : ""
                chen("\n" + thut + them, vao: tv, thay: range)
                return false
            }
            return true
        }

        private func chen(_ s: String, vao tv: UITextView, thay range: NSRange) {
            guard let bd = tv.position(from: tv.beginningOfDocument, offset: range.location),
                  let kt = tv.position(from: bd, offset: range.length),
                  let r = tv.textRange(from: bd, to: kt) else { return }
            tv.replace(r, withText: s)
            // Gọi tay cho chắc: thay chữ bằng mã không phải lúc nào cũng báo
            // `textViewDidChange` — gọi thừa một lần thì vô hại.
            textViewDidChange(tv)
        }
    }
}

/// Ô chữ + cột số dòng.
final class KhungSuaMa: UIView {
    let oChu: UITextView = {
        // TextKit 1 RÕ RÀNG: cột số dòng đọc `layoutManager` để biết dòng
        // logic nào nằm ở toạ độ nào (kể cả khi một dòng dài bị bẻ thành hai).
        let t = UITextView(usingTextLayoutManager: false)
        t.font = UIFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
        t.autocorrectionType = .no
        t.autocapitalizationType = .none
        t.smartQuotesType = .no
        t.smartDashesType = .no
        t.smartInsertDeleteType = .no
        t.spellCheckingType = .no
        t.keyboardType = .asciiCapable
        t.isScrollEnabled = false
        t.backgroundColor = .clear
        t.textContainerInset = UIEdgeInsets(top: 12, left: 6, bottom: 12, right: 10)
        return t
    }()
    let goiY: UILabel = {
        let l = UILabel()
        l.font = UIFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
        l.textColor = .tertiaryLabel
        l.isUserInteractionEnabled = false
        return l
    }()
    private let cot = CotSoDong()
    var khiDoi: (() -> Void)?

    static let rongCot: CGFloat = 38

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        cot.oChu = oChu
        addSubview(cot)
        addSubview(oChu)
        addSubview(goiY)
        oChu.inputAccessoryView = ThanhPhimMa(oChu: oChu)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        cot.frame = CGRect(x: 0, y: 0, width: Self.rongCot, height: bounds.height)
        oChu.frame = CGRect(x: Self.rongCot, y: 0, width: bounds.width - Self.rongCot, height: bounds.height)
        goiY.frame = CGRect(x: Self.rongCot + 11, y: 12, width: bounds.width - Self.rongCot - 20, height: 20)
        cot.setNeedsDisplay()
        khiDoi?()
    }

    func chieuCaoCan(rong: CGFloat? = nil) -> CGFloat {
        let w = (rong ?? bounds.width) - Self.rongCot
        guard w > 0 else { return 220 }
        return oChu.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height
    }

    func veLai() {
        cot.setNeedsDisplay()
        invalidateIntrinsicContentSize()
        khiDoi?()
    }
}

/// Vẽ số dòng LOGIC (theo dấu xuống dòng), canh theo dòng hiển thị đầu tiên
/// của mỗi dòng logic.
final class CotSoDong: UIView {
    weak var oChu: UITextView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let t = oChu else { return }
        let lm = t.layoutManager
        let ns = t.text as NSString
        let font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let kieu: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.tertiaryLabel]
        let tren = t.textContainerInset.top
        var so = 1
        var viTri = 0
        func ve(_ y: CGFloat, _ h: CGFloat) {
            let s = "\(so)" as NSString
            let co = s.size(withAttributes: kieu)
            s.draw(at: CGPoint(x: bounds.width - co.width - 6, y: tren + y + (h - co.height) / 2), withAttributes: kieu)
        }
        lm.ensureLayout(for: t.textContainer)
        if ns.length == 0 {
            ve(0, t.font?.lineHeight ?? 16)
            return
        }
        while viTri < ns.length {
            let dong = ns.lineRange(for: NSRange(location: viTri, length: 0))
            let g = lm.glyphRange(forCharacterRange: NSRange(location: dong.location, length: max(1, min(1, dong.length))),
                                  actualCharacterRange: nil)
            let r = lm.lineFragmentRect(forGlyphAt: g.location, effectiveRange: nil)
            ve(r.minY, r.height)
            so += 1
            viTri = NSMaxRange(dong)
        }
        // Dòng trống cuối (văn bản kết thúc bằng "\n").
        if ns.hasSuffix("\n") {
            let r = lm.extraLineFragmentRect
            ve(r.minY, r.height > 0 ? r.height : (t.font?.lineHeight ?? 16))
        }
        // Vạch ngăn mảnh giữa cột số và mã.
        UIColor.separator.setFill()
        UIRectFill(CGRect(x: bounds.width - 0.5, y: 0, width: 0.5, height: bounds.height))
    }
}

/// Hàng phím ký hiệu trên bàn phím — gõ `{ } ( ) ;` trên iPhone phải đổi
/// bàn phím hai lần cho MỖI ký tự.
final class ThanhPhimMa: UIInputView {
    private weak var oChu: UITextView?
    private static let phim = ["⇥", "{", "}", "(", ")", "[", "]", ";", "=", "<", ">", "\"", "'", "/", "*", "+", "-", "&", "|", "!", "%", "#", "_", ":", ","]

    init(oChu: UITextView) {
        self.oChu = oChu
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 44), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        let cuon = UIScrollView()
        cuon.showsHorizontalScrollIndicator = false
        cuon.translatesAutoresizingMaskIntoConstraints = false
        let hang = UIStackView()
        hang.axis = .horizontal
        hang.spacing = 6
        hang.translatesAutoresizingMaskIntoConstraints = false
        for p in Self.phim {
            var cauHinh = UIButton.Configuration.gray()
            cauHinh.title = p
            cauHinh.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 11, bottom: 6, trailing: 11)
            cauHinh.attributedTitle = AttributedString(p, attributes: AttributeContainer(
                [.font: UIFont.monospacedSystemFont(ofSize: 16, weight: .medium)]))
            let b = UIButton(configuration: cauHinh, primaryAction: UIAction { [weak self] _ in
                self?.go(p)
            })
            b.accessibilityLabel = p == "⇥" ? "Thụt lề" : p
            hang.addArrangedSubview(b)
        }
        var anCH = UIButton.Configuration.plain()
        anCH.image = UIImage(systemName: "keyboard.chevron.compact.down")
        let an = UIButton(configuration: anCH, primaryAction: UIAction { [weak oChu] _ in
            oChu?.resignFirstResponder()
        })
        an.accessibilityLabel = "Ẩn bàn phím"
        an.translatesAutoresizingMaskIntoConstraints = false
        cuon.addSubview(hang)
        addSubview(cuon)
        addSubview(an)
        NSLayoutConstraint.activate([
            an.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            an.centerYAnchor.constraint(equalTo: centerYAnchor),
            cuon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            cuon.trailingAnchor.constraint(equalTo: an.leadingAnchor, constant: -4),
            cuon.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            cuon.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            hang.leadingAnchor.constraint(equalTo: cuon.contentLayoutGuide.leadingAnchor),
            hang.trailingAnchor.constraint(equalTo: cuon.contentLayoutGuide.trailingAnchor),
            hang.topAnchor.constraint(equalTo: cuon.contentLayoutGuide.topAnchor),
            hang.bottomAnchor.constraint(equalTo: cuon.contentLayoutGuide.bottomAnchor),
            hang.heightAnchor.constraint(equalTo: cuon.frameLayoutGuide.heightAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    private func go(_ p: String) {
        guard let t = oChu else { return }
        UIDevice.current.playInputClick()
        t.insertText(p == "⇥" ? "    " : p)
        t.delegate?.textViewDidChange?(t)
    }
}

extension ThanhPhimMa: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
#endif
