import SwiftUI

/// Nhờ AI chấm bài viết theo BỐN tiêu chí IELTS.
///
/// Tên khác `ChamBaiVietView` của My Language là cố ý: cái kia chấm bài viết
/// ngoại ngữ nói chung và cần một đối tượng `NgonNgu`; cái này chấm theo band
/// của từng tiêu chí, vì mỗi tiêu chí sửa bằng một cách khác nhau.
struct ChamVietIeltsView: View {
    let chu: String
    let de: String

    @State private var ketQua: String?
    @State private var dangCham = false
    @State private var loi: String?

    private var soTu: Int {
        chu.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Label("\(soTu) \(T("từ"))", systemImage: "text.alignleft")
                        .font(.captionBold).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                }

                if let k = ketQua {
                    NoiDungMarkdown(noiDung: k)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.md)
                        .background(AppColors.backgroundCard)
                        .cornerRadius(CornerRadius.large)
                } else if dangCham {
                    VStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text(T("Đang đọc bài của bạn…"))
                            .font(.caption).foregroundStyle(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
                } else if let l = loi {
                    Text(l).font(.bodySmall).foregroundStyle(AppColors.error)
                }

                if ketQua == nil && !dangCham {
                    Button { Task { await cham() } } label: {
                        Label(T("Chấm bài"), systemImage: "sparkles")
                            .font(.buttonText).frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm + 2)
                            .background(AppColors.primary)
                            .foregroundStyle(Color.white)
                            .cornerRadius(CornerRadius.medium)
                    }
                    .buttonStyle(.plain)
                    .disabled(soTu < 20)
                    if soTu < 20 {
                        Text(T("Viết ít nhất 20 từ rồi hãy chấm."))
                            .font(.caption2).foregroundStyle(AppColors.textTertiary)
                    }
                }

                DisclosureGroup {
                    Text(chu).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 6)
                } label: {
                    Text(T("Xem lại bài đã gửi")).font(.captionBold)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(Spacing.md)
                .background(AppColors.backgroundCard)
                .cornerRadius(CornerRadius.large)
            }
            .padding(Spacing.md)
            .padding(.bottom, 60)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Chấm bài"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private struct DapAnCham: Decodable {
        let ketQua: String?
        let lyDo: String?
    }

    private func cham() async {
        dangCham = true
        loi = nil
        defer { dangCham = false }
        do {
            let d: DapAnCham = try await APIClient.shared.request(
                .ieltsChamViet(["bai": chu, "de": de]))
            if let k = d.ketQua, !k.isEmpty {
                ketQua = k
            } else if d.lyDo == "ai_unavailable" {
                loi = T("AI đang tắt trên máy chủ. Phần dàn ý, cụm từ và bài mẫu của đề vẫn dùng được.")
            } else {
                loi = T("Máy chủ không trả về kết quả.")
            }
        } catch { loi = error.localizedDescription }
    }
}
