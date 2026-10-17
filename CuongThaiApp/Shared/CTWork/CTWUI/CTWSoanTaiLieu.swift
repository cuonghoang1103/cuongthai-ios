import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - CTWUI — TRÌNH SOẠN tài liệu (markdown) có thanh định dạng
//
// Vì sao không dùng `TextEditor`: iOS 17 không cho SwiftUI biết con trỏ đang ở
// đâu ⇒ không chèn được "## " vào ĐẦU DÒNG đang gõ, không bọc được chữ đang
// chọn. Ở đây bọc `UITextView` và để một `CTWBoSoan` giữ tham chiếu tới nó:
// thanh định dạng gọi `boSoan.boc("**", "**")`, `boSoan.dauDong("- [ ] ")`…
//
// Kết quả là MARKDOWN thô (đúng cú pháp `CTWMarkdown.khoi` dựng lại được) —
// mô-đun tự đổi sang định dạng máy chủ cần (Docs: TipTap JSON).

@MainActor
final class CTWBoSoan: ObservableObject {
    #if os(iOS)
    fileprivate weak var tv: UITextView?
    #endif
    /// Đổi mỗi lần chữ đổi do thanh định dạng — để màn cha biết "đã sửa".
    @Published var lanDoi = 0
    fileprivate var capNhat: ((String) -> Void)?

    /// Chèn chuỗi tại con trỏ (thay vùng đang chọn).
    func chen(_ s: String) {
        #if os(iOS)
        guard let tv else { return }
        tv.becomeFirstResponder()
        let r = tv.selectedRange
        let ns = (tv.text ?? "") as NSString
        tv.text = ns.replacingCharacters(in: r, with: s)
        tv.selectedRange = NSRange(location: r.location + (s as NSString).length, length: 0)
        xong()
        #endif
    }

    /// Chèn một KHỐI (ảnh, khối mã…) trên dòng riêng.
    func chenKhoi(_ s: String) {
        #if os(iOS)
        guard let tv else { return }
        let ns = (tv.text ?? "") as NSString
        let r = tv.selectedRange
        let truoc = r.location > 0 ? ns.substring(with: NSRange(location: r.location - 1, length: 1)) : "\n"
        chen((truoc == "\n" ? "" : "\n") + s + "\n")
        #endif
    }

    /// Bọc vùng chọn bằng `trai`…`phai`; không chọn gì ⇒ chèn `goiY` và chọn nó để gõ đè.
    func boc(_ trai: String, _ phai: String, goiY: String = "text") {
        #if os(iOS)
        guard let tv else { return }
        tv.becomeFirstResponder()
        let r = tv.selectedRange
        let ns = (tv.text ?? "") as NSString
        let giua = r.length > 0 ? ns.substring(with: r) : goiY
        tv.text = ns.replacingCharacters(in: r, with: trai + giua + phai)
        tv.selectedRange = NSRange(location: r.location + (trai as NSString).length, length: (giua as NSString).length)
        xong()
        #endif
    }

    /// Bật/tắt tiền tố ở ĐẦU mọi dòng của vùng chọn ("## ", "- ", "1. ", "- [ ] ", "> ").
    /// Dòng đã có một tiền tố khối khác ⇒ thay bằng tiền tố mới (đổi H2 → H3 trong một chạm).
    func dauDong(_ tienTo: String) {
        #if os(iOS)
        guard let tv else { return }
        tv.becomeFirstResponder()
        let ns = (tv.text ?? "") as NSString
        let vung = ns.lineRange(for: tv.selectedRange)
        let dong = ns.substring(with: vung)
        var cacDong = dong.components(separatedBy: "\n")
        let duoiTrong = cacDong.last == "" && cacDong.count > 1
        if duoiTrong { cacDong.removeLast() }
        let tatCaCo = cacDong.allSatisfy { $0.hasPrefix(tienTo) }
        let moi = cacDong.map { d -> String in
            if tatCaCo { return String(d.dropFirst(tienTo.count)) }
            return tienTo + CTWBoSoan.boTienToKhoi(d)
        }.joined(separator: "\n") + (duoiTrong ? "\n" : "")
        tv.text = ns.replacingCharacters(in: vung, with: moi)
        let cuoi = vung.location + (moi as NSString).length - (duoiTrong ? 1 : 0)
        tv.selectedRange = NSRange(location: max(vung.location, cuoi), length: 0)
        xong()
        #endif
    }

    nonisolated static func boTienToKhoi(_ d: String) -> String {
        for t in ["- [ ] ", "- [x] ", "- [X] ", "###### ", "##### ", "#### ", "### ", "## ", "# ", "> ", "- ", "* "] where d.hasPrefix(t) {
            return String(d.dropFirst(t.count))
        }
        if let cham = d.firstIndex(of: "."), !d[..<cham].isEmpty, d[..<cham].allSatisfy(\.isNumber),
           d[d.index(after: cham)...].hasPrefix(" ") {
            return String(d[d.index(cham, offsetBy: 2)...])
        }
        return d
    }

    func anBanPhim() {
        #if os(iOS)
        tv?.resignFirstResponder()
        #endif
    }

    private func xong() {
        #if os(iOS)
        capNhat?(tv?.text ?? "")
        lanDoi += 1
        #endif
    }
}

#if os(iOS)
/// Ô soạn nhiều dòng. Gõ Enter trong danh sách ⇒ tự thêm gạch đầu dòng/ô việc
/// tiếp theo (như Notes của Apple); Enter trên dòng danh sách trống ⇒ thoát danh sách.
struct CTWOSoanTaiLieu: UIViewRepresentable {
    @Binding var chu: String
    @ObservedObject var boSoan: CTWBoSoan
    var coChu: CGFloat = 16
    var chiDoc = false

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: coChu))
        tv.adjustsFontForContentSizeCategory = true
        tv.backgroundColor = .clear
        tv.textColor = UIColor(AppColors.textPrimary)
        tv.tintColor = UIColor(AppColors.primary)
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 24, right: 12)
        tv.autocapitalizationType = .sentences
        tv.smartDashesType = .no        // "---" phải giữ nguyên là đường kẻ markdown
        tv.smartQuotesType = .no        // dấu nháy cong làm hỏng `code` và liên kết
        tv.keyboardDismissMode = .interactive
        tv.alwaysBounceVertical = true
        tv.delegate = context.coordinator
        tv.text = chu
        tv.isEditable = !chiDoc
        tv.accessibilityLabel = "Page content (Markdown)"
        boSoan.tv = tv
        boSoan.capNhat = { s in context.coordinator.dayRa(s) }
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.cha = self
        if tv.text != chu { tv.text = chu }
        tv.isEditable = !chiDoc
    }

    func makeCoordinator() -> DieuPhoi { DieuPhoi(self) }

    final class DieuPhoi: NSObject, UITextViewDelegate {
        var cha: CTWOSoanTaiLieu
        init(_ cha: CTWOSoanTaiLieu) { self.cha = cha }

        func dayRa(_ s: String) {
            if cha.chu != s { cha.chu = s }
        }

        func textViewDidChange(_ tv: UITextView) { dayRa(tv.text ?? "") }

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n", range.length == 0 else { return true }
            let ns = (tv.text ?? "") as NSString
            let dong = ns.substring(with: ns.lineRange(for: NSRange(location: range.location, length: 0)))
                .trimmingCharacters(in: .newlines)
            let thut = String(dong.prefix { $0 == " " })
            let gon = dong.trimmingCharacters(in: .whitespaces)
            var tiep: String?
            if gon.hasPrefix("- [ ] ") || gon.hasPrefix("- [x] ") || gon.hasPrefix("- [X] ") { tiep = "- [ ] " }
            else if gon.hasPrefix("- ") { tiep = "- " }
            else if gon.hasPrefix("* ") { tiep = "* " }
            else if let cham = gon.firstIndex(of: "."), !gon[..<cham].isEmpty, gon[..<cham].allSatisfy(\.isNumber),
                    gon[gon.index(after: cham)...].hasPrefix(" "), let n = Int(gon[..<cham]) { tiep = "\(n + 1). " }
            guard let tiep else { return true }
            let noiDung = CTWBoSoan.boTienToKhoi(gon)
            if noiDung.trimmingCharacters(in: .whitespaces).isEmpty {
                // Dòng danh sách trống ⇒ xoá gạch đầu dòng, thoát danh sách.
                let vung = ns.lineRange(for: NSRange(location: range.location, length: 0))
                let coXuong = ns.substring(with: vung).hasSuffix("\n")
                tv.text = ns.replacingCharacters(in: vung, with: coXuong ? "\n" : "")
                tv.selectedRange = NSRange(location: vung.location, length: 0)
            } else {
                let s = "\n" + thut + tiep
                tv.text = ns.replacingCharacters(in: range, with: s)
                tv.selectedRange = NSRange(location: range.location + (s as NSString).length, length: 0)
            }
            dayRa(tv.text ?? "")
            return false
        }
    }
}
#endif

/// Thanh định dạng cuộn ngang đặt sát trên bàn phím / cuối màn soạn.
struct CTWThanhDinhDang: View {
    @ObservedObject var boSoan: CTWBoSoan
    var chenAnh: (() -> Void)?
    var chenThe: (() -> Void)?
    var chenLienKet: (() -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                Menu {
                    Button("Heading 1") { boSoan.dauDong("# ") }
                    Button("Heading 2") { boSoan.dauDong("## ") }
                    Button("Heading 3") { boSoan.dauDong("### ") }
                } label: { o("textformat.size", "Heading") }
                nut("bold", "Bold") { boSoan.boc("**", "**") }
                nut("italic", "Italic") { boSoan.boc("_", "_") }
                nut("strikethrough", "Strikethrough") { boSoan.boc("~~", "~~") }
                nut("chevron.left.forwardslash.chevron.right", "Inline code") { boSoan.boc("`", "`", goiY: "code") }
                vach
                nut("list.bullet", "Bulleted list") { boSoan.dauDong("- ") }
                nut("list.number", "Numbered list") { boSoan.dauDong("1. ") }
                nut("checklist", "Checklist") { boSoan.dauDong("- [ ] ") }
                nut("text.quote", "Quote") { boSoan.dauDong("> ") }
                nut("curlybraces", "Code block") { boSoan.chenKhoi("```\ncode\n```") }
                nut("minus", "Divider") { boSoan.chenKhoi("---") }
                vach
                if let chenLienKet { nut("link", "Link", chenLienKet) }
                if let chenThe { nut("number.square", "Link an issue", chenThe) }
                if let chenAnh { nut("photo.on.rectangle", "Insert image", chenAnh) }
                nut("keyboard.chevron.compact.down", "Hide keyboard") { boSoan.anBanPhim() }
            }
            .padding(.horizontal, 8)
            .foregroundColor(AppColors.textPrimary)
        }
        .frame(height: 46)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var vach: some View { Divider().frame(height: 22).padding(.horizontal, 4) }

    private func o(_ icon: String, _ ten: String) -> some View {
        Image(systemName: icon).font(.system(size: 16, weight: .medium))
            .frame(width: 42, height: 44).contentShape(Rectangle())
            .accessibilityLabel(ten)
    }

    private func nut(_ icon: String, _ ten: String, _ lam: @escaping () -> Void) -> some View {
        Button { CTWRung.chon(); lam() } label: { o(icon, ten) }
            .buttonStyle(.plain)
    }
}
