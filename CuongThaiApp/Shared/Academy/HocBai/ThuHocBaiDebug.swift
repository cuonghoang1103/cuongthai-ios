#if DEBUG
import SwiftUI

/// Bàn soi màn học Academy — CHỈ bản DEBUG, mở qua `CT_XEM_MAN` (xem `ManXemThu`).
///
///     SIMCTL_CHILD_CT_XEM_MAN=hocbai-bai SIMCTL_CHILD_CT_SLUG=front-end-web-development-with-react \
///     SIMCTL_CHILD_CT_BAI=649 SIMCTL_CHILD_CT_TU_PHAT=1 xcrun simctl launch <udid> com.cuongthai.app
///
/// Chế độ: `hocbai-khoa` (chi tiết môn) · `hocbai-bai` (màn học, dựng từ `?gon=1` THẬT
/// của máy chủ) · `hocbai-slide` (trình chiếu, `CT_SLIDE` = tấm mở đầu) · `hocbai-cuacuatoi`.
/// Không cần đăng nhập với bài học thử (FER202 649: video R2 riêng, URL ký thật).
///
/// ⚠️ Nằm trọn trong `#if DEBUG` (CLAUDE.md A6) — kiểm lại bằng grep nhị phân Release.
struct ThuHocBaiView: View {
    let cheDo: String

    private var env: [String: String] { ProcessInfo.processInfo.environment }
    private var slug: String { env["CT_SLUG"] ?? "front-end-web-development-with-react" }
    private var baiId: Int { Int(env["CT_BAI"] ?? "") ?? 649 }

    @State private var course: CourseDetail?
    @State private var bai: CourseLesson?
    @State private var loi: String?

    var body: some View {
        Group {
            switch cheDo {
            case "hocbai-khoa":
                CourseDetailView(slug: slug)
            case "hocbai-cuacuatoi":
                MyCoursesView()
            // Dữ liệu MẪU (ghi rõ) — tài liệu/bài tập thật chỉ trả cho tài khoản có quyền.
            case "hocbai-tailieu":
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        DanhSachTaiLieu(tieuDe: "Tài liệu của bài (MẪU)", ds: [
                            TaiLieuBai(id: 1, title: "FER202 - Slot 1 - Introduction.pdf", fileSizeBytes: 2_400_000, fileType: "application/pdf"),
                            TaiLieuBai(id: 2, title: "Lab 1 - Setup.docx", fileSizeBytes: 380_000, fileType: nil),
                            TaiLieuBai(id: 3, title: "Bộ đề PE trên OneDrive", fileUrl: "https://onedrive.live.com", fileType: "link"),
                        ]) { _ in }
                        DanhSachBaiTapNop(ds: [
                            BaiTapNop(id: 1, title: "Exercise 2 — Your first React app", instructions: "Tạo app bằng Vite, đẩy lên GitHub, nộp link repo.", deadline: "2026-10-30T16:59:00.000Z", maxScore: 10),
                            BaiTapNop(id: 2, title: "Exercise 3 — Git push", maxScore: 10,
                                      mySubmission: NopBai(submissionUrl: "https://github.com/sv/fer202-ex3", status: "GRADED", grade: 9, feedback: "Commit message rõ ràng.")),
                        ]) { _ in }
                    }
                    .padding(Spacing.md)
                }
                .background(AppColors.backgroundPrimary)
            case "hocbai-giasu":
                if let bai {
                    GiaSuBaiHocView(lessonId: bai.id, tenBai: bai.title.theoApp, tenMon: course?.courseCode,
                                    slides: DocSlide.tu(bai.content),
                                    boiCanhVideo: { BoiCanhVideoHoi(track: "VI", giay: 125) })
                } else { dangTai }
            // Một câu trả lời AI đọc từ tệp (`CT_TRALOI` = đường dẫn .md), dựng y như bong
            // bóng gia sư: ScrollView › VStack › TraLoiAI. Soi khung WebView có giãn đủ cao không.
            case "hocbai-traloi":
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Câu hỏi mẫu").padding(Spacing.md)
                        TraLoiAI(chu: (try? String(contentsOfFile: env["CT_TRALOI"] ?? "", encoding: .utf8)) ?? "## (thiếu CT_TRALOI)",
                                 xong: true)
                            .padding(Spacing.md)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(AppColors.primary.opacity(0.07)))
                        Text("— hết —").padding(Spacing.md)
                    }
                    .padding(Spacing.md)
                }
                .background(AppColors.backgroundPrimary)
            case "hocbai-slide":
                if let bai {
                    XemSlideView(slides: DocSlide.tu(bai.content), dangXem: Int(env["CT_SLIDE"] ?? "") ?? 0) { _ in }
                } else { dangTai }
            default:
                if let c = course {
                    LessonPlayerView(course: Course(from: c), sections: c.sections ?? [], lessonId: baiId,
                                     coToanQuyen: c.hasPaidAccess == true)
                } else { dangTai }
            }
        }
        .task {
            do {
                let c: CourseDetail = try await APIClient.shared.request(.hocBai(.khoaGon(slug: slug)))
                course = c
                if cheDo == "hocbai-slide" || cheDo == "hocbai-giasu" {
                    bai = try await APIClient.shared.request(.getLesson(courseId: c.id, lessonId: baiId))
                }
            } catch { loi = error.localizedDescription }
        }
    }

    private var dangTai: some View {
        VStack { if let loi { Text(loi) } else { ProgressView() } }
    }
}
#endif
