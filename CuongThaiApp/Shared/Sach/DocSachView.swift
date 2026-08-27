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
    @State private var loi: String?
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
                          dangTai: $dangTai,
                          loi: $loi)
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
            if let l = loi {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 40)).foregroundColor(AppColors.textTertiary)
                    Text("Không mở được sách")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(l)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let u = sach.duongSach {
                        Link("Mở bằng trình duyệt", destination: u)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.top, Spacing.xs)
                    }
                }
                .padding(Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundPrimary)
            } else if dangTai {
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("Đang tải sách…")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            MucLucSachView(mucLuc: mucLuc, mau: sach.mau, cheDo: cheDo) { m in
                nhayToi = m.id
                hienMucLuc = false
            }
        }
    }
}

struct MucLucSach: Identifiable, Hashable {
    let id: String      // số chương, dùng luôn làm mã nhảy tới
    let tua: String
    /// Tựa tiếng Việt, `nil` khi cuốn đó chưa có bản dịch tiêu đề chương.
    var tuaVi: String?

    /// ⚠️ Chế độ SONG NGỮ giữ tựa tiếng Anh — người dùng yêu cầu vậy: đang
    /// đọc đối chiếu thì mục lục phải khớp với tiêu đề tiếng Anh trên trang.
    /// Chỉ chế độ VI mới đổi.
    func hien(_ c: CheDoChu) -> String {
        c == .viet ? (tuaVi ?? tua) : tua
    }
}

// MARK: - Mục lục

private struct MucLucSachView: View {
    let mucLuc: [MucLucSach]
    let mau: Color
    let cheDo: CheDoChu
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
                        Text(m.hien(cheDo))
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
    @Binding var loi: String?

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
            // ⚠️ Tắt vòng xoay NGAY Ở ĐÂY, đừng đợi JS gửi mục lục về.
            //
            // Bản đầu chỉ hạ `dangTai` khi nhận được tin `mucLuc` — nghĩa là
            // JS ném lỗi, hoặc cuốn sách không có khối `.toc-row`, hoặc cầu
            // `webkit.messageHandlers` chưa sẵn sàng, là vòng xoay quay MÃI
            // MÃI dù trang đã hiện xong bên dưới. Người dùng báo đúng cảnh
            // này. Trang đã dựng xong thì phải cho người ta thấy trang.
            Task { @MainActor in cha.dangTai = false; cha.loi = nil }
        }

        // Không có hai hàm này thì mất mạng giữa chừng = vòng xoay vĩnh viễn,
        // không một lời giải thích.
        func webView(_ v: WKWebView, didFail nav: WKNavigation!, withError e: Error) {
            Task { @MainActor in cha.dangTai = false; cha.loi = e.localizedDescription }
        }
        func webView(_ v: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError e: Error) {
            Task { @MainActor in cha.dangTai = false; cha.loi = e.localizedDescription }
        }

        func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
            guard let d = m.body as? [String: Any] else { return }
            Task { @MainActor in
                if let ml = d["mucLuc"] as? [[String: String]] {
                    cha.mucLuc = ml.compactMap {
                        guard let n = $0["n"], let t = $0["t"] else { return nil }
                        let vi = $0["vi"]
                        return MucLucSach(id: n, tua: t, tuaVi: (vi?.isEmpty == false) ? vi : nil)
                    }
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

              // ── Tựa chương tiếng Việt cho mục lục ───────────────
              //
              // ⚠️ PHẢI làm TRƯỚC vòng chèn bên dưới. Chèn xong rồi thì
              // `textContent` của tiêu đề lẫn CẢ Anh LẪN Việt (span `.ctsVi`
              // tuy `display:none` vẫn tính vào `textContent`), băm ra hash
              // khác và không tra được gì.
              //
              // ⚠️ Tra qua thẻ tiêu đề CỦA CHÍNH CHƯƠNG, không so chữ với
              // `.toc-t`: đo trên 25 cuốn thì khoảng nửa số chương có chữ ở
              // mục lục hơi khác chữ tiêu đề thật.
              //
              // Đo 25/08/2026: 11/25 cuốn tra được ĐỦ. 14 cuốn còn lại
              // (tập 12–25) dùng `<h1 class="chap-title">` nằm NGOÀI `.col`
              // nên tiêu đề chương chưa từng được trích để dịch — những cuốn
              // đó mục lục GIỮ tiếng Anh, không để trống.
              try {
                // ⚠️⚠️ Ghép theo SỐ CHƯƠNG, TUYỆT ĐỐI không theo vị trí.
                //
                // Thứ tự các hàng `.toc-row` KHÔNG trùng thứ tự các
                // `section.chap-open` trong DOM. Đo thật trên tập 09 (Git):
                // mục lục chạy 0,1,…,7,9,8,10,13,11,12,14,… trong khi các
                // section chạy ch0…ch16 đều tăm tắp — lệch 5/17 chương.
                // Ghép theo vị trí là gán tựa chương 9 cho chương 8, và cái
                // sai đó KHÔNG lộ ra ở đâu cả: mục lục vẫn đầy đủ, vẫn tiếng
                // Việt, chỉ là sai chương.
                //
                // Mỗi section có `id="ch<số>"` nên tra thẳng bằng số ở
                // `.toc-n` là chính xác tuyệt đối.
                var tuaVi = {};
                document.querySelectorAll('.toc-row').forEach(function (r) {
                  var sn = r.querySelector('.toc-n');
                  if (!sn) return;
                  var n = sn.textContent.trim();
                  var sec = document.getElementById('ch' + n);
                  if (!sec) return;
                  var td = sec.querySelector('h2') || sec.querySelector('h1.chap-title');
                  if (!td) return;
                  var v = bang[bam((td.textContent || '').replace(/\\s+/g, ' ').trim())];
                  // ⚠️ Bản dịch mang thẻ HTML (`<b>`, `<code>`,
                  // `<span class="n">`). Trong TRANG thì chèn bằng
                  // `innerHTML` là đúng, nhưng mục lục là `Text` của SwiftUI
                  // — đưa thẳng vào là hiện ra nguyên `<b>Encapsulation</b>`.
                  // Dựng tạm một thẻ rồi lấy `textContent` để còn CHỮ THUẦN.
                  if (v) {
                    var tmp = document.createElement('div');
                    tmp.innerHTML = v;
                    tuaVi[n] = (tmp.textContent || '').replace(/\\s+/g, ' ').trim();
                  }
                });
                window.ctsTuaVi = tuaVi;
                guiMucLuc();
              } catch (e) { /* mục lục giữ tiếng Anh, không chặn phần dịch */ }

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

          // ⚠️ Nhảy tới chương bằng ID, KHÔNG mò thẻ <a> và KHÔNG dùng chỉ
          // số mảng.
          //
          // Bản đầu tìm hàng mục lục rồi bấm thẻ <a> bên trong — nhưng
          // `.toc-row` KHÔNG có <a> nào cả (đo thật), nên nhánh đó không bao
          // giờ chạy. Nhánh dự phòng thì lấy `.chap[k-1]`, tức lại ghép theo
          // vị trí — đúng cái bẫy đã làm mục lục gán nhầm tựa chương.
          //
          // Mỗi chương có `id="ch<số>"`, tra thẳng là xong.
          window.ctsNhayToi = function (n) {
            var sec = document.getElementById('ch' + n);
            if (sec && sec.scrollIntoView) {
              sec.scrollIntoView({ block: 'start' });
              return;
            }
            // Không thấy id thì so số ở mục lục rồi cuộn tới chính hàng đó,
            // còn hơn là không nhúc nhích.
            var hang = document.querySelectorAll('.toc-row');
            for (var i = 0; i < hang.length; i++) {
              var sn = hang[i].querySelector('.toc-n');
              if (sn && sn.textContent.trim() === n) {
                hang[i].scrollIntoView({ block: 'start' });
                return;
              }
            }
          };

          function guiMucLuc() {
            var ra = [];
            document.querySelectorAll('.toc-row').forEach(function (r) {
              var n = r.querySelector('.toc-n'), t = r.querySelector('.toc-t');
              if (!n || !t) return;
              var c = t.cloneNode(true);
              c.querySelectorAll('small').forEach(function (s) { s.remove(); });
              var tua = (c.textContent || '').replace(/\\s+/g, ' ').trim();
              if (tua) {
                var so = n.textContent.trim();
                ra.push({ n: so, t: tua,
                          vi: (window.ctsTuaVi && window.ctsTuaVi[so]) || '' });
              }
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
