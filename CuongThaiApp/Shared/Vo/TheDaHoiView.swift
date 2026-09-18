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
    private func anhThe(_ t: TheHoiAI, canh: CGFloat, rongCoDinh: CGFloat? = nil) -> some View {
        AnhThe(ten: t.anhTen, canh: canh, rongCoDinh: rongCoDinh)
    }

    private func xoa(_ t: TheHoiAI) {
        if let ten = t.anhTen { KhoAnhThe.bo(ten) }
        if let ten = t.anhTen {
            try? FileManager.default.removeItem(at: KhoVo.duongDanAnhHoi(ten))
        }
        kho.delete(t)
        try? kho.save()
    }
}

// MARK: - Ảnh của thẻ

/// Kho ảnh thẻ đã giải mã, giữ trong bộ nhớ.
///
/// ⚠️ Lý do tồn tại: bản đầu đọc đĩa + giải mã ảnh NGAY TRONG thân View, cho
/// TỪNG thẻ, ở MỌI lần vẽ lại. Một danh sách chục thẻ là chục lượt đọc đĩa
/// và giải mã JPEG trên luồng chính mỗi khi SwiftUI dựng lại — app đơ, bấm
/// nút không ăn. Người dùng báo ngay 18/09/2026: "lag và đơ khi ấn qua mục
/// Đã hỏi, các nút ấn mãi không được".
///
/// `NSCache` tự nhả khi máy thiếu bộ nhớ, nên giữ ảnh ở đây không làm app bị
/// hệ thống thu hồi giữa buổi học.
@MainActor
enum KhoAnhThe {
    private static let kho: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 120
        return c
    }()

    static func san(_ ten: String) -> UIImage? { kho.object(forKey: ten as NSString) }

    static func bo(_ ten: String) {
        kho.removeObject(forKey: ten as NSString)
        try? FileManager.default.removeItem(at: KhoVo.duongDanAnhHoi(ten))
    }

    /// Đọc và THU NHỎ ngoài luồng chính.
    ///
    /// Thu nhỏ chứ không giữ ảnh gốc: thẻ chỉ hiện ở 52-220pt, mà ảnh vùng
    /// khoanh là ảnh màn hình 3× — giữ nguyên cỡ là tốn bộ nhớ gấp mấy chục
    /// lần thứ nhìn thấy.
    static func nap(_ ten: String, canhToiDa: CGFloat) async -> UIImage? {
        if let co = san(ten) { return co }
        let duong = KhoVo.duongDanAnhHoi(ten)
        let px = max(canhToiDa, 64) * 3
        let anh: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let d = try? Data(contentsOf: duong), let goc = UIImage(data: d) else { return nil }
            return goc.preparingThumbnail(of: coVua(goc.size, toiDa: px)) ?? goc
        }.value
        if let anh { kho.setObject(anh, forKey: ten as NSString) }
        return anh
    }

    private nonisolated static func coVua(_ kho: CGSize, toiDa: CGFloat) -> CGSize {
        let ty = min(1, toiDa / max(kho.width, kho.height, 1))
        return CGSize(width: max(kho.width * ty, 1), height: max(kho.height * ty, 1))
    }
}

private struct AnhThe: View {
    let ten: String?
    let canh: CGFloat
    var rongCoDinh: CGFloat?

    @State private var anh: UIImage?

    var body: some View {
        Group {
            if let anh {
                Image(uiImage: anh)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            } else {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(AppColors.backgroundTertiary)
                    .overlay(Image(systemName: ten == nil ? "photo" : "hourglass")
                        .foregroundStyle(AppColors.textTertiary))
            }
        }
        .frame(width: rongCoDinh, height: canh)
        .frame(maxWidth: rongCoDinh == nil ? .infinity : nil)
        .task(id: ten) {
            guard let ten else { anh = nil; return }
            if let co = KhoAnhThe.san(ten) { anh = co; return }
            anh = await KhoAnhThe.nap(ten, canhToiDa: max(canh, rongCoDinh ?? 0))
        }
    }
}
#endif
