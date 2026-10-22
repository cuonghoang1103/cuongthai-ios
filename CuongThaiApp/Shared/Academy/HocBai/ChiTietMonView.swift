import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// ════════════════════════════════════════════════════════════════
// CHI TIẾT MÔN / KHOÁ HỌC (viết lại 22/10/2026)
//
// Nguồn: `GET /courses/:slug?gon=1` — ĐỦ cây chương→bài cho MỌI người (cả bài
// bị khoá, để hiện ổ khoá) mà không kéo `content` nặng (FER202: 69 KB thay vì
// cả MB). `/curriculum` chỉ còn là đường lùi: với khoá trả phí chưa có quyền nó
// trả 402 — trước đây màn này nuốt lỗi đó và hiện "Khoá học này chưa có bài nào".
// `GET /courses/:id/progress` cho dấu tích + vòng tiến độ + "Tiếp tục học";
// `GET /courses/:id/documents` cho tài liệu cấp môn.
//
// Luôn gọi mạng trước (web thêm bài/video rất thường xuyên); bản đã lưu chỉ là
// đường lùi khi mất mạng (tầng `APIClient.perform`).
// ════════════════════════════════════════════════════════════════

private enum BangMon: Identifiable {
    case taiLieu(DichMoTaiLieu)
    case muaPro
    var id: String {
        switch self {
        case .taiLieu(let d): return d.id
        case .muaPro: return "pro"
        }
    }
}

struct CourseDetailView: View {
    let slug: String
    /// Mở thẳng bài này khi vào (từ "Đang học" của Academy / Hồ sơ).
    var moBaiId: Int? = nil

    @StateObject private var viewModel = CourseDetailViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var baiDangMo: CourseLesson?
    @State private var moRongMoTa = false
    @State private var moChuong: Set<Int> = []
    @State private var bang: BangMon?
    @State private var daMoSan = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if viewModel.isLoading && viewModel.course == nil {
                    khungXuong
                } else if let course = viewModel.course {
                    dauTrang(course)
                    if !viewModel.coToanQuyen { theKhoa(course) }
                    gioiThieu(course)
                    if !viewModel.taiLieuKhoa.isEmpty || !(course.documentsNote ?? "").isEmpty {
                        if viewModel.taiLieuKhoa.isEmpty {
                            danhSachY(T("Tài liệu tham khảo"), "book.fill",
                                      CourseDetail.tachY(course.documentsNote), mau: AppColors.primary)
                        } else {
                            DanhSachTaiLieu(tieuDe: T("Tài liệu môn học"), ds: viewModel.taiLieuKhoa,
                                            ghiChu: course.documentsNote) { bang = .taiLieu($0) }
                        }
                    }
                    noiDungMon
                    if let reviews = course.reviews, !reviews.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            tieuDeMuc(T("Đánh giá"), "star.fill")
                            ForEach(reviews.prefix(3)) { ReviewRow(review: $0).padding(.horizontal, -Spacing.md) }
                        }
                    }
                } else if let loi = viewModel.error {
                    ErrorStateView(message: loi) { Task { await viewModel.loadCourseDetail(slug: slug) } }
                        .padding(.top, Spacing.xxl)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xxl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(viewModel.course?.courseCode ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.loadCourseDetail(slug: slug) }
        // Nút tải về NẰM Ở ĐÂY, trên chính màn khoá học — chôn trong Cài đặt thì không ai tìm ra.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let c = viewModel.course, viewModel.coToanQuyen {
                    NutTaiVeHoc(id: c.id, slug: slug, ten: c.title)
                }
            }
        }
        .navigationDestination(item: $baiDangMo) { bai in
            if let ct = viewModel.course {
                LessonPlayerView(course: Course(from: ct), sections: viewModel.chuong,
                                 lessonId: bai.id, coToanQuyen: viewModel.coToanQuyen)
            }
        }
        .sheet(item: $bang) { b in
            switch b {
            case .taiLieu(let d):
                #if os(iOS)
                switch d {
                case let .pdf(u, ten): NavigationStack { XemPdfView(duong: u, tieuDe: ten) }
                case .web(let u): KhungSafari(duong: u).ignoresSafeArea()
                case .tep(let u): XemTepNhanh(url: u).ignoresSafeArea()
                }
                #endif
            case .muaPro:
                #if os(iOS)
                MuaProView()
                #endif
            }
        }
        .task {
            if viewModel.course == nil { await viewModel.loadCourseDetail(slug: slug) }
            if !daMoSan, let id = moBaiId, let b = CayBai.phang(viewModel.chuong).first(where: { $0.id == id }),
               viewModel.moDuoc(b) {
                daMoSan = true
                baiDangMo = b
            }
        }
        // Quay về từ màn học ⇒ dấu tích + vòng tiến độ phải đúng ngay.
        .onChange(of: baiDangMo) { _, moi in
            if moi == nil { Task { await viewModel.taiTienDo() } }
        }
        .onChange(of: appState.currentUser?.isPro) { _, _ in
            Task { await viewModel.loadCourseDetail(slug: slug) }
        }
    }

    // MARK: Đầu trang

    private func dauTrang(_ c: CourseDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                if let ma = c.courseCode, !ma.isEmpty {
                    Text(ma).font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppColors.onPrimary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(AppColors.brandGradient))
                }
                if let ky = c.semesterName { the(ky, mau: AppColors.secondary) }
                if let cd = c.nhanCapDo, c.courseCode == nil { the(cd, mau: AppColors.secondary) }
                if viewModel.laMienPhi { the(T("Miễn phí"), mau: AppColors.success) }
                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(c.title.theoApp)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let kia = c.title.veKiaTheoApp {
                        Text(kia).font(.bodySmall).foregroundColor(AppColors.textTertiary)
                    }
                }
                Spacer(minLength: 0)
                if viewModel.tongSoBai > 0, viewModel.coToanQuyen, appState.currentUser != nil {
                    VongTienDo(tiLe: Double(viewModel.soXong) / Double(max(viewModel.tongSoBai, 1)))
                }
            }

            hangThongSo(c)

            if let gv = c.instructorName ?? c.instructor?.name {
                HStack(spacing: Spacing.sm) {
                    UserAvatarView(url: c.instructorAvatar ?? c.instructor?.avatarUrl, size: 28)
                    Text(gv).font(.buttonSmall).foregroundColor(AppColors.textPrimary)
                    Text("· " + T("Giảng viên")).font(.caption).foregroundColor(AppColors.textTertiary)
                }
            }

            nutChinh
        }
        .padding(Spacing.md)
        .background(
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous).fill(AppColors.backgroundCard)
                anhBia(c)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
            .stroke(AppColors.primary.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .padding(.top, Spacing.sm)
    }

    /// Ảnh bìa mờ ở góc — có thì đẹp, không có không sao (phần lớn môn chưa có ảnh riêng).
    @ViewBuilder
    private func anhBia(_ c: CourseDetail) -> some View {
        #if canImport(Kingfisher)
        if let t = c.thumbnailUrl, let url = URL(string: t) {
            KFImage(url).resizable().aspectRatio(contentMode: .fill)
                .frame(width: 220, height: 160).clipped()
                .opacity(0.16)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .topTrailing, endPoint: .bottomLeading))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        #endif
    }

    private var nutChinh: some View {
        let tiep = viewModel.baiTiepTheo
        return Button {
            if viewModel.coToanQuyen || tiep?.isFreePreview == true {
                baiDangMo = tiep
            } else {
                bang = .muaPro
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: viewModel.coToanQuyen ? "play.fill" : "lock.open.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text(nhanNutChinh).font(.buttonText)
                    if let t = tiep, viewModel.coToanQuyen || t.isFreePreview == true {
                        Text(t.title.theoApp).font(.caption).opacity(0.85).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
            }
            .padding(.horizontal, Spacing.md).padding(.vertical, 13)
            .foregroundColor(AppColors.onPrimary)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous).fill(AppColors.brandGradient))
        }
        .buttonStyle(.nhan)
        .disabled(tiep == nil && viewModel.coToanQuyen)
    }

    private var nhanNutChinh: String {
        if !viewModel.coToanQuyen {
            return viewModel.baiTiepTheo?.isFreePreview == true ? T("Học thử miễn phí") : T("Mở khoá với Pro")
        }
        if viewModel.soXong == 0 { return T("Bắt đầu học") }
        if viewModel.soXong >= viewModel.tongSoBai { return T("Ôn lại từ đầu") }
        return T("Tiếp tục học")
    }

    /// Hàng thông số — chỉ hiện mục CÓ dữ liệu ("0 học viên · 0.0 sao" thì bỏ).
    private func hangThongSo(_ c: CourseDetail) -> some View {
        let soBai = viewModel.tongSoBai > 0 ? viewModel.tongSoBai : (c.totalLessons ?? 0)
        var muc: [(String, String)] = []
        if soBai > 0 { muc.append(("play.rectangle", String(format: T("%d bài"), soBai))) }
        if viewModel.soChuong > 0 { muc.append(("square.stack", String(format: T("%d chương"), viewModel.soChuong))) }
        if let t = c.nhanThoiLuong { muc.append(("clock", t)) }
        if let hv = c.totalStudents, hv > 0 { muc.append(("person.2", String(format: T("%d học viên"), hv))) }
        if let sao = c.avgRating, sao > 0 { muc.append(("star.fill", String(format: "%.1f", sao))) }
        if viewModel.coToanQuyen, viewModel.tongSoBai > 0, appState.currentUser != nil {
            muc.append(("checkmark.circle", String(format: T("%d/%d đã xong"), viewModel.soXong, viewModel.tongSoBai)))
        }
        return FlowRow(spacing: Spacing.md) {
            ForEach(Array(muc.enumerated()), id: \.offset) { _, m in
                HStack(spacing: 4) {
                    Image(systemName: m.0).font(.system(size: 11))
                    Text(m.1).font(.caption)
                }
                .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    /// Khoá trả phí chưa có quyền: nói rõ vì sao chỉ mở được bài học thử, và mở
    /// khoá bằng Pro trong app (StoreKit — App Store 3.1.1, không link mua ngoài).
    private func theKhoa(_ c: CourseDetail) -> some View {
        let chuaDangNhap = appState.currentUser == nil
        return HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "lock.fill").font(.system(size: 18)).foregroundColor(AppColors.warning)
                .frame(width: 38, height: 38)
                .background(Circle().fill(AppColors.warning.opacity(0.14)))
            VStack(alignment: .leading, spacing: 4) {
                Text(chuaDangNhap ? T("Đăng nhập để học trọn môn") : T("Môn này cần mở khoá"))
                    .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                Text(viewModel.thongDiepKhoa ?? (chuaDangNhap
                    ? T("Bạn đang xem bài học thử. Đăng nhập để mở toàn bộ bài, video và tài liệu.")
                    : T("Bạn đang xem các bài học thử. Thành viên Pro học được mọi môn Academy — video, slide, tài liệu, gia sư CuongMini.")))
                    .font(.bodySmall).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                #if os(iOS)
                if !chuaDangNhap {
                    Button { bang = .muaPro } label: {
                        Label(T("Nâng cấp Pro"), systemImage: "sparkles")
                            .font(.buttonSmall).foregroundColor(AppColors.onPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(AppColors.brandGradient))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                #endif
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.warning.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).stroke(AppColors.warning.opacity(0.35), lineWidth: 1))
    }

    @ViewBuilder
    private func gioiThieu(_ c: CourseDetail) -> some View {
        if let mt = c.description ?? c.shortDescription, !mt.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(mt.theoApp)
                    .font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                    .lineSpacing(3)
                    .lineLimit(moRongMoTa ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    withAnimation(.snappy(duration: 0.22)) { moRongMoTa.toggle() }
                } label: {
                    HStack(spacing: 3) {
                        Text(moRongMoTa ? T("Thu gọn") : T("Xem thêm"))
                        Image(systemName: moRongMoTa ? "chevron.up" : "chevron.down").font(.system(size: 10, weight: .semibold))
                    }
                    .font(.buttonSmall).foregroundColor(AppColors.primary)
                }
            }
        }
        danhSachY(T("Bạn sẽ học được gì"), "checkmark.circle.fill",
                  CourseDetail.tachY(c.whatYouLearn), mau: AppColors.success)
        danhSachY(T("Yêu cầu đầu vào"), "info.circle.fill",
                  CourseDetail.tachY(c.requirements), mau: AppColors.secondary)
    }

    @ViewBuilder
    private func danhSachY(_ tieuDe: String, _ bieuTuong: String, _ ds: [String], mau: Color) -> some View {
        if !ds.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                tieuDeMuc(tieuDe, bieuTuong)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(Array(ds.enumerated()), id: \.offset) { _, y in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: bieuTuong).font(.system(size: 13)).foregroundColor(mau).padding(.top, 2)
                            Text(y.theoApp).font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.backgroundCard))
            }
        }
    }

    private func tieuDeMuc(_ chu: String, _ bieuTuong: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: bieuTuong).font(.system(size: 14)).foregroundColor(AppColors.primary)
            Text(chu).font(.titleMedium).foregroundColor(AppColors.textPrimary)
        }
    }

    private func the(_ chu: String, mau: Color) -> some View {
        Text(chu)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(mau)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(mau.opacity(0.14))
            .clipShape(Capsule())
    }

    // MARK: Nội dung môn

    private var noiDungMon: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                tieuDeMuc(T("Nội dung môn học"), "list.bullet.rectangle")
                Spacer()
                if !viewModel.chuong.isEmpty {
                    Button(moChuong.count == viewModel.chuong.count ? T("Thu hết") : T("Mở hết")) {
                        withAnimation(.snappy(duration: 0.22)) {
                            moChuong = moChuong.count == viewModel.chuong.count ? [] : Set(viewModel.chuong.map(\.id))
                        }
                    }
                    .font(.buttonSmall).foregroundColor(AppColors.primary)
                }
            }
            if viewModel.chuong.isEmpty {
                Text(viewModel.loiMucLuc ?? T("Môn này chưa có bài nào."))
                    .font(.bodyMedium).foregroundColor(AppColors.textSecondary)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
            } else {
                ForEach(Array(viewModel.chuong.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }.enumerated()), id: \.element.id) { i, ch in
                    CourseSectionRow(
                        section: ch,
                        thuTu: i,
                        moRong: Binding(get: { moChuong.contains(ch.id) },
                                        set: { if $0 { moChuong.insert(ch.id) } else { moChuong.remove(ch.id) } }),
                        daXong: viewModel.daXong,
                        dangHoc: viewModel.baiTiepTheo?.id,
                        moDuoc: viewModel.moDuoc,
                        chonBai: { bai in
                            if viewModel.moDuoc(bai) { baiDangMo = bai } else { bang = .muaPro }
                        })
                }
            }
        }
        .onChange(of: viewModel.chuong.map(\.id), initial: true) { _, _ in
            // Mở sẵn chương đang học — người học vào là thấy ngay bài kế tiếp.
            if moChuong.isEmpty, let id = viewModel.baiTiepTheo?.sectionId ?? viewModel.chuongCua(viewModel.baiTiepTheo)?.id {
                moChuong = [id]
            }
        }
    }

    private var khungXuong: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SkeletonBox(height: 200, radius: CornerRadius.xl)
            SkeletonBox(height: 14); SkeletonBox(height: 14, width: 220)
            ForEach(0..<5, id: \.self) { _ in SkeletonBox(height: 58, radius: CornerRadius.large) }
        }
        .padding(.top, Spacing.sm)
    }
}

// MARK: - Một chương

struct CourseSectionRow: View {
    let section: CourseSection
    var thuTu: Int = 0
    @Binding var moRong: Bool
    var daXong: Set<Int> = []
    var dangHoc: Int?
    var moDuoc: (CourseLesson) -> Bool = { _ in true }
    var chonBai: ((CourseLesson) -> Void)?

    private var dsBai: [CourseLesson] {
        (section.lessons ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }
    private var soXong: Int { dsBai.filter { daXong.contains($0.id) }.count }
    private var loai: LoaiChuong { LoaiChuong.cua(section.title) }

    private var mauNhan: Color {
        switch loai {
        case .chuyenSau: return AppColors.warning
        case .thi: return AppColors.error
        case .onThi: return AppColors.info
        case .thuong: return AppColors.primary
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.cham()
                withAnimation(.snappy(duration: 0.2)) { moRong.toggle() }
            } label: {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle().fill(mauNhan.opacity(0.14))
                        if soXong == dsBai.count && !dsBai.isEmpty {
                            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(AppColors.success)
                        } else if loai == .chuyenSau {
                            Text("⭐").font(.system(size: 14))
                        } else {
                            Text("\(thuTu)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(mauNhan)
                        }
                    }
                    .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        if loai != .thuong {
                            Text(loai == .chuyenSau ? T("CHUYÊN SÂU · NGOÀI GIÁO TRÌNH") : loai == .thi ? T("THI") : T("ÔN THI"))
                                .font(.system(size: 9.5, weight: .heavy)).tracking(0.5).foregroundColor(mauNhan)
                        }
                        Text(section.title.theoApp.replacingOccurrences(of: "⭐ ", with: ""))
                            .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Spacing.sm) {
                            Text(String(format: T("%d bài"), dsBai.count))
                            if let t = thoiLuong { Text("· \(t)") }
                            if soXong > 0 {
                                Text("· " + String(format: T("%d xong"), soXong)).foregroundColor(AppColors.success)
                            }
                        }
                        .font(.caption).foregroundColor(AppColors.textTertiary)
                        if soXong > 0 {
                            ProgressView(value: Double(soXong), total: Double(max(dsBai.count, 1)))
                                .tint(soXong == dsBai.count ? AppColors.success : mauNhan)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundColor(AppColors.textTertiary)
                        .rotationEffect(.degrees(moRong ? 180 : 0))
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(moRong ? T("Thu gọn chương") : T("Mở chương"))

            if moRong {
                VStack(spacing: 0) {
                    ForEach(dsBai) { bai in
                        Divider().padding(.leading, 60)
                        Button { chonBai?(bai) } label: { hangBai(bai) }
                            .buttonStyle(.plain)
                            .disabled(chonBai == nil)
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            .fill(loai == .chuyenSau ? AppColors.warning.opacity(0.06) : AppColors.backgroundCard))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            .stroke(loai == .chuyenSau ? AppColors.warning.opacity(0.4) : AppColors.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private var thoiLuong: String? {
        let g = dsBai.reduce(0) { $0 + ($1.videoDurationSeconds ?? 0) }
        guard g > 60 else { return nil }
        let h = g / 3600, m = (g % 3600) / 60
        return h > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(m) " + T("phút")
    }

    private func hangBai(_ bai: CourseLesson) -> some View {
        let xong = daXong.contains(bai.id)
        let mo = moDuoc(bai)
        let dang = dangHoc == bai.id
        return HStack(spacing: Spacing.sm) {
            Image(systemName: xong ? "checkmark.circle.fill" : (mo ? bai.loai.bieuTuong : "lock.fill"))
                .font(.system(size: 16))
                .foregroundColor(xong ? AppColors.success : (mo ? (dang ? AppColors.primary : AppColors.textSecondary) : AppColors.textTertiary))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(bai.title.theoApp)
                    .font(.system(size: 14, weight: dang ? .semibold : .regular))
                    .foregroundColor(mo ? AppColors.textPrimary : AppColors.textTertiary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(T(bai.loai.nhan))
                    if let t = bai.thoiLuong { Text("· \(t)") }
                    if bai.isFreePreview == true, mo, !xong, chiHocThu {
                        Text("· " + T("Học thử")).foregroundColor(AppColors.success)
                    }
                    if dang { Text("· " + T("Học tiếp")).foregroundColor(AppColors.primary) }
                }
                .font(.caption).foregroundColor(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
            if mo { Image(systemName: "chevron.right").font(.caption2).foregroundColor(AppColors.textTertiary) }
        }
        .padding(.vertical, 10)
        .padding(.leading, Spacing.md + 8)
        .padding(.trailing, Spacing.md)
        .background(dang ? AppColors.primary.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Có bài bị khoá trong chương ⇒ đáng gắn nhãn "Học thử" cho bài mở được.
    private var chiHocThu: Bool { dsBai.contains { !moDuoc($0) } }
}

// MARK: - ViewModel

@MainActor
final class CourseDetailViewModel: ObservableObject {
    @Published var course: CourseDetail?
    @Published var chuong: [CourseSection] = []
    @Published var daXong: Set<Int> = []
    @Published var taiLieuKhoa: [TaiLieuBai] = []
    @Published var isLoading = false
    @Published var error: String?
    /// Lời của máy chủ khi mục lục bị chặn (402) — hiện nguyên văn trên thẻ khoá.
    @Published var thongDiepKhoa: String?
    @Published var loiMucLuc: String?

    /// Có quyền xem TRỌN môn (`hasPaidAccess`): miễn phí + đã đăng nhập, Pro, đã mua, mã kích hoạt, admin.
    var coToanQuyen: Bool { course?.hasPaidAccess == true }
    var laMienPhi: Bool { course?.accessType == "FREE" || (course?.isFree == true && (course?.price ?? 0) <= 0) }

    func moDuoc(_ b: CourseLesson) -> Bool { coToanQuyen || b.isFreePreview == true }

    var tongSoBai: Int { chuong.reduce(0) { $0 + ($1.lessons?.count ?? 0) } }
    var soChuong: Int { chuong.count }
    var soXong: Int {
        let ids = Set(CayBai.phang(chuong).map(\.id))
        return daXong.intersection(ids).count
    }
    var phanTram: Int { tongSoBai > 0 ? Int(Double(soXong) / Double(tongSoBai) * 100) : 0 }
    var daGhiDanh: Bool { course?.isEnrolled == true }

    /// "Tiếp tục học": bài kế tiếp chưa xong mà mở được.
    var baiTiepTheo: CourseLesson? { CayBai.baiTiep(chuong, daXong: daXong, moDuoc: moDuoc) }

    func chuongCua(_ b: CourseLesson?) -> CourseSection? {
        guard let b else { return nil }
        return chuong.first { ($0.lessons ?? []).contains { $0.id == b.id } }
    }

    func loadCourseDetail(slug: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let ct: CourseDetail
        do {
            ct = try await APIClient.shared.request(.hocBai(.khoaGon(slug: slug)))
        } catch {
            // Bản gọn hỏng (máy chủ cũ, bản ngoại tuyến chỉ có gói đầy đủ) ⇒ gói đầy đủ.
            do {
                ct = try await APIClient.shared.request(.getCourseDetail(slug: slug))
            } catch let e {
                if course == nil { self.error = e.localizedDescription }
                return
            }
        }
        course = ct
        thongDiepKhoa = nil
        loiMucLuc = nil

        var ds = ct.sections ?? []
        if ds.isEmpty {
            do {
                let r: (items: [CourseSection], nextCursor: Int?, hasMore: Bool) =
                    try await APIClient.shared.requestList(.getCurriculum(courseId: ct.id))
                ds = r.items
            } catch {
                // 402 = khoá trả phí chưa có quyền. Nói ra, đừng hiện "chưa có bài".
                thongDiepKhoa = error.localizedDescription
                loiMucLuc = error.localizedDescription
            }
        }
        chuong = ds

        async let a: Void = taiTienDo()
        async let b: Void = taiTaiLieuKhoa()
        _ = await (a, b)
    }

    func taiTienDo() async {
        guard let id = course?.id else { return }
        do {
            let ds: (items: [LessonProgress], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getCourseProgress(courseId: id))
            daXong = Set(ds.items.filter(\.isCompleted).map(\.lessonId))
        } catch {
            // Chưa đăng nhập (401) — bình thường.
        }
    }

    private func taiTaiLieuKhoa() async {
        guard let id = course?.id, coToanQuyen else { taiLieuKhoa = []; return }
        taiLieuKhoa = (try? await APIClient.shared.requestList(.hocBai(.taiLieuKhoa(courseId: id))).items) ?? []
    }
}

// MARK: - Khoá của tôi

/// `GET /courses/my` — bản ghi ghi danh có sẵn % tiến độ và bài học dở gần nhất.
/// Trước 22/10/2026 màn này lọc `/courses?page=1&size=50` theo `isEnrolled` —
/// đường đó KHÔNG trả môn Academy, nên môn đang học ở Academy biến mất khỏi đây.
struct MyCoursesView: View {
    @StateObject private var viewModel = MyCoursesViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                if viewModel.isLoading && viewModel.ds.isEmpty {
                    ForEach(0..<4, id: \.self) { _ in SkeletonBox(height: 84, radius: CornerRadius.large) }
                } else if let loi = viewModel.error, viewModel.ds.isEmpty {
                    ErrorStateView(message: loi) { Task { await viewModel.tai() } }
                } else if viewModel.ds.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "book.closed").font(.system(size: 52)).foregroundColor(AppColors.textTertiary)
                        Text(T("Bạn chưa học môn nào")).font(.titleMedium).foregroundColor(AppColors.textPrimary)
                        Text(T("Mở Academy, chọn một môn và bấm Bắt đầu học.")).font(.bodyMedium)
                            .foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.xxl)
                } else {
                    ForEach(viewModel.ds) { gd in
                        NavigationLink {
                            CourseDetailView(slug: gd.courseSlug, moBaiId: gd.daXong ? nil : gd.lastLessonId)
                        } label: { TheDangHoc(gd: gd, rong: true) }
                        .buttonStyle(.nhan)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Khoá học của tôi"))
        .refreshable { await viewModel.tai() }
        .task { if viewModel.ds.isEmpty { await viewModel.tai() } }
    }
}

/// Thẻ một môn đang học: mã · % · bài dở gần nhất.
struct TheDangHoc: View {
    let gd: Enrollment
    var rong = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            VongTienDo(tiLe: Double(gd.progressPercent ?? 0) / 100, co: 46, net: 5)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let ma = gd.courseCode {
                        Text(ma).font(.system(size: 11, weight: .heavy, design: .monospaced)).foregroundColor(AppColors.primary)
                    }
                    Text(T(gd.nhanTrangThai)).font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(gd.daXong ? AppColors.success : AppColors.textTertiary)
                }
                Text(gd.courseTitle.theoApp).font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                if let t = gd.lastLessonTitle, !gd.daXong {
                    Label(t.theoApp, systemImage: "play.circle").font(.caption)
                        .foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.md)
        .frame(width: rong ? nil : 290, alignment: .leading)
        .frame(maxWidth: rong ? .infinity : nil, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).fill(AppColors.backgroundCard))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous).stroke(AppColors.border, lineWidth: 1))
    }
}

@MainActor
final class MyCoursesViewModel: ObservableObject {
    @Published var ds: [Enrollment] = []
    @Published var isLoading = false
    @Published var error: String?

    /// Giữ tên cũ cho chỗ gọi còn sót.
    var enrolledCourses: [Enrollment] { ds }

    func tai() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let r: (items: [Enrollment], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getMyCourses)
            // Đang học lên trước, xong xuống dưới; cùng nhóm thì học gần nhất lên trên.
            ds = r.items.sorted {
                if $0.daXong != $1.daXong { return !$0.daXong }
                return ($0.lastAccessedAt ?? "") > ($1.lastAccessedAt ?? "")
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadEnrolledCourses() async { await tai() }
}
