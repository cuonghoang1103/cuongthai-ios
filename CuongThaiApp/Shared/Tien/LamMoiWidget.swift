import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Bảo hệ thống vẽ lại widget sau khi ảnh chụp đổi.
///
/// ⚠️ Không có dòng này thì widget vẫn đúng — nhưng chỉ tới lần hệ thống tự
/// làm mới kế tiếp, có thể là hàng giờ sau. Người dùng ghi một khoản chi rồi
/// nhìn màn khoá thấy số cũ sẽ kết luận app không ghi được.
enum LamMoiWidget {
    static func ngay() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
