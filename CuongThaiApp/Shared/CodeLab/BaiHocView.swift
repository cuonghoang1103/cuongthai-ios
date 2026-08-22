import SwiftUI

// MARK: - Bài học của một chương

struct BaiHocView: View {
    let chuong: ChuongCode
    let mauLoTrinh: UInt32

    @State private var bai: BaiHocChuong?
    @State private var dangTai = true
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                dauTrang
                if dangTai {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else if let b = bai, !b.dsKhoi.isEmpty {
                    ForEach(b.dsKhoi) { k in khoi(k) }
                } else {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "book.closed").font(.system(size: 36))
                            .foregroundColor(AppColors.textTertiary)
                        Text(loi ?? "Chương này chưa có bài học.")
                            .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                }
                Spacer(minLength: Spacing.xl)
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Bài học")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard bai == nil else { return }
            dangTai = true; defer { dangTai = false }
            do { bai = try await APIClient.shared.request(.baiHocChuong(chuongId: chuong.id)) }
            catch { loi = error.localizedDescription }
        }
    }

    private var dauTrang: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(chuong.ten)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let d = chuong.description, !d.isEmpty {
                Text(d)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(Color(hex: mauLoTrinh)).frame(height: 3).frame(maxWidth: 56)
                .clipShape(Capsule())
                .padding(.top, Spacing.xs)
        }
    }

    @ViewBuilder
    private func khoi(_ k: KhoiBaiHoc) -> some View {
        switch k.loai {
        case .tieuDe:
            Text(k.tieuDeHien)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.sm)

        case .chu:
            // Dùng lại bộ dựng HTML của màn bài học — nó đã tự co chiều cao và
            // đã có sẵn kiểu chữ cho `<p>`, `<ul>`, `<strong>`, `<code>`.
            RichContent(html: k.htmlHien)

        case .ma:
            KhoiMaNguon(ma: k.code ?? "", ngonNgu: k.language, tieuDe: k.tenMaHien)

        case .soDo:
            SoDoMermaid(ma: k.code ?? "")

        case .lienKet:
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("ĐỌC THÊM")
                    .font(.system(size: 10, weight: .bold)).kerning(0.5)
                    .foregroundColor(AppColors.textTertiary)
                ForEach(k.items ?? []) { m in
                    if let u = m.url, let url = URL(string: u) {
                        Link(destination: url) {
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.note ?? u)
                                        .font(.system(size: 13))
                                        .foregroundColor(AppColors.textPrimary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(url.host ?? u)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppColors.textTertiary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.backgroundCard))
        }
    }
}
