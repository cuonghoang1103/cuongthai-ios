import SwiftUI
import WebKit
import SafariServices

// ════════════════════════════════════════════════════════════════
// ĐỌC SÁCH — TỪNG CHƯƠNG, NẰM TRÊN MÁY
//
// Bản trước nạp CẢ CUỐN vào một `WKWebView` trỏ thẳng ra web. Nó chết, và
// chết theo kiểu khó chịu nhất: tiến trình nội dung bị hệ thống giết giữa
// chừng nên không có lỗi nào để đọc, chỉ thấy "đang tải" quay mãi.
//
// Đo thật 27/08/2026 trên tập 25 (Networking), cuốn nặng nhất:
//   · cả cuốn 1.001 KB · 14.172 thẻ · 120 bảng · 3.620 ô · 133 khối lệnh
//   · `SFSafariViewController` — tiến trình riêng, ngân sách bộ nhớ lớn hơn
//     hẳn WebView nhúng — CŨNG chết ("Đã có sự cố xảy ra liên tục").
//
// Tức không phải app yếu, mà một trang 1 MB như thế thì WebKit trên điện
// thoại không dựng nổi. Nên đổi cách: cắt theo chương ở Swift, mỗi lần chỉ
// dựng head + MỘT chương.
//
//   head 20 KB + chương lớn nhất 71 KB = **92 KB** (trung bình 60 KB)
//   → nhẹ hơn **11 lần** ở trường hợp xấu nhất, **16 lần** ở mức trung bình.
//
// Kèm theo, ba thứ từng hỏng nay biến mất vì không còn tồn tại:
//   · Nhảy tới chương KHÔNG còn nhờ JS cuộn trong trang 800 trang (từng ra
//     màn hình đen) — nay là đổi `phan`, dựng đúng chương đó, cuộn ở đầu.
//   · Mục lục KHÔNG còn phải moi ra từ DOM sau khi trang tải xong.
//   · Vòng lặp tải lại vô tận không còn chỗ để xảy ra.
//
// ⚠️ SONG NGỮ vẫn dùng ĐÚNG thuật toán của web (`frontend/src/lib/
// bookBlocks.ts`): khối trong `.col` khớp `p,h1..h4,li,blockquote,figcaption,
// th,td`, bỏ khối trong `pre/code/.terminal`, chỉ giữ khối LÁ, gộp khoảng
// trắng rồi băm FNV-1a 32-bit. Lệch một chi tiết là không khớp đoạn nào và
// bản dịch biến mất sạch mà KHÔNG có lỗi nào.
//
// ⚠️ Bản dịch đi qua CẦU MESSAGE, không để JS `fetch`. File dịch 771 KB cho
// cả cuốn; một chương chỉ cần vài trăm khối. JS gửi danh sách hash nó cần,
// Swift tra rồi gửi lại đúng chừng ấy (~40 KB).
//
// ⚠️ Chương chưa dịch tựa là chuyện của DỮ LIỆU, không phải lỗi ở đây:
// `section.chap-open` nằm NGOÀI `.col`, mà bộ rút khối của web chỉ quét
// `.col`, nên `h1.chap-title` / `p.chap-deck` / `.eyebrow` chưa bao giờ được
// đưa đi dịch (đo tập 25: tựa 2/24, câu dẫn 0/24).
// ════════════════════════════════════════════════════════════════

enum CheDoChu: String, CaseIterable {
    case anh = "en", song = "bi", viet = "vi"
    var nhan: String {
        switch self {
        case .anh: return "EN"
        case .song: return T("Song ngữ")
        case .viet: return "VI"
        }
    }
}

struct DocSachView: View {
    let sach: Sach

    @AppStorage("sach.cheDoChu") private var maCheDo = CheDoChu.anh.rawValue
    @State private var kho: SachDaCat?
    /// 0 = bìa + trang đầu + mục lục; 1…n = chương thứ (phan-1).
    ///
    /// Nhớ theo TỪNG CUỐN. Sách 800 trang mà mỗi lần mở lại quay về bìa thì
    /// không ai đọc hết được.
    @State private var phan = 0
    @State private var hienMucLuc = false
    @State private var tienDoCuon: Double = 0
    @State private var dangTai = true
    @State private var loi: String?
    @State private var moSafari = false

    private var cheDo: CheDoChu { CheDoChu(rawValue: maCheDo) ?? .anh }
    private var mucLuc: [MucLucSach] { kho?.mucLuc ?? [] }
    private var soChuong: Int { kho?.chuong.count ?? 0 }

    /// Tiến độ cả cuốn = chương đang đọc + phần đã cuộn trong chương đó.
    private var tienDo: Double {
        guard soChuong > 0 else { return 0 }
        let tong = Double(soChuong + 1)
        return min(1, (Double(phan) + tienDoCuon) / tong)
    }

    private var tuaPhan: String {
        guard phan > 0, let k = kho, phan - 1 < k.chuong.count else { return T("Mở đầu") }
        let so = k.chuong[phan - 1].so
        if let m = mucLuc.first(where: { $0.id == so }) { return m.hien(cheDo) }
        return T("Chương") + " \(so)"
    }

    var body: some View {
        ZStack(alignment: .top) {
            if let k = kho {
                VStack(spacing: 0) {
                    KhungSach(trang: trangHTML(k),
                              // Đổi `phan` phải dựng lại; đổi chế độ chữ thì
                              // KHÔNG — chỉ bật/tắt lớp CSS, giữ nguyên chỗ đọc.
                              khoaDung: "\(sach.slug)#\(phan)",
                              cheDo: cheDo,
                              dich: k.dich,
                              xinNhay: { nhayToi($0) },
                              tienDo: $tienDoCuon,
                              dangTai: $dangTai,
                              loi: $loi)
                    thanhChuyenChuong
                }
            }
            GeometryReader { g in
                Rectangle()
                    .fill(sach.mau)
                    .frame(width: g.size.width * tienDo, height: 2.5)
            }
            .frame(height: 2.5)

            if let l = loi {
                loiView(l)
            } else if dangTai {
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text(T("Đang mở sách…"))
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
            // Tập tiếng Việt gốc không có bản dịch — bày ra nút EN/VI bấm
            // vào không đổi gì thì tệ hơn là không có nút.
            if sach.coSongNgu {
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
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { hienMucLuc = true } label: { Image(systemName: "list.bullet") }
                    .disabled(mucLuc.isEmpty)
            }
        }
        .task { await nap() }
        .onChange(of: phan) { _, m in
            UserDefaults.standard.set(m, forKey: "sach.dangDoc.\(sach.slug)")
        }
        .fullScreenCover(isPresented: $moSafari) {
            if let u = sach.duongSach { KhungSafari(duong: u).ignoresSafeArea() }
        }
        .sheet(isPresented: $hienMucLuc) {
            MucLucSachView(mucLuc: mucLuc, mau: sach.mau, cheDo: cheDo,
                           dangDoc: kho.map { phan > 0 ? $0.chuong[phan - 1].so : "" } ?? "") { m in
                hienMucLuc = false
                nhayToi(m.id)
            }
        }
    }

    // MARK: Thanh chuyển chương

    @ViewBuilder private var thanhChuyenChuong: some View {
        if soChuong > 0 {
            HStack(spacing: Spacing.md) {
                nut(hinh: "chevron.left", nhan: T("Trước"), bat: phan > 0) { doiPhan(phan - 1) }
                VStack(spacing: 1) {
                    Text(tuaPhan)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    Text("\(phan + 1)/\(soChuong + 1)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                nut(hinh: "chevron.right", nhan: T("Sau"), bat: phan < soChuong) { doiPhan(phan + 1) }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.backgroundSecondary)
            .overlay(Rectangle().frame(height: 0.5).foregroundColor(AppColors.border), alignment: .top)
        }
    }

    @ViewBuilder
    private func nut(hinh: String, nhan: String, bat: Bool, lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            HStack(spacing: 3) {
                if hinh == "chevron.left" { Image(systemName: hinh) }
                Text(nhan).font(.system(size: 13, weight: .semibold))
                if hinh == "chevron.right" { Image(systemName: hinh) }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(bat ? sach.mau : AppColors.textTertiary.opacity(0.5))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
        }
        .disabled(!bat)
    }

    @ViewBuilder private func loiView(_ l: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40)).foregroundColor(AppColors.textTertiary)
            Text(T("Không mở được sách"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(l)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.md) {
                Button(T("Thử lại")) {
                    loi = nil; dangTai = true
                    KhoSachCucBo.xoa(sach)
                    Task { await nap() }
                }
                .font(.system(size: 14, weight: .semibold))
                Button(T("Mở bằng trình duyệt")) { moSafari = true }
                    .font(.system(size: 14))
            }
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundPrimary)
    }

    // MARK: Việc

    private func nap() async {
        do {
            let k = try await KhoSachCucBo.nap(sach)
            let cu = UserDefaults.standard.integer(forKey: "sach.dangDoc.\(sach.slug)")
            await MainActor.run {
                kho = k
                if cu > 0, cu <= k.chuong.count { phan = cu }
                loi = k.chuong.isEmpty
                    ? T("Cuốn này không cắt được theo chương. Mở bằng trình duyệt để đọc tạm.")
                    : nil
            }
        } catch {
            await MainActor.run {
                dangTai = false
                loi = T("Chưa tải được cuốn này. Kiểm tra mạng rồi thử lại — tải xong một lần là đọc được cả khi không có mạng.")
            }
        }
    }

    private func doiPhan(_ p: Int) {
        guard p >= 0, p <= soChuong, p != phan else { return }
        dangTai = true
        tienDoCuon = 0
        phan = p
    }

    private func nhayToi(_ soChuong: String) {
        guard let k = kho, let i = k.chuong.firstIndex(where: { $0.so == soChuong }) else { return }
        doiPhan(i + 1)
    }

    /// Ghép trang cho `WKWebView`: `<head>` của sách (mang toàn bộ CSS) + đúng
    /// một phần thân.
    private func trangHTML(_ k: SachDaCat) -> String {
        let than: String
        if phan == 0 {
            than = k.mo
        } else if phan - 1 < k.chuong.count {
            than = k.chuong[phan - 1].html
        } else {
            than = k.mo
        }
        // `k.mo` bắt đầu bằng chính thẻ `<body …>` của sách (giữ nguyên để
        // không mất class/thuộc tính chủ đề của nó); các chương thì không.
        // `k.mo` bắt đầu bằng chính thẻ `<body …>` nhưng KHÔNG có thẻ đóng
        // (chỗ cắt nằm giữa thân), nên phải tự đóng lại.
        let mo = phan == 0 ? "\(than)\n</body>" : "<body>\n\(than)\n</body>"
        return "<!DOCTYPE html><html lang=\"en\">\(k.dau)\(mo)</html>"
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
    let dangDoc: String
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
                            .font(.system(size: 15, weight: m.id == dangDoc ? .semibold : .regular))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if m.id == dangDoc {
                            Image(systemName: "book.fill")
                                .font(.system(size: 11)).foregroundColor(mau)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(T("Mục lục") + " (\(mucLuc.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Đóng")) { dong() }
                }
            }
        }
    }
}

// MARK: - WKWebView dựng MỘT phần sách

private struct KhungSach: UIViewRepresentable {
    let trang: String
    /// Đổi khoá ⇒ dựng lại. Chế độ chữ KHÔNG nằm trong khoá, nên đổi EN/VI
    /// không làm mất chỗ đang đọc.
    let khoaDung: String
    let cheDo: CheDoChu
    let dich: [String: String]
    /// Bấm một hàng mục lục in trong trang → nhảy chương bằng SwiftUI.
    let xinNhay: ((String) -> Void)?
    @Binding var tienDo: Double
    @Binding var dangTai: Bool
    @Binding var loi: String?

    func makeCoordinator() -> Dieu { Dieu(self) }

    func makeUIView(context: Context) -> WKWebView {
        let c = WKWebViewConfiguration()
        c.allowsInlineMediaPlayback = true
        let u = WKUserContentController()
        u.add(context.coordinator, name: "sach")
        c.userContentController = u

        let v = WKWebView(frame: .zero, configuration: c)
        v.navigationDelegate = context.coordinator
        v.isOpaque = false
        v.backgroundColor = .clear
        v.scrollView.backgroundColor = .clear
        v.scrollView.delegate = context.coordinator
        v.scrollView.contentInsetAdjustmentBehavior = .always
        context.coordinator.web = v
        return v
    }

    func updateUIView(_ v: WKWebView, context: Context) {
        context.coordinator.cha = self
        if context.coordinator.khoaDaDung != khoaDung {
            context.coordinator.khoaDaDung = khoaDung
            context.coordinator.daGuiDich = false
            v.loadHTMLString(trang, baseURL: URL(string: "https://cuongthai.com/books/"))
        } else {
            v.evaluateJavaScript("window.ctsDatCheDo && ctsDatCheDo('\(cheDo.rawValue)')")
        }
    }

    final class Dieu: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIScrollViewDelegate {
        var cha: KhungSach
        weak var web: WKWebView?
        var khoaDaDung: String?
        var daGuiDich = false
        private var soLanChet = 0

        init(_ c: KhungSach) { cha = c }

        func webView(_ v: WKWebView, didFinish nav: WKNavigation!) {
            soLanChet = 0
            v.evaluateJavaScript(Dieu.kichBan(cheDo: cha.cheDo.rawValue)) { _, e in
                if let e { NhatKy.sach.error("kịch bản hỏng: \(e.localizedDescription)") }
            }
            Task { @MainActor in
                cha.dangTai = false
                cha.tienDo = 0
            }
        }

        func webView(_ v: WKWebView, didFail nav: WKNavigation!, withError e: Error) { bao(e) }
        func webView(_ v: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError e: Error) { bao(e) }
        private func bao(_ e: Error) {
            NhatKy.sach.error("dựng hỏng: \(e.localizedDescription)")
            Task { @MainActor in cha.dangTai = false }
        }

        // ⚠️ Với một chương ~60 KB thì đây gần như không còn xảy ra. Giữ lại
        // làm lưới đỡ, và giữ luôn cái CHẶN: tải lại vô điều kiện trong hàm
        // này chính là thứ đã tạo ra vòng lặp "xoay → hiện → xoay" hôm 26/08.
        func webViewWebContentProcessDidTerminate(_ v: WKWebView) {
            soLanChet += 1
            NhatKy.sach.error("tiến trình nội dung bị giết lần \(soLanChet)")
            guard soLanChet < 2 else {
                Task { @MainActor in
                    cha.dangTai = false
                    cha.loi = T("Chương này quá nặng so với bộ nhớ còn trống. Đóng bớt ứng dụng khác rồi thử lại.")
                }
                return
            }
            daGuiDich = false
            Task { @MainActor in cha.dangTai = true; cha.loi = nil }
            v.loadHTMLString(cha.trang, baseURL: URL(string: "https://cuongthai.com/books/"))
        }

        func scrollViewDidScroll(_ s: UIScrollView) {
            let cao = s.contentSize.height - s.bounds.height
            guard cao > 1 else { return }
            let t = min(1, max(0, s.contentOffset.y / cao))
            if abs(t - cha.tienDo) > 0.004 { Task { @MainActor in cha.tienDo = t } }
        }

        func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
            guard let d = m.body as? [String: Any] else { return }
            if let l = d["loiJS"] as? String {
                NhatKy.sach.error("JS: \(l)")
                return
            }
            // JS gửi lên danh sách hash nó cần — Swift tra rồi gửi lại ĐÚNG
            // chừng ấy. Cả cuốn 771 KB, một chương chỉ vài chục KB.
            if let so = d["nhay"] as? String {
                Task { @MainActor in cha.xinNhay?(so) }
                return
            }
            if let can = d["can"] as? [String], !daGuiDich {
                daGuiDich = true
                var bang: [String: String] = [:]
                bang.reserveCapacity(can.count)
                for h in can { if let v = cha.dich[h] { bang[h] = v } }
                guard let js = try? JSONSerialization.data(withJSONObject: bang),
                      let chu = String(data: js, encoding: .utf8) else { return }
                NhatKy.sach.info("dịch: khớp \(bang.count)/\(can.count) khối")
                web?.evaluateJavaScript("window.ctsNhanDich && ctsNhanDich(\(chu))")
            }
        }

        /// Phần chèn vào trang.
        ///
        /// ⚠️ `bam` phải GIỐNG HỆT `hashBlockText` của web (FNV-1a 32-bit,
        /// `Math.imul`, hex 8 ký tự). Đổi một phép toán là không khớp đoạn nào.
        static func kichBan(cheDo: String) -> String { """
        (function () {
          if (window.ctsDaGan) { ctsDatCheDo('\(cheDo)'); return; }
          window.ctsDaGan = true;
          function bao(e) {
            try { webkit.messageHandlers.sach.postMessage({ loiJS: String(e && e.message || e) }); } catch (x) {}
          }
          window.addEventListener('error', function (ev) { bao(ev.message); });
          try {

          var st = document.createElement('style');
          st.textContent = [
            'html { -webkit-text-size-adjust: 100%; }',
            '.cv-back, .book-nav, .toc-back { display: none !important; }',
            /* Cột chữ của sách (74ch, canh trái trong .page 1080px) hẹp và
               lệch trên điện thoại — nới ra dùng hết bề ngang. */
            '.page, .fm, .chap { max-width: none !important; }',
            '.col { max-width: none !important; margin: 0 auto !important;',
            '       width: auto !important; padding-left: 16px !important;',
            '       padding-right: 16px !important; }',
            '.chap-open { padding-left: 16px !important; padding-right: 16px !important; }',
            /* ⚠️ `overflow-x` đặt thẳng lên <table> KHÔNG tạo vùng cuộn — thẻ
               table không phải khối cuộn được. Phải BỌC nó (xem bocBangCuon).
               `pre`/`.terminal` là khối nên đặt thẳng được. */
            'pre, .terminal { max-width: 100%; overflow-x: auto; }',
            '.ctsCuon { max-width: 100%; overflow-x: auto; -webkit-overflow-scrolling: touch; }',
            '.ctsCuon > table { max-width: none; }',
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
          function gon(s) { return (s || '').replace(/\\s+/g, ' ').trim(); }

          /* Bảng phải cuộn ngang được, không thì tràn và kéo lệch cả trang. */
          function bocBangCuon() {
            document.querySelectorAll('table').forEach(function (t) {
              var p = t.parentElement;
              if (p && p.classList.contains('ctsCuon')) return;
              var box = document.createElement('div');
              box.className = 'ctsCuon';
              t.parentNode.insertBefore(box, t);
              box.appendChild(t);
            });
          }
          bocBangCuon();

          /* ── Xin bản dịch ────────────────────────────────────────
             Gửi lên hash của mọi khối trong CHƯƠNG NÀY, Swift tra rồi
             gửi lại. Không `fetch` file 771 KB của cả cuốn. */
          var khoi = layKhoi(), hash = [];
          for (var i = 0; i < khoi.length; i++) {
            var h = bam(gon(khoi[i].textContent));
            khoi[i].setAttribute('data-cts-h', h);
            hash.push(h);
          }
          try { webkit.messageHandlers.sach.postMessage({ can: hash }); } catch (x) {}

          /* Mục lục IN TRONG TRANG: các hàng `.toc-row` không phải thẻ <a>,
             bấm vào không có gì xảy ra — người đọc thấy một mục lục chết ngay
             trang đầu. Nối nó vào bộ nhảy chương của app. */
          document.querySelectorAll('.toc-row').forEach(function (r) {
            var n = r.querySelector('.toc-n');
            if (!n) return;
            r.style.cursor = 'pointer';
            r.addEventListener('click', function () {
              try {
                webkit.messageHandlers.sach.postMessage({ nhay: gon(n.textContent) });
              } catch (x) {}
            });
          });

          window.ctsNhanDich = function (bang) {
            /* Chèn theo MẺ. Chèn hết một lượt trên chương 70 KB làm đơ
               khung hình thấy rõ; 150 khối mỗi nhịp vẽ thì mượt. */
            var ds = [];
            for (var i = 0; i < khoi.length; i++) {
              var v = bang[khoi[i].getAttribute('data-cts-h')];
              if (v) ds.push([khoi[i], v]);
            }
            var k = 0;
            function meKe() {
              var het = Math.min(k + 150, ds.length);
              for (; k < het; k++) chenMot(ds[k][0], ds[k][1]);
              if (k < ds.length) requestAnimationFrame(meKe);
            }
            requestAnimationFrame(meKe);
          };

          function chenMot(el, vi) {
            if (el.getAttribute('data-cts-xong')) return;
            el.setAttribute('data-cts-xong', '1');
            /* Bọc phần tiếng Anh để chế độ VI ẩn được nó đi. */
            var en = document.createElement('span');
            en.className = 'ctsEn';
            while (el.firstChild) en.appendChild(el.firstChild);
            el.appendChild(en);
            var vn = document.createElement('span');
            vn.className = 'ctsVi';
            /* ⚠️ `innerHTML`, KHÔNG phải `textContent`: bản dịch có <code>,
               <strong>… đặt bằng textContent thì thẻ hiện ra dạng chữ. */
            vn.innerHTML = vi;
            el.appendChild(vn);
          }

          window.ctsDatCheDo = function (m) {
            document.body.classList.remove('cts-bi', 'cts-vi');
            if (m === 'bi') document.body.classList.add('cts-bi');
            if (m === 'vi') document.body.classList.add('cts-vi');
          };
          ctsDatCheDo('\(cheDo)');

          } catch (e) { bao(e); }
        })();
        """ }
    }
}

// MARK: - Safari (đường lùi cuối)

struct KhungSafari: UIViewControllerRepresentable {
    let duong: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: duong)
    }
    func updateUIViewController(_ v: SFSafariViewController, context: Context) {}
}
