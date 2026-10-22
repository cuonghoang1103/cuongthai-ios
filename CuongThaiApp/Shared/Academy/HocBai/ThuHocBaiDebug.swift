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
                if cheDo == "hocbai-slide" {
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
