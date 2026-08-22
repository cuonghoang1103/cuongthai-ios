import SwiftUI
#if os(iOS)
import WebKit

// MARK: - Sơ đồ Mermaid
//
// Bài học có 16 khối `mermaid` chỉ trong 6 chương đầu của PostgreSQL — sơ đồ
// quan hệ bảng, luồng câu lệnh. Bỏ qua thì mất đúng phần dễ hiểu nhất.
//
// Dựng bằng WKWebView + thư viện mermaid tải từ CDN. Không có bản dựng THUẦN
// SwiftUI nào cho mermaid, mà tự vẽ lại cú pháp đó là một dự án riêng.
//
// ⚠️ Cần MẠNG cho lần vẽ đầu (WKWebView tự nhớ tạm sau đó). Hỏng thì hiện
// nguyên mã sơ đồ thay vì một khoảng trắng — người đọc vẫn lần ra được ý.

struct SoDoMermaidView: UIViewRepresentable {
    let ma: String
    @Binding var chieuCao: CGFloat
    @Binding var hong: Bool

    func makeUIView(context: Context) -> WKWebView {
        let ch = WKWebViewConfiguration()
        ch.userContentController.add(context.coordinator, name: "soDo")
        let w = WKWebView(frame: .zero, configuration: ch)
        w.scrollView.isScrollEnabled = false
        w.scrollView.bounces = false
        w.isOpaque = false
        w.backgroundColor = .clear
        w.scrollView.backgroundColor = .clear
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) {
        let khoa = "\(ma.hashValue)|\(context.environment.colorScheme)"
        guard context.coordinator.khoa != khoa else { return }
        context.coordinator.khoa = khoa
        w.loadHTMLString(trang(toi: context.environment.colorScheme == .dark), baseURL: nil)
    }

    func makeCoordinator() -> Dieu { Dieu(self) }

    final class Dieu: NSObject, WKScriptMessageHandler {
        let cha: SoDoMermaidView
        var khoa: String?
        init(_ c: SoDoMermaidView) { cha = c }

        func userContentController(_ uc: WKUserContentController, didReceive m: WKScriptMessage) {
            guard m.name == "soDo", let d = m.body as? [String: Any] else { return }
            Task { @MainActor in
                if let e = d["loi"] as? Bool, e { cha.hong = true; return }
                if let h = d["cao"] as? CGFloat, h > 0, abs(cha.chieuCao - h) > 1 { cha.chieuCao = h }
            }
        }
    }

    private func trang(toi: Bool) -> String {
        let json = String(data: (try? JSONSerialization.data(withJSONObject: [ma])) ?? Data(),
                          encoding: .utf8) ?? "[\"\"]"
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          html,body{margin:0;padding:0;background:transparent}
          #v{display:flex;justify-content:center}
          svg{max-width:100%;height:auto}
        </style></head><body><div id="v"></div>
        <script type="module">
          const bao = (o) => window.webkit?.messageHandlers?.soDo?.postMessage(o);
          // Hết 8 giây chưa vẽ xong thì báo hỏng, để giao diện quay về hiện mã
          // — chờ mãi một khung trắng còn tệ hơn là thấy mã nguồn sơ đồ.
          const hen = setTimeout(() => bao({loi: true}), 8000);
          try {
            const m = await import('https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs');
            m.default.initialize({ startOnLoad: false, securityLevel: 'strict',
                                   theme: '\(toi ? "dark" : "default")' });
            const { svg } = await m.default.render('so-do', \(json)[0]);
            document.getElementById('v').innerHTML = svg;
            clearTimeout(hen);
            requestAnimationFrame(() => bao({cao: document.body.scrollHeight}));
          } catch (e) { clearTimeout(hen); bao({loi: true}); }
        </script></body></html>
        """
    }
}
#endif

/// Bọc lại: tự giữ chiều cao, hỏng thì quay về hiện mã sơ đồ.
struct SoDoMermaid: View {
    let ma: String
    @State private var cao: CGFloat = 120
    @State private var hong = false

    var body: some View {
        #if os(iOS)
        if hong {
            KhoiMaNguon(ma: ma, ngonNgu: "mermaid", tieuDe: "Sơ đồ (không vẽ được)")
        } else {
            SoDoMermaidView(ma: ma, chieuCao: $cao, hong: $hong)
                .frame(height: cao)
                .padding(.vertical, Spacing.sm)
        }
        #else
        KhoiMaNguon(ma: ma, ngonNgu: "mermaid", tieuDe: "Sơ đồ")
        #endif
    }
}
