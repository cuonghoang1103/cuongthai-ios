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
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                khungVideo
                tieuDe
                if let bai = baiHienTai, (bai.videoTracks?.count ?? 0) > 1 {
                    boChonLuong(bai)
                }
                if let credit = luongDung?.credit, !credit.isEmpty {
                    dongGhiCong(credit)
                }
                noiDung
                nutHoanThanh
                dieuHuongBai
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
        .background(AppColors.backgroundPrimary)
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
    }

    // MARK: Khối

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

    /// Bài QUIZ: backend chưa có đường trả nội dung quiz (soi `course.routes.ts`
    /// 19/08/2026 không thấy). Nói thẳng và đưa người dùng sang web, thay vì
    /// để một màn trống không giải thích gì.
    private var khungQuiz: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 40))
                .foregroundColor(AppColors.primary)
            Text("Bài kiểm tra")
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)
            Text("Phần kiểm tra hiện làm trên website. Tiến độ vẫn được tính chung.")
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
    @Published var dangLuu = false
    @Published var loi: String?
    /// Vị trí đã lưu của bài đang mở, tính bằng giây.
    @Published var viTriDaLuu = 0

    private var daTaiTienDo = false

    func tai(courseId: Int, lessonId: Int) async {
        baiDayDu = nil
        if !daTaiTienDo {
            daTaiTienDo = true
            await taiTienDo(courseId: courseId)
        }
        viTriDaLuu = 0   // sẽ đặt lại bên dưới nếu có bản ghi

        // Nội dung đầy đủ (ghi chú giảng dạy, mã nguồn) chỉ có ở đường riêng;
        // `/curriculum` không trả. Hỏng thì bỏ qua — vẫn còn phần từ mục lục.
        do {
            baiDayDu = try await APIClient.shared.request(.getLesson(courseId: courseId, lessonId: lessonId))
        } catch {
            baiDayDu = nil
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
