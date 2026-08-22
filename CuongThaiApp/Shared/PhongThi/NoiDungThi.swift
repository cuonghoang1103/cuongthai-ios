import SwiftUI
#if os(iOS)
import WebKit
#endif

// MARK: - Tách nội dung song ngữ
//
// Máy chủ ghép hai thứ tiếng vào MỘT chuỗi, ngăn bằng `|||`:
// "Which feature…?|||Đặc điểm phê phán nào…?" — đúng cách web làm (`pickLang`
// trong `frontend/src/lib/utils.ts`).
//
// ⚠️ 23/08/2026 người dùng gửi ảnh: đề thi hiện NGUYÊN cả hai thứ tiếng dính
// nhau kèm ba gạch đứng giữa câu. App mới tách cho TÊN ĐỀ (`DeThi.tach`), còn
// đề bài và đáp án thì chưa — mà đó mới là chỗ người ta đọc.

/// Ngôn ngữ đang xem của đề thi.
///
/// ⚠️ Mặc định là **TIẾNG ANH**, đúng như web (`useState<'en'|'vi'>('en')`
/// ở cả ba màn thi, kèm ghi chú "exams default to English"). Đề gốc là tiếng
/// Anh; bản tiếng Việt là bản dịch kèm theo, người thi bật khi cần.
enum NgonNguDe: String {
    case anh = "en", viet = "vi"

    /// Nhãn nút: hiện ngôn ngữ SẮP chuyển sang, không phải ngôn ngữ hiện tại —
    /// giống hệt web.
    var nhanNut: String { self == .viet ? "EN" : "VI" }
    var doiSang: NgonNguDe { self == .viet ? .anh : .viet }
}

private struct KhoaNgonNguDe: EnvironmentKey {
    static let defaultValue: NgonNguDe = .anh
}

extension EnvironmentValues {
    /// Cả màn hình dùng CHUNG một giá trị: bấm một nút là đề bài, đáp án và
    /// lời giải đổi cùng lúc.
    var ngonNguDe: NgonNguDe {
        get { self[KhoaNgonNguDe.self] }
        set { self[KhoaNgonNguDe.self] = newValue }
    }
}

extension String {
    /// Lấy đúng nửa theo ngôn ngữ; nửa đó rỗng thì lấy nửa còn lại; không có
    /// `|||` thì giữ nguyên (đề đơn ngữ vẫn hiện bình thường). Cùng quy tắc
    /// với `pickLang` của web.
    func tachSongNgu(_ ngonNgu: NgonNguDe = .anh) -> String {
        guard let r = range(of: "|||") else { return self }
        let en = String(self[startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let vi = String(self[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return ngonNgu == .viet ? (vi.isEmpty ? en : vi) : (en.isEmpty ? vi : en)
    }

    /// Xuống dòng trước mỗi mục đánh số La Mã `(i) (ii) (iii)…`.
    ///
    /// Đề FPTU liệt kê các lựa chọn NGAY TRONG một dòng đề bài
    /// ("(i) … (ii) … (iii) …"), đọc rất tức mắt. Cổng đúng ba chỗ:
    ///
    /// 1. **Bỏ qua đoạn công thức.** `(x)` trong `$f(x)$` hay `(i)` là đơn vị
    ///    ảo mà bị chèn `<br>` vào giữa là KaTeX vỡ luôn cả công thức.
    /// 2. **Phải có từ HAI mục trở lên.** Một chữ "(i)" lẻ trong câu văn xuôi
    ///    thì để yên.
    /// 3. **Mục dài đứng trước** trong biểu thức, không thì "(iv)" bị "(i)"
    ///    khớp mất một nửa.
    ///
    /// Chỉ dùng cho ĐỀ BÀI, không dùng cho đáp án.
    var xuongDongMucLaMa: String {
        // Chuỗi THÔ `#"…"#`: biểu thức chính quy đầy dấu chéo, viết kiểu
        // chuỗi thường thì mỗi dấu phải nhân đôi, và sai một cái là Swift
        // báo "invalid escape sequence" — đúng thứ vừa xảy ra.
        let doanCongThuc = #"(\$\$[\s\S]*?\$\$|\$[^$]*?\$|\\\([\s\S]*?\\\)|\\\[[\s\S]*?\\\])"#
        let mucLaMa = #"\s*(?:<br\s*/?>)?\s*\((viii|vii|iii|ii|iv|ix|vi|xi|x|v|i)\)"#

        guard let reDoan = try? NSRegularExpression(pattern: doanCongThuc),
              let reMuc = try? NSRegularExpression(pattern: mucLaMa, options: .caseInsensitive)
        else { return self }

        let ns = self as NSString
        // Cắt chuỗi thành các mảnh: mảnh nào là công thức thì KHÔNG đụng tới.
        var manh: [(String, Bool)] = []
        var viTri = 0
        for m in reDoan.matches(in: self, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > viTri {
                manh.append((ns.substring(with: NSRange(location: viTri, length: m.range.location - viTri)), false))
            }
            manh.append((ns.substring(with: m.range), true))
            viTri = m.range.location + m.range.length
        }
        if viTri < ns.length {
            manh.append((ns.substring(from: viTri), false))
        }

        let dem = manh.filter { !$0.1 }.reduce(0) { d, m in
            d + reMuc.numberOfMatches(in: m.0, range: NSRange(location: 0, length: (m.0 as NSString).length))
        }
        guard dem >= 2 else { return self }

        let ra = manh.map { m -> String in
            guard !m.1 else { return m.0 }
            return reMuc.stringByReplacingMatches(
                in: m.0, range: NSRange(location: 0, length: (m.0 as NSString).length),
                withTemplate: "<br>($1)")
        }.joined()
        // Bỏ `<br>` thừa ở ngay đầu.
        return ra.replacingOccurrences(of: #"^(?:\s*<br\s*/?>)+"#, with: "",
                                       options: .regularExpression)
    }

    /// Thoát ký tự để chuỗi CHỮ THUẦN đi qua đường HTML mà không bị hiểu sai.
    ///
    /// ⚠️ Chèn `<br>` vào một đề bài chữ thuần là đẩy nó sang bộ dựng HTML —
    /// và lúc đó `a < b` trong đề sẽ bị nuốt thành một thẻ không tồn tại, mất
    /// luôn phần sau. Thoát trước rồi mới chèn.
    var thoatHTML: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Có cần tới bộ dựng HTML không, hay `Text` thường là đủ.
    ///
    /// Dựng WebView cho MỌI đáp án thì một đề 60 câu × 4 lựa chọn là 240
    /// WebView — máy tụt hẳn. Chỉ những chuỗi thật sự mang thẻ, công thức hay
    /// sơ đồ mới cần.
    var canDungGiau: Bool {
        let s = self
        if s.contains("<") && s.contains(">") { return true }        // thẻ HTML
        if s.contains("$") || s.contains("\\(") || s.contains("\\[") { return true }  // công thức
        if s.lowercased().contains("mermaid") { return true }
        return false
    }
}

#if os(iOS)

// MARK: - Bộ dựng nội dung đề thi

/// Dựng HTML của đề thi cho ĐÚNG như web: công thức KaTeX, sơ đồ mermaid,
/// bảng, ảnh, mã có tô màu.
struct NoiDungThiWeb: UIViewRepresentable {
    let html: String
    @Binding var chieuCao: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let ch = WKWebViewConfiguration()
        ch.userContentController.add(context.coordinator, name: "cao")
        let w = WKWebView(frame: .zero, configuration: ch)
        w.navigationDelegate = context.coordinator
        w.scrollView.isScrollEnabled = false
        w.scrollView.bounces = false
        w.isOpaque = false
        w.backgroundColor = .clear
        w.scrollView.backgroundColor = .clear
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) {
        let toi = w.traitCollection.userInterfaceStyle == .dark
        let khoa = "\(html.hashValue)|\(toi)"
        guard context.coordinator.khoa != khoa else { return }
        context.coordinator.khoa = khoa
        w.loadHTMLString(trang(toi: toi), baseURL: nil)
    }

    func makeCoordinator() -> Dieu { Dieu(self) }

    final class Dieu: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let cha: NoiDungThiWeb
        var khoa: String?
        init(_ c: NoiDungThiWeb) { cha = c }

        func userContentController(_ uc: WKUserContentController, didReceive m: WKScriptMessage) {
            guard m.name == "cao", let h = m.body as? CGFloat, h > 0 else { return }
            Task { @MainActor in if abs(cha.chieuCao - h) > 1 { cha.chieuCao = h } }
        }

        func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if a.navigationType == .linkActivated, let u = a.request.url {
                UIApplication.shared.open(u); decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }
    }

    /// ⚠️ Bỏ mọi khai báo `color`/`background-color` gắn thẳng trong `style`.
    /// Nội dung dán từ Word mang theo màu chữ của NGUỒN (thường gần đen) —
    /// trên nền tối là chữ vô hình. Web cũng làm đúng thế
    /// (`stripInlineColors`), và chỉ bỏ hai thuộc tính đó chứ không bỏ cả
    /// `style`, để `text-align` và lớp tô màu mã còn nguyên.
    private var htmlSach: String {
        html.replacingOccurrences(
            of: "(?i)(?:background-)?color\\s*:\\s*[^;\"']+;?",
            with: "", options: .regularExpression)
    }

    private func trang(toi: Bool) -> String {
        let chuChinh = toi ? "#FFFFFF" : "#14141C"
        let chuPhu = toi ? "#C9C9D4" : "#3A3A44"
        let vien = toi ? "#2A2A38" : "#E2E2EA"
        let nenMa = toi ? "#1E1E1E" : "#F6F8FA"
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.css">
        <style>
          :root{color-scheme:\(toi ? "dark" : "light")}
          html,body{margin:0;padding:0;background:transparent;-webkit-text-size-adjust:100%}
          body{font:16px/1.6 -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;
               color:\(chuChinh);word-wrap:break-word}
          p{margin:0 0 10px} strong,b{font-weight:700}
          ul,ol{margin:0 0 10px;padding-left:22px} li{margin:0 0 5px}
          h1,h2,h3,h4{margin:16px 0 8px;line-height:1.3}
          blockquote{margin:8px 0;padding:6px 12px;border-left:3px solid \(vien);color:\(chuPhu)}
          a{color:#8C5AF0;text-decoration:none}
          hr{border:0;border-top:1px solid \(vien);margin:14px 0}
          img{max-width:100%;height:auto;border-radius:8px;margin:8px 0}

          /* Bảng phải cuộn NGANG được: đề chụp từ giấy hay có bảng rộng hơn
             màn hình, mà co lại thì chữ nhỏ tới mức không đọc nổi. */
          table{border-collapse:collapse;width:auto;max-width:100%;margin:10px 0;
                display:block;overflow-x:auto}
          th,td{border:1px solid \(vien);padding:6px 10px;text-align:left;font-size:14px}
          th{font-weight:700;background:\(toi ? "#1A1A24" : "#F3F3F7")}

          pre{background:\(nenMa);border:1px solid \(vien);border-radius:10px;
              padding:10px 12px;overflow-x:auto;margin:10px 0}
          pre code,code{font:13px/1.5 ui-monospace,Menlo,monospace}
          :not(pre)>code{background:\(nenMa);padding:1px 5px;border-radius:5px}

          /* Bảng màu VS Code Dark+/Light+ cho mã ĐÃ được tô sẵn ở máy chủ
             (lớp .hljs-* / .tok-*) — cùng màu với `ToMauMa` bên Swift để hai
             chỗ không lệch nhau. */
          .hljs-comment,.hljs-quote,.tok-comment{color:\(toi ? "#6A9955" : "#008000")}
          .hljs-string,.hljs-attr,.tok-string{color:\(toi ? "#CE9178" : "#A31515")}
          .hljs-number,.hljs-literal,.tok-number{color:\(toi ? "#B5CEA8" : "#098658")}
          .hljs-keyword,.hljs-selector-tag,.tok-keyword{color:\(toi ? "#569CD6" : "#0000FF")}
          .hljs-type,.hljs-title.class_,.tok-type{color:\(toi ? "#4EC9B0" : "#267F99")}
          .hljs-title,.hljs-function,.tok-function{color:\(toi ? "#DCDCAA" : "#795E26")}

          .katex-display{overflow-x:auto;overflow-y:hidden;padding:4px 0;margin:10px 0}
          .katex{font-size:1.05em}
          .so-do{display:flex;justify-content:center;margin:10px 0}
          .so-do svg{max-width:100%;height:auto}
        </style></head>
        <body><div id="v">\(htmlSach)</div>
        <script>
          const bao = () => window.webkit?.messageHandlers?.cao?.postMessage(document.body.scrollHeight);
          const el = document.getElementById('v');
          (async () => {
            try {
              // Công thức: chỉ nạp KaTeX khi có dấu hiệu, không thì mỗi câu
              // hỏi đều kéo về một thư viện chẳng dùng tới.
              if (/\\$|\\\\\\(|\\\\\\[/.test(el.textContent || '')) {
                const m = await import('https://cdn.jsdelivr.net/npm/katex@0.16/dist/contrib/auto-render.mjs');
                const k = await import('https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.mjs');
                window.katex = k.default;
                m.default(el, { delimiters: [
                  {left:'$$',right:'$$',display:true},
                  {left:'\\\\[',right:'\\\\]',display:true},
                  {left:'\\\\(',right:'\\\\)',display:false},
                  {left:'$',right:'$',display:false}], throwOnError:false });
              }
            } catch (e) {}
            try {
              const kh = el.querySelectorAll('pre.mermaid, code.language-mermaid, .language-mermaid');
              if (kh.length) {
                const mm = (await import('https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs')).default;
                mm.initialize({ startOnLoad:false, securityLevel:'strict', theme:'\(toi ? "dark" : "default")' });
                let i = 0;
                for (const b of kh) {
                  try {
                    const { svg } = await mm.render('thi-mmd-' + (i++), b.textContent || '');
                    const w = document.createElement('div'); w.className = 'so-do'; w.innerHTML = svg;
                    (b.closest('pre') || b).replaceWith(w);
                  } catch (e) {}
                }
              }
            } catch (e) {}
            requestAnimationFrame(bao);
            // Ảnh tải xong thì chiều cao đổi — đo lại, không thì phần dưới bị
            // cắt đúng bằng chiều cao ảnh.
            el.querySelectorAll('img').forEach(im => im.addEventListener('load', bao));
            new ResizeObserver(bao).observe(document.body);
          })();
        </script></body></html>
        """
    }
}
#endif

// MARK: - Bọc lại cho gọn

/// Hiện một đoạn nội dung đề thi. Tự tách `|||`, và chỉ dựng WebView khi nội
/// dung THỰC SỰ cần (có thẻ, công thức hay sơ đồ).
struct NoiDungThi: View {
    let chu: String
    var coChu: CGFloat = 16
    var mauChu: Color = AppColors.textPrimary
    /// Đề bài thì xuống dòng cho các mục `(i) (ii) (iii)`; đáp án thì KHÔNG —
    /// một đáp án chỉ là "(i)" mà xuống dòng thì thành dòng trống.
    var laDeBai = false

    @State private var cao: CGFloat = 24
    @Environment(\.ngonNguDe) private var ngonNgu

    private var da: String {
        let t = chu.tachSongNgu(ngonNgu)
        guard laDeBai else { return t }
        // Đề đã là HTML thì chèn thẳng; đề chữ thuần thì phải thoát ký tự
        // trước, vì chèn `<br>` là đẩy nó sang bộ dựng HTML.
        let laHTML = t.contains("<") && t.contains(">")
        let nen = laHTML ? t : t.thoatHTML
        let ra = nen.xuongDongMucLaMa
        // Không có mục La Mã nào thì trả NGUYÊN BẢN, để chuỗi chữ thuần vẫn đi
        // đường `Text` nhanh chứ không dựng WebView vì mấy ký tự vừa thoát.
        return ra == nen ? t : ra
    }

    var body: some View {
        #if os(iOS)
        if da.canDungGiau {
            NoiDungThiWeb(html: da, chieuCao: $cao)
                .frame(height: cao)
        } else {
            Text(da)
                .font(.system(size: coChu))
                .foregroundColor(mauChu)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        #else
        Text(da)
            .font(.system(size: coChu))
            .foregroundColor(mauChu)
            .fixedSize(horizontal: false, vertical: true)
        #endif
    }
}
