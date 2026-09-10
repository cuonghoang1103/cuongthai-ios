import SwiftUI

// MARK: - Bài học của một chương

struct BaiHocView: View {
    let chuong: ChuongCode
    let mauLoTrinh: UInt32

    @State private var bai: BaiHocChuong?
    @State private var dangTai = true
    @State private var loi: String?
    /// Nhớ qua cả bài học lẫn bài tập — xem `NgonNguCodeLab.swift`.
    @AppStorage(CodeLabNgonNgu.khoa) private var ngonNgu: NgonNguDe = .anh

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
        .toolbar {
            // Chỉ hiện khi bài NÀY có bản dịch. Nút luôn hiện ở lộ trình chưa
            // dịch (java, python, sql…) là bấm xong màn hình y nguyên.
            if bai?.coTiengViet == true {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NutDoiNgonNgu(ngonNgu: $ngonNgu)
                }
            }
        }
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
            Text(k.tieuDe(ngonNgu))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.sm)

        case .phan:
            // Vách ngăn phần — bài học dài chia thành mấy phần đánh số.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    if let n = k.number, !n.isEmpty {
                        Text(n)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color(hex: mauLoTrinh)))
                    }
                    Text(k.tieuDe(ngonNgu))
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let p = k.phuDe(ngonNgu) {
                    Text(p)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color(hex: mauLoTrinh).opacity(0.12)))
            .padding(.top, Spacing.md)

        case .chu:
            // Dùng lại bộ dựng HTML của màn bài học — nó đã tự co chiều cao và
            // đã có sẵn kiểu chữ cho `<p>`, `<ul>`, `<strong>`, `<code>`.
            RichContent(html: k.noiDungHTML(ngonNgu))

        case .ma:
            KhoiMaNguon(ma: k.ma(ngonNgu), ngonNgu: k.language, tieuDe: k.tenMa(ngonNgu))

        case .soDo:
            SoDoMermaid(ma: k.ma(ngonNgu))

        case .anh:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let u = k.url { AnhBaiHoc(duong: u) }
                if let c = k.chuThich(ngonNgu) {
                    Text(c).font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                }
            }

        case .lienKet:
            hopLienKet(k, tieuDe: "ĐỌC THÊM", bieuTuong: "arrow.up.right.square")

        case .thucHanh:
            // Đường dẫn sang bài tập/chương khác. Đường là ĐƯỜNG TRONG WEB
            // ("/code-lab/java-core#module-246") nên phải ghép tên miền.
            hopLienKet(k, tieuDe: "LUYỆN TẬP", bieuTuong: "chevron.right.square")

        case .khac:
            // Máy chủ thêm loại khối mới. Im lặng bỏ qua ở bản phát hành,
            // nhưng bản DEBUG phải NÓI RA — đúng cái bẫy đã nuốt mất
            // `part`/`practice` suốt từ lúc dựng màn này.
            #if DEBUG
            Text("⚠️ khối lạ: \(k.type ?? "nil")")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
            #else
            EmptyView()
            #endif
        }
    }

    /// Hộp danh sách đường dẫn, dùng chung cho `links` và `practice`.
    private func hopLienKet(_ k: KhoiBaiHoc, tieuDe: String, bieuTuong: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(tieuDe)
                .font(.system(size: 10, weight: .bold)).kerning(0.5)
                .foregroundColor(AppColors.textTertiary)
            ForEach(k.items ?? []) { m in
                if let url = duongDay(m.url) {
                    Link(destination: url) {
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: bieuTuong)
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.ten(ngonNgu))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let mt = m.moTa(ngonNgu) {
                                    Text(mt)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColors.textSecondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
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

    /// `practice` trả đường TƯƠNG ĐỐI của web ("/code-lab/…"), `links` trả
    /// đường tuyệt đối. Không ghép tên miền thì `URL(string:)` ra đường không
    /// mở được và cả mục biến mất.
    private func duongDay(_ s: String?) -> URL? {
        guard let s, !s.isEmpty else { return nil }
        if s.hasPrefix("/") { return URL(string: "https://cuongthai.com" + s) }
        return URL(string: s)
    }
}
