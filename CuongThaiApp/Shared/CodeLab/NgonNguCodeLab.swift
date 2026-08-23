import SwiftUI

// MARK: - Ngôn ngữ ĐỌC của Code Lab
//
// Dùng lại đúng `NgonNguDe` của Phòng thi — một enum, một quy tắc cho cả app.
// Khác Phòng thi ở hai điểm, và cả hai đều là CỐ Ý:
//
// 1. **Lựa chọn được NHỚ.** Web lưu vào `localStorage['codelab.lessonLang']`
//    và dùng chung khoá đó cho cả bảng bài học lẫn trang bài tập, nên người
//    học chọn một lần là đi hết lộ trình. App dùng `@AppStorage` cùng tên
//    khoá. Phòng thi thì KHÔNG nhớ: mỗi đề là một lượt thi riêng.
//
// 2. **Nút chỉ hiện khi CÓ bản dịch.** Đo thật 23/08/2026 trên 36 bài học
//    mẫu của 12 lộ trình: `lab211` 361/366 khối có tiếng Việt, `javascript`
//    131/146, `postgresql` 103/113, `react` 102/113, `nextjs` 98/108,
//    `typescript` 78/84 — còn `java`, `python`, `spring-boot`, `sql`,
//    `kubernetes`, `flutter` thì **0**. Đề bài tập thì tuyệt đối chưa dịch:
//    2.849 bài rải cả trang mới nhất lẫn cũ nhất, `problemHtmlVi` null hết.
//    Hiện nút ở chỗ không có bản dịch là bấm xong màn hình y nguyên.

/// Khoá lưu lựa chọn. Trùng tên với web cho dễ đối chiếu khi đọc hai bên.
enum CodeLabNgonNgu {
    static let khoa = "codelab.lessonLang"
}

/// Nút EN/VI dùng chung cho Code Lab.
struct NutDoiNgonNgu: View {
    @Binding var ngonNgu: NgonNguDe

    var body: some View {
        Button { ngonNgu = ngonNgu.doiSang } label: {
            Text(ngonNgu.nhanNut).font(.system(size: 13, weight: .bold))
        }
        .accessibilityLabel(ngonNgu == .viet ? "Chuyển sang tiếng Anh" : "Chuyển sang tiếng Việt")
    }
}

extension Optional where Wrapped == String {
    /// Chọn giữa bản gốc (tiếng Anh) và bản dịch, RƠI VỀ theo TỪNG TRƯỜNG.
    ///
    /// Một bài học dịch dở — heading có `textVi` mà prose thì không — vẫn
    /// đọc trôi, chỉ vài đoạn còn tiếng Anh. Ngược lại, gộp cả bài về một
    /// thứ tiếng theo "bài này có dịch hay không" thì một khối thiếu là mất
    /// nguyên đoạn.
    func theo(_ ngonNgu: NgonNguDe, viet: String?) -> String {
        if ngonNgu == .viet, let v = viet, !v.isEmpty { return v }
        return self ?? ""
    }
}
