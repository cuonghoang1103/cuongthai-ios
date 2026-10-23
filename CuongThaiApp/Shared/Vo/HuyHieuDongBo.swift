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
                if !dongBo.trangMayChuDaXoa.isEmpty && dongBo.soTrangChoDay == 0 {
                    // Không phải lỗi đồng bộ (KHÔNG đỏ) — có trang chờ người
                    // dùng quyết: khôi phục hay bỏ. Màu vàng để chạm vào xem.
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.icloud")
                        Text("\(dongBo.trangMayChuDaXoa.count)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(AppColors.warning)
                } else if dongBo.soTrangChoDay > 0 {
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
                .frame(minWidth: 280, idealWidth: dongBo.trangMayChuDaXoa.isEmpty ? 280 : 360)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var nhan: String {
        switch dongBo.trangThai {
        case .dangDay(let x, let t): return T("Đang đẩy") + " \(x)/\(t)"
        case .loi(let m): return T("Đồng bộ lỗi") + ": " + m
        case .nghi, .xong:
            if dongBo.soTrangChoDay > 0 { return "\(dongBo.soTrangChoDay) " + T("trang chưa đẩy") }
            if !dongBo.trangMayChuDaXoa.isEmpty {
                return "\(dongBo.trangMayChuDaXoa.count) " + T("trang đã bị xoá ở máy khác")
            }
            return T("Đã đồng bộ")
        }
    }
}

struct ChiTietDongBo: View {
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
                      : (dongBo.trangMayChuDaXoa.isEmpty ? T("Mọi trang đã lên máy chủ")
                                                         : T("Các trang khác đã lên máy chủ")),
                      systemImage: dongBo.soTrangChoDay > 0 ? "clock" : "checkmark.circle")
            }

            if !dongBo.trangMayChuDaXoa.isEmpty {
                TrangDaXoaOMayKhac(dongBo: dongBo)
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

/// "N trang đã bị xoá ở máy khác" — trang máy chủ đã xoá (thùng rác web /
/// máy khác) nhưng máy này còn bản. Hai lối ra, cả hai do NGƯỜI DÙNG chọn:
/// khôi phục (bỏ xoá trên máy chủ rồi đẩy lại) hoặc bỏ bản trên máy này.
/// Không có lối nào tự chạy: mất một trang ghi chép là không lấy lại được.
struct TrangDaXoaOMayKhac: View {
    @ObservedObject var dongBo: DongBoVo
    @State private var dangLam = false
    @State private var loi: String?
    @State private var hoiXoa = false
    @State private var ds: [DongBoVo.MucDaXoa] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("\(ds.count) " + T("trang đã bị xoá ở máy khác"), systemImage: "trash.slash")
                .font(Font.bodyMedium.weight(.semibold))
                .foregroundStyle(AppColors.warning)
            Text(T("Máy chủ đã xoá các trang này (thùng rác trên web hoặc máy khác), nhưng iPad này vẫn giữ bản đầy đủ. Chúng tạm không được đồng bộ."))
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ds) { m in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundStyle(AppColors.textTertiary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.tenTrang)
                                    .font(Font.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .lineLimit(1)
                                if !m.noiO.isEmpty {
                                    Text(m.noiO)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: min(CGFloat(max(ds.count, 1)) * 44, 180))

            if let loi {
                Label(loi, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Spacing.xs) {
                Button {
                    Task {
                        dangLam = true
                        loi = await dongBo.khoiPhucLenMayChu(ds.map(\.id))
                        dangLam = false
                        napLai()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if dangLam { ProgressView().controlSize(.mini) }
                        Label(T("Khôi phục lên máy chủ"), systemImage: "arrow.uturn.up.circle")
                    }
                    .frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                .disabled(dangLam || ds.isEmpty)

                Button(role: .destructive) {
                    hoiXoa = true
                } label: {
                    Label(T("Xoá khỏi máy này"), systemImage: "trash")
                        .font(Font.bodyMedium.weight(.medium))
                        .foregroundStyle(AppColors.error)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(AppColors.error.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.error.opacity(0.35)))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(dangLam || ds.isEmpty)
            }
        }
        .padding(Spacing.sm)
        .background(AppColors.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .onAppear(perform: napLai)
        .onChange(of: dongBo.trangMayChuDaXoa) { _, _ in napLai() }
        .confirmationDialog(
            String(format: T("Xoá %d trang khỏi iPad này?"), ds.count),
            isPresented: $hoiXoa, titleVisibility: .visible
        ) {
            Button(T("Xoá khỏi máy này"), role: .destructive) {
                dongBo.xoaKhoiMayNay(ds.map(\.id))
                napLai()
            }
            Button(T("Huỷ"), role: .cancel) {}
        } message: {
            Text(T("Nét viết trên máy này sẽ mất. Bản trên web vẫn nằm trong Thùng rác của Notes 30 ngày kể từ lúc bị xoá — khôi phục ở đó được."))
        }
    }

    private func napLai() { ds = dongBo.danhSachMayChuDaXoa() }
}
#endif
