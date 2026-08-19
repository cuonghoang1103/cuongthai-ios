import SwiftUI
#if os(iOS)
import WebKit
#endif

// MARK: - Dựng nội dung bài học
//
// Nội dung bài KHÔNG phải văn bản thuần. Nó là HTML `rich-content` do web soạn,
// mang bảng, khối `callout` / `pitfall`, nhãn `eyebrow`, lưới `kv-grid`, khối
// mã — VÀ chứa CẢ HAI ngôn ngữ cùng lúc, web ẩn bớt một bằng thuộc tính
// `data-ml` trên thẻ bọc:
//
//     .rich-content[data-ml="vi"] .ml-en { display: none }
//
// Bản đầu dựng bằng `NSAttributedString`. Hậu quả đo được (19/08/2026):
//   • `<table>` bị BẸP thành danh sách dòng nối đuôi — user đọc thấy
//     "4 / Chèn & truy vấn / INSERT, SELECT…" rời rạc và tưởng lỗi phông
//   • cả tiếng Anh lẫn tiếng Việt cùng hiện, chồng lên nhau
//   • callout, pitfall, kv-grid mất sạch khung viền
//
// Nên phải dựng bằng WKWebView thật, chèn CSS bám theo bảng màu của app.
// Đổi lại phải TỰ ĐO chiều cao, vì web view lồng trong ScrollView không tự
// co giãn: dùng ResizeObserver báo về mỗi lần bố cục đổi (ảnh tải xong, phông
// tải xong, xoay máy) thay vì đo một lần rồi thôi.

#if os(iOS)
struct RichContentView: UIViewRepresentable {
    let html: String
    @Binding var chieuCao: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let cauHinh = WKWebViewConfiguration()
        cauHinh.userContentController.add(context.coordinator, name: "chieuCao")

        let web = WKWebView(frame: .zero, configuration: cauHinh)
        web.navigationDelegate = context.coordinator
        web.scrollView.isScrollEnabled = false      // ScrollView bên ngoài cuộn
        web.scrollView.bounces = false
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        let khoa = "\(html.hashValue)|\(context.environment.colorScheme)"
        guard context.coordinator.khoaDangHien != khoa else { return }
        context.coordinator.khoaDangHien = khoa
        web.loadHTMLString(trangHTML(toi: context.environment.colorScheme == .dark), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let cha: RichContentView
        var khoaDangHien: String?

        init(_ cha: RichContentView) { self.cha = cha }

        func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "chieuCao", let h = message.body as? CGFloat, h > 0 else { return }
            Task { @MainActor in
                // Chênh dưới 1pt thì bỏ qua — không thì ResizeObserver và
                // SwiftUI đẩy qua đẩy lại nhau thành vòng lặp vẽ vô tận.
                if abs(cha.chieuCao - h) > 1 { cha.chieuCao = h }
            }
        }

        /// Bấm link trong bài thì mở Safari, không điều hướng ngay trong khung
        /// nội dung (người dùng sẽ mắc kẹt, không có nút Back nào ở đó).
        func webView(_ web: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }

    private func trangHTML(toi: Bool) -> String {
        let ngonNgu = (Locale.preferredLanguages.first?.hasPrefix("vi") ?? false) ? "vi" : "en"

        let chuChinh = toi ? "#FFFFFF" : "#14141C"
        let chuPhu   = toi ? "#B8B8C4" : "#3A3A44"
        let chuMo    = toi ? "#737380" : "#81818C"
        let nenPhu   = toi ? "#141420" : "#F2F2F6"
        let nenMa    = toi ? "#1A1A24" : "#EDEDF2"
        let vien     = toi ? "rgba(255,255,255,.12)" : "rgba(0,0,0,.10)"

        return """
        <!DOCTYPE html><html lang="\(ngonNgu)"><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
          :root{color-scheme:\(toi ? "dark" : "light")}
          html,body{margin:0;padding:0;background:transparent;
            -webkit-text-size-adjust:100%}
          body{font:16px/1.6 -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;
            color:\(chuPhu);word-wrap:break-word}

          /* Ẩn ngôn ngữ còn lại — đúng cách web đang làm */
          .rich-content[data-ml="vi"] .ml-en{display:none}
          .rich-content[data-ml="en"] .ml-vi{display:none}

          h1,h2,h3,h4{color:\(chuChinh);line-height:1.3;margin:22px 0 10px;font-weight:700}
          h1{font-size:22px} h2{font-size:20px} h3{font-size:17px} h4{font-size:16px}
          p{margin:0 0 12px}
          strong,b{color:\(chuChinh)}
          a{color:#8C5AF0;text-decoration:none}
          ul,ol{margin:0 0 12px;padding-left:22px}
          li{margin:0 0 6px}
          hr{border:0;border-top:1px solid \(vien);margin:20px 0}

          .eyebrow{display:inline-block;font-family:ui-monospace,Menlo,monospace;
            font-size:11px;letter-spacing:.14em;text-transform:uppercase;
            font-weight:700;color:\(chuMo);margin-bottom:6px}
          .lead{font-size:17px;color:\(chuChinh)}

          /* BẢNG — thứ bị bẹp hoàn toàn ở bản dựng cũ.
             Bọc trong khung cuộn ngang để bảng rộng không phá bố cục trang. */
          .bang-cuon{overflow-x:auto;-webkit-overflow-scrolling:touch;margin:0 0 14px}
          table{border-collapse:collapse;width:100%;font-size:14px;min-width:340px}
          th,td{border:1px solid \(vien);padding:8px 10px;text-align:left;vertical-align:top}
          th{background:\(nenPhu);color:\(chuChinh);font-weight:700;white-space:nowrap}
          tr:nth-child(even) td{background:\(toi ? "rgba(255,255,255,.02)" : "rgba(0,0,0,.02)")}

          code{font-family:ui-monospace,Menlo,monospace;font-size:13.5px;
            background:\(nenMa);padding:2px 5px;border-radius:5px;color:\(chuChinh)}
          pre{background:\(nenMa);padding:12px;border-radius:10px;overflow-x:auto;
            -webkit-overflow-scrolling:touch;margin:0 0 14px}
          pre code{background:none;padding:0;font-size:13px;line-height:1.5}

          .callout,.pitfall{border-left:3px solid #8C5AF0;background:rgba(140,90,240,.10);
            padding:10px 14px;border-radius:0 10px 10px 0;margin:0 0 14px}
          .callout>:first-child,.pitfall>:first-child{margin-top:0}
          .callout>:last-child,.pitfall>:last-child{margin-bottom:0}
          .callout.ok{border-left-color:#2F9E6B;background:rgba(47,158,107,.12)}
          .callout.warn{border-left-color:#D69220;background:rgba(214,146,32,.14)}
          .callout.danger,.pitfall{border-left-color:#E0554B;background:rgba(224,85,75,.12)}

          /* Lưới khoá–giá trị. `.k` PHẢI là block, không thì nhãn dính liền
             vào nội dung: "Store durablyWrite once; it survives…" */
          .kv-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));
            gap:10px;margin:14px 0}
          .kv{background:\(nenPhu);border:1px solid \(vien);border-radius:10px;padding:10px 12px}
          .kv .k{display:block;font-family:ui-monospace,Menlo,monospace;font-size:10.5px;
            letter-spacing:.05em;text-transform:uppercase;color:\(chuMo);margin-bottom:3px}
          .kv .v{font-weight:700;color:\(chuChinh)}
          .kv .v small{font-weight:400;color:\(chuPhu)}

          /* Các lớp còn lại web dùng trong bài — lấy đủ một lượt để khỏi phải
             quay lại vá từng cái khi gặp bài dùng tới. */
          .badge{display:inline-block;font-family:ui-monospace,Menlo,monospace;
            font-size:10.5px;font-weight:700;letter-spacing:.03em;padding:2px 7px;
            border-radius:999px;background:\(nenMa);color:\(chuPhu)}
          .formula{margin:18px 0;padding:14px 16px;text-align:center;
            font-family:ui-monospace,Menlo,monospace;font-size:15px;
            background:\(nenMa);border-radius:10px;color:\(chuChinh)}
          .out{background:\(toi ? "rgba(255,255,255,.05)" : "rgba(0,0,0,.04)");
            border:1px dashed \(vien);border-radius:10px;padding:10px 12px;margin:14px 0}
          .note-ct{border:1px solid rgba(99,102,241,.4);background:rgba(99,102,241,.08);
            border-radius:10px;padding:10px 14px;margin:14px 0;font-size:15px}
          .diagram{background:\(nenMa);border:1px solid \(vien);border-radius:10px;
            padding:12px 14px;margin:14px 0;font-family:ui-monospace,Menlo,monospace;
            font-size:13px;overflow-x:auto;-webkit-overflow-scrolling:touch;white-space:pre}

          /* ── Lộ trình học (.lz-*) ─────────────────────────────────────
             Đây là thứ user chụp lại và bảo "nhìn lộn xộn". Bản đầu tôi gom
             chung với .diagram thành khối chữ đơn cách — nên huy hiệu số, tên
             chương và mô tả rơi thành ba dòng rời, mất hết khung và đường nối.
             Chép đúng cấu trúc web: cột dọc, mỗi bước là huy hiệu + thẻ. */
          .lz-map{display:flex;flex-direction:column;gap:14px;margin:18px 0}
          .lz-stage{font-family:ui-monospace,Menlo,monospace;font-size:10.5px;
            letter-spacing:.12em;text-transform:uppercase;color:\(chuMo);
            margin:8px 0 -3px 8px;display:flex;align-items:center;gap:8px}
          .lz-stage::before{content:"";width:6px;height:6px;border-radius:999px;
            background:#6366F1;box-shadow:0 0 0 4px rgba(99,102,241,.22)}
          .lz-node{position:relative;display:flex;gap:14px;align-items:flex-start}
          /* Đường nối dọc giữa các bước — thứ làm nó ra hình lộ trình */
          .lz-node:not(:last-child)::before{content:"";position:absolute;left:19px;
            top:42px;bottom:-16px;width:2px;
            background:linear-gradient(#6366F1,rgba(99,102,241,.2))}
          .lz-node .lz-badge{flex-shrink:0;width:40px;height:40px;border-radius:12px;
            display:grid;place-items:center;font-weight:700;font-size:14px;
            background:rgba(99,102,241,.14);color:#8B8DF5;
            border:1px solid rgba(99,102,241,.26);position:relative;z-index:1}
          .lz-node .lz-nbody{flex:1;border:1px solid \(vien);background:\(nenPhu);
            border-radius:12px;padding:9px 14px}
          .lz-node .lz-ntitle{font-weight:700;color:\(chuChinh)}
          .lz-node .lz-nsub{font-size:13.5px;color:\(chuMo);margin-top:1px}

          /* Chuỗi bước ngang — trên điện thoại xếp dọc, mũi tên quay xuống */
          .lz-flow{display:flex;flex-direction:column;gap:10px;margin:18px 0}
          .lz-flow .lz-step{border:1px solid \(vien);background:\(nenPhu);
            border-radius:14px;padding:12px 15px;position:relative}
          .lz-flow .lz-step .lz-k{font-family:ui-monospace,Menlo,monospace;font-size:10px;
            letter-spacing:.08em;text-transform:uppercase;color:#8B8DF5;font-weight:700}
          .lz-flow .lz-step .lz-t{font-weight:700;color:\(chuChinh);margin-top:2px}
          .lz-flow .lz-step .lz-d{font-size:13px;color:\(chuMo);margin-top:3px}
          .lz-flow .lz-step:not(:last-child)::after{content:"▾";position:absolute;
            left:22px;bottom:-12.5px;color:#8B8DF5;font-size:15px;z-index:2}

          .lz-stack{display:flex;flex-direction:column;gap:6px;margin:18px 0}
          .lz-stack .lz-layer{border:1px solid \(vien);border-left:3px solid #6366F1;
            background:\(nenPhu);border-radius:9px;padding:9px 14px;display:flex;
            justify-content:space-between;align-items:center;gap:12px}
          .lz-stack .lz-layer .lz-lname{font-weight:700;color:\(chuChinh);
            font-family:ui-monospace,Menlo,monospace;font-size:14px}
          .lz-stack .lz-layer .lz-lnote{font-size:13px;color:\(chuMo);text-align:right}
          .link-card{display:flex;align-items:center;gap:10px;border:1px solid \(vien);
            border-radius:12px;padding:10px 12px;margin:0 0 10px;background:\(nenPhu)}
          kbd{font-family:ui-monospace,Menlo,monospace;font-size:.8em;background:\(nenMa);
            border:1px solid \(vien);border-bottom-width:2px;border-radius:5px;padding:1px 5px}
          .sim-card,.sim-video{border:1px solid \(vien);border-radius:10px;
            padding:10px 12px;margin:14px 0;background:\(nenPhu)}

          img{max-width:100%;height:auto;border-radius:10px}
          blockquote{margin:0 0 14px;padding-left:14px;border-left:3px solid \(vien);color:\(chuMo)}
        </style></head>
        <body>
          <div class="rich-content" data-ml="\(ngonNgu)">\(html)</div>
          <script>
            // Bảng rộng hơn màn hình sẽ kéo giãn cả trang và làm chữ bé tí.
            // Bọc mỗi bảng vào một khung cuộn ngang riêng.
            document.querySelectorAll('table').forEach(function (t) {
              if (t.parentElement && t.parentElement.classList.contains('bang-cuon')) return;
              var box = document.createElement('div');
              box.className = 'bang-cuon';
              t.parentNode.insertBefore(box, t);
              box.appendChild(t);
            });

            function bao() {
              var h = document.documentElement.scrollHeight;
              window.webkit.messageHandlers.chieuCao.postMessage(h);
            }
            // Báo lại mỗi lần bố cục đổi: ảnh tải xong, phông tải xong, xoay máy.
            // Đo một lần lúc load xong là thiếu — chiều cao lúc đó chưa đúng.
            new ResizeObserver(bao).observe(document.documentElement);
            window.addEventListener('load', bao);
            bao();
          </script>
        </body></html>
        """
    }
}
#endif

/// Bọc web view lại cho gọn: tự giữ chiều cao, tự co giãn theo nội dung.
struct RichContent: View {
    let html: String
    @State private var chieuCao: CGFloat = 40

    var body: some View {
        #if os(iOS)
        RichContentView(html: html, chieuCao: $chieuCao)
            .frame(height: chieuCao)
        #else
        // macOS chưa dùng màn học; hiện bản đã lột thẻ cho khỏi trống.
        Text(html.lotTheHTML)
            .font(.bodyMedium)
            .foregroundColor(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        #endif
    }
}
