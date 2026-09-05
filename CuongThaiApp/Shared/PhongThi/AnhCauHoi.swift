import SwiftUI
import Kingfisher

// ════════════════════════════════════════════════════════════════
// ẢNH KÈM CÂU HỎI THI — CÓ CHỐT CHẶN ẢNH CẮT HỎNG
//
// ⚠️ Ảnh đề là ảnh CẮT TỰ ĐỘNG từ đề giấy, và một lượt cắt dò nhầm cột thì
// ra hàng loạt ảnh rác. Đo thật 05/09/2026 trên 145 ảnh lấy mẫu ngẫu nhiên:
// **49 ảnh (34%) là dải trắng**, trong đó 45 ảnh đúng cùng một kích thước
// **56×484 px**. Riêng SWR302-FE22 dính 39/60 câu.
//
// Vẽ đúng tỉ lệ 1:8,6 trên khung rộng 390pt ⇒ một khối trắng **cao ~3.400pt**
// đẩy hết đáp án xuống dưới màn hình. Người dùng gửi ảnh chụp: "sao có mấy
// môn có câu lỗi khoảng trắng rộng như này".
//
// Hai lớp chặn ở đây:
//   1. **Trần chiều cao.** Ảnh nào cũng không được cao quá 420pt — một ảnh
//      lạ không bao giờ được phép chiếm cả màn hình.
//   2. **Ẩn hẳn dải rác.** Rộng < 140px VÀ cao gấp > 3 lần rộng thì không
//      có cách nào đọc được gì trong đó; hiện nó ra chỉ tổ che đáp án. Đề
//      bài và 4 phương án vẫn đủ chữ để làm bài.
//
// ⚠️ Đây là VÁ Ở NGỌN. Gốc là mấy tệp `content/exams/*.mjs` đang trỏ vào ảnh
// cắt hỏng — phải cắt lại từ đề gốc. Chốt này chỉ để một ảnh hỏng không phá
// được màn hình.
// ════════════════════════════════════════════════════════════════

struct AnhCauHoi: View {
    let duong: String
    /// Trần chiều cao. Đề dạng bảng/biểu đồ vẫn đọc được ở 420pt, và bấm vào
    /// thì mở xem to.
    var caoToiDa: CGFloat = 420

    @State private var laRac = false

    /// Rộng < 140px VÀ cao gấp hơn 3 lần rộng ⇒ dải cắt hỏng.
    ///
    /// ⚠️ Phải có CẢ HAI điều kiện. Chỉ xét tỉ lệ thì một ảnh chụp đoạn mã
    /// dài và hẹp cũng bị ẩn oan; chỉ xét bề rộng thì một biểu tượng vuông
    /// nhỏ cũng mất.
    static func laDaiRac(_ co: CGSize) -> Bool {
        co.width > 0 && co.width < 140 && co.height / co.width > 3
    }

    var body: some View {
        if !laRac, let u = URL(string: duong) {
            KFImage(u)
                .onSuccess { r in
                    if Self.laDaiRac(r.image.size) { laRac = true }
                }
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: caoToiDa)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }
}
