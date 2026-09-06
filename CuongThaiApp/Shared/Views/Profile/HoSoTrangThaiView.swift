import SwiftUI

/// Ba trạng thái mà màn Hồ sơ PHẢI vẽ khi chưa có dữ liệu thật.
///
/// ⚠️ Vì sao tồn tại: `ProfileView` cũ lấp chỗ trống bằng `?? "User"` và
/// `?? "username"`, nên bất kỳ lúc nào hồ sơ chưa về — đang tải, mạng hỏng,
/// token hết hạn — người dùng đều thấy MỘT HỒ SƠ GIẢ: "User / @username /
/// 0 bài viết / 0 người theo dõi", ảnh đại diện rỗng, kèm nút "Chỉnh sửa".
/// Nhìn y hệt app hỏng. Và đó đúng là nội dung giữ chỗ, thứ App Store đánh
/// trượt theo Guideline 2.1 (App Completeness).
///
/// Nguyên tắc: KHÔNG BAO GIỜ vẽ hồ sơ khi không có hồ sơ. Đang tải thì vẽ
/// khung xám; hỏng thì nói hỏng và cho bấm thử lại; chưa đăng nhập thì mời
/// đăng nhập.

// MARK: - Khung xám lúc đang tải

/// Vệt sáng chạy qua khung xám. Có chuyển động thì người dùng biết app đang
/// làm việc; khung xám đứng im lại giống hệt giao diện chết.
private struct VetSang: ViewModifier {
    @State private var chay = false
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { g in
                    LinearGradient(
                        colors: [.clear, AppColors.textPrimary.opacity(0.08), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: g.size.width * 0.6)
                    .offset(x: chay ? g.size.width : -g.size.width * 0.6)
                }
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { chay = true }
            }
    }
}

private struct O: View {
    var w: CGFloat? = nil
    var h: CGFloat = 14
    var bo: CGFloat = 6
    var body: some View {
        RoundedRectangle(cornerRadius: bo)
            .fill(AppColors.backgroundTertiary)
            .frame(width: w, height: h)
            .frame(maxWidth: w == nil ? .infinity : nil, alignment: .leading)
            .modifier(VetSang())
    }
}

struct HoSoDangTaiView: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.backgroundTertiary)
                .frame(height: 180)
                .modifier(VetSang())

            HStack(alignment: .bottom) {
                Circle()
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: 96, height: 96)
                    .overlay(Circle().stroke(AppColors.backgroundPrimary, lineWidth: 4))
                    .modifier(VetSang())
                    .offset(y: -44)
                Spacer()
                O(w: 104, h: 34, bo: CornerRadius.medium).offset(y: -8)
            }
            .padding(.horizontal, Spacing.md)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                O(w: 172, h: 22)
                O(w: 108, h: 14)
                O(h: 12)
                O(w: 220, h: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .offset(y: -28)

            HStack(spacing: Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 6) { O(w: 38, h: 18); O(w: 62, h: 11) }
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.md)
        }
        .accessibilityLabel(T("Đang tải hồ sơ"))
    }
}

// MARK: - Hỏng / chưa đăng nhập

/// Một khung duy nhất cho cả hai: cùng bố cục, khác chữ và khác nút.
struct HoSoTrongView: View {
    let bieuTuong: String
    let tieuDe: String
    let moTa: String
    let nhanNut: String
    let hanhDong: () -> Void
    var nhanPhu: String? = nil
    var hanhDongPhu: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.12))
                    .frame(width: 84, height: 84)
                Image(systemName: bieuTuong)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(AppColors.primary)
            }
            .padding(.bottom, Spacing.xs)

            Text(tieuDe)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(moTa)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.md)

            Button(action: hanhDong) {
                Text(nhanNut)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .padding(.top, Spacing.xs)

            if let nhanPhu, let hanhDongPhu {
                Button(action: hanhDongPhu) {
                    Text(nhanPhu)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 380)
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxl)
    }
}
