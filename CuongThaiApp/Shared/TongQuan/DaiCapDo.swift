import SwiftUI

// ════════════════════════════════════════════════════════════════
// DẢI TIẾN ĐỘ — cấp độ, EXP và chuỗi ngày, gói trong một hàng
//
// Trước đây ba con số này chiếm hai chỗ: một vòng tròn cấp độ 54pt ở góc phải
// đầu trang (chen với lời chào, khiến lời chào phải co lại còn hai dòng), và
// một ô thống kê "chuỗi ngày" trong lưới 2×2 — ô này hiện "—" suốt với người
// chưa có chuỗi nào, tức một thẻ to chỉ để nói "không có gì".
//
// Đây là thông tin PHỤ: nó nói về động lực, không nói về "hôm nay học gì".
// Nên nó xuống dưới, mỏng đi, và biến mất hẳn khi chưa có gì để khoe.
// ════════════════════════════════════════════════════════════════

struct DaiCapDo: View {
    let capDo: Int
    let exp: Int
    let expMoiCap: Int
    /// 0…1. Nhận sẵn thay vì tự chia — nguồn sự thật vẫn là view model.
    let phanTram: Double
    let chuoiNgay: Int

    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("\(capDo)")
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .foregroundColor(AppColors.onPrimary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(AppColors.primary))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                // Huy hiệu bên trái ĐÃ nói cấp mấy. Viết "Cấp 7" lần nữa ngay
                // cạnh nó là đọc to con số vừa nhìn thấy; chỗ đó để dành nói
                // điều chưa biết: còn bao nhiêu nữa thì lên cấp.
                Text(String(format: T("%d/%d EXP · tới cấp %d"), exp, expMoiCap, capDo + 1))
                    .font(.system(size: 12.5, weight: .medium).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.backgroundTertiary)
                        Capsule()
                            .fill(LinearGradient(colors: [AppColors.primary, AppColors.primaryLight],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, g.size.width * CGFloat(min(max(phanTram, 0), 1))))
                    }
                }
                .frame(height: 5)
                // ⚠️ Khoá vào `phanTram` — một con số ỔN ĐỊNH. Khoá vào thứ
                // tính lại mỗi lần dựng (một `Color` động chẳng hạn) thì
                // animation nổ liên tục và kéo theo cả vị trí của view.
                .animation(giamChuyenDong ? nil : .easeOut(duration: 0.4), value: phanTram)
            }

            if chuoiNgay > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.error)
                    Text(String(format: T("%d ngày"), chuoiNgay))
                        .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(Capsule().fill(AppColors.error.opacity(0.12)))
                .accessibilityLabel(String(format: T("Chuỗi %d ngày liên tiếp"), chuoiNgay))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }
}
