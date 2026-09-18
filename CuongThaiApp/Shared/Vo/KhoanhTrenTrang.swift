#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// BÚT HỎI AI — khoanh THẲNG trên trang
//
// Người dùng 18/09/2026: "nó chỉ chụp full màn hình. Tôi chọn từng chữ chi
// tiết không được." Đúng: bản trước mở một cửa sổ riêng, nhét CẢ TRANG A4
// vào ô rộng 400pt — một chữ còn vài điểm ảnh, khoanh sao trúng.
//
// Bản này khoanh ngay trên trang, ở ĐÚNG mức phóng người dùng đang nhìn. Họ
// đã chụm hai ngón phóng tới cỡ đọc được rồi mới khoanh, nên vùng cắt ra
// cũng sắc đúng bằng thứ họ thấy.
//
// ⚠️ Lớp phủ này PHỦ KÍN khung vẽ và NUỐT mọi chạm. Đó là chủ đích: cú kéo
// đè lên `PKCanvasView` luôn bị cắt khúc (đo ba lần trong ngày), còn một lớp
// phủ chiếm trọn cử chỉ thì kéo mượt — đúng như cửa sổ cắt đã chứng minh.
// ════════════════════════════════════════════════════════════════

struct LopKhoanhTrenTrang: View {
    /// Trả về khung bao của nét khoanh, theo toạ độ của chính lớp phủ này.
    let khiXong: (CGRect) -> Void
    let khiHuy: () -> Void

    @State private var diem: [CGPoint] = []
    @State private var dangVe = false

    /// Nới khung bao ra một chút: người ta khoanh VÒNG QUANH chữ, nét vòng
    /// thường cắt sát mép chữ nên cắt đúng khung bao là mất chân chữ.
    private let noi: CGFloat = 10

    private var khung: CGRect? {
        guard diem.count > 2 else { return nil }
        let xs = diem.map(\.x), ys = diem.map(\.y)
        let r = CGRect(x: xs.min()!, y: ys.min()!,
                       width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
            .insetBy(dx: -noi, dy: -noi)
        return (r.width > 16 && r.height > 16) ? r : nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Nền mờ RẤT nhẹ: đủ để biết đang ở chế độ khoanh, không đủ để
            // che mất chữ đang cần đọc.
            Color.black.opacity(0.06)

            if let k = khung {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.primary.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.primary, lineWidth: 2))
                    .frame(width: k.width, height: k.height)
                    .position(x: k.midX, y: k.midY)
                    .allowsHitTesting(false)
            }

            // Nét khoanh của người dùng, vẽ dần theo ngón/bút.
            Path { p in
                guard let d = diem.first else { return }
                p.move(to: d)
                for q in diem.dropFirst() { p.addLine(to: q) }
            }
            .stroke(AppColors.primary.opacity(0.85),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .allowsHitTesting(false)

            thanhNhac
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if !dangVe { dangVe = true; diem = [] }
                    diem.append(g.location)
                }
                .onEnded { _ in
                    dangVe = false
                    guard let k = khung else { return }
                    Haptics.cham()
                    khiXong(k)
                },
        )
    }

    private var thanhNhac: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "lasso.badge.sparkles")
                .foregroundStyle(AppColors.primary)
            Text(diem.isEmpty ? T("Khoanh tròn hoặc tô chỗ cần hỏi")
                              : T("Thả tay ra là hỏi được"))
                .font(Font.bodyMedium.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
            Spacer(minLength: Spacing.sm)
            Button(T("Huỷ")) { khiHuy() }
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.primary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .background(Capsule().fill(AppColors.backgroundCard)
            .shadow(color: .black.opacity(0.18), radius: 10, y: 3))
        .padding(.top, Spacing.md)
        .allowsHitTesting(true)
    }
}

// MARK: - Nút bút AI, đứng cạnh bảng công cụ

/// Người dùng xin "một cây bút AI ở dưới, ấn vào rồi khoanh".
///
/// ⚠️ KHÔNG nhét được vào `PKToolPicker` — Apple không cho thêm công cụ tự
/// chế vào bảng đó. Nên đặt một nút NGAY CẠNH bảng, cùng tầng, cùng kiểu
/// bo tròn: nhìn ra là một phần của bộ công cụ, và không phải đi tìm.
struct NutButAI: View {
    let dangBat: Bool
    let cham: () -> Void

    var body: some View {
        Button(action: cham) {
            Image(systemName: "lasso.badge.sparkles")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(dangBat ? AppColors.onPrimary : AppColors.primary)
                .frame(width: 52, height: 52)
                .background(
                    Circle().fill(dangBat ? AppColors.primary : AppColors.backgroundCard)
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 3),
                )
                .overlay(Circle().stroke(AppColors.primary.opacity(dangBat ? 0 : 0.35),
                                         lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(T("Bút hỏi AI"))
        .accessibilityHint(T("Bật rồi khoanh tròn chỗ cần hỏi"))
    }
}
#endif
