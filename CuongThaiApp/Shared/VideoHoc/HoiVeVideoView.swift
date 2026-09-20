#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// HỎI VỀ VIDEO NÀY — phòng học cùng AI
//
// Vì sao ở đây hơn trợ lý video của YouTube: phụ đề của chính video đã nằm
// trong cơ sở dữ liệu, kèm mốc thời gian từng câu. Gia sư trả lời theo
// ĐÚNG LỜI người giảng nói, và biết người học đang ở giây nào — nên câu
// "giải thích đoạn này" trúng đích thay vì đoán từ tiêu đề.
//
// Dùng lại đường sẵn có của gia sư Academy (`/courses/lessons/:id/ai/…`,
// model `course_tutor` = Claude Opus 4.8) thay vì dựng một đường AI thứ
// hai: một chỗ sửa, cả hai nơi cùng tốt lên.
// ════════════════════════════════════════════════════════════════

struct HoiVeVideoView: View {
    let video: VideoHoc
    /// Giây đang phát — gửi kèm mỗi câu hỏi.
    let giayHienTai: () -> Double
    /// Tua video tới một mốc (khi người học chạm `[2:19]`).
    let tua: (Double) -> Void

    @State private var luot: [LuotHoi] = []
    @State private var cauHoi = ""
    @State private var dangHoi = false
    @State private var loi: String?
    @FocusState private var dangGo: Bool

    struct LuotHoi: Identifiable {
        let id = UUID()
        let hoi: String
        var dap: String
        var xong: Bool
    }

    /// Nút gợi ý. Mỗi cái là một câu hỏi ĐẦY ĐỦ gửi lên, không phải nhãn —
    /// model trả lời theo câu hỏi chứ không theo tên nút.
    private struct Goi: Identifiable {
        let id: String
        let nhan: String
        let icon: String
        let cau: String
        /// Khoá bộ nhớ đệm: câu hỏi cố định thì mọi người học dùng chung một
        /// câu trả lời, đỡ tiền và trả lời tức thì từ lần thứ hai.
        let khoa: String?
    }

    private var goiY: [Goi] {
        [
            .init(id: "tomtat", nhan: T("Tóm tắt video"), icon: "list.bullet.rectangle",
                  cau: "Tóm tắt video này theo từng phần, mỗi phần kèm khoảng thời gian.",
                  khoa: "video_tomtat"),
            // KHÔNG cache: câu trả lời phụ thuộc giây đang xem.
            .init(id: "doannay", nhan: T("Giải thích đoạn này"), icon: "text.magnifyingglass",
                  cau: "Giải thích kỹ đoạn tôi đang xem: người giảng đang nói gì, và vì sao nó quan trọng?",
                  khoa: nil),
            .init(id: "thuatngu", nhan: T("Thuật ngữ"), icon: "character.book.closed",
                  cau: "Liệt kê các thuật ngữ chuyên môn trong video: từ tiếng Anh, nghĩa tiếng Việt, và một câu giải thích dễ hiểu.",
                  khoa: "video_thuatngu"),
            .init(id: "sodo", nhan: T("Vẽ sơ đồ"), icon: "flowchart",
                  cau: "Vẽ sơ đồ mermaid tóm tắt nội dung/quy trình chính trong video, rồi giải thích sơ đồ đó.",
                  khoa: "video_sodo"),
            .init(id: "tuvung", nhan: T("Từ vựng tiếng Anh"), icon: "textformat.abc",
                  cau: "Chọn 12 từ/cụm từ tiếng Anh đáng học nhất trong video này. Mỗi từ: phiên âm, nghĩa, và chính câu trong video có từ đó kèm mốc thời gian.",
                  khoa: "video_tuvung"),
            .init(id: "vidu", nhan: T("Ví dụ thực tế"), icon: "lightbulb",
                  cau: "Cho ví dụ thực tế, cụ thể để tôi hiểu rõ hơn nội dung video này.",
                  khoa: "video_vidu"),
            .init(id: "kiemtra", nhan: T("Kiểm tra tôi"), icon: "checkmark.circle",
                  cau: "Ra 5 câu hỏi kiểm tra xem tôi đã hiểu video này chưa. Đừng cho đáp án ngay, để tôi trả lời trước.",
                  khoa: "video_kiemtra"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            if luot.isEmpty && !dangHoi { moDau } else { cuocHoi }
            Divider()
            hangGoiY
            oNhap
        }
        .background(AppColors.backgroundPrimary)
    }

    // MARK: Mở đầu

    private var moDau: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "sparkles").foregroundStyle(AppColors.primary)
                    Text(T("Hỏi về video này"))
                        .font(.headline).foregroundStyle(AppColors.textPrimary)
                }
                Text(T("Gia sư đã đọc toàn bộ lời giảng trong video, kèm mốc thời gian. Hỏi bất cứ điều gì — và chạm vào mốc [2:19] trong câu trả lời để nhảy tới đúng đoạn đó."))
                    .font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(goiY.prefix(4)) { g in
                    Button { hoi(g.cau, khoa: g.khoa) } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: g.icon).frame(width: 22)
                                .foregroundStyle(AppColors.primary)
                            Text(g.nhan).font(.bodyMedium)
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        .padding(Spacing.md)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.backgroundCard))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
    }

    // MARK: Cuộc hỏi đáp

    private var cuocHoi: some View {
        ScrollViewReader { cuon in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(luot) { l in
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(l.hoi)
                                .font(.bodySmall.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .fill(AppColors.primary.opacity(0.10)))

                            if l.dap.isEmpty && !l.xong {
                                HStack(spacing: Spacing.sm) {
                                    ProgressView().controlSize(.small)
                                    Text(T("Gia sư đang đọc lại video…"))
                                        .font(.caption).foregroundStyle(AppColors.textTertiary)
                                }
                            } else {
                                // Mốc `[2:19]` được biến thành liên kết TRƯỚC
                                // khi dựng markdown, nên bộ dựng sẵn có lo nốt.
                                NoiDungMarkdown(noiDung: MocThoiGian.themLienKet(l.dap))
                            }
                        }
                        .id(l.id)
                    }
                    if let e = loi {
                        Text(e).font(.caption).foregroundStyle(AppColors.error)
                    }
                }
                .padding(Spacing.md)
            }
            .onChange(of: luot.last?.dap) { _, _ in
                if let id = luot.last?.id {
                    withAnimation { cuon.scrollTo(id, anchor: .bottom) }
                }
            }
            // Chạm mốc trong câu trả lời = tua video.
            .environment(\.openURL, OpenURLAction { u in
                if let g = MocThoiGian.giayTuURL(u) { tua(g); return .handled }
                return .systemAction
            })
        }
    }

    // MARK: Gợi ý + ô nhập

    private var hangGoiY: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(goiY) { g in
                    Button { hoi(g.cau, khoa: g.khoa) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: g.icon).font(.caption2)
                            Text(g.nhan).font(.caption)
                        }
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 6)
                        .background(Capsule().fill(AppColors.backgroundCard))
                        .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(dangHoi)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    private var oNhap: some View {
        HStack(spacing: Spacing.sm) {
            TextField(T("Đặt câu hỏi về video…"), text: $cauHoi, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                .background(Capsule().fill(AppColors.backgroundCard))
                .focused($dangGo)
                .onSubmit { guiCauGo() }
            Button { guiCauGo() } label: {
                Image(systemName: dangHoi ? "stop.circle" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(cauHoi.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? AppColors.textTertiary : AppColors.primary)
            }
            .disabled(cauHoi.trimmingCharacters(in: .whitespaces).isEmpty || dangHoi)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundCard)
    }

    private func guiCauGo() {
        let c = cauHoi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return }
        cauHoi = ""
        dangGo = false
        hoi(c, khoa: nil)
    }

    // MARK: Gọi gia sư

    private func hoi(_ cau: String, khoa: String?) {
        guard !dangHoi else { return }
        // Bài giảng của web có `lessonId` DƯƠNG. Video người dùng tự thêm có
        // id ÂM và không nằm trong khoá học nào, nên gia sư bài học không có
        // bối cảnh — nói thẳng thay vì gọi rồi nhận lỗi khó hiểu.
        guard !video.laCuaToi else {
            loi = T("Hỏi AI hiện chỉ dùng được với video bài giảng của khoá học.")
            return
        }
        loi = nil
        dangHoi = true
        luot.append(LuotHoi(hoi: cau, dap: "", xong: false))
        let i = luot.count - 1

        Task {
            defer { dangHoi = false }
                let than: [String: Any] = [
                    "question": cau,
                    "phongVideo": true,
                    "phuDeGiay": Int(giayHienTai()),
                    // Lịch sử để hỏi tiếp "vậy còn…" mà không phải nhắc lại.
                    "history": luot.dropLast().suffix(4).flatMap { l -> [[String: String]] in
                        [["role": "user", "content": l.hoi],
                         ["role": "assistant", "content": l.dap]]
                    },
                ].merging(khoa.map { ["cacheKey": $0] } ?? [:]) { a, _ in a }

                // Dùng lại đúng bộ SSE của gia sư bài học — một chỗ sửa,
                // mọi màn hỏi AI cùng tốt lên.
                var gom = ""
                for await sk in LuongHoiDap.doc(
                    duong: "/api/v1/courses/lessons/\(video.lessonId)/ai/ask-stream",
                    than: than,
                    loiTheoMa: { ma in
                        switch ma {
                        case 401: return T("Phiên đăng nhập đã hết hạn.")
                        case 403: return T("Hỏi AI về video là tính năng Pro.")
                        case 404: return T("Video này chưa gắn với bài học nào.")
                        case 400: return T("AI đang không dùng được (hết hạn mức hôm nay, hoặc đang tạm nghỉ).")
                        default:  return T("Máy chủ trả lỗi") + " \(ma)"
                        }
                    }) {
                    switch sk {
                    case .mau(let c):
                        gom += c
                        if i < luot.count { luot[i].dap = gom }
                    case .xong(let traLoi, _):
                        if i < luot.count {
                            luot[i].dap = traLoi.isEmpty ? gom : traLoi
                            luot[i].xong = true
                        }
                    case .hong(let e):
                        if i < luot.count, luot[i].dap.isEmpty { luot.remove(at: i) }
                        loi = e
                    }
                }
                if i < luot.count, !luot[i].xong { luot[i].xong = true }
        }
    }
}
#endif
