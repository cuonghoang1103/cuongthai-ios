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

extension String {
    /// Lấy nửa tiếng Việt; rỗng thì lấy nửa còn lại; không có `|||` thì giữ
    /// nguyên (đề đơn ngữ vẫn hiện bình thường).
    var tachSongNgu: String {
        guard let r = range(of: "|||") else { return self }
        let en = String(self[startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let vi = String(self[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return vi.isEmpty ? en : vi
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

    @State private var cao: CGFloat = 24

    private var da: String { chu.tachSongNgu }

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
