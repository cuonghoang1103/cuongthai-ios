#if os(iOS)
import SwiftUI

/// Huy hiệu trạng thái đồng bộ.
///
/// ⚠️ Phải NÓI RA khi còn trang chưa đẩy. Một cuốn vở im lặng "chắc là đã
/// lưu rồi" là thứ khiến người ta mất buổi ghi chép mà mãi sau mới biết —
/// và lúc biết thì không còn gì để cứu.
struct HuyHieuDongBo: View {
    @ObservedObject private var dongBo = DongBoVo.shared
    @State private var hienChiTiet = false

    var body: some View {
        Button { hienChiTiet = true } label: {
            switch dongBo.trangThai {
            case .dangDay(let xong, let tong):
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text("\(xong)/\(tong)")
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(AppColors.textSecondary)

            case .loi:
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(AppColors.error)

            case .nghi, .xong:
                if dongBo.soTrangChoDay > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "icloud.and.arrow.up")
                        Text("\(dongBo.soTrangChoDay)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(AppColors.warning)
                } else {
                    Image(systemName: "checkmark.icloud")
                        .foregroundStyle(AppColors.success.opacity(0.85))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nhan)
        .popover(isPresented: $hienChiTiet) {
            ChiTietDongBo(dongBo: dongBo)
                .frame(minWidth: 280)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var nhan: String {
        switch dongBo.trangThai {
        case .dangDay(let x, let t): return T("Đang đẩy") + " \(x)/\(t)"
        case .loi(let m): return T("Đồng bộ lỗi") + ": " + m
        case .nghi, .xong:
            return dongBo.soTrangChoDay > 0
                ? "\(dongBo.soTrangChoDay) " + T("trang chưa đẩy")
                : T("Đã đồng bộ")
        }
    }
}

private struct ChiTietDongBo: View {
    @ObservedObject var dongBo: DongBoVo
    @Environment(\.dismiss) private var dong

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(T("Đồng bộ vở"))
                .font(Font.titleSmall)
                .foregroundStyle(AppColors.textPrimary)

            switch dongBo.trangThai {
            case .dangDay(let x, let t):
                Label("\(T("Đang đẩy")) \(x)/\(t)", systemImage: "icloud.and.arrow.up")
            case .loi(let m):
                Label(m, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(AppColors.error)
            case .xong(let luc):
                Label(T("Xong lúc") + " " + luc.formatted(date: .omitted, time: .shortened),
                      systemImage: "checkmark.circle")
            case .nghi:
                Label(dongBo.soTrangChoDay > 0
                      ? "\(dongBo.soTrangChoDay) " + T("trang chờ đẩy")
                      : T("Mọi trang đã lên máy chủ"),
                      systemImage: dongBo.soTrangChoDay > 0 ? "clock" : "checkmark.circle")
            }

            Text(T("Nét vẽ luôn được lưu trên máy trước. Đồng bộ chỉ là bản sao trên máy chủ — mất mạng không mất bài."))
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                DongBoVo.shared.batDau(keoVeTruoc: true)
                dong()
            } label: {
                Label(T("Đồng bộ ngay"), systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .primaryButtonStyle()
        }
        .font(Font.bodyMedium)
        .foregroundStyle(AppColors.textSecondary)
        .padding(Spacing.md)
    }
}
#endif
