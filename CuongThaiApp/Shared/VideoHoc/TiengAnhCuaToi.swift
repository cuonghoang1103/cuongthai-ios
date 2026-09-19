import SwiftUI

// ════════════════════════════════════════════════════════════════
// CÂY CẦU: từ mới gặp lúc HỌC → sổ ôn tập ngắt quãng ĐÃ CÓ
//
// ⚠️ KHÔNG dựng bộ ôn tập thứ hai. App đã có đủ: `LangNotebookEntry` mang
// sẵn SM-2 (easeFactor / intervalDays / repetitions / nextReviewAt), màn
// `OnTapView` để ôn, `TheGhiNhoView` để lật thẻ, và `NutLuuSoTay` để lưu.
// Thứ THIẾU là đường đi từ chỗ người ta GẶP từ mới (phụ đề video, bài đọc
// IELTS, tra từ) vào cái sổ đó — gặp xong không lưu thì từ bay mất, và
// tra lại lần thứ ba vẫn thấy lạ.
//
// Đây là lần thứ BA trong một phiên: thứ cần đã có, chỉ là không với tới
// được từ nơi người dùng gặp vấn đề.
// ════════════════════════════════════════════════════════════════

/// Giữ đối tượng "tiếng Anh" để mọi nút lưu dùng chung.
///
/// Nạp MỘT lần rồi nhớ: mỗi lần chạm một từ trong phụ đề mà gọi lại danh
/// sách ngôn ngữ là một vòng mạng cho một dữ liệu không bao giờ đổi.
@MainActor
final class TiengAnhCuaToi: ObservableObject {
    static let chung = TiengAnhCuaToi()

    @Published private(set) var tiengAnh: NgonNgu?
    private var dangTai = false

    func nap() async {
        guard tiengAnh == nil, !dangTai else { return }
        dangTai = true
        defer { dangTai = false }
        let ds: [NgonNgu]? = try? await APIClient.shared.request(.dsNgonNgu)
        // Khớp theo MÃ, không theo tên: tên có thể là "Tiếng Anh" hay
        // "English" tuỳ ngôn ngữ giao diện, còn mã thì cố định.
        tiengAnh = ds?.first { $0.code.lowercased().hasPrefix("en") }
    }
}

/// Nút lưu một TỪ hoặc một CÂU tiếng Anh vào sổ ôn tập.
///
/// Tự ẩn khi chưa biết "tiếng Anh" là ngôn ngữ nào — hiện một nút bấm vào
/// không có gì xảy ra còn tệ hơn không có nút.
struct NutLuuTiengAnh: View {
    let tieuDe: String
    let than: String
    var nghia: String?
    var loai: LoaiMuc = .tuVung

    @ObservedObject private var kho = TiengAnhCuaToi.chung

    var body: some View {
        Group {
            if let n = kho.tiengAnh {
                NutLuuSoTay(ngonNgu: n, loai: loai, tieuDe: tieuDe,
                            than: than, cachDoc: nil, nghia: nghia)
            }
        }
        .task { await kho.nap() }
    }
}
