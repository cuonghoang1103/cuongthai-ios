import SwiftUI
#if os(iOS)
import WebKit
#endif

// MARK: - Trình phát bài học
//
// Mọi video của khoá đều là `videoPlatform: EMBED` trỏ tới YouTube (đo thật
// 19/08/2026 trên khoá PostgreSQL: 54/54 bài). Nên trình phát ở đây là một
// WKWebView nhúng khung YouTube.
//
// ⚠️ CHỈ phát, KHÔNG tải về. App Store Guideline 5.2.3 cấm lưu/chuyển đổi/tải
// media từ nguồn thứ ba — đó chính là lý do module Nhạc đã bị gỡ khỏi app.
// Đừng thêm nút tải, kể cả khi có người xin.

// MARK: Khung YouTube

#if os(iOS)
struct YouTubePlayer: UIViewRepresentable {
    let videoId: String
    /// Giây bắt đầu — dùng để mở lại đúng chỗ đang xem dở.
    var batDauTaiGiay: Int = 0

    func makeUIView(context: Context) -> WKWebView {
        let cauHinh = WKWebViewConfiguration()
        // Cho phát ngay trong trang thay vì bung ra toàn màn hình.
        cauHinh.allowsInlineMediaPlayback = true
        cauHinh.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: cauHinh)
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard context.coordinator.videoDangTai != videoId else { return }
        context.coordinator.videoDangTai = videoId

        // Bốn cách nạp, đã thử thật hết cả bốn:
        //   1. loadHTMLString + baseURL           → "unavailable, 152"
        //   2. load(URLRequest) thẳng /embed      → "player configuration error"
        //   3. loadSimulatedRequest, origin youtube.com → khung tải được nhưng
        //      vẫn "152 - 4" TRÊN MÁY THẬT (20/08/2026)
        //   4. loadSimulatedRequest, origin cuongthai.com → cách này
        //
        // Chỗ sai ở (3): đặt origin là `youtube.com` tức bảo YouTube "trang
        // nhúng chính là YouTube" — vô nghĩa, và nó từ chối. Khung nhúng cần
        // một origin BÊN THỨ BA hợp lệ, và `origin` trong URL phải KHỚP với
        // origin của trang cha.
        //
        // Bằng chứng dẫn tới cách (4): CÙNG những video này đang nhúng tốt
        // trên cuongthai.com. Khác biệt duy nhất là origin. Dùng lại đúng
        // origin của web thì khung nhúng ở app không khác gì khung ở web.
        //
        // ⚠️ oEmbed trả 200 KHÔNG chứng minh video nhúng được — video bị chủ
        // kênh tắt nhúng vẫn trả 200. Tôi từng dựa vào đó để kết luận "cả 6
        // video đều nhúng được"; kết luận ấy vô giá trị.
        guard let goc = URL(string: Self.trangChu) else { return }
        web.loadSimulatedRequest(URLRequest(url: goc), responseHTML: trangHTML)
    }

    /// Origin của trang nhúng — phải là trang thật của mình, và phải trùng với
    /// tham số `origin` trong địa chỉ khung nhúng.
    private static let trangChu = "https://cuongthai.com/"

    private var trangHTML: String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden}
        iframe{border:0;width:100%;height:100%}</style></head>
        <body><iframe
          src="https://www.youtube.com/embed/\(videoId)?playsinline=1&rel=0&modestbranding=1&start=\(batDauTaiGiay)&origin=https%3A%2F%2Fcuongthai.com"
          allow="accelerometer; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen></iframe></body></html>
        """
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator { var videoDangTai: String? }

}
#endif

/// Rút mã video từ mọi kiểu URL YouTube đang có trong dữ liệu:
/// `youtu.be/<id>`, `youtube.com/watch?v=<id>`, `youtube.com/embed/<id>`.
func maVideoYouTube(_ url: String?) -> String? {
    guard let url, let u = URL(string: url) else { return nil }
    if u.host?.contains("youtu.be") == true {
        let ma = u.lastPathComponent
        return ma.isEmpty ? nil : ma
    }
    if let items = URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems,
       let v = items.first(where: { $0.name == "v" })?.value, !v.isEmpty {
        return v
    }
    if u.path.contains("/embed/") {
        let ma = u.lastPathComponent
        return ma.isEmpty ? nil : ma
    }
    return nil
}

// MARK: - Màn học

struct LessonPlayerView: View {
    let course: Course
    let sections: [CourseSection]
    @State private var lessonId: Int

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = LessonPlayerViewModel()
    @State private var hienMucLuc = false
    @State private var hienGiaSu = false
    /// Câu quiz đang nhờ AI giải thích. `nil` = hỏi chung về bài (nút nổi).
    @State private var quizHoi: HoiVeCau?
    @State private var moLuyenChuong = false
    @State private var luongDangChon: String?

    init(course: Course, sections: [CourseSection], lessonId: Int) {
        self.course = course
        self.sections = sections
        _lessonId = State(initialValue: lessonId)
    }

    /// Mọi bài, đã trải phẳng theo đúng thứ tự học — để làm Bài trước/Bài tiếp.
    private var tatCaBai: [CourseLesson] {
        sections
            .sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            .flatMap { ($0.lessons ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) } }
    }

    private var chiSoHienTai: Int? { tatCaBai.firstIndex { $0.id == lessonId } }
    private var baiHienTai: CourseLesson? { tatCaBai.first { $0.id == lessonId } }
    private var baiTruoc: CourseLesson? {
        guard let i = chiSoHienTai, i > 0 else { return nil }
        return tatCaBai[i - 1]
    }
    private var baiTiep: CourseLesson? {
        guard let i = chiSoHienTai, i + 1 < tatCaBai.count else { return nil }
        return tatCaBai[i + 1]
    }

    private var luongDung: VideoTrack? {
        guard let bai = baiHienTai else { return nil }
        let ds = (bai.videoTracks ?? []).filter { maVideoYouTube($0.url) != nil }
        if let chon = luongDangChon, let t = ds.first(where: { $0.track == chon }) { return t }
        if let mac = bai.defaultVideoTrack, let t = ds.first(where: { $0.track == mac }) { return t }
        return ds.first
    }

    private var maVideo: String? {
        maVideoYouTube(luongDung?.url ?? baiHienTai?.videoUrl)
    }

    var body: some View {
        ScrollViewReader { cuon in
        ZStack(alignment: .bottomTrailing) {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                khungVideo
                tieuDe
                if let bai = baiHienTai, (bai.videoTracks?.count ?? 0) > 1 {
                    boChonLuong(bai)
                }
                if let credit = luongDung?.credit, !credit.isEmpty {
                    dongGhiCong(credit)
                }
                noiDung
                khoiLuyenChuong
                nutHoanThanh
                dieuHuongBai
            }
            .padding(.horizontal, Spacing.md)
            // Chừa chỗ cho nút nổi "Hỏi AI" khỏi che mất nút Bài tiếp.
            .padding(.bottom, Spacing.xxl + 44)
        }
        .background(AppColors.backgroundPrimary)

        // Gia sư AI cho ĐÚNG bài đang mở. Nút nổi thay vì một khối chèn giữa
        // trang như web: trên điện thoại, khối chat nằm lọt giữa bài giảng thì
        // hoặc phải cuộn qua nó mỗi lần, hoặc phải cuộn đi tìm nó mỗi lần hỏi.
        nutGiaSu
        // ⛔⛔ Sheet gia sư phải gắn Ở ĐÂY, không gắn cạnh sheet mục lục.
        //
        // SwiftUI chỉ tôn trọng MỘT `.sheet` trên mỗi view. Trước 07/09/2026
        // cả hai (`hienGiaSu`, `hienMucLuc`) cùng gắn lên `ZStack`, và cái sau
        // nuốt cái trước: **nút nổi "Hỏi AI" trong bài học chưa từng mở được
        // gì**, im lặng, không lỗi. Mục lục chạy nên không ai ngờ.
        // Đo ra khi làm nút "Hỏi AI vì sao sai" của bài kiểm tra: bấm không ra
        // gì, và hoá ra không phải nút mới hỏng.
        .sheet(isPresented: $hienGiaSu) {
            if let bai = baiHienTai {
                GiaSuBaiHocView(lessonId: bai.id,
                                tenBai: bai.title.tachSongNgu(.viet),
                                tenMon: course.courseCode,
                                quizContext: quizHoi?.boiCanh ?? [],
                                cauHoiSan: quizHoi?.cauMoDau)
                    // ⚠️ `id` phải đổi theo BÀI: `sheet` giữ nguyên view khi
                    // nội dung bên dưới đổi, nên không có dòng này thì mở gia
                    // sư ở bài 5 vẫn thấy cuộc hỏi của bài 4 — đúng cái web né
                    // bằng `useEffect(..., [lessonId])`.
                    // Kèm cả câu quiz vào `id`: hỏi câu 3 rồi đóng, mở
                    // câu 5 mà `id` không đổi thì sheet giữ nguyên cuộc hỏi cũ
                    // và câu mở đầu mới không bao giờ chạy.
                    .id("\(bai.id)-\(quizHoi?.id ?? "chung")")
                    .presentationDetents([.fraction(0.68), .large])
                    .presentationDragIndicator(.visible)
            }
        }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    hienMucLuc = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
        }
        .sheet(isPresented: $hienMucLuc) {
            MucLucView(
                sections: sections,
                baiDangHoc: lessonId,
                daXong: vm.daXong,
                chon: { moBai($0) },
            )
        }
        .task(id: lessonId) { await vm.tai(courseId: course.id, lessonId: lessonId) }
        .onDisappear { vm.luuViTriNeuCan(courseId: course.id, lessonId: lessonId) }
        // Bài trước/Bài tiếp nằm ở CUỐI trang, và mục lục mở từ thanh trên —
        // cả hai đều đổi bài trong khi vẫn đang cuộn sâu.
        .onChange(of: lessonId) { _, _ in cuon.veDauTrang() }
        }
    }

    // MARK: Khối

    private var nutGiaSu: some View {
        Button {
            quizHoi = nil          // nút nổi = hỏi chung, không kèm câu quiz
            hienGiaSu = true
            Haptics.cham()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                Text("Hỏi AI")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Capsule().fill(
                LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                               startPoint: .topLeading, endPoint: .bottomTrailing)))
            .shadow(color: AppColors.primary.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    @ViewBuilder
    private var khungVideo: some View {
        if let bai = baiHienTai, bai.laQuiz {
            khungQuiz
        } else if let ma = maVideo {
            #if os(iOS)
            VStack(alignment: .trailing, spacing: 6) {
                YouTubePlayer(videoId: ma, batDauTaiGiay: vm.viTriDaLuu)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                // Lối thoát: một số video bị chủ kênh tắt nhúng (YouTube trả
                // "Video unavailable"). Khi đó vẫn xem được, chỉ là ra ngoài.
                Link(destination: URL(string: "https://www.youtube.com/watch?v=\(ma)")!) {
                    Label("Mở trên YouTube", systemImage: "arrow.up.forward.app")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            #else
            khungTrong("Trình phát video chỉ có trên iOS")
            #endif
        } else {
            khungTrong("Bài này chưa có video")
        }
    }

    /// Bài QUIZ — làm NGAY TRONG APP.
    ///
    /// ⛔ Bản trước ghi ở đây: "backend chưa có đường trả nội dung quiz (soi
    /// `course.routes.ts` 19/08/2026 không thấy)" rồi đẩy người dùng sang
    /// Safari. Câu đó SAI. `GET /courses/:id/lessons/:id` trả `quizData` từ
    /// 11/07/2026 (commit e1a79f7e) — grep sót một lần đã khoá tính năng gần
    /// hai tháng, và cái chú thích tự tin kia làm không ai đi kiểm lại.
    /// Xem [[feedback_grep_khong_thay_khong_nghia_la_khong_co]].
    ///
    /// Vẫn giữ đường sang web, nhưng chỉ khi bài thật sự KHÔNG có `quizData`
    /// (bài cũ chưa soạn), và nói đúng lý do.
    @ViewBuilder
    private var khungQuiz: some View {
        if let q = vm.baiDayDu?.quizData, !q.cauHoi.isEmpty {
            BaiKiemTraView(
                de: q,
                lessonId: lessonId,
                tenBai: (baiHienTai?.title ?? "").tachSongNgu(.viet),
                tenMon: course.courseCode,
                khiHoiAI: { q in quizHoi = q; hienGiaSu = true },
                khiNop: {
                    // Web đánh dấu hoàn thành ngay khi nộp. Chỉ gọi khi CHƯA
                    // xong, không thì bấm "làm lại rồi nộp" sẽ bỏ đánh dấu.
                    if !vm.daXong.contains(lessonId) {
                        Task { await vm.doiHoanThanh(courseId: course.id, lessonId: lessonId) }
                    }
                })
        } else if vm.dangTaiBai {
            HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, Spacing.xl)
        } else {
            khungQuizTrong
        }
    }

    private var khungQuizTrong: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 40))
                .foregroundColor(AppColors.primary)
            Text("Bài kiểm tra")
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)
            Text(vm.loiTaiBai.map { String(format: "Không tải được bài: %@", $0) }
                 ?? "Bài này chưa có bộ câu hỏi trong hệ thống. Bản trên website có thể đã được soạn thêm.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Link(destination: URL(string: "https://cuongthai.com/courses/\(course.slug)/learn")!) {
                Text("Mở trên website")
                    .font(.buttonText)
                    .foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(AppColors.primary)
                    .cornerRadius(CornerRadius.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(CornerRadius.medium)
    }

    private func khungTrong(_ chu: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.backgroundSecondary)
            Text(chu)
                .font(.bodySmall)
                .foregroundColor(AppColors.textTertiary)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    private var tieuDe: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(baiHienTai?.title.songNguTheoMay ?? "")
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            // Vế ngôn ngữ kia hiện mờ bên dưới — người học đối chiếu được mà
            // không phải rời màn hình.
            if let kia = baiHienTai?.title.songNguVeKia, !kia.isEmpty {
                Text(kia)
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Spacing.sm) {
                if let i = chiSoHienTai {
                    Text("Bài \(i + 1)/\(tatCaBai.count)")
                }
                if let t = baiHienTai?.thoiLuong {
                    Text("·"); Text(t)
                }
            }
            .font(.caption)
            .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func boChonLuong(_ bai: CourseLesson) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(bai.videoTracks ?? [], id: \.track) { luong in
                    let dungDuoc = maVideoYouTube(luong.url) != nil
                    Button {
                        luongDangChon = luong.track
                    } label: {
                        Text(luong.nhan)
                            .font(.buttonSmall)
                            .foregroundColor(luongDung?.track == luong.track ? AppColors.onPrimary : AppColors.textSecondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 6)
                            .background(luongDung?.track == luong.track ? AppColors.primary : AppColors.backgroundTertiary)
                            .clipShape(Capsule())
                    }
                    .disabled(!dungDuoc)
                    .opacity(dungDuoc ? 1 : 0.4)
                }
            }
        }
    }

    /// Video của người khác thì phải ghi công người ta.
    private func dongGhiCong(_ credit: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
            Text("Nguồn: \(credit)")
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundColor(AppColors.textTertiary)
    }

    /// Chương chứa bài đang mở — cần cả `id` (gọi API) lẫn tên (hiện ra).
    private var chuongCuaBai: CourseSection? {
        sections.first { ($0.lessons ?? []).contains { $0.id == lessonId } }
    }

    /// Đề luyện cuối chương. Câu hỏi THẬT từ đề FE/PE/PT đã gán về chương này —
    /// đúng thứ để làm sau khi học xong chương.
    ///
    /// Chỉ hiện khi chương đó THẬT SỰ có câu (`soCauLuyen`), vì phần lớn chương
    /// của khoá tự soạn thì chưa gán câu nào, và một nút bấm vào ra "chưa có
    /// gì" thì tệ hơn là không có nút.
    @ViewBuilder
    private var khoiLuyenChuong: some View {
        if let ch = chuongCuaBai, let n = vm.soCauLuyen[ch.id], n > 0 {
            Button { moLuyenChuong = true } label: {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 20)).foregroundColor(AppColors.primary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(format: "Đề luyện cuối chương — %d câu", n))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Text("Câu hỏi thật từ đề FE/PE/PT của chương này. Chấm ngay, có giải thích, hỏi được gia sư.")
                            .font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.primary.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(AppColors.primary.opacity(0.35), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $moLuyenChuong) {
                LuyenChuongView(
                    sectionId: ch.id,
                    tenChuong: ch.title,
                    soCau: n,
                    // Gia sư gắn theo BÀI, nên lấy bài đầu chương làm ngữ cảnh
                    // — đúng cách web làm (`lessonId={lessons[0]?.id}`).
                    lessonId: (ch.lessons ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }.first?.id,
                    // ⚠️ `courseCode` CÓ THỂ RỖNG (đo thật: SWR302 trong
                    // `/curriculum` không kèm mã). Lùi về tên khoá — ô tìm của
                    // Phòng Thi quét cả `tenKhoa`, nên vẫn lọc đúng. Không lùi
                    // thì hàng "mở Phòng Thi" bị ẩn IM LẶNG.
                    tenMon: (course.courseCode?.isEmpty == false ? course.courseCode : nil) ?? course.title)
            }
        }
    }

    @ViewBuilder
    private var noiDung: some View {
        let chu = vm.baiDayDu?.content ?? baiHienTai?.description
        if let chu, !chu.isEmpty {
            // Nội dung bài là HTML (có `<h2>`, `<p>`, `<strong>`, và cả hai
            // ngôn ngữ phân bằng class `ml-en` / `ml-vi`). Đổ thẳng ra `Text`
            // thì người học đọc nguyên thẻ — đúng như đã thấy lúc chạy thử.
            RichContent(html: chu)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if let ghiChu = vm.baiDayDu?.teachingNotes, !ghiChu.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Ghi chú bài giảng", systemImage: "text.book.closed")
                    .font(.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                RichContent(html: ghiChu)
            }
            .padding(Spacing.md)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(CornerRadius.medium)
        }
        if let ma = vm.baiDayDu?.sourceCodeUrl ?? baiHienTai?.sourceCodeUrl,
           let url = URL(string: ma) {
            Link(destination: url) {
                Label("Mã nguồn của bài", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.buttonSmall)
                    .foregroundColor(AppColors.primary)
            }
        }
    }

    private var nutHoanThanh: some View {
        Button {
            Task { await vm.doiHoanThanh(courseId: course.id, lessonId: lessonId) }
        } label: {
            HStack(spacing: Spacing.sm) {
                if vm.dangLuu {
                    ProgressView().tint(AppColors.onPrimary)
                } else {
                    Image(systemName: vm.daXong.contains(lessonId) ? "checkmark.circle.fill" : "circle")
                }
                Text(vm.daXong.contains(lessonId) ? "Đã hoàn thành" : "Đánh dấu hoàn thành")
                    .font(.buttonText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(vm.daXong.contains(lessonId) ? AppColors.success : AppColors.primary)
            .foregroundColor(AppColors.onPrimary)
            .cornerRadius(CornerRadius.medium)
        }
        .disabled(vm.dangLuu)
    }

    private var dieuHuongBai: some View {
        HStack(spacing: Spacing.md) {
            if let truoc = baiTruoc {
                Button {
                    moBai(truoc.id)
                } label: {
                    Label("Bài trước", systemImage: "chevron.left")
                        .font(.buttonSmall)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(AppColors.backgroundTertiary)
                        .foregroundColor(AppColors.textPrimary)
                        .cornerRadius(CornerRadius.medium)
                }
            }
            if let tiep = baiTiep {
                Button {
                    moBai(tiep.id)
                } label: {
                    HStack {
                        Text("Bài tiếp")
                        Image(systemName: "chevron.right")
                    }
                    .font(.buttonSmall)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(AppColors.backgroundTertiary)
                    .foregroundColor(AppColors.textPrimary)
                    .cornerRadius(CornerRadius.medium)
                }
            }
        }
    }

    private func moBai(_ id: Int) {
        Haptics.cham()
        vm.luuViTriNeuCan(courseId: course.id, lessonId: lessonId)
        luongDangChon = nil
        lessonId = id
        hienMucLuc = false
    }
}

// MARK: - Mục lục

struct MucLucView: View {
    let sections: [CourseSection]
    let baiDangHoc: Int
    let daXong: Set<Int>
    let chon: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }) { chuong in
                    Section(chuong.title.songNguTheoMay) {
                        ForEach((chuong.lessons ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }) { bai in
                            Button {
                                chon(bai.id)
                                dismiss()
                            } label: {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: bieuTuong(bai))
                                        .foregroundColor(daXong.contains(bai.id) ? AppColors.success : AppColors.textTertiary)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bai.title.songNguTheoMay)
                                            .font(.bodyMedium)
                                            .foregroundColor(bai.id == baiDangHoc ? AppColors.primary : AppColors.textPrimary)
                                            .multilineTextAlignment(.leading)
                                        if let t = bai.thoiLuong {
                                            Text(t).font(.caption).foregroundColor(AppColors.textTertiary)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    if bai.id == baiDangHoc {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.caption)
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mục lục")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }

    private func bieuTuong(_ bai: CourseLesson) -> String {
        if daXong.contains(bai.id) { return "checkmark.circle.fill" }
        return bai.laQuiz ? "square.and.pencil" : "play.circle"
    }
}

// MARK: - ViewModel

@MainActor
final class LessonPlayerViewModel: ObservableObject {
    @Published var daXong: Set<Int> = []
    @Published var baiDayDu: CourseLesson?
    @Published var dangTaiBai = false
    /// Hỏng khi tải bài. Phải HIỆN RA: với bài QUIZ, `baiDayDu == nil` vì mất
    /// mạng trông y hệt "bài này chưa có câu hỏi" — một câu SAI mà người dùng
    /// sẽ tin. Xem [[feedback_fallback_path_is_where_bugs_hide]].
    @Published var loiTaiBai: String?
    /// `{sectionId: số câu luyện}` của khoá. Rỗng = chưa tải xong hoặc khoá
    /// chưa gán câu nào.
    @Published var soCauLuyen: [Int: Int] = [:]
    @Published var dangLuu = false
    @Published var loi: String?
    /// Vị trí đã lưu của bài đang mở, tính bằng giây.
    @Published var viTriDaLuu = 0

    private var daTaiTienDo = false

    func tai(courseId: Int, lessonId: Int) async {
        baiDayDu = nil
        loiTaiBai = nil
        dangTaiBai = true
        defer { dangTaiBai = false }
        if !daTaiTienDo {
            daTaiTienDo = true
            await taiTienDo(courseId: courseId)
            await taiSoCauLuyen(courseId: courseId)
        }
        viTriDaLuu = 0   // sẽ đặt lại bên dưới nếu có bản ghi

        // Nội dung đầy đủ (ghi chú giảng dạy, mã nguồn) chỉ có ở đường riêng;
        // `/curriculum` không trả. Hỏng thì bỏ qua — vẫn còn phần từ mục lục.
        do {
            baiDayDu = try await APIClient.shared.request(.getLesson(courseId: courseId, lessonId: lessonId))
        } catch {
            baiDayDu = nil
            loiTaiBai = error.localizedDescription
        }
    }

    /// ⚠️ Máy chủ trả đối tượng JSON có KHOÁ LÀ CHUỖI (`{"12": 193}`) — JSON
    /// không có khoá số. Giải mã thẳng vào `[Int: Int]` thì `JSONDecoder` chờ
    /// một MẢNG xen kẽ [khoá, giá trị] và ném; phải qua `[String: Int]` rồi tự
    /// đổi.
    private func taiSoCauLuyen(courseId: Int) async {
        do {
            let m: [String: Int] = try await APIClient.shared.request(
                .soCauLuyenTheoChuong(courseId: courseId))
            soCauLuyen = Dictionary(uniqueKeysWithValues: m.compactMap { k, v in
                Int(k).map { ($0, v) }
            })
        } catch {
            // Không có số thì chỉ mất cái nút luyện chương, không hỏng bài học.
            soCauLuyen = [:]
        }
    }

    private func taiTienDo(courseId: Int) async {
        do {
            let ds: (items: [LessonProgress], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getCourseProgress(courseId: courseId))
            daXong = Set(ds.items.filter(\.isCompleted).map(\.lessonId))
        } catch {
            // Chưa ghi danh thì 401/403 — không phải lỗi đáng báo.
        }
    }

    func doiHoanThanh(courseId: Int, lessonId: Int) async {
        let dangXong = daXong.contains(lessonId)
        dangLuu = true
        defer { dangLuu = false }

        // Đổi trên máy trước cho tay bấm thấy phản hồi tức thì, hỏng thì trả lại.
        if dangXong { daXong.remove(lessonId) } else { daXong.insert(lessonId) }
        Haptics.xong()

        do {
            try await APIClient.shared.send(
                .saveLessonProgress(courseId: courseId, lessonId: lessonId,
                                    isCompleted: !dangXong, watchTimeSeconds: nil,
                                    lastPositionSeconds: nil),
            )
        } catch {
            if dangXong { daXong.insert(lessonId) } else { daXong.remove(lessonId) }
            loi = error.localizedDescription
            Haptics.hong()
        }
    }

    /// Gọi khi rời bài. Hiện chỉ ghi nhận đã xem; lấy mốc giây thật từ khung
    /// YouTube cần cầu JS hai chiều — để dành khi nào làm tiếp tục-xem tử tế.
    func luuViTriNeuCan(courseId: Int, lessonId: Int) {
        guard !daXong.contains(lessonId) else { return }
        Task {
            try? await APIClient.shared.send(
                .saveLessonProgress(courseId: courseId, lessonId: lessonId,
                                    isCompleted: nil, watchTimeSeconds: nil,
                                    lastPositionSeconds: nil),
            )
        }
    }
}

// Bản dựng bằng NSAttributedString đã GỠ: nó bẹp `<table>` thành dòng
// nối đuôi và hiện cả hai ngôn ngữ cùng lúc. Xem RichContentView.swift.

extension String {
    /// Lột hết thẻ, gộp khoảng trắng — bản dự phòng khi dựng HTML thất bại.
    var lotTheHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
