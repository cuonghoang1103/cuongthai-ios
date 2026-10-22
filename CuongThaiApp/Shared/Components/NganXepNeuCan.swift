import SwiftUI

/// Bọc `NavigationStack` CHỈ khi màn đứng một mình.
///
/// Một màn như Tiền nong vừa là gốc (cột chi tiết iPad, cửa sổ phụ, tấm phủ)
/// vừa được ĐẨY vào stack có sẵn (Hôm nay › Đi nhanh, Tất cả tính năng). Bản
/// cũ luôn tự mở `NavigationStack` ⇒ đẩy vào là hai stack lồng nhau: hai
/// thanh tiêu đề, nút quay lại về sai chỗ, màn con đẩy vào stack trong cùng
/// rồi kẹt (lỗi (b) đợt rút gọn 22/10/2026). `VoView`/`NoiDungVoView` đã tách
/// đôi để tránh đúng chuyện này; với các màn lớn thì một cờ rẻ hơn tách tệp.
struct NganXepNeuCan<NoiDung: View>: View {
    /// `true` = màn đứng một mình, tự mang stack. `false` = đã nằm trong stack.
    var rieng: Bool
    @ViewBuilder var noiDung: () -> NoiDung

    var body: some View {
        if rieng {
            NavigationStack { noiDung() }
        } else {
            noiDung()
        }
    }
}
