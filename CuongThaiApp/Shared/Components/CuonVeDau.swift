import SwiftUI

// MARK: - Cuộn về đầu khi đổi nội dung
//
// `ScrollView` của SwiftUI GIỮ NGUYÊN vị trí cuộn khi nội dung bên trong đổi.
// Đúng với việc tải thêm hoặc lọc tại chỗ, nhưng SAI hẳn khi chuyển sang một
// thứ khác: bấm "Bài tiếp" ở cuối trang là bài mới mở ra ngay tại cuối trang,
// người học phải tự vuốt ngược lên đầu mỗi bài. Người dùng báo đúng chỗ này
// ngày 23/08/2026.
//
// ⚠️ Chỉ dính khi nút bấm VẪN NHÌN THẤY lúc đang cuộn sâu — nghĩa là nó nằm ở
// thanh đáy cố định, ở thanh trên cố định, hoặc trong một sheet. Rà thật cả
// app: thẻ lọc của Code Lab và Phòng thi nằm TRONG `ScrollView` nên cuộn mất
// theo nội dung, muốn bấm thì đã phải lên đầu rồi — bốn màn dưới đây mới cần:
//
//   · `LessonPlayerView`  — Bài trước/Bài tiếp ở cuối trang + mục lục
//   · `LamBaiView`        — Câu trước/Câu tiếp ở thanh đáy + lưới câu + tự
//                           nhảy câu sau khi chọn đáp án
//   · `HomeView`          — hàng thẻ Tất cả/Bài viết/Video/File ghim trên
//   · `SnippetsView`      — ô tìm + thẻ danh mục ghim trên
//
// Cách dùng, ba bước:
//   ScrollViewReader { cuon in
//       ScrollView {
//           VStack { NeoDauTrang(); … }     // 1. neo ở phần tử ĐẦU TIÊN
//       }
//       .onChange(of: moc) { _, _ in cuon.veDauTrang() }   // 2. mốc đổi
//   }

enum NeoCuon {
    static let dau = "ct-neo-dau-trang"
}

/// Neo vô hình đặt ở đầu nội dung `ScrollView`.
///
/// Dùng một view riêng chứ KHÔNG gắn `.id()` lên nội dung thật: `.id()` là
/// danh tính của view, gắn nhầm chỗ là SwiftUI dựng lại cả cây con và trạng
/// thái bên trong (ô đang gõ, video đang chạy) mất sạch.
struct NeoDauTrang: View {
    var body: some View {
        Color.clear.frame(height: 0).id(NeoCuon.dau)
    }
}

extension ScrollViewProxy {
    /// Nhảy về đầu, KHÔNG hoạt ảnh.
    ///
    /// Cuộn mượt ở đây là sai: nội dung đã là của bài MỚI, nên hoạt ảnh sẽ
    /// vẽ lướt qua giữa bài mới rồi mới dừng ở đầu — trông như trang bị giật.
    func veDauTrang() {
        scrollTo(NeoCuon.dau, anchor: .top)
    }
}
