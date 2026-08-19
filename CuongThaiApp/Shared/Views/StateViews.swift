import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Trạng thái tải / rỗng / lỗi
//
// Trước đây các màn chỉ có hai trạng thái: đang tải (vòng xoay) và có dữ liệu.
// Khi gọi API hỏng, `error` được gán nhưng KHÔNG màn nào hiển thị nó — danh
// sách rỗng nên người dùng thấy "Chưa có bài viết". Mất mạng mà báo là "không
// có nội dung" là nói sai, và người dùng không có lý do gì để thử lại.

/// Khối lỗi có nút thử lại. Luôn kèm nút — báo lỗi mà không cho lối thoát thì
/// người dùng chỉ còn cách thoát app.
struct ErrorStateView: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundColor(AppColors.textTertiary)

            Text("Không tải được")
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)

            Text(message)
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.xl)

            if let onRetry {
                Button {
                    Haptics.cham()
                    onRetry()
                } label: {
                    Text("Thử lại")
                        .font(.buttonText)
                        .foregroundColor(AppColors.onPrimary)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.sm)
                        .background(AppColors.primary)
                        .cornerRadius(CornerRadius.medium)
                }
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
    }
}

/// Khối xám nhấp nháy thay cho vòng xoay. Vòng xoay không nói gì về thứ sắp
/// hiện ra; khung xương cho thấy trước bố cục nên màn hình không "nhảy" một
/// cái khi dữ liệu về.
struct SkeletonBox: View {
    var height: CGFloat = 16
    var width: CGFloat? = nil
    var radius: CGFloat = CornerRadius.small

    @State private var sang = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(AppColors.backgroundTertiary)
            .frame(width: width, height: height)
            .opacity(sang ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: sang)
            .onAppear { sang = true }
    }
}

/// Khung xương của một thẻ bài viết — dùng lúc bảng tin đang tải lần đầu.
struct PostSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                SkeletonBox(height: 44, width: 44, radius: 22)
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBox(height: 14, width: 140)
                    SkeletonBox(height: 11, width: 90)
                }
                Spacer()
            }
            SkeletonBox(height: 12)
            SkeletonBox(height: 12)
            SkeletonBox(height: 12, width: 200)
            SkeletonBox(height: 180, radius: CornerRadius.medium)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }
}

// MARK: - Rung phản hồi

/// Rung nhẹ cho các thao tác có kết quả. Chỉ iOS có Taptic Engine — trên macOS
/// mọi hàm dưới đây là lệnh rỗng, gọi thoải mái không cần bọc `#if`.
enum Haptics {
    /// Chạm một nút, chọn một mục.
    static func cham() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Việc xong xuôi: gửi tin, đăng bài, lưu hồ sơ.
    static func xong() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Việc hỏng.
    static func hong() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
