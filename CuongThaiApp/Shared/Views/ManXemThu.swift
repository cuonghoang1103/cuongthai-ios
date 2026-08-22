#if DEBUG
import SwiftUI

/// Cửa XEM MÀN HÌNH — chỉ tồn tại trong bản DEBUG.
///
/// Vì sao có: app bắt đăng nhập ở `ContentView`, nên không mở được một màn cụ
/// thể trên máy mô phỏng để soi giao diện. Suốt 22/08/2026 tôi phải nhờ người
/// dùng chụp màn hình mới biết bố cục lệch — và họ đã phải chỉ ra hai lần.
///
/// Dùng: đặt biến môi trường khi mở app.
///
///     xcrun simctl launch --console <udid> com.cuongthai.app \
///       --setenv CT_XEM_MAN=codelab
///
/// ⚠️ Nằm trọn trong `#if DEBUG` nên KHÔNG vào bản Release. Đây đúng thứ đã
/// từng hỏng theo chiều ngược lại: cờ `DEBUG` đặt nhầm ở `settings.base` lọt
/// vào Release làm TestFlight đăng ký APNs sandbox (xem `project.yml`). Giờ cờ
/// đó nằm đúng trong `configs: Debug:`, đã kiểm lại trước khi viết file này.
struct ManXemThu: View {
    let ten: String

    /// Ngôn ngữ giả để dựng những màn cần `NgonNgu` mà không phải gọi mạng.
    private var tiengNhat: NgonNgu {
        NgonNgu(id: 2, name: "Tiếng Nhật", nameEn: "Japanese", code: "ja",
                flagEmoji: "🇯🇵", order: 2, isActive: true, counts: nil)
    }

    var body: some View {
        NavigationStack {
            switch ten.lowercased() {
            case "codelab": CodeLabView()
            case "snippet", "snippets": SnippetsView()
            case "tudien": TuDienView(ngonNgu: tiengNhat)
            case "lotrinh": LoTrinhView(ngonNgu: tiengNhat)
            case "phongthi": PhongThiView()
            default:
                VStack(spacing: Spacing.sm) {
                    Text("Không có màn tên “\(ten)”")
                        .font(.system(size: 15, weight: .semibold))
                    Text("codelab · snippets · tudien · lotrinh · phongthi")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
}
#endif
