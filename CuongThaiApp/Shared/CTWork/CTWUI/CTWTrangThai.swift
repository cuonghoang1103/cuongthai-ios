import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - CTWUI — trạng thái màn: trống · lỗi · đang tải (skeleton) · rung

/// Ô TRỐNG chuẩn: biểu tượng tròn tô nhạt + tiêu đề + mô tả + nút tuỳ chọn.
struct CTWOTrong: View {
    let bieuTuong: String
    let tieuDe: String
    var moTa: String = ""
    var nut: String?
    var hanhDong: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: bieuTuong)
                .font(.ctw(size: 30, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 76, height: 76)
                .background(Circle().fill(AppColors.primary.opacity(0.12)))
                .padding(.bottom, 4)
                .accessibilityHidden(true)
            Text(tieuDe).font(.ctw(size: 17, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            if !moTa.isEmpty {
                Text(moTa).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            if let nut, let hanhDong {
                Button(action: hanhDong) {
                    Text(nut).font(.ctw(size: 15, weight: .semibold)).padding(.horizontal, 18).padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.xl)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }
}

/// Ô LỖI toàn màn + nút Thử lại (lỗi nhỏ tại chỗ thì dùng `CTWErrorBanner`).
struct CTWOLoi: View {
    let loi: String
    let thuLai: () -> Void
    var body: some View {
        CTWOTrong(bieuTuong: "wifi.exclamationmark", tieuDe: String(localized: "Couldn't load"), moTa: loi, nut: String(localized: "Try again"), hanhDong: thuLai)
    }
}

/// KHUNG TẢI (skeleton) — vài hàng xám nhấp nháy nhẹ, thay cho vòng quay giữa
/// màn trống. Tôn trọng "Giảm chuyển động" của hệ thống.
struct CTWKhungTai: View {
    var soHang = 6
    var coAvatar = true

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<soHang, id: \.self) { i in
                HStack(spacing: 12) {
                    if coAvatar { Circle().frame(width: 30, height: 30) }
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 4).frame(height: 12).frame(maxWidth: i % 2 == 0 ? .infinity : 220)
                        RoundedRectangle(cornerRadius: 4).frame(width: 120, height: 9)
                    }
                }
                .padding(.vertical, 12)
                if i < soHang - 1 { Divider() }
            }
        }
        .foregroundColor(AppColors.backgroundTertiary)
        .anhLuot()   // 21/10/2026: ánh lướt thay cho nhấp nháy (Shared/ChuyenDong) — Giảm chuyển động ⇒ đứng yên
        .padding(.horizontal, 16)
        .ctwThe(14)
        .padding(Spacing.md)
        .accessibilityLabel("Loading")
    }
}

/// KHUNG TẢI của BẢNG: vài cột, mỗi cột tiêu đề + 3 thẻ xám có ánh lướt — thay vòng quay giữa màn (21/10/2026).
struct CTWKhungTaiBang: View {
    var soCot = 3
    var body: some View {
        GeometryReader { g in
            let rong = g.size.width > 600 ? 280 : max(240, g.size.width * 0.82)
            HStack(alignment: .top, spacing: 12) {
                ForEach(0..<soCot, id: \.self) { c in
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 5).frame(width: 96, height: 14).padding(.bottom, 4)
                        ForEach(0..<(3 - c % 2), id: \.self) { i in
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 4).frame(height: 12)
                                RoundedRectangle(cornerRadius: 4).frame(width: i % 2 == 0 ? 150 : 110, height: 12)
                                HStack {
                                    RoundedRectangle(cornerRadius: 4).frame(width: 54, height: 10)
                                    Spacer()
                                    Circle().frame(width: 22, height: 22)
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.backgroundCard))
                        }
                    }
                    .padding(10)
                    .frame(width: rong, alignment: .top)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundSecondary.opacity(0.6)))
                }
            }
            .foregroundColor(AppColors.backgroundTertiary)
            .anhLuot()
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}

/// RUNG nhẹ — phản hồi cho thao tác thành công/lỗi/chọn. Gọi ở chỗ thao tác
/// THẬT xong (sau khi máy chủ trả lời), không gọi lúc vừa bấm.
enum CTWRung {
    static func thanhCong() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func loi() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
    static func chon() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

// MARK: - Thanh lọc (chip ngang)

struct CTWChipLoc: Identifiable, Hashable {
    var id: String
    var nhan: String
    var bieuTuong: String?
    var bat: Bool
}

/// Hàng chip lọc cuộn ngang. ⚠️ Chữ trong ScrollView ngang PHẢI `fixedSize`
/// (bẫy SwiftUI: thiếu là chữ bị cắt cụt mà trông như bình thường).
struct CTWThanhLoc: View {
    let chip: [CTWChipLoc]
    let bam: (CTWChipLoc) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chip) { c in
                    Button { CTWRung.chon(); bam(c) } label: {
                        HStack(spacing: 5) {
                            if let b = c.bieuTuong { Image(systemName: b).font(.ctw(size: 11, weight: .semibold)) }
                            Text(c.nhan).font(.ctw(size: 13, weight: .semibold)).fixedSize()
                        }
                        .foregroundColor(c.bat ? AppColors.onPrimary : AppColors.textPrimary)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(c.bat ? AppColors.primary : AppColors.backgroundCard))
                        .overlay(Capsule().strokeBorder(c.bat ? Color.clear : AppColors.border, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(c.bat ? .isSelected : [])
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 4)
        }
    }
}
