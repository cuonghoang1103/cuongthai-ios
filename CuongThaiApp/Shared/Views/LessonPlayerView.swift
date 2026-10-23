import SwiftUI
#if os(iOS)
import WebKit
#endif

// MARK: - Màn học một bài Academy
//
// Viết lại 22/10/2026 cho đủ như trang học của web (`LearnPageClient.tsx`):
//   · video R2 riêng (AVPlayer) + YouTube, chọn VN/EN/YT, tốc độ, Hình trong hình;
//   · mở lại đúng chỗ đang xem, lưu mốc định kỳ, báo thời lượng, xong ở 90%/hết,
//     tự chuyển "Bài tiếp theo";
//   · trình chiếu slide, tài liệu (PDF/Quick Look/link), bài tập nộp link,
//     luyện Code Lab, sổ tay, chứng chỉ, lộ trình chương;
//   · "Học cùng CuongMini": cột bên thường trực trên iPad, sheet có nấc trên iPhone.
//
// Mọi thứ đọc từ API lúc chạy — web thêm bài/video/tài liệu là app có ngay.
//
// ⚠️ CHỈ phát, KHÔNG tải video về. App Store Guideline 5.2.3 cấm lưu/chuyển
// đổi/tải media từ nguồn thứ ba — đó chính là lý do module Nhạc đã bị gỡ.

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
        // Khung nhúng cần một origin BÊN THỨ BA hợp lệ, và `origin` trong URL
        // phải KHỚP với origin của trang cha — dùng lại đúng origin của web.
        //
        // ⚠️ oEmbed trả 200 KHÔNG chứng minh video nhúng được — video bị chủ
        // kênh tắt nhúng vẫn trả 200.
        guard let goc = URL(string: Self.trangChu) else { return }
        web.loadSimulatedRequest(URLRequest(url: goc), responseHTML: trangHTML)
    }

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
    guard let url, let u = URL(string: url), let host = u.host?.lowercased() else { return nil }
    if host.contains("youtu.be") {
        let ma = u.lastPathComponent
        return ma.isEmpty || ma == "/" ? nil : ma
    }
    guard host.contains("youtube.com") || host.contains("youtube-nocookie.com") else { return nil }
    if let items = URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems,
       let v = items.first(where: { $0.name == "v" })?.value, !v.isEmpty {
        return v
    }
    if u.path.contains("/embed/") || u.path.contains("/shorts/") || u.path.contains("/live/") {
        let ma = u.lastPathComponent
        return ma.isEmpty ? nil : ma
    }
    return nil
}

// MARK: - Màn học

/// Mọi thứ màn học có thể trình bày lên trên — MỘT `.sheet(item:)` (CLAUDE.md C5).
private enum BangBaiHoc: Identifiable {
    case mucLuc
    case giaSu(cau: String?, khoa: String?, quiz: HoiVeCau?)
    case taiLieu(DichMoTaiLieu)
    case nopBai(BaiTapNop)
    case luyenChuong(CourseSection, Int)
    case muaPro

    var id: String {
        switch self {
        case .mucLuc: return "mucluc"
        case let .giaSu(c, k, q): return "giasu-\(q?.id ?? "")-\(k ?? "")-\(c ?? "")"
        case .taiLieu(let d): return "tl-" + d.id
        case .nopBai(let b): return "nop-\(b.id)"
        case let .luyenChuong(c, _): return "lc-\(c.id)"
        case .muaPro: return "pro"
        }
    }
}

struct LessonPlayerView: View {
    let course: Course
    let sections: [CourseSection]
    /// Có quyền xem TRỌN khoá (`hasPaidAccess`). `false` ⇒ chỉ bài học thử mở được.
    let coToanQuyen: Bool
    @State private var lessonId: Int

    @Environment(\.horizontalSizeClass) private var coNgang
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = LessonPlayerViewModel()
    @StateObject private var soTay = SoTayBaiVM()
    #if os(iOS)
    /// Giữ trình phát qua MỘT lớp vỏ không @Published: `BoPhatVideo` đổi `giay` mỗi giây,
    /// quan sát thẳng ở đây là cả màn học (WebView nội dung, rút slide…) dựng lại mỗi giây.
    /// Chỉ `KhoiVideoBai` quan sát nó.
    @StateObject private var voPhat = VoBoPhat()
    private var bo: BoPhatVideo { voPhat.bo }
    #endif

    @State private var bang: BangBaiHoc?
    @State private var slideMo: Int?
    @State private var luongDangChon: String?
    @State private var chuDangChon: (chu: String, code: Bool)?
    @State private var baiTiepCho: CourseLesson?
    @State private var thongBao: String?
    /// Cột bên iPad: Mục lục ⟷ CuongMini.
    @State private var cotBen: CotBen = .cuongMini
    @State private var yeuCauHoi: YeuCauHoiGiaSu?
    /// Mốc cần quay lại sau khi xin URL ký mới (URL cũ hết hạn giữa chừng).
    @State private var mocSauKyLai: Double?

    enum CotBen: String, CaseIterable { case cuongMini, mucLuc }

    init(course: Course, sections: [CourseSection], lessonId: Int, coToanQuyen: Bool = true) {
        self.course = course
        self.sections = sections
        self.coToanQuyen = coToanQuyen
        _lessonId = State(initialValue: lessonId)
    }

    // MARK: Dữ liệu suy ra

    private var tatCaBai: [CourseLesson] { CayBai.phang(sections) }
    private var chiSoHienTai: Int? { tatCaBai.firstIndex { $0.id == lessonId } }
    private var baiHienTai: CourseLesson? { tatCaBai.first { $0.id == lessonId } }
    /// Bài đầy đủ CỦA ĐÚNG bài đang mở (đổi bài nhanh tay thì gói cũ còn nằm đó vài trăm ms).
    private var dayDu: CourseLesson? { vm.baiDayDu?.id == lessonId ? vm.baiDayDu : nil }
    private var chuongCuaBai: CourseSection? {
        sections.first { ($0.lessons ?? []).contains { $0.id == lessonId } }
    }
    private func moDuoc(_ b: CourseLesson) -> Bool { coToanQuyen || b.isFreePreview == true }
    private var baiTruoc: CourseLesson? {
        guard let i = chiSoHienTai, i > 0 else { return nil }
        return tatCaBai[..<i].last(where: moDuoc)
    }
    private var baiTiep: CourseLesson? {
        guard let i = chiSoHienTai, i + 1 < tatCaBai.count else { return nil }
        return tatCaBai[(i + 1)...].first(where: moDuoc)
    }
    private var loai: LoaiBai { (dayDu ?? baiHienTai)?.loai ?? .video }
    private var tenBai: String { (baiHienTai?.title ?? dayDu?.title ?? "").theoApp }
    private var tenMon: String? {
        (course.courseCode?.isEmpty == false ? course.courseCode : nil) ?? course.title.theoApp
    }

    private var dsLuong: [OLuongVideo] {
        ChonLuong.dsO(dayDu: dayDu?.videoTracks, mucLuc: baiHienTai?.videoTracks,
                      videoUrlCu: dayDu?.videoUrl ?? baiHienTai?.videoUrl,
                      nenTangCu: dayDu?.videoPlatform ?? baiHienTai?.videoPlatform)
    }
    private var luongDung: OLuongVideo? {
        ChonLuong.chon(dsLuong, dangChon: luongDangChon,
                       uaThich: UserDefaults.standard.string(forKey: ChonLuong.khoaUaThich),
                       macDinh: dayDu?.defaultVideoTrack ?? baiHienTai?.defaultVideoTrack)
    }
    private var coVideo: Bool { dsLuong.contains(where: \.coVideo) }
    private var slides: [SlideBai] { dayDu == nil ? [] : vm.slides }

    /// Khoá nạp trình phát: bài + luồng + URL (URL ký lại ⇒ khoá mới ⇒ nạp lại, giữ mốc).
    private var khoaPhat: String {
        guard let o = luongDung, o.laFileRieng, let u = o.url else { return "none-\(lessonId)" }
        return "\(lessonId)|\(o.track)|\(u)"
    }

    private var laCotDoi: Bool { coNgang == .regular }

    // MARK: Thân

    /// Màn đọc/tập trung ⇒ chủ đề mùa tự dừng chuyển động khi màn này hiện (Shared/ChuDe).
    var body: some View { thanManYen.nenMuaYen() }

    @ViewBuilder private var thanManYen: some View {
        Group {
            if laCotDoi {
                HStack(spacing: 0) {
                    cotChinh
                    Divider()
                    cotPhai
                        .frame(width: 380)
                }
            } else {
                cotChinh
                    .overlay(alignment: .bottomTrailing) { nutCuongMini }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(tenMon ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !laCotDoi {
                    Button { bang = .mucLuc } label: { Image(systemName: "list.bullet.rectangle") }
                        .accessibilityLabel(T("Mục lục"))
                }
            }
        }
        .sheet(item: $bang) { b in bangNoiDung(b) }
        #if os(iOS)
        .fullScreenCover(item: Binding(get: { slideMo.map { MoSlide(viTri: $0) } }, set: { slideMo = $0?.viTri })) { m in
            XemSlideView(slides: slides, dangXem: m.viTri) { s in
                slideMo = nil
                hoiCuongMini(s.cauHoi, khoa: s.khoaCache)
            }
        }
        #endif
        .task(id: lessonId) {
            chuDangChon = nil
            baiTiepCho = nil
            ganSuKienPhat()
            vm.datTongBai(tatCaBai.count)
            await vm.tai(courseId: course.id, lessonId: lessonId)
            await soTay.tai(courseSlug: course.slug, lessonId: lessonId)
        }
        #if os(iOS)
        .task(id: khoaPhat) { napPhat() }
        .onDisappear {
            vm.luuViTri(courseId: course.id, lessonId: lessonId, giay: bo.giay, ep: true)
            bo.dung()
            // Gỡ closure (chúng giữ màn này ⇒ vòng giữ nhau với trình phát).
            bo.goSuKien()
        }
        .onAppear { ganSuKienPhat() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            vm.luuViTri(courseId: course.id, lessonId: lessonId, giay: bo.giay, ep: true)
        }
        #endif
        .onChange(of: soTay.thongBao) { _, m in if let m { hienThongBao(m); soTay.thongBao = nil } }
        .overlay(alignment: .top) {
            if let thongBao {
                Text(thongBao)
                    .font(.buttonSmall).foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(AppColors.textPrimary.opacity(0.9)))
                    .padding(.top, Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private struct MoSlide: Identifiable { let viTri: Int; var id: Int { viTri } }

    // MARK: Cột chính

    private var cotChinh: some View {
        ScrollViewReader { cuon in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    NeoDauTrang()
                    dauBai
                    khoiChinh
                    tieuDeVaNut
                    #if os(iOS)
                    if loai == .video || coVideo {
                        TheLuyenCodeLab(courseSlug: course.slug, lessonSlug: dayDu?.slug ?? baiHienTai?.slug)
                    }
                    #endif
                    if !slides.isEmpty {
                        DaiSlideBai(slides: slides) { slideMo = $0 }
                    }
                    noiDung
                    khoiTaiLieuBaiTap
                    if let ma = dayDu?.sourceCodeUrl ?? baiHienTai?.sourceCodeUrl, let url = URL(string: ma) {
                        Link(destination: url) {
                            Label(T("Mã nguồn của bài"), systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.buttonSmall).foregroundColor(AppColors.primary)
                        }
                    }
                    if !course.slug.isEmpty, appState.currentUser != nil { KhoiSoTayBai(vm: soTay) }
                    khoiLuyenChuong
                    if let cc = vm.chungChi { TheChungChi(chungChi: cc, tenMon: course.title.theoApp) }
                    dieuHuongBai
                    if !laCotDoi { loTrinhChuong }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl + 56)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .bottom) { thanhNoi }
            .onChange(of: lessonId) { _, _ in cuon.veDauTrang() }
        }
    }

    /// "Chương 3 — JSX & Render · Bài 12/108 · Video · 12:05"
    private var dauBai: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let ch = chuongCuaBai {
                // Tiêu đề chương ĐÃ mang "⭐ Chuyên sâu …" — chỉ đổi màu, không chèn nhãn lặp lại.
                Text(ch.title.theoApp.uppercased())
                    .font(.system(size: 11, weight: .semibold)).tracking(0.4)
                    .foregroundColor(LoaiChuong.cua(ch.title) == .chuyenSau ? AppColors.warning : AppColors.textTertiary)
                    .lineLimit(1)
            }
            HStack(spacing: Spacing.sm) {
                Label(T(loai.nhan), systemImage: loai.bieuTuong)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                if let i = chiSoHienTai {
                    Text(String(format: T("Bài %d/%d"), i + 1, tatCaBai.count))
                }
                if let t = baiHienTai?.thoiLuong { Text("· \(t)") }
                if vm.daXong.contains(lessonId) {
                    Label(T("Đã xong"), systemImage: "checkmark.circle.fill").foregroundColor(AppColors.success)
                }
            }
            .font(.caption)
            .foregroundColor(AppColors.textTertiary)
        }
        .padding(.top, Spacing.sm)
    }

    /// Video / bài kiểm tra / đề PDF — thứ chiếm chỗ đầu tiên của bài.
    @ViewBuilder
    private var khoiChinh: some View {
        if loai == .quiz {
            khungQuiz
        } else {
            if loai == .baiTap || loai == .dapAn { khungDePdf }
            if coVideo || (loai == .video && vm.dangTaiBai) {
                #if os(iOS)
                KhoiVideoBai(dsO: dsLuong, dangChon: luongDung, dangTaiBai: vm.dangTaiBai,
                             loiTaiBai: vm.loiTaiBai, bo: bo,
                             khiChonLuong: { k in
                                 luongDangChon = k
                                 UserDefaults.standard.set(k, forKey: ChonLuong.khoaUaThich)
                             },
                             khiThuLai: {
                                 Task {
                                     mocSauKyLai = bo.giay
                                     await vm.taiLaiDeLayURL(courseId: course.id, lessonId: lessonId, ep: true)
                                     napPhat(ep: true)
                                 }
                             },
                             khiHoiDoanNay: {
                                 let g = Int(bo.giay)
                                 hoiCuongMini(String(format: T("Giải thích giúp tôi đoạn video quanh mốc %@."), TienDoXem.dongHo(Double(g))), khoa: nil)
                             })
                if let tiep = baiTiepCho {
                    LopBaiTiep(tenBai: tiep.title.theoApp, giayCho: 6,
                               khiChuyen: { moBai(tiep.id, tuPhat: true) },
                               khiHuy: { withAnimation { baiTiepCho = nil } })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                #endif
            } else if loai == .video, !vm.dangTaiBai, dayDu != nil {
                khungTrong(T("Bài này chưa có video"), he: "video.slash")
            }
        }
    }

    /// Bài QUIZ — làm NGAY TRONG APP (`quizData` của `GET /courses/:id/lessons/:id`).
    @ViewBuilder
    private var khungQuiz: some View {
        if let q = dayDu?.quizData, !q.cauHoi.isEmpty {
            BaiKiemTraView(
                de: q,
                lessonId: lessonId,
                tenBai: tenBai,
                tenMon: tenMon,
                khiHoiAI: { q in bang = .giaSu(cau: nil, khoa: nil, quiz: q) },
                khiNop: {
                    // Web đánh dấu hoàn thành ngay khi nộp. Chỉ khi CHƯA xong.
                    vm.danhDauXong(courseId: course.id, lessonId: lessonId)
                })
        } else if vm.dangTaiBai {
            HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, Spacing.xl)
        } else {
            VStack(spacing: Spacing.md) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 40)).foregroundColor(AppColors.primary)
                Text(T("Bài kiểm tra")).font(.titleMedium).foregroundColor(AppColors.textPrimary)
                Text(vm.loiTaiBai.map { String(format: T("Không tải được bài: %@"), $0) }
                     ?? T("Bài này chưa có bộ câu hỏi. Kéo xuống để tải lại khi giảng viên soạn xong."))
                    .font(.bodySmall).foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                Button(T("Tải lại")) { Task { await vm.tai(courseId: course.id, lessonId: lessonId, ep: true) } }
                    .buttonStyle(.borderedProminent).tint(AppColors.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
    }

    /// Bài BÀI TẬP / ĐÁP ÁN — đề nằm trong tệp PDF đính kèm (như `LessonPdfViewer` của web).
    @ViewBuilder
    private var khungDePdf: some View {
        let pdf = (dayDu?.documents ?? []).first { $0.kieu == .pdf }
        if let pdf {
            Button {
                Task {
                    if let d = try? await MoTaiLieu.chuanBi(pdf) { bang = .taiLieu(d) }
                    else { hienThongBao(T("Không mở được tệp PDF.")) }
                }
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: loai == .dapAn ? "checkmark.seal.fill" : "doc.richtext.fill")
                        .font(.system(size: 26)).foregroundColor(AppColors.onPrimary)
                        .frame(width: 54, height: 54)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.brandGradient))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loai == .dapAn ? T("Mở đáp án (PDF)") : T("Mở đề bài (PDF)"))
                            .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                        Text(pdf.title.theoApp).font(.caption).foregroundColor(AppColors.textSecondary).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundColor(AppColors.textTertiary)
                }
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.backgroundCard))
            }
            .buttonStyle(.nhan)
        } else if !vm.dangTaiBai, dayDu != nil {
            khungTrong(T("Chưa có tệp PDF cho bài này."), he: "doc")
                .frame(height: 90)
        }
    }

    private func khungTrong(_ chu: String, he: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: he).font(.system(size: 26)).foregroundColor(AppColors.textTertiary)
            Text(chu).font(.bodySmall).foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundSecondary))
    }

    private var tieuDeVaNut: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(tenBai)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let kia = baiHienTai?.title.veKiaTheoApp {
                Text(kia).font(.bodySmall).foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let mt = (dayDu?.description ?? baiHienTai?.description), !mt.isEmpty {
                Text(mt.theoApp).font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            nutHoanThanh
        }
    }

    private var nutHoanThanh: some View {
        let xong = vm.daXong.contains(lessonId)
        return Button {
            Task { await vm.doiHoanThanh(courseId: course.id, lessonId: lessonId) }
        } label: {
            HStack(spacing: Spacing.sm) {
                if vm.dangLuu {
                    ProgressView().tint(xong ? AppColors.success : AppColors.onPrimary)
                } else {
                    Image(systemName: xong ? "checkmark.circle.fill" : "circle")
                }
                Text(xong ? T("Đã hoàn thành") : T("Đánh dấu hoàn thành")).font(.buttonText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundColor(xong ? AppColors.success : AppColors.onPrimary)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(xong ? AnyShapeStyle(AppColors.success.opacity(0.14)) : AnyShapeStyle(AppColors.brandGradient)))
        }
        .buttonStyle(.nhan)
        .disabled(vm.dangLuu)
        .accessibilityHint(xong ? T("Chạm để bỏ đánh dấu") : "")
    }

    @ViewBuilder
    private var noiDung: some View {
        let chu = dayDu?.content
        if let chu, !chu.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(T("Nội dung bài học"), systemImage: "book.pages")
                    .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                RichContent(
                    html: chu,
                    khiChamSlide: { i, src in
                        let ds = slides
                        slideMo = ds.firstIndex { $0.anh == src } ?? min(i, max(ds.count - 1, 0))
                    },
                    khiChonChu: { t, code in
                        withAnimation(.snappy(duration: 0.2)) { chuDangChon = t.isEmpty ? nil : (t, code) }
                    })
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.backgroundCard))
        } else if vm.dangTaiBai {
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBox(height: 18, width: 180)
                SkeletonBox(height: 12); SkeletonBox(height: 12); SkeletonBox(height: 12, width: 240)
                SkeletonBox(height: 140, radius: CornerRadius.medium)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
        if let ghiChu = dayDu?.teachingNotes, !ghiChu.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(T("Ghi chú giảng dạy"), systemImage: "text.book.closed")
                    .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                RichContent(html: ghiChu)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.backgroundCard))
        }
    }

    @ViewBuilder
    private var khoiTaiLieuBaiTap: some View {
        let docs = dayDu?.documents ?? []
        if !docs.isEmpty {
            DanhSachTaiLieu(tieuDe: T("Tài liệu của bài"), ds: docs) { bang = .taiLieu($0) }
        }
        if !vm.baiTap.isEmpty {
            DanhSachBaiTapNop(ds: vm.baiTap) { bang = .nopBai($0) }
        }
    }

    /// Đề luyện cuối chương — câu THẬT từ đề FE/PE/PT gán về chương này.
    @ViewBuilder
    private var khoiLuyenChuong: some View {
        if let ch = chuongCuaBai, let n = vm.soCauLuyen[ch.id], n > 0 {
            Button { bang = .luyenChuong(ch, n) } label: {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 20)).foregroundColor(AppColors.primary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(format: T("Đề luyện cuối chương — %d câu"), n))
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        Text(T("Câu hỏi thật từ đề FE/PE/PT của chương này. Chấm ngay, có giải thích, hỏi được gia sư."))
                            .font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.primary.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(AppColors.primary.opacity(0.35), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var dieuHuongBai: some View {
        HStack(spacing: Spacing.md) {
            if let truoc = baiTruoc {
                Button { moBai(truoc.id) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(T("Bài trước"), systemImage: "chevron.left").font(.captionBold)
                            .foregroundColor(AppColors.textTertiary)
                        Text(truoc.title.theoApp).font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(AppColors.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
                }
                .buttonStyle(.nhan)
            }
            if let tiep = baiTiep {
                Button { moBai(tiep.id) } label: {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) { Text(T("Bài tiếp")); Image(systemName: "chevron.right") }
                            .font(.captionBold).foregroundColor(AppColors.onPrimary.opacity(0.85))
                        Text(tiep.title.theoApp).font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(AppColors.onPrimary).lineLimit(2).multilineTextAlignment(.trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(Spacing.md)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.brandGradient))
                }
                .buttonStyle(.nhan)
            }
        }
    }

    /// Lộ trình chương: thanh tiến độ mỗi chương, chạm để nhảy (iPhone — iPad có cột Mục lục).
    private var loTrinhChuong: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label(T("Lộ trình môn"), systemImage: "map").font(.titleSmall).foregroundColor(AppColors.textPrimary)
                Spacer()
                Button(T("Mục lục")) { bang = .mucLuc }.font(.buttonSmall).foregroundColor(AppColors.primary)
            }
            ForEach(sections.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }) { ch in
                let ds = (ch.lessons ?? [])
                let xong = ds.filter { vm.daXong.contains($0.id) }.count
                let dangO = ds.contains { $0.id == lessonId }
                Button {
                    if let b = CayBai.baiTiep([ch], daXong: vm.daXong, moDuoc: moDuoc) { moBai(b.id) }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Circle().fill(dangO ? AppColors.primary : (xong == ds.count && !ds.isEmpty ? AppColors.success : AppColors.border))
                            .frame(width: 8, height: 8)
                        Text(ch.title.theoApp).font(.system(size: 13, weight: dangO ? .semibold : .regular))
                            .foregroundColor(dangO ? AppColors.primary : AppColors.textSecondary).lineLimit(1)
                        Spacer(minLength: Spacing.sm)
                        ProgressView(value: Double(xong), total: Double(max(ds.count, 1)))
                            .tint(xong == ds.count && !ds.isEmpty ? AppColors.success : AppColors.primary)
                            .frame(width: 60)
                        Text("\(xong)/\(ds.count)").font(.system(size: 11, design: .monospaced))
                            .foregroundColor(AppColors.textTertiary).frame(width: 40, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.backgroundCard))
    }

    /// Thanh nổi đáy cột chính: đang bôi đen chữ ⇒ "Lưu vào sổ tay / Hỏi".
    @ViewBuilder
    private var thanhNoi: some View {
        if let c = chuDangChon, appState.currentUser != nil {
            ThanhChonChu(chu: c.chu, dangLuu: soTay.dangLuu,
                         khiLuu: {
                             Task {
                                 if await soTay.luu(c.chu, laCode: c.code) { withAnimation { chuDangChon = nil } }
                             }
                         },
                         khiHoi: {
                             let doan = String(c.chu.prefix(1200))
                             withAnimation { chuDangChon = nil }
                             hoiCuongMini(T("Giải thích giúp tôi đoạn này trong bài:") + "\n\n> " + doan, khoa: nil)
                         })
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md + (laCotDoi ? 0 : 56))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: CuongMini

    /// Nút nổi iPhone — mở sheet gia sư có nấc.
    private var nutCuongMini: some View {
        Button {
            bang = .giaSu(cau: nil, khoa: nil, quiz: nil)
            Haptics.cham()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "sparkles").font(.system(size: 15, weight: .semibold))
                Text("CuongMini").font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Capsule().fill(AppColors.brandGradient))
            .shadow(color: AppColors.primary.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.nhan)
        .accessibilityLabel(T("Học cùng CuongMini"))
        .padding(.trailing, Spacing.md)
        .padding(.bottom, Spacing.md)
        .opacity(chuDangChon == nil ? 1 : 0)
    }

    /// Cột phải iPad: CuongMini thường trực + Mục lục.
    private var cotPhai: some View {
        VStack(spacing: 0) {
            Picker("", selection: $cotBen) {
                Text(T("CuongMini")).tag(CotBen.cuongMini)
                Text(T("Mục lục")).tag(CotBen.mucLuc)
            }
            .pickerStyle(.segmented)
            .padding(Spacing.sm)
            .background(AppColors.backgroundSecondary)
            switch cotBen {
            case .cuongMini:
                GiaSuBaiHocView(lessonId: lessonId, tenBai: tenBai, tenMon: tenMon,
                                slides: slides, boiCanhVideo: boiCanhVideo, nhung: true, yeuCau: yeuCauHoi)
                    .id("giasu-\(lessonId)")
            case .mucLuc:
                MucLucBaiHoc(sections: sections, baiDangHoc: lessonId, daXong: vm.daXong,
                             moDuoc: moDuoc, hienHocThu: !coToanQuyen, chon: { moBai($0) })
            }
        }
        .background(AppColors.backgroundPrimary)
    }

    private func hoiCuongMini(_ cau: String, khoa: String?) {
        if laCotDoi {
            cotBen = .cuongMini
            yeuCauHoi = YeuCauHoiGiaSu(cau: cau, khoaCache: khoa)
        } else {
            bang = .giaSu(cau: cau, khoa: khoa, quiz: nil)
        }
    }

    /// Mốc video LÚC HỎI. YouTube không báo giây về app ⇒ chỉ gửi luồng.
    private var boiCanhVideo: (() -> BoiCanhVideoHoi?)? {
        guard coVideo else { return nil }
        #if os(iOS)
        let bo = bo
        return {
            guard let o = luongDung, o.trangThai == .phatDuoc else { return nil }
            let g = o.laFileRieng && bo.giay > 0 ? Int(bo.giay) : nil
            return BoiCanhVideoHoi(track: o.track, giay: g)
        }
        #else
        return nil
        #endif
    }

    @ViewBuilder
    private func bangNoiDung(_ b: BangBaiHoc) -> some View {
        switch b {
        case .mucLuc:
            NavigationStack {
                MucLucBaiHoc(sections: sections, baiDangHoc: lessonId, daXong: vm.daXong,
                             moDuoc: moDuoc, hienHocThu: !coToanQuyen, chon: { id in bang = nil; moBai(id) })
                    .navigationTitle(T("Mục lục"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { bang = nil } } }
            }
            .presentationDetents([.medium, .large])
        case let .giaSu(cau, khoa, quiz):
            GiaSuBaiHocView(lessonId: lessonId, tenBai: tenBai, tenMon: tenMon,
                            quizContext: quiz?.boiCanh ?? [],
                            cauHoiSan: quiz?.cauMoDau ?? cau, khoaCacheSan: quiz == nil ? khoa : nil,
                            slides: slides, boiCanhVideo: boiCanhVideo)
                .presentationDetents([.fraction(0.62), .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.62)))
        case .taiLieu(let d):
            #if os(iOS)
            switch d {
            case let .pdf(u, ten): NavigationStack { XemPdfView(duong: u, tieuDe: ten) }
            case .web(let u): KhungSafari(duong: u).ignoresSafeArea()
            case .tep(let u): XemTepNhanh(url: u).ignoresSafeArea()
            }
            #endif
        case .nopBai(let a):
            NopBaiTapView(baiTap: a) { n in vm.capNhatBaiNop(a.id, n) }
        case let .luyenChuong(ch, n):
            LuyenChuongView(
                sectionId: ch.id, tenChuong: ch.title, soCau: n,
                // Gia sư gắn theo BÀI, nên lấy bài đầu chương làm ngữ cảnh
                // — đúng cách web làm (`lessonId={lessons[0]?.id}`).
                lessonId: (ch.lessons ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }.first?.id,
                // ⚠️ `courseCode` CÓ THỂ RỖNG — lùi về tên khoá, không thì hàng
                // "mở Phòng Thi" bị ẩn IM LẶNG.
                tenMon: tenMon)
        case .muaPro:
            #if os(iOS)
            MuaProView()
            #endif
        }
    }

    // MARK: Hành động

    private func moBai(_ id: Int, tuPhat: Bool = false) {
        Haptics.cham()
        #if os(iOS)
        vm.luuViTri(courseId: course.id, lessonId: lessonId, giay: bo.giay, ep: true)
        #endif
        luongDangChon = nil
        baiTiepCho = nil
        tuPhatBaiSau = tuPhat
        lessonId = id
    }

    @State private var tuPhatBaiSau = false

    private func hienThongBao(_ m: String) {
        withAnimation(.snappy) { thongBao = m }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            withAnimation(.easeOut) { thongBao = nil }
        }
    }

    #if os(iOS)
    /// Nạp file vào trình phát khi (bài, luồng, URL) đổi. Luồng không phải file ⇒ nhả trình phát.
    private func napPhat(ep: Bool = false) {
        guard let o = luongDung, o.laFileRieng, let s = o.url, let url = URL(string: s) else {
            bo.thaRa()
            return
        }
        let batDau = mocSauKyLai ?? TienDoXem.mocMoLai(vm.tienDo[lessonId],
                                                       thoiLuong: Double(baiHienTai?.videoDurationSeconds ?? 0))
        mocSauKyLai = nil
        #if DEBUG
        if ProcessInfo.processInfo.environment["CT_TU_PHAT"] == "1" { tuPhatBaiSau = true }
        #endif
        bo.nap(url: url, khoa: khoaPhat + (ep ? "|\(Date().timeIntervalSince1970)" : ""), batDau: batDau, tuPhat: tuPhatBaiSau)
        tuPhatBaiSau = false
    }

    /// Nối sự kiện trình phát ⇒ tiến độ. Gọi lại mỗi lần đổi bài.
    private func ganSuKienPhat() {
        let courseId = course.id
        bo.khiTick = { giay, thoiLuong in
            vm.luuViTri(courseId: courseId, lessonId: lessonId, giay: giay)
            if TienDoXem.duXong(giay: giay, thoiLuong: thoiLuong) {
                vm.danhDauXong(courseId: courseId, lessonId: lessonId, giay: Int(giay))
            }
        }
        bo.khiDung = { giay in vm.luuViTri(courseId: courseId, lessonId: lessonId, giay: giay, ep: true) }
        bo.khiHet = {
            vm.danhDauXong(courseId: courseId, lessonId: lessonId, giay: Int(bo.thoiLuong))
            if let tiep = baiTiep { withAnimation(.snappy) { baiTiepCho = tiep } }
        }
        bo.khiCoThoiLuong = { d in
            vm.baoThoiLuong(lessonId: lessonId, giay: d, daLuu: baiHienTai?.videoDurationSeconds)
        }
        bo.khiHong = { giay in
            // URL ký 6 giờ hết hạn (để app mở qua đêm, hoặc bản ngoại tuyến cũ) ⇒
            // xin bài lại MỘT lần, phát tiếp từ đúng mốc. Hỏng nữa mới báo lỗi.
            guard vm.conDuocXinLai(lessonId) else { return false }
            Task {
                mocSauKyLai = giay
                await vm.taiLaiDeLayURL(courseId: courseId, lessonId: lessonId)
                napPhat(ep: true)
            }
            return true
        }
    }
    #else
    private func ganSuKienPhat() {}
    #endif
}

// MARK: - Mục lục

/// Danh sách chương → bài, dùng cho sheet (iPhone) và cột bên (iPad).
struct MucLucBaiHoc: View {
    let sections: [CourseSection]
    let baiDangHoc: Int
    let daXong: Set<Int>
    let moDuoc: (CourseLesson) -> Bool
    var hienHocThu = false
    let chon: (Int) -> Void

    var body: some View {
        ScrollViewReader { cuon in
            List {
                ForEach(sections.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }) { chuong in
                    Section {
                        ForEach((chuong.lessons ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }) { bai in
                            hang(bai).id(bai.id)
                        }
                    } header: {
                        TieuDeChuong(tieuDe: chuong.title, soBai: chuong.lessons?.count ?? 0,
                                     soXong: (chuong.lessons ?? []).filter { daXong.contains($0.id) }.count)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onAppear { cuon.scrollTo(baiDangHoc, anchor: .center) }
        }
    }

    private func hang(_ bai: CourseLesson) -> some View {
        let mo = moDuoc(bai)
        let dang = bai.id == baiDangHoc
        return Button {
            guard mo else { return }
            chon(bai.id)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: daXong.contains(bai.id) ? "checkmark.circle.fill" : (mo ? bai.loai.bieuTuong : "lock.fill"))
                    .foregroundColor(daXong.contains(bai.id) ? AppColors.success : (dang ? AppColors.primary : AppColors.textTertiary))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bai.title.theoApp)
                        .font(.system(size: 14, weight: dang ? .semibold : .regular))
                        .foregroundColor(dang ? AppColors.primary : (mo ? AppColors.textPrimary : AppColors.textTertiary))
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text(T(bai.loai.nhan))
                        if let t = bai.thoiLuong { Text("· \(t)") }
                        if hienHocThu, bai.isFreePreview == true { Text("· " + T("Học thử")).foregroundColor(AppColors.success) }
                    }
                    .font(.caption).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
                if dang {
                    Image(systemName: "waveform").font(.caption).foregroundColor(AppColors.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(dang ? AppColors.primary.opacity(0.08) : AppColors.backgroundCard)
        .accessibilityHint(mo ? "" : T("Bài này cần mở khoá môn học"))
    }
}

/// Tiêu đề chương với nhãn ⭐ Chuyên sâu / 🎓 Thi / 📝 Ôn thi.
struct TieuDeChuong: View {
    let tieuDe: String
    let soBai: Int
    let soXong: Int

    var body: some View {
        let loai = LoaiChuong.cua(tieuDe)
        HStack(spacing: 6) {
            Text(tieuDe.theoApp)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(loai == .chuyenSau ? AppColors.warning : AppColors.textSecondary)
                .textCase(nil)
                .lineLimit(2)
            Spacer(minLength: 0)
            Text("\(soXong)/\(soBai)").font(.system(size: 11, design: .monospaced))
                .foregroundColor(soXong == soBai && soBai > 0 ? AppColors.success : AppColors.textTertiary)
        }
    }

    private func nhan(_ s: String, _ m: Color) -> some View {
        Text(s).font(.system(size: 9.5, weight: .heavy)).foregroundColor(m)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(m.opacity(0.14)))
            .textCase(nil)
    }
}

// MARK: - ViewModel

@MainActor
final class LessonPlayerViewModel: ObservableObject {
    @Published var daXong: Set<Int> = []
    /// Mọi dòng tiến độ của khoá (để mở lại đúng mốc từng bài).
    @Published var tienDo: [Int: LessonProgress] = [:]
    @Published var baiDayDu: CourseLesson?
    @Published var dangTaiBai = false
    /// Hỏng khi tải bài. Phải HIỆN RA: với bài QUIZ, `baiDayDu == nil` vì mất
    /// mạng trông y hệt "bài này chưa có câu hỏi" — một câu SAI mà người dùng tin.
    @Published var loiTaiBai: String?
    /// `{sectionId: số câu luyện}` của khoá.
    @Published var soCauLuyen: [Int: Int] = [:]
    @Published var dangLuu = false
    @Published var loi: String?
    @Published var baiTap: [BaiTapNop] = []
    @Published var chungChi: ChungChiKhoa?
    /// Slide rút từ `content` — tính MỘT lần mỗi khi bài về, không mỗi lần dựng view.
    @Published private(set) var slides: [SlideBai] = []

    private var daTaiTienDo = false
    private var tongBai = 0
    private var nhip = NhipLuuTienDo()
    private var nhipCuaBai: Int?
    private var daBaoThoiLuong = Set<Int>()
    private var daXinLai = Set<Int>()

    func tai(courseId: Int, lessonId: Int, ep: Bool = false) async {
        if baiDayDu?.id != lessonId { baiDayDu = nil; baiTap = [] }
        loiTaiBai = nil
        dangTaiBai = true
        defer { dangTaiBai = false }
        if !daTaiTienDo || ep {
            daTaiTienDo = true
            async let a: Void = taiTienDo(courseId: courseId)
            async let b: Void = taiSoCauLuyen(courseId: courseId)
            _ = await (a, b)
        }
        do {
            let bai: CourseLesson = try await APIClient.shared.request(.getLesson(courseId: courseId, lessonId: lessonId))
            slides = DocSlide.tu(bai.content)
            baiDayDu = bai
            baiTap = bai.assignments ?? []
        } catch {
            if baiDayDu?.id != lessonId { baiDayDu = nil }
            loiTaiBai = error.localizedDescription
        }
    }

    /// Xin lại bài CHỈ để có URL ký mới — giữ nguyên nội dung đang hiện.
    func taiLaiDeLayURL(courseId: Int, lessonId: Int, ep: Bool = false) async {
        if ep { daXinLai.remove(lessonId) }
        daXinLai.insert(lessonId)
        if let bai: CourseLesson = try? await APIClient.shared.request(.getLesson(courseId: courseId, lessonId: lessonId)) {
            slides = DocSlide.tu(bai.content)
            baiDayDu = bai
            loiTaiBai = nil
        }
    }

    func conDuocXinLai(_ lessonId: Int) -> Bool { !daXinLai.contains(lessonId) }

    /// ⚠️ Máy chủ trả đối tượng JSON có KHOÁ LÀ CHUỖI (`{"12": 193}`) — phải qua
    /// `[String: Int]` rồi tự đổi.
    private func taiSoCauLuyen(courseId: Int) async {
        do {
            let m: [String: Int] = try await APIClient.shared.request(.soCauLuyenTheoChuong(courseId: courseId))
            soCauLuyen = Dictionary(uniqueKeysWithValues: m.compactMap { k, v in Int(k).map { ($0, v) } })
        } catch {
            soCauLuyen = [:]
        }
    }

    private func taiTienDo(courseId: Int) async {
        do {
            let ds: (items: [LessonProgress], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getCourseProgress(courseId: courseId))
            tienDo = Dictionary(ds.items.map { ($0.lessonId, $0) }, uniquingKeysWith: { a, _ in a })
            daXong = Set(ds.items.filter(\.isCompleted).map(\.lessonId))
        } catch {
            // Chưa đăng nhập ⇒ 401 — không phải lỗi đáng báo.
        }
        await kiemChungChi(courseId: courseId)
    }

    func doiHoanThanh(courseId: Int, lessonId: Int) async {
        let dangXong = daXong.contains(lessonId)
        dangLuu = true
        defer { dangLuu = false }
        if dangXong { daXong.remove(lessonId) } else { daXong.insert(lessonId) }
        Haptics.xong()
        do {
            try await APIClient.shared.send(.saveLessonProgress(
                courseId: courseId, lessonId: lessonId, isCompleted: !dangXong,
                watchTimeSeconds: nil, lastPositionSeconds: dangXong ? nil : 0))
            await kiemChungChi(courseId: courseId)
        } catch {
            if dangXong { daXong.insert(lessonId) } else { daXong.remove(lessonId) }
            loi = error.localizedDescription
            Haptics.hong()
        }
    }

    /// Đánh dấu xong (KHÔNG đảo): video hết / qua 90% / nộp quiz. Gọi nhiều lần vô hại.
    func danhDauXong(courseId: Int, lessonId: Int, giay: Int? = nil) {
        guard !daXong.contains(lessonId) else { return }
        daXong.insert(lessonId)
        Haptics.xong()
        Task {
            do {
                // Web: xong ⇒ lastPositionSeconds 0 (xem lại thì từ đầu).
                try await APIClient.shared.send(.saveLessonProgress(
                    courseId: courseId, lessonId: lessonId, isCompleted: true,
                    watchTimeSeconds: giay, lastPositionSeconds: 0))
                await kiemChungChi(courseId: courseId)
            } catch {
                daXong.remove(lessonId)
            }
        }
    }

    /// Lưu mốc đang xem — theo nhịp `NhipLuuTienDo` (15 giây; `ep` = dừng/rời bài/vào nền).
    /// KHÔNG gửi `isCompleted` — xem dở không bao giờ được lật trạng thái xong.
    func luuViTri(courseId: Int, lessonId: Int, giay: Double, ep: Bool = false) {
        if nhipCuaBai != lessonId { nhipCuaBai = lessonId; nhip.datLai() }
        guard nhip.nenLuu(giay: giay, bayGio: Date().timeIntervalSince1970, ep: ep) else { return }
        let moc = Int(giay.rounded())
        let cu = tienDo[lessonId]
        let daXem = max(cu?.watchTimeSeconds ?? 0, moc)
        tienDo[lessonId] = LessonProgress(id: cu?.id, lessonId: lessonId, isCompleted: cu?.isCompleted ?? false,
                                          watchTimeSeconds: daXem, lastPositionSeconds: moc)
        Task {
            try? await APIClient.shared.send(.saveLessonProgress(
                courseId: courseId, lessonId: lessonId, isCompleted: nil,
                watchTimeSeconds: daXem, lastPositionSeconds: moc))
        }
    }

    /// Báo thời lượng thật MỘT lần — chỉ khi máy chủ chưa biết (0), như web.
    func baoThoiLuong(lessonId: Int, giay: Double, daLuu: Int?) {
        guard (daLuu ?? 0) <= 0, giay.isFinite, giay > 0, !daBaoThoiLuong.contains(lessonId) else { return }
        daBaoThoiLuong.insert(lessonId)
        Task { try? await APIClient.shared.send(.hocBai(.baoThoiLuong(lessonId: lessonId, giay: Int(giay.rounded())))) }
    }

    func capNhatBaiNop(_ id: Int, _ n: NopBai) {
        if let i = baiTap.firstIndex(where: { $0.id == id }) { baiTap[i].mySubmission = n }
    }

    /// Đủ 100% ⇒ máy chủ đã cấp chứng chỉ (tự cấp ở `POST /progress`). 404 = chưa.
    func kiemChungChi(courseId: Int) async {
        guard chungChi == nil, tongBai > 0, daXong.count >= tongBai else { return }
        chungChi = try? await APIClient.shared.request(.hocBai(.chungChiKhoa(courseId: courseId)))
    }

    func datTongBai(_ n: Int) { tongBai = n }
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
