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
                .font(.system(size: 30, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 76, height: 76)
                .background(Circle().fill(AppColors.primary.opacity(0.12)))
                .padding(.bottom, 4)
                .accessibilityHidden(true)
            Text(tieuDe).font(.system(size: 17, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            if !moTa.isEmpty {
                Text(moTa).font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            if let nut, let hanhDong {
                Button(action: hanhDong) {
                    Text(nut).font(.system(size: 15, weight: .semibold)).padding(.horizontal, 18).padding(.vertical, 9)
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
        CTWOTrong(bieuTuong: "wifi.exclamationmark", tieuDe: "Couldn't load", moTa: loi, nut: "Try again", hanhDong: thuLai)
    }
}

/// KHUNG TẢI (skeleton) — vài hàng xám nhấp nháy nhẹ, thay cho vòng quay giữa
/// màn trống. Tôn trọng "Giảm chuyển động" của hệ thống.
struct CTWKhungTai: View {
    var soHang = 6
    var coAvatar = true
    @State private var sang = false
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong

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
        .padding(.horizontal, 16)
        .ctwThe(14)
        .padding(Spacing.md)
        .opacity(sang ? 0.55 : 1)
        .onAppear {
            guard !giamChuyenDong else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { sang = true }
        }
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
                            if let b = c.bieuTuong { Image(systemName: b).font(.system(size: 11, weight: .semibold)) }
                            Text(c.nhan).font(.system(size: 13, weight: .semibold)).fixedSize()
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
