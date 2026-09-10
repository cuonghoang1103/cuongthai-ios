import SwiftUI

// MARK: - Dựng câu trả lời

/// Markdown lúc đang chảy, HTML đầy đủ khi xong.
///
/// ⚠️ Đừng dựng WebView trong lúc chữ còn chảy: mỗi mẩu chữ là một lần nạp
/// lại cả trang, và công thức mới về một nửa (`$x =`) thì KaTeX dựng ra một
/// khối đỏ nhấp nháy. Web tránh đúng chỗ này bằng `renderMath={!t.streaming}`.
struct TraLoiAI: View {
    let chu: String
    let xong: Bool
    @State private var cao: CGFloat = 40

    private var coCongThuc: Bool {
        chu.contains("$") || chu.contains("\\(") || chu.contains("\\[")
    }

    /// Có thứ mà bộ dựng native KHÔNG làm được không.
    ///
    /// ⚠️ BẢN CŨ CHỈ ĐỔI SANG WEBVIEW KHI CÓ CÔNG THỨC TOÁN. Nên câu trả lời
    /// có SVG, có bảng, hay có khối mã đều rơi vào bộ dựng native:
    ///   · SVG hiện ra DẠNG MÃ NGUỒN (người dùng chụp lại 10/09/2026)
    ///   · bảng mất khung
    ///   · mã không có màu
    /// Trong khi trang WebView đã sẵn `marked` (bảng GFM), KaTeX, Mermaid,
    /// bảng màu VS Code và `svg{max-width:100%}` — chỉ là không ai gọi tới.
    private var canWebView: Bool {
        coCongThuc
            || chu.contains("```")          // khối mã · sơ đồ mermaid · svg
            || chu.contains("<svg")         // svg viết thẳng, không bọc khối
            || chu.contains("|---")         // bảng GFM
            || chu.contains("| ---")
    }

    var body: some View {
        #if os(iOS)
        if xong && canWebView {
            NoiDungThiWeb(html: chu, chieuCao: $cao, laMarkdown: true)
                .frame(height: cao)
        } else {
            NoiDungMarkdown(noiDung: chu)
        }
        #else
        NoiDungMarkdown(noiDung: chu)
        #endif
    }
}
