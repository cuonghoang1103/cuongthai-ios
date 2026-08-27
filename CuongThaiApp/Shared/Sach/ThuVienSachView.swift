import SwiftUI

// ════════════════════════════════════════════════════════════════
// THƯ VIỆN SÁCH
//
// Bìa vẽ NATIVE chứ không chép cách của web. Web phủ logo hãng bằng CSS mask
// lên file SVG ở `/books/logos/*.svg` — SwiftUI không dựng được SVG, mà kéo
// Kingfisher vào để tải SVG thì cũng không giải mã được. Nên bìa ở đây dựng
// bằng chính màu nhũ của từng tập + số tập + tên: sắc nét ở mọi mật độ điểm
// ảnh, không tốn một lượt mạng nào, và hợp với dáng kệ sách trên điện thoại
// hơn là bê nguyên bìa của web xuống.
// ════════════════════════════════════════════════════════════════

struct ThuVienSachView: View {
    @State private var tim = ""

    private var nhomHien: [NhomSach] {
        let k = tim.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return KhoSach.nhom }
        return KhoSach.nhom.compactMap { n in
            let ds = n.sach.filter {
                $0.tua.localizedCaseInsensitiveContains(k) || $0.vol.contains(k)
            }
            return ds.isEmpty ? nil : NhomSach(tua: n.tua, moTa: n.moTa, sach: ds)
        }
    }

    private let cot = [GridItem(.flexible(), spacing: Spacing.md),
                       GridItem(.flexible(), spacing: Spacing.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                khoiSoLieu
                oTim
                if nhomHien.isEmpty {
                    Text("Không có tập nào khớp “\(tim)”.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                }
                ForEach(nhomHien) { n in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(n.tua)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        Text(n.moTa)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        LazyVGrid(columns: cot, spacing: Spacing.md) {
                            ForEach(n.sach) { s in
                                NavigationLink { DocSachView(sach: s) } label: { bia(s) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, Spacing.xs)
                    }
                }
                Spacer(minLength: Spacing.xl)
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Thư viện sách")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var khoiSoLieu: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("CuongThai Book Series")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(AppColors.textPrimary)
            // Sáu con số của cả bộ — cho người mở lần đầu thấy ngay tầm vóc.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3),
                      spacing: Spacing.sm) {
                ForEach(KhoSach.thongKe, id: \.0) { so, nhan in
                    VStack(spacing: 1) {
                        Text(so)
                            .font(.system(size: 17, weight: .bold).monospacedDigit())
                            .foregroundColor(AppColors.primary)
                        Text(nhan)
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(AppColors.backgroundCard))
                }
            }
        }
    }

    private var oTim: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
            TextField("Tìm tập sách…", text: $tim)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            if !tim.isEmpty {
                Button { tim = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.sm + 2)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    // ── Bìa sách ─────────────────────────────────────────────────
    private func bia(_ s: Sach) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ZStack(alignment: .topLeading) {
                // Gáy sách: dải đậm bên trái, đúng dáng bìa cứng nhìn nghiêng.
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(LinearGradient(colors: [s.mau, s.mau.opacity(0.72)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                HStack(spacing: 0) {
                    Rectangle().fill(.black.opacity(0.22)).frame(width: 9)
                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("VOL \(s.vol)")
                        .font(.system(size: 10, weight: .heavy).monospacedDigit())
                        .kerning(1.2)
                        .foregroundColor(.white.opacity(0.85))
                    Spacer(minLength: 0)
                    Text(s.tua)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, Spacing.md + 6)
                .padding([.trailing, .top, .bottom], Spacing.md)
            }
            .frame(height: 168)
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1))

            Text("\(s.soChuong) chương · \(s.soBaiTap) bài tập")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
                .lineLimit(1)
        }
    }
}

// MARK: - Lối vào từ tab Học

struct SachEntryCard: View {
    var body: some View {
        NavigationLink { ThuVienSachView() } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x8A5A14), Color(hex: 0xC08A2E)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thư viện sách")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("25 tập · 412 chương · song ngữ Anh–Việt")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard))
        }
        .buttonStyle(.plain)
    }
}
