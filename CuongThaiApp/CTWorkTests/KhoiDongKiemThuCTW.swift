import Foundation
@testable import CTWork

/// Lớp chính của gói kiểm thử (Info.plist `NSPrincipalClass`) — chạy TRƯỚC mọi phép kiểm.
///
/// Các phép kiểm so chữ hiển thị bằng tiếng Anh ("Paused", "moved from To Do to In Progress"…). Máy mô phỏng
/// có thể đang chọn tiếng Việt (Account › Language, hoặc `defaults write … ngonNgu vi` khi chụp màn) ⇒ đặt tiếng
/// Anh CHỈ trong bộ nhớ, không ghi đè lựa chọn đã lưu.
final class KhoiDongKiemThuCTW: NSObject {
    override init() {
        super.init()
        Self.veTiengAnh()
    }

    static func veTiengAnh() {
        NgonNguCTW.datTrongBoNho(.en)
        CTWDinhDang.locale = Locale(identifier: "en_US")
    }
}
