#if os(iOS)
import SwiftData
import SwiftUI

// ════════════════════════════════════════════════════════════════
// ĐÃ HỎI — chỗ nào mình từng vướng
//
// Mỗi lần khoanh–hỏi trong vở đẻ ra một thẻ ở đây. Hai việc:
//
//  · Câu trả lời KHÔNG bay mất. Trước đây tra một chữ giữa giờ học, đóng
//    khung hỏi là hết — tối về không còn gì.
//  · Thành bộ ÔN TẬP. Khoanh 20 từ trong buổi học thì tối có 20 thẻ, đúng
//    những chỗ mình đã vướng chứ không phải một danh sách chung chung.
//
// Bộ thẻ này hơn danh sách từ vựng in sẵn ở chỗ: nó là những chỗ CHÍNH MÌNH
// không hiểu, kèm đúng bối cảnh trang sách lúc đó.
// ════════════════════════════════════════════════════════════════

struct TheDaHoiView: View {
    @Environment(\.modelContext) private var kho
    @Query(sort: \TheHoiAI.taoLuc, order: .reverse) private var the: [TheHoiAI]

    @State private var cheDoOn = false
    @State private var chiSo = 0
    @State private var lat = false

    private var chuaThuoc: [TheHoiAI] { the.filter { !$0.daThuoc } }

    var body: some View {
        Group {
            if the.isEmpty {
                trong
            } else if cheDoOn {
                manOn
            } else {
                danhSach
            }
        }
        .navigationTitle(T("Đã hỏi"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !the.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        chiSo = 0; lat = false
                        withAnimation(.easeOut(duration: 0.2)) { cheDoOn.toggle() }
                    } label: {
                        Label(cheDoOn ? T("Danh sách") : T("Ôn tập"),
                              systemImage: cheDoOn ? "list.bullet" : "rectangle.on.rectangle")
                    }
                    .disabled(!cheDoOn && chuaThuoc.isEmpty)
                }
            }
        }
    }

    // ── Trống ───────────────────────────────────────────────────
    private var trong: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "lasso.badge.sparkles")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.textTertiary)
            Text(T("Chưa có thẻ nào"))
                .font(Font.titleSmall)
                .foregroundStyle(AppColors.textPrimary)
            Text(T("Mở một cuốn vở, bấm bút AI rồi khoanh một chữ để hỏi — mỗi lần hỏi sẽ thành một thẻ ở đây."))
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundPrimary)
    }

    // ── Danh sách ───────────────────────────────────────────────
    private var danhSach: some View {
        List {
            if !chuaThuoc.isEmpty {
                Section {
                    Text("\(chuaThuoc.count) \(T("thẻ chưa thuộc")) · \(the.count) \(T("thẻ tất cả"))")
                        .font(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            ForEach(the) { t in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        anhThe(t, canh: 52, rongCoDinh: 92)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.cauHoi)
                                .font(Font.bodyMedium.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text("\(t.tenCuon) · \(T("trang")) \(t.soTrang)")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        Spacer(minLength: 0)
                        if t.daThuoc {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(AppColors.success)
                        }
                    }
                    Text(t.traLoi)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(4)
                }
                .padding(.vertical, 2)
                .swipeActions {
                    Button(role: .destructive) { xoa(t) } label: {
                        Label(T("Xoá"), systemImage: "trash")
                    }
                    Button { t.daThuoc.toggle(); try? kho.save() } label: {
                        Label(t.daThuoc ? T("Ôn lại") : T("Đã thuộc"),
                              systemImage: t.daThuoc ? "arrow.counterclockwise" : "checkmark")
                    }
                    .tint(AppColors.success)
                }
            }
        }
    }

    // ── Ôn tập ──────────────────────────────────────────────────
    @ViewBuilder
    private var manOn: some View {
        let ds = chuaThuoc
        if ds.isEmpty {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.success)
                Text(T("Thuộc hết rồi!"))
                    .font(Font.titleMedium)
                    .foregroundStyle(AppColors.textPrimary)
                Button(T("Xem lại danh sách")) { cheDoOn = false }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.backgroundPrimary)
        } else {
            let t = ds[min(chiSo, ds.count - 1)]
            VStack(spacing: Spacing.md) {
                Text("\(min(chiSo + 1, ds.count)) / \(ds.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppColors.textTertiary)

                // Mặt trước: ảnh vùng đã khoanh + câu hỏi. Người học nhìn lại
                // đúng chỗ mình từng vướng, tự nhớ trước khi lật.
                VStack(spacing: Spacing.sm) {
                    anhThe(t, canh: 220)
                    Text(t.cauHoi)
                        .font(Font.bodyLarge.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("\(t.tenCuon) · \(T("trang")) \(t.soTrang)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(AppColors.backgroundCard))

                if lat {
                    ScrollView {
                        Text(t.traLoi)
                            .font(Font.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.md)
                    }
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(AppColors.backgroundCard))
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { lat = true }
                        Haptics.cham()
                    } label: {
                        Label(T("Lật xem đáp án"), systemImage: "arrow.2.squarepath")
                            .font(Font.buttonText)
                            .foregroundStyle(AppColors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                                .fill(AppColors.primary))
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }

                if lat {
                    HStack(spacing: Spacing.sm) {
                        nut(T("Chưa thuộc"), "arrow.counterclockwise", AppColors.warning) {
                            sang(ds)
                        }
                        nut(T("Đã thuộc"), "checkmark", AppColors.success) {
                            t.daThuoc = true
                            try? kho.save()
                            sang(ds)
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppColors.backgroundPrimary)
        }
    }

    private func nut(_ nhan: String, _ icon: String, _ mau: Color,
                     _ cham: @escaping () -> Void) -> some View {
        Button(action: cham) {
            Label(nhan, systemImage: icon)
                .font(Font.buttonSmall)
                .foregroundStyle(mau)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(mau.opacity(0.14)))
                .overlay(Capsule().stroke(mau.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func sang(_ ds: [TheHoiAI]) {
        lat = false
        // Danh sách co lại khi một thẻ được đánh dấu thuộc, nên phải kẹp lại
        // — không thì chỉ số trỏ ra ngoài mảng và màn hình trống trơn.
        chiSo = ds.count <= 1 ? 0 : (chiSo + 1) % max(ds.count - 1, 1)
    }

    /// - Parameter rongCoDinh: đặt khi ảnh phải nằm trong một HÀNG.
    ///
    /// ⚠️ Không có nó thì `maxWidth: .infinity` cho ảnh nở hết bề ngang thẻ
    /// và đẩy câu hỏi sang tận mép phải — vùng khoanh thường rất dẹt (một
    /// dòng chữ), nên nở theo tỉ lệ là nó chiếm cả hàng.
    @ViewBuilder
    private func anhThe(_ t: TheHoiAI, canh: CGFloat, rongCoDinh: CGFloat? = nil) -> some View {
        if let ten = t.anhTen,
           let d = try? Data(contentsOf: KhoVo.duongDanAnhHoi(ten)),
           let ui = UIImage(data: d) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: rongCoDinh, height: canh)
                .frame(maxWidth: rongCoDinh == nil ? .infinity : nil)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        } else {
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(AppColors.backgroundTertiary)
                .frame(width: rongCoDinh ?? canh, height: canh * 0.6)
                .overlay(Image(systemName: "photo")
                    .foregroundStyle(AppColors.textTertiary))
        }
    }

    private func xoa(_ t: TheHoiAI) {
        if let ten = t.anhTen {
            try? FileManager.default.removeItem(at: KhoVo.duongDanAnhHoi(ten))
        }
        kho.delete(t)
        try? kho.save()
    }
}
#endif
