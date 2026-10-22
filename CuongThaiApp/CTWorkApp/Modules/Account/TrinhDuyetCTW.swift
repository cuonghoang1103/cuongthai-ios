import SwiftUI
import WebKit

// MARK: - Mở trang web trong app — có CHỐT 3.1.1 (18/10/2026)
//
// Vì sao không còn dùng SFSafariViewController cho cuongthai.com: trang web CT Work có nút "Upgrade to Pro"
// (`/pro`) ở bảng AI, trang agent, báo cáo tuần… (`frontend/src/components/work/ai/UpgradeDialog.tsx`,
// `agents/BuiltinBits.tsx`, `reports/WeeklyReportTab.tsx`). SFSafariViewController không cho chặn điều hướng
// ⇒ reviewer bấm một lần là tới trang mua ngoài IAP ⇒ trả về theo 3.1.1. Ở đây:
//   1. CHẶN điều hướng tới mọi đường mua/nâng cấp (`laDuongMua`) — kể cả khi trang tự chuyển hướng;
//   2. ẨN mọi liên kết/nút trỏ tới các đường đó bằng CSS + MutationObserver (`kichBanAn`);
//   3. KHÔNG nói "mua trên web" ở bất kỳ đâu (3.1.1 cấm cả lời gợi ý).
// Trang NGOÀI cuongthai.com (link người dùng dán, EULA của Apple) vẫn mở bằng trình duyệt hệ thống.
// Lối web chung "Open CT Work on the web" ĐÃ GỠ khỏi app; chỉ còn lối web cho đúng một tính năng nặng.
//
// ⚠️ Build 7 (22/10/2026, audit B4b) — từ CHẶN-DANH-SÁCH-ĐEN sang DANH SÁCH TRẮNG. Build 6 mở mọi trang cuongthai.com
// trong khung này trừ vài đường mua ⇒ chân trang "Điều khoản" có `/huong-dan-mua-hang`, `/chinh-sach-thanh-toan`
// (PayOS/VNPay, giá) lọt vào app. Nay `cachMo(_:)` là luật DUY NHẤT (có kiểm thử — SuaLoiBuild7Tests):
//   · `.chan`     — đường mua/nâng cấp/thanh toán/giá/Pro/khoá học bán (`laDuongMua`) ở BẤT KỲ đâu: không mở, ẩn link;
//   · `.trongApp` — cuongthai.com thuộc `duongChoPhep` (pháp lý, giới thiệu/hỗ trợ, /work…, quên mật khẩu, OTP,
//                   đăng nhập web cho /work, hướng dẫn CT Work);
//   · `.safari`   — mọi trang cuongthai.com khác + mọi trang ngoài ⇒ trình duyệt hệ thống, KHÔNG lướt trong app.
// Trang web là ứng dụng Next.js: chuyển trang phía khách (`pushState`) KHÔNG đi qua `decidePolicyFor` ⇒ chặn thêm hai
// lớp: kịch bản bắt cú chạm link (`kichBanAn`) + theo dõi `WKWebView.url` (KVO) — URL ra ngoài danh sách thì lùi lại.

struct SafariCTW: View {
    let url: URL

    var body: some View {
        switch TrinhDuyetCuongThaiCTW.cachMo(url) {
        case .trongApp: TrinhDuyetCuongThaiCTW(url: url)
        case .safari:
            // Trang ngoài ⇒ SFSafariViewController như cũ. Trang cuongthai.com NGOÀI danh sách trắng ⇒ Safari của hệ thống
            // (SFSafariViewController không chặn được điều hướng — từ đó bấm tới /pro là trang mua trong app).
            if TrinhDuyetCuongThaiCTW.laCuaCuongThai(url) { MoSafariHeThongCTW(url: url) } else { SafariGocCTW(url: url) }
        case .chan: TrangBiChanCTW()
        }
    }
}

/// Mở trong Safari của hệ thống rồi tự đóng tấm phủ (dùng được ở mọi `.sheet { SafariCTW(...) }` sẵn có).
struct MoSafariHeThongCTW: View {
    let url: URL
    @Environment(\.dismiss) private var dong
    @Environment(\.openURL) private var moURL

    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.backgroundPrimary)
            .task {
                moURL(url)
                try? await Task.sleep(for: .milliseconds(250))
                dong()
            }
    }
}

/// Đường mua bị chặn: không mở, không nói "mua trên web" (3.1.1).
struct TrangBiChanCTW: View {
    @Environment(\.dismiss) private var dong
    var body: some View {
        NavigationStack {
            CTWOTrong(bieuTuong: "nosign", tieuDe: String(localized: "Not available in the app"),
                      moTa: String(localized: "This page can't be opened in CT Work."))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } } }
        }
    }
}

struct TrinhDuyetCuongThaiCTW: View {
    let url: URL
    @Environment(\.dismiss) private var dong
    @State private var tieuDe = ""
    @State private var dangTai = true

    enum CachMo: Equatable { case trongApp, safari, chan }

    static func laCuaCuongThai(_ u: URL) -> Bool {
        guard let h = u.host?.lowercased() else { return false }
        let goc = URL(string: APIClient.diaChiGoc)?.host?.lowercased() ?? "cuongthai.com"
        return h == goc || h == "cuongthai.com" || h.hasSuffix(".cuongthai.com")
    }

    /// Hướng dẫn dùng CT Work (khoá miễn phí `huong-dan-ct-work`, web `components/work/help/videos.ts › CTW_COURSE_HREF`).
    static let huongDan = "/courses/huong-dan-ct-work"

    /// DANH SÁCH TRẮNG — trang cuongthai.com được mở NGAY TRONG app. `(đường, gồm trang con)`.
    static let duongChoPhep: [(String, Bool)] = [
        ("/chinh-sach-bao-mat", false),   // Chính sách bảo mật
        ("/dieu-khoan-su-dung", false),   // Điều khoản sử dụng
        ("/about", false),                // Giới thiệu + liên hệ (Support URL) — KHÔNG gồm /about/* (trang portfolio)
        ("/work", true),                  // CT Work web (mở một tính năng nặng)
        ("/login", false),                // /work chưa có phiên web ⇒ máy chủ 307 sang /login?redirect=/work/…
        ("/forgot-password", false),
        ("/verify-otp", false),
        ("/reset-password", false),       // bước cuối của "Quên mật khẩu" (link trong email)
        (huongDan, true),
    ]

    /// Đường dẫn của trang mua / nâng cấp / thanh toán / giá / Pro / cửa hàng — KHÔNG được mở (kể cả ra Safari).
    static let duongMua = ["/pro", "/pricing", "/upgrade", "/checkout", "/nang-cap", "/thanh-toan", "/goi", "/billing",
                           "/payment", "/vi-diem", "/wallet", "/cart", "/shop", "/my-orders", "/courses",
                           "/huong-dan-mua-hang", "/chinh-sach-thanh-toan", "/chinh-sach-doi-tra", "/chinh-sach-giao-hang"]
    static let mienThanhToan = ["vnpay", "momo", "stripe", "paypal", "zalopay", "payos", "sepay"]

    private static func khop(_ p: String, _ goc: String, con: Bool = true) -> Bool {
        p == goc || (con && p.hasPrefix(goc + "/"))
    }

    /// Đường chuẩn hoá: gỡ `.`/`..` (`/work/../pro` KHÔNG được lọt danh sách trắng), chữ thường, bỏ "/" cuối (trừ gốc).
    private static func duong(_ u: URL) -> String {
        var p = u.standardized.path.lowercased()
        while p.count > 1, p.hasSuffix("/") { p.removeLast() }
        return p.isEmpty ? "/" : p
    }

    static func laDuongMua(_ u: URL) -> Bool {
        let h = (u.host ?? "").lowercased()
        if mienThanhToan.contains(where: { h.contains($0) }) { return true }
        // Đường mua chỉ tính trên cuongthai.com (hoặc đường tương đối) — "/pro" của trang khác không liên quan.
        guard u.host == nil || laCuaCuongThai(u) else { return false }
        let p = duong(u)
        if khop(p, huongDan) { return false }   // hướng dẫn CT Work miễn phí nằm dưới /courses
        return duongMua.contains { khop(p, $0) }
    }

    static func choPhepTrongApp(_ u: URL) -> Bool {
        guard ["http", "https"].contains(u.scheme?.lowercased() ?? ""), laCuaCuongThai(u), !laDuongMua(u) else { return false }
        let p = duong(u)
        return duongChoPhep.contains { khop(p, $0.0, con: $0.1) }
    }

    /// Luật DUY NHẤT: URL này mở ở đâu.
    static func cachMo(_ u: URL) -> CachMo {
        if laDuongMua(u) { return .chan }
        if choPhepTrongApp(u) { return .trongApp }
        guard let s = u.scheme?.lowercased(), ["http", "https", "mailto", "tel"].contains(s) else { return .chan }
        return .safari
    }

    var body: some View {
        NavigationStack {
            WebKhungCTW(url: url, tieuDe: $tieuDe, dangTai: $dangTai)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(tieuDe.isEmpty ? "CT Work" : tieuDe)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } }
                    if dangTai { ToolbarItem(placement: .topBarLeading) { ProgressView() } }
                }
        }
    }

    /// Chuỗi JS của một mảng đường.
    private static func js(_ a: [String]) -> String {
        "[" + a.map { "'\($0)'" }.joined(separator: ",") + "]"
    }

    /// (1) ẨN mọi liên kết/nút trỏ tới đường mua (chạy lại mỗi khi DOM đổi — trang là ứng dụng React).
    /// (2) Khung CHÍNH: chạm một link NGOÀI danh sách trắng ⇒ chặn trước khi router của Next.js kịp `pushState`,
    ///     link thường ⇒ nhờ app mở bằng Safari (`ctwMoNgoai`), link mua ⇒ bỏ qua.
    static var kichBanAn: String {
        let mua = js(duongMua), cho = js(duongChoPhep.filter { !$0.1 }.map(\.0)), choCon = js(duongChoPhep.filter(\.1).map(\.0))
        let tt = js(mienThanhToan)
        return """
        (function(){
          var P=\(mua), C=\(cho), CC=\(choCon), T=\(tt), HD='\(huongDan)';
          function u_(h){ try{ return new URL(h, location.href); }catch(e){ return null; } }
          function ct(u){ var h=u.hostname.toLowerCase(); return h===location.hostname.toLowerCase() || h==='cuongthai.com' || /\\.cuongthai\\.com$/.test(h); }
          function dg(u){ var p=u.pathname.toLowerCase().replace(/\\/+$/,''); return p||'/'; }
          function k(p,x,con){ return p===x || (con && p.indexOf(x+'/')===0); }
          function laMua(u){ if(!u) return false; var h=u.hostname.toLowerCase();
            if(T.some(function(x){ return h.indexOf(x)>=0; })) return true;
            if(!ct(u)) return false; var p=dg(u); if(k(p,HD,true)) return false;
            return P.some(function(x){ return k(p,x,true); }); }
          function choPhep(u){ if(!u || !/^https?:$/.test(u.protocol) || !ct(u) || laMua(u)) return false; var p=dg(u);
            return C.some(function(x){ return k(p,x,false); }) || CC.some(function(x){ return k(p,x,true); }); }
          function an(){ document.querySelectorAll('a[href],[data-href]').forEach(function(a){
            if(laMua(u_(a.getAttribute('href')||a.getAttribute('data-href')))){ a.style.setProperty('display','none','important'); } }); }
          an(); new MutationObserver(an).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['href']});
          if(window.top!==window) return;
          document.addEventListener('click', function(e){
            var a=e.target && e.target.closest ? e.target.closest('a[href]') : null; if(!a) return;
            var u=u_(a.getAttribute('href')); if(!u || choPhep(u)) return;
            if(!/^(https?|mailto|tel):$/.test(u.protocol)) return;
            e.preventDefault(); e.stopImmediatePropagation();
            if(!laMua(u)){ try{ window.webkit.messageHandlers.ctwMoNgoai.postMessage(u.href); }catch(x){} }
          }, true);
        })();
        """
    }
}

private struct WebKhungCTW: UIViewRepresentable {
    let url: URL
    @Binding var tieuDe: String
    @Binding var dangTai: Bool

    func makeCoordinator() -> DieuPhoi { DieuPhoi(self) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.addUserScript(WKUserScript(source: TrinhDuyetCuongThaiCTW.kichBanAn,
                                                             injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        // Proxy yếu: userContentController giữ MẠNH handler ⇒ giữ thẳng coordinator là vòng giữ nhau với WKWebView.
        cfg.userContentController.add(ProxyTinNhanCTW(context.coordinator), name: "ctwMoNgoai")
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.navigationDelegate = context.coordinator
        w.uiDelegate = context.coordinator
        w.allowsBackForwardNavigationGestures = true
        context.coordinator.theoDoi(w)
        w.load(URLRequest(url: url))
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) {}

    static func dismantleUIView(_ w: WKWebView, coordinator: DieuPhoi) {
        coordinator.quanSat = nil
        w.configuration.userContentController.removeScriptMessageHandler(forName: "ctwMoNgoai")
    }

    /// Mở ngoài app bằng Safari của hệ thống (đường mua thì không bao giờ).
    @MainActor static func moNgoai(_ u: URL) {
        guard TrinhDuyetCuongThaiCTW.cachMo(u) == .safari else { return }
        UIApplication.shared.open(u)
    }

    final class ProxyTinNhanCTW: NSObject, WKScriptMessageHandler {
        weak var dich: DieuPhoi?
        init(_ d: DieuPhoi) { dich = d }
        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
            dich?.nhan(m)
        }
    }

    final class DieuPhoi: NSObject, WKNavigationDelegate, WKUIDelegate {
        let cha: WebKhungCTW
        var quanSat: NSKeyValueObservation?
        /// URL cuối cùng THUỘC danh sách trắng mà khung đã hiện — chuyển trang phía khách đi lạc thì quay về đây.
        private var cuoiHopLe: URL?
        init(_ c: WebKhungCTW) { cha = c; cuoiHopLe = TrinhDuyetCuongThaiCTW.choPhepTrongApp(c.url) ? c.url : nil }

        /// Next.js đổi trang bằng `pushState` — KHÔNG đi qua `decidePolicyFor`. Theo dõi `url`: ra ngoài danh sách trắng
        /// ⇒ (không phải đường mua) mở Safari + lùi lại trang hợp lệ trước đó.
        func theoDoi(_ w: WKWebView) {
            quanSat = w.observe(\.url, options: [.new]) { [weak self] w, _ in
                Task { @MainActor in self?.kiemUrl(w) }
            }
        }

        @MainActor private func kiemUrl(_ w: WKWebView) {
            guard let u = w.url, ["http", "https"].contains(u.scheme?.lowercased() ?? "") else { return }
            switch TrinhDuyetCuongThaiCTW.cachMo(u) {
            case .trongApp: cuoiHopLe = u
            case .safari, .chan:
                WebKhungCTW.moNgoai(u)
                if w.canGoBack { w.goBack() } else if let l = cuoiHopLe { w.load(URLRequest(url: l)) } else { w.stopLoading() }
            }
        }

        /// Kịch bản trang báo một cú chạm link ngoài danh sách trắng (chỉ nhận từ khung CHÍNH của cuongthai.com).
        @MainActor func nhan(_ m: WKScriptMessage) {
            guard m.frameInfo.isMainFrame, let goc = m.frameInfo.request.url, TrinhDuyetCuongThaiCTW.laCuaCuongThai(goc),
                  let s = m.body as? String, let u = URL(string: s) else { return }
            WebKhungCTW.moNgoai(u)
        }

        func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let u = a.request.url else { decisionHandler(.cancel); return }
            let chinh = a.targetFrame?.isMainFrame ?? true
            switch TrinhDuyetCuongThaiCTW.cachMo(u) {
            case .chan:
                // about:blank / data: của khung con (nhúng video…) vẫn cho; đường mua thì không bao giờ.
                let s = u.scheme?.lowercased() ?? ""
                decisionHandler(!chinh && !TrinhDuyetCuongThaiCTW.laDuongMua(u) && ["about", "data", "blob"].contains(s) ? .allow : .cancel)
            case .trongApp:
                decisionHandler(.allow)
            case .safari:
                // Khung con (YouTube nhúng trong Docs…) được tải tại chỗ; khung CHÍNH rời danh sách trắng ⇒ Safari.
                if !chinh { decisionHandler(.allow); return }
                WebKhungCTW.moNgoai(u)
                decisionHandler(.cancel)
            }
        }

        /// `target=_blank` / `window.open` ⇒ trang trong danh sách trắng mở trong cùng khung, còn lại ⇒ Safari.
        func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let u = a.request.url else { return nil }
            switch TrinhDuyetCuongThaiCTW.cachMo(u) {
            case .trongApp: w.load(URLRequest(url: u))
            case .safari: WebKhungCTW.moNgoai(u)
            case .chan: break
            }
            return nil
        }

        func webView(_ w: WKWebView, didStartProvisionalNavigation n: WKNavigation!) { cha.dangTai = true }
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) { cha.dangTai = false; cha.tieuDe = w.title ?? "" }
        func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { cha.dangTai = false }
        func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { cha.dangTai = false }
    }
}
