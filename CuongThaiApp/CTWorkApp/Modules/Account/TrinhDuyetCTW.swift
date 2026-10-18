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

struct SafariCTW: View {
    let url: URL

    var body: some View {
        if TrinhDuyetCuongThaiCTW.laCuaCuongThai(url) {
            TrinhDuyetCuongThaiCTW(url: url)
        } else {
            SafariGocCTW(url: url)
        }
    }
}

struct TrinhDuyetCuongThaiCTW: View {
    let url: URL
    @Environment(\.dismiss) private var dong
    @State private var tieuDe = ""
    @State private var dangTai = true

    static func laCuaCuongThai(_ u: URL) -> Bool {
        guard let h = u.host?.lowercased() else { return false }
        let goc = URL(string: APIClient.diaChiGoc)?.host?.lowercased() ?? "cuongthai.com"
        return h == goc || h == "cuongthai.com" || h.hasSuffix(".cuongthai.com")
    }

    /// Đường dẫn của trang mua / nâng cấp / thanh toán gói — KHÔNG được mở trong app iOS.
    static func laDuongMua(_ u: URL) -> Bool {
        let p = u.path.lowercased()
        let tien = ["/pro", "/pricing", "/upgrade", "/checkout", "/nang-cap", "/thanh-toan", "/goi", "/billing", "/payment", "/vi-diem", "/wallet"]
        if tien.contains(where: { p == $0 || p.hasPrefix($0 + "/") }) { return true }
        let ngoai = ["vnpay", "momo", "stripe", "paypal", "zalopay", "payos", "sepay"]
        return ngoai.contains { (u.host ?? "").lowercased().contains($0) }
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

    /// Ẩn liên kết/nút trỏ tới đường mua (chạy lại mỗi khi DOM đổi — trang là ứng dụng React).
    static let kichBanAn = """
    (function(){
      var P=['/pro','/pricing','/upgrade','/checkout','/nang-cap','/thanh-toan','/billing','/payment'];
      function laMua(h){ if(!h) return false; try{ var u=new URL(h, location.href); var p=u.pathname.toLowerCase();
        return P.some(function(x){ return p===x || p.indexOf(x+'/')===0; }); }catch(e){ return false; } }
      function an(){ document.querySelectorAll('a[href],[data-href]').forEach(function(a){
        if(laMua(a.getAttribute('href')||a.getAttribute('data-href'))){ a.style.setProperty('display','none','important'); } }); }
      an(); new MutationObserver(an).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['href']});
    })();
    """
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
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.navigationDelegate = context.coordinator
        w.uiDelegate = context.coordinator
        w.allowsBackForwardNavigationGestures = true
        w.load(URLRequest(url: url))
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) {}

    final class DieuPhoi: NSObject, WKNavigationDelegate, WKUIDelegate {
        let cha: WebKhungCTW
        init(_ c: WebKhungCTW) { cha = c }

        func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let u = a.request.url else { decisionHandler(.cancel); return }
            if TrinhDuyetCuongThaiCTW.laDuongMua(u) { decisionHandler(.cancel); return }
            // Rời cuongthai.com (link ngoài trong tài liệu…) ⇒ trình duyệt hệ thống, không lướt tiếp trong khung này.
            if ["http", "https"].contains(u.scheme?.lowercased() ?? ""), !TrinhDuyetCuongThaiCTW.laCuaCuongThai(u),
               a.navigationType == .linkActivated {
                UIApplication.shared.open(u)
                decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }

        /// `target=_blank` / `window.open` ⇒ mở trong cùng khung (vẫn qua chốt trên).
        func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let u = a.request.url, !TrinhDuyetCuongThaiCTW.laDuongMua(u) { w.load(URLRequest(url: u)) }
            return nil
        }

        func webView(_ w: WKWebView, didStartProvisionalNavigation n: WKNavigation!) { cha.dangTai = true }
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) { cha.dangTai = false; cha.tieuDe = w.title ?? "" }
        func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { cha.dangTai = false }
        func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { cha.dangTai = false }
    }
}
