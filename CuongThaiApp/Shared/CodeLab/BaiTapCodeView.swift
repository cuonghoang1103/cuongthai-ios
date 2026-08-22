import SwiftUI

// MARK: - Chi tiết một bài tập
//
// KHÔNG gọi mạng: danh sách đã trả về trọn vẹn đối tượng (đề bài, ví dụ, gợi
// ý, mã lời giải). Mở là hiện ngay.

struct BaiTapCodeView: View {
    let bai: BaiTapCode

    @State private var hienGoiY = 0
    @State private var hienLoiGiai = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                dauTrang

                if !bai.deBai.isEmpty { RichContent(html: bai.deBai) }

                if let s = bai.inputSpec, !s.isEmpty { o("ĐẦU VÀO", s) }
                if let s = bai.outputSpec, !s.isEmpty { o("ĐẦU RA", s) }
                if let s = bai.constraints, !s.isEmpty { o("RÀNG BUỘC", s) }

                // Nút viết mã đặt NGAY dưới đề bài, trên cả ví dụ: người ta
                // đọc đề xong là muốn bắt tay vào viết, không phải cuộn qua
                // gợi ý và lời giải mới thấy chỗ gõ.
                NavigationLink { SoanMaView(bai: bai) } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("Viết mã và kiểm tra")
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppColors.onPrimary)
                    .padding(Spacing.md)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(Color(hex: bai.doKho.mau)))
                }
                .buttonStyle(.plain)

                if let vd = bai.examplesJson, !vd.isEmpty {
                    nhan("VÍ DỤ")
                    ForEach(Array(vd.enumerated()), id: \.offset) { i, v in theViDu(i + 1, v) }
                }

                if let gy = bai.hintsJson, !gy.isEmpty { khungGoiY(gy) }

                if let ma = bai.solutionCodeJson, !ma.isEmpty { khungLoiGiai(ma) }

                if let cs = bai.concepts, !cs.isEmpty { theNhan("KHÁI NIỆM", cs) }
                if let ts = bai.tags, !ts.isEmpty { theNhan("THẺ", ts) }

                Spacer(minLength: Spacing.xl)
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(bai.doKho.ten)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Mảnh

    private var dauTrang: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(bai.title)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.sm) {
                Text(bai.doKho.ten)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, Spacing.sm).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: bai.doKho.mau)))
                if let l = bai.language {
                    Text(l).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                if bai.phut > 0 {
                    Text("· \(bai.phut) phút").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                }
                if bai.diem > 0 {
                    Text("· \(bai.diem) điểm").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                }
            }
        }
    }

    private func nhan(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 10, weight: .bold)).kerning(0.5)
            .foregroundColor(AppColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func o(_ ten: String, _ chu: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            nhan(ten)
            Text(chu)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
    }

    private func theViDu(_ so: Int, _ v: BaiTapCode.ViDu) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Ví dụ \(so)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.primary)
            if let i = v.input, !i.isEmpty { doiMa("Vào", i) }
            if let o = v.output, !o.isEmpty { doiMa("Ra", o) }
            if let e = v.explanation, !e.isEmpty {
                Text(e).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
    }

    private func doiMa(_ ten: String, _ chu: String) -> some View {
        // Vào/Ra của ví dụ thường là JSON hoặc giá trị mẫu — tô màu theo ngôn
        // ngữ của chính bài để dấu ngoặc, chuỗi và số tách nhau ra.
        KhoiMaNguon(ma: chu, ngonNgu: bai.language, tieuDe: ten, choChep: false)
    }

    /// Gợi ý mở DẦN từng cái một — mở hết cùng lúc thì người ta đọc luôn cái
    /// cuối, mà cái cuối gần như là lời giải.
    private func khungGoiY(_ gy: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            nhan("GỢI Ý (\(hienGoiY)/\(gy.count))")
            ForEach(0..<min(hienGoiY, gy.count), id: \.self) { i in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("\(i + 1)").font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: 0xD97706))
                    Text(gy[i]).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if hienGoiY < gy.count {
                Button {
                    withAnimation { hienGoiY += 1 }
                } label: {
                    Text(hienGoiY == 0 ? "Xem gợi ý đầu tiên" : "Gợi ý tiếp theo")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: 0xD97706))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(Color(hex: 0xD97706).opacity(0.10)))
    }

    /// Lời giải GIẤU sau một nút. Hiện sẵn thì cuộn qua là thấy, và bài tập
    /// mất hết tác dụng trước khi người ta kịp nghĩ.
    private func khungLoiGiai(_ ma: [BaiTapCode.KhoiMa]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if hienLoiGiai {
                nhan("LỜI GIẢI")
                ForEach(ma) { k in
                    KhoiMaNguon(ma: k.code ?? "", ngonNgu: k.language ?? bai.language,
                                tieuDe: k.name)
                }
                if let gt = bai.giaiThich { RichContent(html: gt) }
            } else {
                Button {
                    withAnimation { hienLoiGiai = true }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "eye")
                        Text("Xem lời giải").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .strokeBorder(AppColors.primary.opacity(0.5), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func theNhan(_ ten: String, _ ds: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            nhan(ten)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(ds, id: \.self) { s in
                        Text(s)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, Spacing.sm).padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.backgroundTertiary))
                    }
                }
            }
        }
    }
}
