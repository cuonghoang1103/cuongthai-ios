import SwiftUI

// ════════════════════════════════════════════════════════════════
// THẺ CUONGMINI — gộp con robot và ô chat nhanh làm một
//
// Trước đây đây là HAI khối rời nhau chiếm gần trọn màn hình đầu: một biểu
// ngữ robot cao ~136pt gõ chữ, rồi ngay dưới là một thẻ chat riêng cũng có
// tiêu đề riêng. Hai khối cùng nói một chuyện ("có trợ lý ở đây") và cùng
// đẩy buổi học kế tiếp xuống dưới màn hình.
//
// Nay: một thẻ. Robot thu nhỏ đứng cạnh tên và một dòng gợi ý, rồi tới các
// câu mồi và ô nhập.
//
// ⚠️ Dòng gợi ý KHÔNG gọi LLM. Nó suy từ dữ liệu đã có sẵn trên trang chủ
// (buổi kế tiếp, số việc chưa xong). Không suy được thì nói một câu mời
// trung tính — chứ không bịa ra một câu nghe như máy đã biết điều gì đó.
// ════════════════════════════════════════════════════════════════

struct TheCuongMini: View {
    /// Dòng gợi ý một câu, đã tính sẵn ở ngoài. Rỗng thì bỏ hẳn dòng.
    let goiY: String
    /// Câu mồi — bấm là mở chat với sẵn câu hỏi đó.
    let cauMoi: [String]
    var tamTrang: TamTrangRobot = .binhThuong
    /// `nil` = mở chat trống.
    var moChat: (String?) -> Void

    @State private var o = ""
    @FocusState private var dangGo: Bool

    private var trong: Bool { o.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Vùng bấm CHỈ ở hàng tiêu đề. Bọc cả thẻ thì nút bọc ngoài giành
            // mất cú bấm của các con chip bên dưới — chat vẫn mở, nhưng mở
            // rỗng, nhìn như chip hỏng.
            Button { moChat(nil) } label: {
                HStack(spacing: Spacing.sm) {
                    RobotChaoMung(tamTrang: tamTrang, gon: true)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("CuongMini Pro")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.secondary)
                        }
                        if !goiY.isEmpty {
                            Text(goiY)
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(T("Mở chat với CuongMini Pro"))

            if !cauMoi.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(cauMoi, id: \.self) { c in
                            Button { moChat(c) } label: {
                                Text(c)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 34)
                                    .background(Capsule().fill(AppColors.backgroundTertiary))
                                    .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 1))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.vertical, 1)
                }
            }

            HStack(spacing: Spacing.sm) {
                TextField(T("Hỏi CuongMini bất cứ điều gì…"), text: $o)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .focused($dangGo)
                    .submitLabel(.send)
                    .onSubmit(gui)
                Button(action: gui) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(trong ? AppColors.textTertiary : AppColors.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(trong)
                .accessibilityLabel(T("Gửi câu hỏi"))
            }
            .padding(.leading, 12)
            .padding(.trailing, 2)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.backgroundTertiary))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1))
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(AppColors.secondary.opacity(0.22), lineWidth: 1))
        )
    }

    private func gui() {
        let c = o.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return }
        o = ""
        dangGo = false
        moChat(c)
    }
}
