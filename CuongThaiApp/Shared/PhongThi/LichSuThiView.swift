import SwiftUI

// MARK: - Lượt thi của tôi
//
// Dùng `GET /exams/attempts/mine` — endpoint này đã được KHAI trong
// `APIEndpoint` từ đợt dựng Phòng thi nhưng chưa từng có màn nào gọi tới, nên
// người dùng thi xong là mất dấu bài đã làm.

struct LichSuThiView: View {
    @State private var ds: [LuotDaLam] = []
    /// Mặc định TIẾNG ANH, giống Phòng thi và màn làm bài.
    @State private var ngonNgu: NgonNguDe = .anh
    @State private var dangTai = true
    @State private var loi: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                if dangTai {
                    ProgressView().padding(.top, Spacing.xxl)
                } else if ds.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text(loi ?? "Bạn chưa làm bài thi nào.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.xxl)
                } else {
                    ForEach(ds) { l in
                        NavigationLink { NapXemLaiView(luot: l) } label: { hang(l) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Lượt thi của tôi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { ngonNgu = ngonNgu.doiSang } label: {
                    Text(ngonNgu.nhanNut).font(.system(size: 13, weight: .bold))
                }
                .accessibilityLabel(ngonNgu == .viet ? "Chuyển sang tiếng Anh" : "Chuyển sang tiếng Việt")
            }
        }
        .environment(\.ngonNguDe, ngonNgu)
        .task {
            dangTai = true
            do { ds = try await APIClient.shared.request(.luotThiCuaToi) }
            catch { loi = error.localizedDescription }
            dangTai = false
        }
    }

    private func hang(_ l: LuotDaLam) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(spacing: 1) {
                Text(String(format: "%.2g", l.score ?? 0))
                    .font(.system(size: 19, weight: .black))
                    .foregroundColor(l.passed == true ? AppColors.success : AppColors.warning)
                Text("/\(String(format: "%.2g", l.maxScore ?? 10))")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textTertiary)
            }
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.exam?.ten(ngonNgu) ?? "Đề thi")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: Spacing.xs) {
                    Text(l.passed == true ? "Đạt" : "Chưa đạt")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(l.passed == true ? AppColors.success : AppColors.warning)
                    if let d = l.feedback?.correctCount, let t = l.feedback?.total {
                        Text("· đúng \(d)/\(t)")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    if (l.timeSpentSeconds ?? 0) > 0 {
                        Text("· \(l.phut)′\(String(format: "%02d", l.giay))″")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                if let s = l.submittedAt {
                    Text(TimeFormatter.formatTimeAgo(s))
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                }
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
}

// MARK: - Nạp bản xem lại của một lượt cũ

/// Lượt vừa nộp thì bản xem lại đã có sẵn trong phản hồi; lượt CŨ thì phải gọi
/// `GET /exams/attempts/:id` để lấy lại đáp án và lời giải.
struct NapXemLaiView: View {
    let luot: LuotDaLam
    @State private var xemLai: XemLaiBaiThi?
    @State private var loi: String?

    var body: some View {
        Group {
            if let x = xemLai {
                XemLaiView(xemLai: x, tenDe: luot.exam?.title ?? "Đề thi")
            } else if let l = loi {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.warning)
                    Text(l).font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundPrimary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundPrimary)
            }
        }
        .task {
            guard xemLai == nil else { return }
            do { xemLai = try await APIClient.shared.request(.xemLaiLuotThi(attemptId: luot.id)) }
            catch { loi = error.localizedDescription }
        }
    }
}
