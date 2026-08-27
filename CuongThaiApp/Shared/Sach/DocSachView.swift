import SwiftUI
import WebKit

// ════════════════════════════════════════════════════════════════
// ĐỌC SÁCH
//
// Sách là file HTML TỰ CHỨA trên `media`/web (`/books/<file>`), nên bộ đọc là
// một `WKWebView` tải đúng địa chỉ đó — y hệt web dùng `<iframe>`. Không cố
// bóc HTML ra dựng lại bằng SwiftUI: sách có bảng, khối lệnh, hình, chú lề và
// bộ chủ đề sáng/tối của riêng nó; dựng lại là mất hết.
//
// ⚠️ SONG NGỮ dùng ĐÚNG thuật toán của web, chép nguyên sang JS chèn vào:
//   · lấy khối trong `.col` khớp `p,h1..h4,li,blockquote,figcaption,th,td`
//   · BỎ khối nằm trong `<pre>/<code>/.terminal` (đó là mã, không dịch)
//   · chỉ giữ khối LÁ (blockquote chứa p thì chỉ dịch p, tránh dịch hai lần)
//   · gộp khoảng trắng rồi băm FNV-1a 32-bit → tra `blocks[].h` trong file
//     `/books/i18n/<slug>.vi.json`
//
// Lệch một chi tiết là hash lệch và KHÔNG khớp được đoạn nào — bản dịch biến
// mất sạch mà không có lỗi nào. Nguồn gốc: `frontend/src/lib/bookBlocks.ts`.
// Đo 25/08/2026: bản dịch phủ 100% (2.211/2.211 khối ở tập 01).
// ════════════════════════════════════════════════════════════════

enum CheDoChu: String, CaseIterable {
    case anh = "en", song = "bi", viet = "vi"
    var nhan: String {
        switch self {
        case .anh: return "EN"
        case .song: return "Song ngữ"
        case .viet: return "VI"
        }
    }
}

struct DocSachView: View {
    let sach: Sach

    @AppStorage("sach.cheDoChu") private var maCheDo = CheDoChu.anh.rawValue
    @State private var mucLuc: [MucLucSach] = []
    @State private var hienMucLuc = false
    @State private var tienDo: Double = 0
    @State private var dangTai = true
    @State private var nhayToi: String?

    private var cheDo: CheDoChu { CheDoChu(rawValue: maCheDo) ?? .anh }

    var body: some View {
        ZStack(alignment: .top) {
            if let u = sach.duongSach {
                KhungSach(duong: u,
                          duongDich: sach.duongDich,
                          cheDo: cheDo,
                          nhayToi: $nhayToi,
                          mucLuc: $mucLuc,
                          tienDo: $tienDo,
                          dangTai: $dangTai)
                    .ignoresSafeArea(edges: .bottom)
            }
            // Thanh tiến độ mảnh, bám mép trên — biết đang ở đâu trong 800
            // trang mà không tốn một dòng giao diện nào.
            GeometryReader { g in
                Rectangle()
                    .fill(sach.mau)
                    .frame(width: g.size.width * tienDo, height: 2.5)
            }
            .frame(height: 2.5)
            if dangTai {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundPrimary)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(sach.tua)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("", selection: $maCheDo) {
                        ForEach(CheDoChu.allCases, id: \.rawValue) { c in
                            Text(c.nhan).tag(c.rawValue)
                        }
                    }
                } label: {
                    Text(cheDo.nhan).font(.system(size: 13, weight: .bold))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { hienMucLuc = true } label: { Image(systemName: "list.bullet") }
                    .disabled(mucLuc.isEmpty)
            }
        }
        .sheet(isPresented: $hienMucLuc) {
            MucLucSachView(mucLuc: mucLuc, mau: sach.mau) { m in
                nhayToi = m.id
                hienMucLuc = false
            }
        }
    }
}

struct MucLucSach: Identifiable, Hashable {
    let id: String      // số chương, dùng luôn làm mã nhảy tới
    let tua: String
}

// MARK: - Mục lục

private struct MucLucSachView: View {
    let mucLuc: [MucLucSach]
    let mau: Color
    let chon: (MucLucSach) -> Void
    @Environment(\.dismiss) private var dong

    var body: some View {
        NavigationStack {
            List(mucLuc) { m in
                Button { chon(m) } label: {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        Text(m.id)
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundColor(mau)
                            .frame(width: 30, alignment: .leading)
                        Text(m.tua)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Mục lục (\(mucLuc.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dong() }
                }
            }
        }
    }
}

// MARK: - WKWebView

private struct KhungSach: UIViewRepresentable {
    let duong: URL
    let duongDich: URL?
    let cheDo: CheDoChu
    @Binding var nhayToi: String?
    @Binding var mucLuc: [MucLucSach]
    @Binding var tienDo: Double
    @Binding var dangTai: Bool

    func makeCoordinator() -> Dieu { Dieu(self) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let ndc = WKUserContentController()
        ndc.add(context.coordinator, name: "sach")
        cfg.userContentController = ndc
        let v = WKWebView(frame: .zero, configuration: cfg)
        v.navigationDelegate = context.coordinator
        v.allowsBackForwardNavigationGestures = false
        v.isOpaque = false
        v.backgroundColor = .clear
        v.load(URLRequest(url: duong))
        return v
    }

    func updateUIView(_ v: WKWebView, context: Context) {
        // Đổi chế độ chữ: chỉ bật/tắt lớp CSS, KHÔNG tải lại trang — tải lại
        // là mất vị trí đang đọc giữa cuốn 800 trang.
        if context.coordinator.cheDoDaApDung != cheDo {
            context.coordinator.cheDoDaApDung = cheDo
            v.evaluateJavaScript("window.ctsDatCheDo && window.ctsDatCheDo('\(cheDo.rawValue)')")
        }
        if let m = nhayToi {
            v.evaluateJavaScript("window.ctsNhayToi && window.ctsNhayToi('\(m)')")
            DispatchQueue.main.async { nhayToi = nil }
        }
    }

    final class Dieu: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let cha: KhungSach
        var cheDoDaApDung: CheDoChu?
        init(_ cha: KhungSach) { self.cha = cha }

        func webView(_ v: WKWebView, didFinish nav: WKNavigation!) {
            let dich = cha.duongDich?.absoluteString ?? ""
            v.evaluateJavaScript(Self.kichBan(duongDich: dich, cheDo: cha.cheDo.rawValue))
            cheDoDaApDung = cha.cheDo
        }

        func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
            guard let d = m.body as? [String: Any] else { return }
            Task { @MainActor in
                if let ml = d["mucLuc"] as? [[String: String]] {
                    cha.mucLuc = ml.compactMap {
                        guard let n = $0["n"], let t = $0["t"] else { return nil }
                        return MucLucSach(id: n, tua: t)
                    }
                    cha.dangTai = false
                }
                if let p = d["tienDo"] as? Double { cha.tienDo = min(1, max(0, p)) }
            }
        }

        /// Toàn bộ phần chèn vào trang sách.
        ///
        /// ⚠️ `hash` phải GIỐNG HỆT `hashBlockText` của web (FNV-1a 32-bit,
        /// `Math.imul`, hex 8 ký tự). Đổi một phép toán là không khớp đoạn nào.
        static func kichBan(duongDich: String, cheDo: String) -> String { """
        (function () {
          if (window.ctsDaGan) return; window.ctsDaGan = true;

          var st = document.createElement('style');
          st.textContent = [
            'html { scroll-behavior: smooth; -webkit-text-size-adjust: 100%; }',
            '.cv-back { display: none !important; }',
            /* Trên điện thoại cột chữ của sách (74ch, canh trái trong .page
               1080px) hẹp và lệch — nới ra dùng hết bề ngang. */
            '.page, .fm, .chap { max-width: none !important; }',
            '.col { max-width: none !important; margin: 0 auto !important;',
            '       width: auto !important; padding-left: 16px !important;',
            '       padding-right: 16px !important; }',
            /* Bảng và khối lệnh phải CUỘN NGANG được, không thì tràn ra ngoài
               và cả trang bị kéo lệch. */
            'pre, table, .terminal { max-width: 100%; overflow-x: auto; }',
            ':root { --cts-gold: oklch(52% 0.13 82); }',
            '@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --cts-gold: oklch(80% 0.12 82); } }',
            ':root[data-theme="dark"] { --cts-gold: oklch(80% 0.12 82); }',
            '.ctsVi { display:none; margin-top:.45em; padding:1px 0 1px 12px;',
            '         border-left:2px solid var(--cts-gold); opacity:.92; }',
            'body.cts-bi .ctsVi { display:block; }',
            'body.cts-vi .ctsVi { display:block; }',
            'body.cts-vi .ctsEn { display:none; }'
          ].join('\\n');
          document.head.appendChild(st);

          function bam(s) {
            var h = 0x811c9dc5;
            for (var i = 0; i < s.length; i++) {
              h ^= s.charCodeAt(i);
              h = Math.imul(h, 0x01000193);
            }
            return (h >>> 0).toString(16).padStart(8, '0');
          }

          var CHON = 'p, h1, h2, h3, h4, li, blockquote, figcaption, th, td';
          function trongKhoiMa(el, goc) {
            for (var c = el; c; c = c.parentElement) {
              if (c.tagName === 'PRE' || c.tagName === 'CODE') return true;
              if (c.classList && c.classList.contains('terminal')) return true;
              if (c === goc) break;
            }
            return false;
          }
          function layKhoi() {
            var cols = document.querySelectorAll('.col'), tho = [], da = new Set();
            cols.forEach(function (col) {
              col.querySelectorAll(CHON).forEach(function (el) {
                if (da.has(el) || trongKhoiMa(el, col)) return;
                da.add(el); tho.push(el);
              });
            });
            var tap = new Set(tho);
            return tho.filter(function (el) {
              return !Array.prototype.some.call(el.querySelectorAll(CHON), function (c) { return tap.has(c); });
            });
          }

          window.ctsDatCheDo = function (m) {
            document.body.classList.remove('cts-bi', 'cts-vi');
            if (m === 'bi') document.body.classList.add('cts-bi');
            if (m === 'vi') document.body.classList.add('cts-vi');
            if (m !== 'en') napDich();
          };

          var daNap = false;
          function napDich() {
            if (daNap) return; daNap = true;
            fetch('\(duongDich)').then(function (r) { return r.json(); }).then(function (d) {
              var bang = {};
              (d.blocks || []).forEach(function (b) { bang[b.h] = b.vi; });
              layKhoi().forEach(function (el) {
                if (el.dataset.ctsXong) return;
                var vi = bang[bam((el.textContent || '').replace(/\\s+/g, ' ').trim())];
                if (!vi) return;
                el.dataset.ctsXong = '1';
                // Bọc phần Anh lại để chế độ "chỉ VI" ẩn được nó đi.
                var en = document.createElement('span');
                en.className = 'ctsEn';
                while (el.firstChild) en.appendChild(el.firstChild);
                el.appendChild(en);
                var v = document.createElement('span');
                v.className = 'ctsVi';
                // ⚠️ `innerHTML`, KHÔNG phải `textContent`. Bản dịch có mang
                // thẻ (`<code>`, `<strong>`, `<em>`) và thực thể (`&nbsp;`) —
                // `textContent` in chúng ra thành chữ, người đọc thấy nguyên
                // `<code>deploy</code>` giữa câu. Web dùng `innerHTML`; chép
                // theo. Nguồn chữ là file dịch của chính mình, không phải dữ
                // liệu người lạ gửi tới.
                v.innerHTML = vi;
                el.appendChild(v);
              });
            }).catch(function () { daNap = false; });
          }

          window.ctsNhayToi = function (n) {
            var hang = document.querySelectorAll('.toc-row');
            for (var i = 0; i < hang.length; i++) {
              var s = hang[i].querySelector('.toc-n');
              if (s && s.textContent.trim() === n) {
                var a = hang[i].querySelector('a') || hang[i];
                if (a.click) { a.click(); return; }
              }
            }
            var ch = document.querySelectorAll('.chap');
            var k = parseInt(n, 10);
            if (!isNaN(k) && ch[k - 1]) ch[k - 1].scrollIntoView({ block: 'start' });
          };

          function guiMucLuc() {
            var ra = [];
            document.querySelectorAll('.toc-row').forEach(function (r) {
              var n = r.querySelector('.toc-n'), t = r.querySelector('.toc-t');
              if (!n || !t) return;
              var c = t.cloneNode(true);
              c.querySelectorAll('small').forEach(function (s) { s.remove(); });
              var tua = (c.textContent || '').replace(/\\s+/g, ' ').trim();
              if (tua) ra.push({ n: n.textContent.trim(), t: tua });
            });
            webkit.messageHandlers.sach.postMessage({ mucLuc: ra });
          }

          var cho = null;
          window.addEventListener('scroll', function () {
            if (cho) return;
            cho = setTimeout(function () {
              cho = null;
              var h = document.documentElement;
              var tong = h.scrollHeight - h.clientHeight;
              webkit.messageHandlers.sach.postMessage({ tienDo: tong > 0 ? h.scrollTop / tong : 0 });
            }, 120);
          }, { passive: true });

          guiMucLuc();
          window.ctsDatCheDo('\(cheDo)');
        })();
        """ }
    }
}
