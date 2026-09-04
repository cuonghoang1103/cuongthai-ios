import SwiftUI

// MARK: - Dựng câu trả lời

/// Markdown lúc đang chảy, markdown + công thức khi xong.
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

    var body: some View {
        #if os(iOS)
        if xong && coCongThuc {
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
