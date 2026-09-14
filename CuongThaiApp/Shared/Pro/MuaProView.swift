#if os(iOS)
import SwiftUI
import StoreKit

// ════════════════════════════════════════════════════════════════
// MÀN NÂNG CẤP PRO
//
// ⚠️ Giá hiện ở đây là `product.displayPrice` của StoreKit, KHÔNG phải giá
// lấy từ `/api/v1/pro/plans`. Hai lý do:
//   · Apple quy đổi tiền tệ và thuế theo cửa hàng của từng nước; in giá của
//     web ra là sai với người dùng ở nước khác, và sai tiền là lỗi nặng.
//   · Ngoài cửa hàng Mỹ, guideline 3.1.1(a) cấm mọi lời dẫn người dùng sang
//     cách thanh toán khác. Nói "trên web rẻ hơn" là đúng thứ bị cấm.
//
// Nút "Khôi phục giao dịch" là BẮT BUỘC theo 3.1.1 ("make sure you have a
// restore mechanism"). Link Điều khoản + Bảo mật cũng bắt buộc trên màn bán.
// ════════════════════════════════════════════════════════════════

struct MuaProView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var kho = KhoPro.shared
    @Environment(\.dismiss) private var dismiss

    private var dangPro: Bool { appState.currentUser?.isPro == true }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    dauTrang
                    if dangPro { theDangCo }
                    bangGoi
                    loiIch
                    chanTrang
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Nâng cấp Pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Đóng")) { dismiss() }
                }
            }
            .task { await kho.napGoi() }
            .alert(T("Không thực hiện được"), isPresented: Binding(
                get: { kho.loi != nil }, set: { if !$0 { kho.loi = nil } })) {
                Button("OK") { kho.loi = nil }
            } message: { Text(kho.loi ?? "") }
            .onChange(of: kho.vuaXong) { _, xong in
                if xong { kho.vuaXong = false; dismiss() }
            }
        }
    }

    // MARK: Các mảnh

    private var dauTrang: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundColor(AppColors.accent)
                .padding(.top, Spacing.md)
            Text(T("Mở khoá toàn bộ CuongMini"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    /// Đang có Pro thì KHÔNG giấu bảng giá — mua thêm là gia hạn, và máy chủ
    /// cộng dồn vào hạn hiện có chứ không ghi đè.
    private var theDangCo: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.seal.fill").foregroundColor(AppColors.success)
            Text(T("Bạn đang có Pro. Mua thêm sẽ CỘNG vào hạn hiện tại, không mất ngày nào."))
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(AppColors.success.opacity(0.12)))
    }

    @ViewBuilder
    private var bangGoi: some View {
        if kho.dangTai && kho.goi.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, Spacing.xl)
        } else if kho.goi.isEmpty {
            // Hay gặp nhất khi chưa duyệt hợp đồng Paid Applications, hoặc mã
            // sản phẩm chưa tạo. Nói rõ hơn là để một khoảng trắng.
            VStack(spacing: Spacing.sm) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 24)).foregroundColor(AppColors.warning)
                Text(T("Chưa tải được bảng giá từ App Store."))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Button(T("Thử lại")) { Task { await kho.napGoi() } }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity).padding(.vertical, Spacing.lg)
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(kho.goi, id: \.id) { sp in hangGoi(sp) }
            }
        }
    }

    private func hangGoi(_ sp: Product) -> some View {
        Button {
            guard let id = appState.currentUser?.id else { return }
            Task { await kho.mua(sp, userId: id) }
        } label: {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(sp.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    if !sp.description.isEmpty {
                        Text(sp.description)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: Spacing.sm)
                if kho.dangMua == sp.id {
                    ProgressView()
                } else {
                    Text(sp.displayPrice)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .fill(AppColors.backgroundCard)
                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .strokeBorder(AppColors.primary.opacity(0.28), lineWidth: 1))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(kho.dangMua != nil)
    }

    private var loiIch: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(T("Pro mở khoá"))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            ForEach([
                T("Hỏi CuongMini trong phòng thi"),
                T("Gia sư AI cho từng bài học"),
                T("Chấm mã bằng AI ở Code Lab"),
                T("Luyện nói và gia sư ngoại ngữ"),
                T("Chấm và viết lại CV bằng AI"),
            ], id: \.self) { d in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13)).foregroundColor(AppColors.success)
                    Text(d).font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private var chanTrang: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                Task { await kho.khoiPhuc() }
            } label: {
                if kho.dangMua == "khoi-phuc" {
                    ProgressView()
                } else {
                    Text(T("Khôi phục giao dịch"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
            }
            .frame(minHeight: 44)
            .disabled(kho.dangMua != nil)

            Text(T("Đã mua Pro trên web? Đăng nhập cùng tài khoản là dùng được ngay, không phải mua lại."))
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.md) {
                NavigationLink(T("Điều khoản")) { TermsView() }
                Text("·").foregroundColor(AppColors.textTertiary)
                NavigationLink(T("Chính sách bảo mật")) { PrivacyPolicyView() }
            }
            .font(.system(size: 12))
            .foregroundColor(AppColors.primary)
            .padding(.top, 2)
        }
        .padding(.top, Spacing.sm)
    }
}
#endif
