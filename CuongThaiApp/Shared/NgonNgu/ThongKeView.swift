import SwiftUI

// ════════════════════════════════════════════════════════════════
// THỐNG KÊ HỌC TẬP
//
// `GET /my-language/stats?languageCode=` — tuyến này đã được khai trong
// `APIEndpoint` từ lâu mà KHÔNG màn nào gọi tới, nên số liệu học tập của
// người dùng nằm im trên máy chủ. Web có `/language/[code]/stats`, app thì
// không có gì.
//
// ⚠️⚠️ **`perSection` KHÔNG lọc theo ngôn ngữ.** Đọc `getStats` ở backend:
// `groupBy` chỉ có `where: { userId }`, còn `languageCode` chỉ được dùng để
// lọc `quizHistory`. Nghĩa là số "đã thuộc / đang ôn" là TỔNG của cả tiếng
// Anh, Nhật, Trung cộng lại. Đây là hành vi của máy chủ, không phải lỗi app —
// nên màn này phải NÓI RA điều đó thay vì gắn nhãn "Tiếng Anh" lên một con số
// gộp ba thứ tiếng. Web cũng không nói, và đó là chỗ web đang gây hiểu nhầm.
// ════════════════════════════════════════════════════════════════

struct ThongKeView: View {
    let ngonNgu: NgonNgu

    @State private var tk: ThongKeHoc?
    @State private var dangTai = true
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if dangTai && tk == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
                } else if let t = tk {
                    theChuoiNgay(t)
                    if !t.dsMuc.isEmpty { khoiTungMuc(t) }
                    if !t.dsQuiz.isEmpty { khoiLichSu(t) }
                    if t.dsMuc.isEmpty && t.dsQuiz.isEmpty { trong }
                } else {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 40)).foregroundColor(AppColors.textTertiary)
                        Text(loi ?? "Chưa có dữ liệu học tập.")
                            .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
                }
                Spacer(minLength: Spacing.xl)
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Thống kê")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard tk == nil else { return }
            dangTai = true; defer { dangTai = false }
            do { tk = try await APIClient.shared.request(.thongKeNgonNgu(code: ngonNgu.code)) }
            catch { loi = error.localizedDescription }
        }
    }

    private var trong: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 36)).foregroundColor(AppColors.textTertiary)
            Text("Chưa có gì để thống kê — học vài từ hoặc làm một bài kiểm tra là số liệu hiện ra.")
                .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
    }

    // ── Chuỗi ngày ───────────────────────────────────────────────
    private func theChuoiNgay(_ t: ThongKeHoc) -> some View {
        HStack(spacing: Spacing.md) {
            Text("🔥").font(.system(size: 40))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(t.streak) ngày liên tiếp")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text(t.streak == 0
                     ? "Ôn một từ hôm nay là bắt đầu chuỗi mới."
                     : "Ôn tập hôm nay để giữ chuỗi.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    // ── Tiến độ từng mục ─────────────────────────────────────────
    private func khoiTungMuc(_ t: ThongKeHoc) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("TIẾN ĐỘ TỪNG MỤC")
                .font(.system(size: 10, weight: .bold)).kerning(0.5)
                .foregroundColor(AppColors.textTertiary)
            // Nói thẳng con số này gộp mọi thứ tiếng — xem ghi chú đầu file.
            Text("Máy chủ trả phần này cho TẤT CẢ ngôn ngữ bạn học, chưa tách riêng \(ngonNgu.name).")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(t.dsMuc, id: \.ma) { m in hangMuc(m) }
        }
    }

    private func hangMuc(_ m: ThongKeHoc.Muc) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(m.ten)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(m.mastered)/\(m.total)")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
            }
            // Ba khúc: đã thuộc · đang ôn · đang học. Vẽ bằng GeometryReader
            // chứ không bằng ba `Rectangle` cố định, vì tổng có thể là 0.
            GeometryReader { g in
                HStack(spacing: 1) {
                    khuc(g.size.width, m.mastered, m.total, AppColors.success)
                    khuc(g.size.width, m.reviewing, m.total, AppColors.primary)
                    khuc(g.size.width, m.learning, m.total, AppColors.warning)
                    khuc(g.size.width, m.moi, m.total, AppColors.textTertiary)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 8)
            .background(Capsule().fill(AppColors.backgroundTertiary))
            .clipShape(Capsule())

            HStack(spacing: Spacing.md) {
                chuThich("đã thuộc", m.mastered, AppColors.success)
                chuThich("đang ôn", m.reviewing, AppColors.primary)
                chuThich("đang học", m.learning, AppColors.warning)
                if m.moi > 0 { chuThich("chưa học", m.moi, AppColors.textTertiary) }
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private func khuc(_ rong: CGFloat, _ n: Int, _ tong: Int, _ mau: Color) -> some View {
        Rectangle().fill(mau)
            .frame(width: tong > 0 ? rong * CGFloat(n) / CGFloat(tong) : 0)
    }

    /// 80% trở lên là xanh, 50–79% vàng, dưới 50% đỏ.
    private func mauDiem(_ pt: Int) -> Color {
        pt >= 80 ? AppColors.success : (pt >= 50 ? AppColors.warning : AppColors.error)
    }

    private func chuThich(_ ten: String, _ n: Int, _ mau: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(mau).frame(width: 7, height: 7)
            Text("\(ten) \(n)")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
        }
    }

    // ── Lịch sử kiểm tra ─────────────────────────────────────────
    private func khoiLichSu(_ t: ThongKeHoc) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("LỊCH SỬ KIỂM TRA (\(t.dsQuiz.count))")
                .font(.system(size: 10, weight: .bold)).kerning(0.5)
                .foregroundColor(AppColors.textTertiary)
            // Máy chủ trả theo thứ tự CŨ → MỚI (`quizzes.reverse()`), nên đảo
            // lại để lượt gần nhất nằm trên cùng.
            ForEach(t.dsQuiz.reversed()) { q in
                HStack(spacing: Spacing.md) {
                    Text("\(q.score)/\(q.total)")
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .foregroundColor(mauDiem(q.phanTram))
                        .frame(width: 56, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(q.phanTramChu)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                        if let d = q.ngayGon {
                            Text(d).font(.system(size: 11))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundCard))
            }
        }
    }
}
