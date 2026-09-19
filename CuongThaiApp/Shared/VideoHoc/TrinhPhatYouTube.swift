#if os(iOS)
import SwiftUI
import WebKit

// ════════════════════════════════════════════════════════════════
// TRÌNH PHÁT YOUTUBE ĐIỀU KHIỂN ĐƯỢC
//
// Khác `YouTubePlayer` ở `LessonPlayerView` (khung nhúng trơn): bản này bật
// IFrame API để TUA được và BIẾT đang ở giây nào — hai thứ bắt buộc cho
// bảng phụ đề (chạm câu là tua tới đó, và câu đang nói phải sáng lên).
//
// ⚠️ Giữ NGUYÊN cách nhúng đã trả giá: `loadSimulatedRequest` với origin
// `https://cuongthai.com/`, và tham số `origin` trong URL khung nhúng phải
// KHỚP. Đổi sang `loadHTMLString` hay origin `youtube.com` là quay lại lỗi
// 152 trên máy thật — xem chú thích dài trong `LessonPlayerView`.
//
// ⚠️ MÁY ẢO iOS KHÔNG PHÁT ĐƯỢC YOUTUBE (Safari trong máy ảo cũng lỗi 153).
// Không dùng máy ảo để kết luận bất cứ điều gì về màn này.
// ════════════════════════════════════════════════════════════════

/// Tay điều khiển — màn hình giữ một cái, trình phát nhận lệnh qua nó.
@MainActor
final class DieuKhienVideo: ObservableObject {
    /// Giây hiện tại, trình phát tự bắn về mỗi 250ms.
    @Published var giay: Double = 0
    @Published var dangPhat = false
    @Published var sanSang = false

    /// Lặp một đoạn (A–B) để nhại theo. `nil` = tắt.
    @Published var lapTu: Double?
    @Published var lapDen: Double?

    fileprivate weak var web: WKWebView?

    func tua(_ s: Double) { chay("p.seekTo(\(max(0, s)), true); p.playVideo();") }
    func phat() { chay("p.playVideo();") }
    func dung() { chay("p.pauseVideo();") }
    func tocDo(_ x: Double) { chay("p.setPlaybackRate(\(x));") }

    /// Lặp đúng một câu — cách luyện nói hiệu quả nhất mà lại dễ làm nhất.
    func lapCau(tu: Double, den: Double) {
        lapTu = tu; lapDen = den
        tua(tu)
    }
    func thoiLap() { lapTu = nil; lapDen = nil }

    private func chay(_ js: String) {
        // `p` chưa tồn tại lúc trang mới tải xong — bọc trong try để không
        // ném một lỗi JS mỗi lần người dùng chạm sớm.
        web?.evaluateJavaScript("try{\(js)}catch(e){}", completionHandler: nil)
    }
}

struct TrinhPhatYouTube: UIViewRepresentable {
    let videoId: String
    @ObservedObject var dk: DieuKhienVideo

    private static let trangChu = "https://cuongthai.com/"

    func makeUIView(context: Context) -> WKWebView {
        let ch = WKWebViewConfiguration()
        ch.allowsInlineMediaPlayback = true
        ch.mediaTypesRequiringUserActionForPlayback = []
        ch.userContentController.add(context.coordinator, name: "video")
        let web = WKWebView(frame: .zero, configuration: ch)
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        dk.web = web
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        dk.web = web
        guard context.coordinator.dangTai != videoId else { return }
        context.coordinator.dangTai = videoId
        guard let goc = URL(string: Self.trangChu) else { return }
        web.loadSimulatedRequest(URLRequest(url: goc), responseHTML: html)
    }

    private var html: String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden}
        #p{width:100%;height:100%}</style></head><body><div id="p"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        var p, dem;
        function onYouTubeIframeAPIReady(){
          p = new YT.Player('p', {
            videoId: '\(videoId)',
            playerVars: {playsinline:1, rel:0, modestbranding:1,
                         origin:'https://cuongthai.com'},
            events: {
              onReady: function(){
                bao({k:'sanSang'});
                // 250ms: đủ mượt để câu sáng đúng lúc, mà không làm web view
                // bận rộn vô ích. 100ms không mượt hơn mấy, 500ms thì câu
                // sáng trễ nửa nhịp và trông như phụ đề lệch.
                dem = setInterval(function(){
                  bao({k:'giay', v: p.getCurrentTime()});
                }, 250);
              },
              onStateChange: function(e){
                bao({k:'trangThai', v: e.data});
              }
            }
          });
        }
        function bao(m){
          try{ window.webkit.messageHandlers.video.postMessage(m); }catch(e){}
        }
        </script></body></html>
        """
    }

    func makeCoordinator() -> Dieu { Dieu(dk: dk) }

    final class Dieu: NSObject, WKScriptMessageHandler {
        var dangTai: String?
        let dk: DieuKhienVideo
        init(dk: DieuKhienVideo) { self.dk = dk }

        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
            guard let d = m.body as? [String: Any], let k = d["k"] as? String else { return }
            Task { @MainActor in
                switch k {
                case "sanSang": dk.sanSang = true
                case "giay":
                    let g = d["v"] as? Double ?? 0
                    dk.giay = g
                    // Lặp A–B: tới điểm B thì nhảy về A. Kiểm ở ĐÂY chứ không
                    // đặt hẹn giờ riêng — hẹn giờ lệch dần với video thật khi
                    // người dùng tua tay, còn mốc này luôn là giây thật.
                    if let a = dk.lapTu, let b = dk.lapDen, g >= b { dk.tua(a) }
                case "trangThai":
                    dk.dangPhat = (d["v"] as? Int) == 1
                default: break
                }
            }
        }
    }
}
#endif
