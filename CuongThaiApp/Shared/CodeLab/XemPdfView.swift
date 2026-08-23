import SwiftUI
#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - Đọc đề gốc dạng PDF
//
// Web nhúng bằng `<iframe src="…pdf">` và ngay dưới có dòng tự thừa nhận:
// "On phones the viewer may stay blank — use Open PDF full screen". Trên iOS
// KHÔNG cần chịu vậy: PDFKit dựng thật, cuộn và phóng to được, và biết tổng
// số trang.
//
// ⚠️ Tải bằng `URLSession` rồi mới đưa vào `PDFDocument`, KHÔNG dùng
// `PDFDocument(url:)`. Khởi tạo bằng URL mạng là **chặn luồng gọi nó** cho
// tới khi tải xong — gọi trên luồng chính là app đứng hình, và hỏng thì chỉ
// trả `nil`, không nói vì sao.

struct XemPdfView: View {
    let duong: URL
    let tieuDe: String

    @State private var dulieu: Data?
    @State private var loi: String?
    @State private var dangTai = true

    var body: some View {
        Group {
            #if canImport(PDFKit)
            if let d = dulieu {
                KhungPdf(dulieu: d)
                    .ignoresSafeArea(edges: .bottom)
            } else if dangTai {
                ProgressView("Đang tải đề gốc…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                loiTai
            }
            #else
            loiTai
            #endif
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(tieuDe)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Mở bằng Safari/Files: in ra giấy, lưu vào Tệp, gửi cho bạn.
                Link(destination: duong) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Mở bằng ứng dụng khác")
            }
        }
        .task {
            guard dulieu == nil else { return }
            dangTai = true; defer { dangTai = false }
            do {
                let (d, resp) = try await URLSession.shared.data(from: duong)
                if let h = resp as? HTTPURLResponse, !(200...299).contains(h.statusCode) {
                    loi = "Máy chủ trả HTTP \(h.statusCode)."; return
                }
                // Kiểm THẬT: máy chủ trả trang lỗi HTML vẫn là 200, và
                // `PDFDocument` nuốt im lặng thành nil.
                guard d.count > 4, d.prefix(4) == Data("%PDF".utf8) else {
                    loi = "File tải về không phải PDF (\(d.count) byte)."; return
                }
                dulieu = d
            } catch { loi = error.localizedDescription }
        }
    }

    private var loiTai: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36)).foregroundColor(AppColors.textTertiary)
            Text(loi ?? "Không mở được đề gốc.")
                .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Link("Mở bằng trình duyệt", destination: duong)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if canImport(PDFKit)
private struct KhungPdf: UIViewRepresentable {
    let dulieu: Data

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true                    // vừa bề ngang màn hình
        v.displayMode = .singlePageContinuous  // cuộn liền mạch, không lật trang
        v.displayDirection = .vertical
        v.backgroundColor = .systemBackground
        v.document = PDFDocument(data: dulieu)
        return v
    }

    func updateUIView(_ v: PDFView, context: Context) {
        // Chỉ nạp lại khi dữ liệu ĐỔI THẬT. Gán `document` mỗi lần SwiftUI vẽ
        // lại sẽ nhảy về trang 1 giữa lúc người ta đang đọc dở.
        if v.document == nil { v.document = PDFDocument(data: dulieu) }
    }
}
#endif
