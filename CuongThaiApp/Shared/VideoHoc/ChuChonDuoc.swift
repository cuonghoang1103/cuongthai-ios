#if os(iOS)
import SwiftUI
import UIKit

// ════════════════════════════════════════════════════════════════
// CHỮ CHỌN ĐƯỢC — bôi bằng Apple Pencil hoặc ngón tay, rồi chọn việc
//
// SwiftUI `Text` không cho chọn một PHẦN chữ và không cho gắn việc riêng vào
// menu chọn. Nên bọc `UITextView` (không sửa được, chọn được) và tự dựng
// menu bằng `UIEditMenuInteraction`.
//
// ⚠️ Cử chỉ vuốt của Apple Pencil trong một `ScrollView` mặc định là CUỘN,
// không phải bôi chọn. Nên gắn hẳn một `UIPanGestureRecognizer` chỉ nhận
// `.pencil` để bôi — ngón tay vẫn cuộn như thường, hai đường không giẫm nhau.
// ════════════════════════════════════════════════════════════════

enum ViecTrenChu: Hashable {
    case traNghia, hoiAI, luuSoTay, dichCau, lapDoan, docTo
}

struct ChuChonDuoc: UIViewRepresentable {
    let chu: String
    var coChu: UIFont
    var mauChu: UIColor
    /// Chạm một cái (không bôi) — dùng để tua tới câu này.
    var cham: () -> Void
    /// Người dùng chọn một việc trên đoạn chữ đã bôi.
    var lam: (String, ViecTrenChu) -> Void

    func makeUIView(context: Context) -> UITextView {
        let v = ChuView()
        v.isEditable = false
        v.isSelectable = true
        v.isScrollEnabled = false            // để nó tự khai chiều cao
        v.backgroundColor = .clear
        // Vệt bôi rõ để người dùng thấy NGAY mình vừa lấy đúng chữ nào.
        v.tintColor = UIColor(red: 0.48, green: 0.27, blue: 0.91, alpha: 1)
        v.textContainerInset = .zero
        v.textContainer.lineFragmentPadding = 0
        v.delegate = context.coordinator
        v.setContentCompressionResistancePriority(.required, for: .vertical)
        v.setContentHuggingPriority(.required, for: .vertical)

        let menu = UIEditMenuInteraction(delegate: context.coordinator)
        v.addInteraction(menu)
        context.coordinator.menu = menu
        context.coordinator.oChu = v
        context.coordinator.gan(vao: v)

        let boi = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.boiBangBut(_:)))
        boi.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        v.addGestureRecognizer(boi)

        // Chạm bằng BÚT = chọn đúng từ dưới đầu bút. Chạm bằng NGÓN = tua.
        // Hai cử chỉ riêng, lọc theo loại chạm, nên không giẫm lên nhau.
        let chamBut = UITapGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.chamBut(_:)))
        chamBut.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        v.addGestureRecognizer(chamBut)

        let go = UITapGestureRecognizer(target: context.coordinator,
                                        action: #selector(Coordinator.chamMot))
        go.numberOfTapsRequired = 1
        go.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        v.addGestureRecognizer(go)

        // Chạm HAI lần bằng bút = lấy trọn CÂU.
        let haiCham = UITapGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.chamHaiLan(_:)))
        haiCham.numberOfTapsRequired = 2
        haiCham.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        v.addGestureRecognizer(haiCham)
        chamBut.require(toFail: haiCham)

        return v
    }

    func updateUIView(_ v: UITextView, context: Context) {
        context.coordinator.cha = self
        // Chỉ gán lại khi ĐỔI: gán `attributedText` mỗi lần update sẽ xoá
        // vùng đang bôi, người dùng chưa kịp bấm menu đã mất vệt chọn.
        if v.text != chu || v.font != coChu || v.textColor != mauChu {
            v.attributedText = NSAttributedString(string: chu, attributes: [
                .font: coChu, .foregroundColor: mauChu,
            ])
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(cha: self) }

    /// `UITextView` trong SwiftUI cần khai chiều rộng sẵn có, không thì nó
    /// tự giãn ra một dòng dài vô tận.
    final class ChuView: UITextView {
        override var intrinsicContentSize: CGSize {
            let w = bounds.width > 0 ? bounds.width : UIView.noIntrinsicMetric
            guard w != UIView.noIntrinsicMetric else { return super.intrinsicContentSize }
            let h = sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height
            return CGSize(width: UIView.noIntrinsicMetric, height: ceil(h))
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            invalidateIntrinsicContentSize()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIEditMenuInteractionDelegate {
        var cha: ChuChonDuoc
        weak var oChu: UITextView?
        var menu: UIEditMenuInteraction?
        private var dauBoi: UITextPosition?

        /// Nét mực đang vẽ. Vẽ THẬT theo đầu bút, không phải hiệu ứng trang
        /// trí: người dùng cần thấy mình vừa quệt trúng chữ nào TRƯỚC khi
        /// menu hiện ra, giống như tô bút dạ lên giấy.
        private var diemNet: [CGPoint] = []
        private lazy var lopMuc: CAShapeLayer = {
            let l = CAShapeLayer()
            l.fillColor = nil
            l.lineWidth = 20
            l.lineCap = .round
            l.lineJoin = .round
            l.strokeColor = UIColor(red: 0.48, green: 0.27, blue: 0.91, alpha: 0.30).cgColor
            return l
        }()
        private var hienMenuSau: DispatchWorkItem?

        func gan(vao v: UITextView) {
            if lopMuc.superlayer == nil { v.layer.addSublayer(lopMuc) }
            lopMuc.frame = v.bounds
            lopMuc.masksToBounds = false
        }

        private func veNet() {
            // Đồng bộ khung mỗi lần vẽ: `CAShapeLayer` con mặc định có
            // bounds bằng 0, và nếu khung lệch thì nét mực vẽ ra một nơi
            // trong khi đầu bút đi một nẻo — lỗi trông như "bút không
            // chính xác" mà thật ra là toạ độ.
            if let v = oChu { lopMuc.frame = v.bounds }
            guard diemNet.count > 1 else { lopMuc.path = nil; return }
            let d = UIBezierPath()
            d.move(to: diemNet[0])
            for p in diemNet.dropFirst() { d.addLine(to: p) }
            lopMuc.removeAllAnimations()
            lopMuc.opacity = 1
            lopMuc.path = d.cgPath
        }

        /// Mực tan dần rồi biến mất — để người dùng kịp thấy nó trùng với
        /// vùng chữ vừa được chọn, rồi nhường chỗ cho vệt chọn của hệ thống.
        private func xoaMuc(ngay: Bool = false) {
            hienMenuSau?.cancel()
            if ngay { lopMuc.path = nil; return }
            let mo = CABasicAnimation(keyPath: "opacity")
            mo.fromValue = 1; mo.toValue = 0; mo.duration = 0.45
            mo.fillMode = .forwards; mo.isRemovedOnCompletion = false
            lopMuc.add(mo, forKey: "tan")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.lopMuc.path = nil
            }
        }

        init(cha: ChuChonDuoc) { self.cha = cha }

        @objc func chamMot() {
            guard let v = oChu else { return }
            // Chạm khi ĐANG bôi = bỏ chọn, không tua. Tua lúc đó thì người
            // dùng vừa bôi xong chạm hụt là video nhảy đi mất.
            if let r = v.selectedTextRange, !r.isEmpty {
                v.selectedTextRange = nil
                xoaMuc(ngay: true)
                diemNet = []
                return
            }
            cha.cham()
        }

        /// Nới một vị trí ra mép TỪ gần nhất.
        ///
        /// ⚠️ Đây là chỗ quyết định cảm giác dùng bút. Chọn theo từng KÝ TỰ
        /// thì lệch một milimét là cắt giữa từ ("commun|ication"), và người
        /// dùng phải dí bút kéo qua lại để canh — đúng lời than 20/09/2026.
        /// Bám theo từ thì tô trúng bất cứ đâu trong từ là lấy trọn từ đó.
        private func mepTu(_ v: UITextView, _ vt: UITextPosition,
                           veSau: Bool) -> UITextPosition {
            let huong: UITextDirection = veSau ? .storage(.forward) : .storage(.backward)
            if let r = v.tokenizer.rangeEnclosingPosition(vt, with: .word, inDirection: huong) {
                return veSau ? r.end : r.start
            }
            // Đầu bút rơi vào khoảng trắng: thử nhìn sang phía bên kia, vì
            // giữa hai từ thì "từ gần nhất" nằm ở hướng ngược lại.
            let nguoc: UITextDirection = veSau ? .storage(.backward) : .storage(.forward)
            if let r = v.tokenizer.rangeEnclosingPosition(vt, with: .word, inDirection: nguoc) {
                return veSau ? r.end : r.start
            }
            return vt
        }

        /// Vùng chứa trọn các TỪ mà nét bút đi qua.
        private func vungTheoTu(_ v: UITextView, tu a: UITextPosition,
                                den b: UITextPosition) -> UITextRange? {
            // Kéo ngược từ phải sang trái vẫn phải ra vùng đúng chiều.
            let xuoi = v.compare(a, to: b) != .orderedDescending
            let dau = mepTu(v, xuoi ? a : b, veSau: false)
            let cuoi = mepTu(v, xuoi ? b : a, veSau: true)
            return v.textRange(from: dau, to: cuoi)
        }

        private func hienMenu(_ v: UITextView, tai p: CGPoint) {
            guard let r = v.selectedTextRange, !r.isEmpty else { return }
            v.becomeFirstResponder()
            menu?.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: p))
        }

        @objc func chamBut(_ g: UITapGestureRecognizer) {
            guard let v = oChu else { return }
            let p = g.location(in: v)
            guard let vt = v.closestPosition(to: p) else { return }
            v.selectedTextRange = vungTheoTu(v, tu: vt, den: vt)
            hienMenu(v, tai: p)
        }

        /// Chạm hai lần = lấy trọn CÂU quanh điểm chạm.
        @objc func chamHaiLan(_ g: UITapGestureRecognizer) {
            guard let v = oChu, let chu = v.text else { return }
            let p = g.location(in: v)
            guard let vt = v.closestPosition(to: p) else { return }
            let i = v.offset(from: v.beginningOfDocument, to: vt)
            guard let idx = Range(NSRange(location: i, length: 0), in: chu)?.lowerBound
            else { return }

            // Tìm mép câu bằng dấu kết câu. `.sentence` của tokenizer hay
            // trượt qua dấu chấm trong "Node.js" hay "3.7"; tự dò thì đoán
            // được bằng mắt và sửa được khi sai.
            var dau = chu.startIndex
            var j = idx
            while j > chu.startIndex {
                let t = chu.index(before: j)
                if ".?!".contains(chu[t]) { dau = chu.index(after: t); break }
                j = t
            }
            var cuoi = chu.endIndex
            var k = idx
            while k < chu.endIndex {
                if ".?!".contains(chu[k]) { cuoi = chu.index(after: k); break }
                k = chu.index(after: k)
            }
            let ns = NSRange(dau..<cuoi, in: chu)
            guard let a = v.position(from: v.beginningOfDocument, offset: ns.location),
                  let b = v.position(from: a, offset: ns.length),
                  let r = v.textRange(from: a, to: b) else { return }
            v.selectedTextRange = r
            hienMenu(v, tai: p)
        }

        /// Vùng chữ mà CẢ NÉT BÚT đi qua.
        ///
        /// Lấy theo từng điểm của nét chứ không chỉ điểm đầu và điểm cuối:
        /// quệt cong, quệt ngược, quệt vắt qua hai dòng đều ra đúng phần
        /// mình vừa tô. Chỉ lấy đầu–cuối thì một nét cong lên rồi xuống sẽ
        /// chọn hụt phần giữa.
        private func vungTheoNet(_ v: UITextView) -> UITextRange? {
            var nhoNhat = Int.max, lonNhat = -1
            for p in diemNet {
                guard let vt = v.closestPosition(to: p) else { continue }
                let o = v.offset(from: v.beginningOfDocument, to: vt)
                nhoNhat = min(nhoNhat, o); lonNhat = max(lonNhat, o)
            }
            guard lonNhat >= 0, nhoNhat <= lonNhat,
                  let a = v.position(from: v.beginningOfDocument, offset: nhoNhat),
                  let b = v.position(from: v.beginningOfDocument, offset: lonNhat)
            else { return nil }
            return vungTheoTu(v, tu: a, den: b)
        }

        @objc func boiBangBut(_ g: UIPanGestureRecognizer) {
            guard let v = oChu else { return }
            let p = g.location(in: v)
            switch g.state {
            case .began:
                hienMenuSau?.cancel()
                v.selectedTextRange = nil
                diemNet = [p]
                dauBoi = v.closestPosition(to: p)
                lopMuc.opacity = 1
                lopMuc.path = nil
            case .changed:
                // Bỏ điểm quá sát nhau: nét mượt hơn và đỡ hàng trăm điểm
                // thừa cho bước dò chữ ở dưới.
                if let cuoi = diemNet.last, hypot(p.x - cuoi.x, p.y - cuoi.y) < 2 { return }
                diemNet.append(p)
                veNet()
            case .ended, .cancelled:
                // Nét quá ngắn = người dùng định CHẠM chứ không định kéo.
                // Vẫn phải ra một từ, không thì bút "bấm hụt" không làm gì.
                let vung = diemNet.count > 2 ? vungTheoNet(v)
                    : dauBoi.flatMap { vungTheoTu(v, tu: $0, den: $0) }
                guard let r = vung, !r.isEmpty else { xoaMuc(ngay: true); return }
                v.selectedTextRange = r

                // Đợi một nhịp rồi mới hiện tuỳ chọn: nhấc bút lên là menu
                // bật ngay thì nó che mất đúng chỗ vừa tô, và người dùng
                // chưa kịp thấy mình tô trúng gì.
                let viec = DispatchWorkItem { [weak self, weak v] in
                    guard let self, let v else { return }
                    self.xoaMuc()
                    self.hienMenu(v, tai: p)
                }
                hienMenuSau = viec
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: viec)
            default: break
            }
        }

        private var chuDaChon: String {
            guard let v = oChu, let r = v.selectedTextRange else { return "" }
            return (v.text(in: r) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private func cacViec() -> [UIMenuElement] {
            let s = chuDaChon
            guard !s.isEmpty else { return [] }
            let mot = s.split(whereSeparator: { !$0.isLetter && $0 != "'" }).count
            var ra: [UIMenuElement] = []
            // Một từ thì "tra nghĩa" là việc hay làm nhất; cả câu thì "dịch".
            if mot <= 3 {
                ra.append(UIAction(title: "Tra nghĩa",
                                   image: UIImage(systemName: "character.book.closed")) { _ in
                    self.cha.lam(s, .traNghia) })
            } else {
                ra.append(UIAction(title: "Dịch đoạn này",
                                   image: UIImage(systemName: "translate")) { _ in
                    self.cha.lam(s, .dichCau) })
            }
            ra.append(UIAction(title: "Hỏi AI", image: UIImage(systemName: "sparkles")) { _ in
                self.cha.lam(s, .hoiAI) })
            ra.append(UIAction(title: "Lưu vào sổ tay",
                               image: UIImage(systemName: "bookmark")) { _ in
                self.cha.lam(s, .luuSoTay) })
            ra.append(UIAction(title: "Đọc to", image: UIImage(systemName: "speaker.wave.2")) { _ in
                self.cha.lam(s, .docTo) })
            ra.append(UIAction(title: "Lặp đoạn này",
                               image: UIImage(systemName: "repeat.1")) { _ in
                self.cha.lam(s, .lapDoan) })
            return ra
        }

        // Menu khi chọn bằng NGÓN TAY (UITextView tự dựng menu của nó).
        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange,
                      suggestedActions: [UIMenuElement]) -> UIMenu? {
            UIMenu(children: cacViec() + suggestedActions)
        }

        /// Menu tắt (chạm ra chỗ khác, hoặc chọn xong một việc) thì BỎ LUÔN
        /// vệt chọn và nét mực. Không bỏ thì vệt tím nằm lại trên màn hình
        /// sau khi menu đã biến mất — trông như app còn đang chọn dở.
        func editMenuInteraction(_ i: UIEditMenuInteraction,
                                 willDismissMenuFor c: UIEditMenuConfiguration,
                                 animator: UIEditMenuInteractionAnimating) {
            animator.addCompletion { [weak self] in
                self?.oChu?.selectedTextRange = nil
                self?.xoaMuc(ngay: true)
                self?.diemNet = []
            }
        }

        // Menu khi bôi bằng BÚT (ta tự trình bày).
        func editMenuInteraction(_ i: UIEditMenuInteraction,
                                 menuFor c: UIEditMenuConfiguration,
                                 suggestedActions: [UIMenuElement]) -> UIMenu? {
            UIMenu(children: cacViec() + suggestedActions)
        }
    }
}
#endif
