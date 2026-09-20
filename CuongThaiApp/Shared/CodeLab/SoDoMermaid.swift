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
    /// Toàn màn hình: cho cuộn cả hai chiều, không khớp chiều cao theo nội dung.
    var trongKhungRong: Bool = false

    func makeUIView(context: Context) -> WKWebView {
        let ch = WKWebViewConfiguration()
        ch.userContentController.add(context.coordinator, name: "soDo")
        let w = WKWebView(frame: .zero, configuration: ch)
        /*
         * ⚠️ PHẢI CHO CUỘN NGANG VÀ PHÓNG TO.
         *
         * Một sơ đồ `graph TD` có 12 nhánh song song thì RỘNG, dù hướng là
         * dọc. Ép `max-width:100%` vào cột 400pt của iPhone là mỗi ô còn ~30pt
         * — vẽ ra hình nhưng chữ nhỏ tới mức vô dụng. Người dùng nói đúng:
         * *"khó nhìn vậy không hiểu"*.
         *
         * Nên: SVG giữ kích thước THẬT, WebView tự cuộn NGANG và cho chụm hai
         * ngón phóng to. Cuộn DỌC thì tắt (`alwaysBounceVertical = false` +
         * chiều cao khung khớp nội dung) để không giành cử chỉ với danh sách
         * chat bên ngoài.
         */
        w.scrollView.isScrollEnabled = true
        w.scrollView.alwaysBounceVertical = trongKhungRong
        w.scrollView.showsVerticalScrollIndicator = trongKhungRong
        /* Thu nhỏ tới 0,25: sơ đồ rộng gấp 4 lần màn hình vẫn nhìn được
           TOÀN CẢNH bằng một cú chụm, rồi phóng lại chỗ cần đọc. */
        w.scrollView.minimumZoomScale = 0.25
        w.scrollView.maximumZoomScale = 5
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
                if let e = d["loi"] as? Bool, e {
                    // PHÉP ĐO tạm: một khung trống có nhiều nguyên nhân trông
                    // giống hệt nhau, phải có SỐ mới biết — xem ghi chú
                    // feedback_webview_khung_trong_ba_nguyen_nhan.
                    print("[SODO] HỎNG buoc=\(d["buoc"] ?? "?") loi=\(d["chiTiet"] ?? "?")")
                    cha.hong = true; return
                }
                if let h = d["cao"] as? CGFloat, h > 0, abs(cha.chieuCao - h) > 1 { cha.chieuCao = h }
            }
        }
    }

    private func trang(toi: Bool) -> String {
        let json = String(data: (try? JSONSerialization.data(withJSONObject: [ma])) ?? Data(),
                          encoding: .utf8) ?? "[\"\"]"
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=0.25, maximum-scale=5, user-scalable=yes">
        <style>
          html,body{margin:0;padding:0;background:transparent}
          /* KHÔNG `justify-content:center`: khi sơ đồ rộng hơn màn hình, căn
             giữa đẩy mép trái ra ngoài vùng cuộn và không kéo lại được. */
          #v{padding:4px 6px}
          /* KHÔNG `max-width:100%` — xem ghi chú ở `makeUIView`. */
          svg{height:auto}
        </style></head><body><div id="v"></div>
        <script type="module">
          const bao = (o) => window.webkit?.messageHandlers?.soDo?.postMessage(o);
          // Hết 8 giây chưa vẽ xong thì báo hỏng, để giao diện quay về hiện mã
          // — chờ mãi một khung trắng còn tệ hơn là thấy mã nguồn sơ đồ.
          let buoc = 'bat-dau';
          // 20 giây: lần đầu phải kéo ~1,5MB thư viện từ CDN, và người học hay mở
          // đúng lúc video đang chạy nên mạng đã bận. Trần 8 giây cũ cắt ngang
          // một lượt tải VẪN ĐANG chạy, và người dùng chỉ thấy mã nguồn thô.
          const hen = setTimeout(() => bao({loi: true, buoc, chiTiet: 'het 20 giay'}), 20000);
          try {
            buoc = 'nap-thu-vien';
            const m = await import('https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs');
            buoc = 'khoi-tao';
            /*
             * Chủ đề: chữ TO và ô có viền rõ — người dùng 20/09/2026 muốn nó
             * "như 1 trang slide ô vuông". Mặc định của mermaid là 14px chữ
             * xám nhạt trên nền xám, đọc trên iPad rất mệt.
             *
             * Nếu AI có đặt `classDef`/`style` riêng thì phần đó THẮNG các giá
             * trị dưới đây — đúng ý đồ: mỗi nhóm một màu, còn đây chỉ là nền.
             */
            const toi = \(toi ? "true" : "false");
            m.default.initialize({
              startOnLoad: false, securityLevel: 'strict',
              theme: 'base',
              themeVariables: {
                fontFamily: '-apple-system, system-ui, sans-serif',
                fontSize: '17px',
                primaryColor:       toi ? '#1e293b' : '#eff6ff',
                primaryTextColor:   toi ? '#f1f5f9' : '#0f172a',
                primaryBorderColor: toi ? '#8b5cf6' : '#6366f1',
                lineColor:          toi ? '#94a3b8' : '#475569',
                secondaryColor:     toi ? '#312e81' : '#e0e7ff',
                tertiaryColor:      toi ? '#134e4a' : '#ccfbf1',
                background:         'transparent',
                mainBkg:            toi ? '#1e293b' : '#eff6ff',
                nodeBorder:         toi ? '#8b5cf6' : '#6366f1',
                clusterBkg:         toi ? '#0f172a' : '#f8fafc',
                titleColor:         toi ? '#f1f5f9' : '#0f172a',
                edgeLabelBackground: toi ? '#0f172a' : '#ffffff',
              },
              flowchart: { padding: 14, nodeSpacing: 30, rankSpacing: 44, useMaxWidth: true },
            });
            buoc = 've';
            const { svg } = await m.default.render('so-do', \(json)[0]);
            document.getElementById('v').innerHTML = svg;
            /*
             * ⚠️ VỪA BỀ NGANG, RỒI CHỤM HAI NGÓN ĐỂ PHÓNG TO.
             *
             * Bản trước tôi ép SVG về kích thước THẬT để chữ khỏi bé. Sai:
             * khung inline khi đó chỉ hiện GÓC TRÊN TRÁI — một ô trống, còn
             * tệ hơn sơ đồ nhỏ. Người học cần thấy TOÀN CẢNH trước rồi mới
             * phóng vào chỗ muốn đọc.
             *
             * Nên giữ `useMaxWidth` (vừa khung), và cái THẬT SỰ thiếu trước
             * đây là PHÓNG TO: `scrollView.isScrollEnabled = false` khoá luôn
             * cả cử chỉ chụm. Nay đã mở, cộng nút xem toàn màn hình.
             */
            const g = document.querySelector('#v svg');
            clearTimeout(hen);
            requestAnimationFrame(() => {
              const r = g ? g.getBoundingClientRect() : null;
              bao({ cao: Math.ceil(r ? r.height + 8 : document.body.scrollHeight),
                    rong: Math.ceil(r ? r.width : document.body.scrollWidth) });
            });
          } catch (e) {
            clearTimeout(hen);
            bao({loi: true, buoc, chiTiet: String(e && e.message || e).slice(0, 300)});
          }
        </script></body></html>
        """
    }
}
#endif

/// Bọc lại: tự giữ chiều cao, hỏng thì quay về hiện mã sơ đồ.
///
/// ⚠️ LUÔN CÓ ĐƯỜNG XEM TO. Sơ đồ nhiều nhánh song song thì rộng bằng mấy lần
/// cột chat, và dù đã cho cuộn ngang + chụm hai ngón thì đọc một sơ đồ 12 ô
/// qua khe 400pt vẫn là cực hình. Chạm vào sơ đồ là mở toàn màn hình.
struct SoDoMermaid: View {
    let ma: String
    @State private var cao: CGFloat = 120
    @State private var hong = false
    @State private var moTo = false

    var body: some View {
        #if os(iOS)
        if hong {
            KhoiMaNguon(ma: ma, ngonNgu: "mermaid", tieuDe: "Sơ đồ (không vẽ được)")
        } else {
            SoDoMermaidView(ma: ma, chieuCao: $cao, hong: $hong)
                .frame(height: cao)
                .padding(.vertical, Spacing.sm)
                .overlay(alignment: .topTrailing) {
                    Button { moTo = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(7)
                            .background(Circle().fill(AppColors.backgroundCard.opacity(0.92)))
                            .overlay(Circle().stroke(AppColors.border, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .accessibilityLabel(T("Xem sơ đồ toàn màn hình"))
                }
                .fullScreenCover(isPresented: $moTo) { SoDoToanManHinhChung(ma: ma) }
        }
        #else
        KhoiMaNguon(ma: ma, ngonNgu: "mermaid", tieuDe: "Sơ đồ")
        #endif
    }
}

#if os(iOS)
/// Sơ đồ chiếm trọn màn hình — xoay ngang được, chụm hai ngón phóng to.
struct SoDoToanManHinhChung: View {
    let ma: String
    @Environment(\.dismiss) private var dong
    @State private var cao: CGFloat = 400
    @State private var hong = false

    var body: some View {
        NavigationStack {
            Group {
                if hong {
                    ScrollView { KhoiMaNguon(ma: ma, ngonNgu: "mermaid", tieuDe: "Sơ đồ (không vẽ được)") }
                } else {
                    /* Ở đây KHÔNG khớp chiều cao theo nội dung: cho WebView
                       chiếm trọn màn hình và tự lo cả cuộn dọc lẫn cuộn ngang,
                       vì không còn danh sách nào bên ngoài để giành cử chỉ. */
                    SoDoMermaidView(ma: ma, chieuCao: $cao, hong: $hong, trongKhungRong: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Sơ đồ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(T("Xong")) { dong() }.fontWeight(.semibold)
                }
            }
        }
    }
}
#endif
