import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Courses View
struct CoursesView: View {
    @StateObject private var viewModel = CoursesViewModel()
    @State private var searchQuery = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    searchBar
                    // ⚠️ MỌI thẻ lối vào chỉ nhận lề từ `.padding(Spacing.md)`
                    // của VStack này. ĐỪNG thêm `.padding(.horizontal, …)` vào
                    // riêng thẻ nào, và cũng đừng kéo ngược bằng số ÂM.
                    //
                    // 22/08/2026 làm đúng cả hai việc đó cùng lúc: ba thẻ cũ tự
                    // thêm +16 bên trong, còn ngoài này rải -16 cho ba thẻ
                    // (không phải cùng ba thẻ đó) ⇒ lề thật thành 0 · 16 · 32,
                    // năm thẻ ba bề rộng. Người dùng nhìn ảnh là thấy ngay.
                    //
                    // Academy đặt NGAY dưới ô tìm kiếm, thành một nhánh riêng
                    // có viền — không trộn vào lưới khoá bên dưới. Hai thứ
                    // khác mục đích: một bên là chương trình đại học theo kỳ,
                    // một bên là khoá chọn học tuỳ ý.
                    AcademyEntryCard()

                    NgoaiNguEntryCard()

                    PhongThiEntryCard()

                    // Code Lab: kho lớn nhất của nền tảng (12.549 bài tập) mà
                    // app chưa hề mở. Đặt cạnh Phòng thi vì cùng là "luyện",
                    // khác với Academy/Ngoại ngữ là "học".
                    CodeLabEntryCard()

                    // Bộ sách 25 tập: 412 chương, 809.780 từ, song ngữ Anh–Việt
                    // phủ 100%. Đọc trên điện thoại hợp hơn hẳn — sách dài,
                    // người ta đọc lúc nằm chứ không ngồi trước máy.
                    SachEntryCard()

                    // Mẩu mã: 48/51 mẩu là hướng dẫn cài môi trường bằng
                    // TIẾNG VIỆT kèm lệnh chép được — thứ người ta tra trên
                    // điện thoại đúng lúc đang dựng máy, không phải lúc ngồi
                    // trước máy tính.
                    LoTrinhNgheEntryCard()
                    DuAnEntryCard()
                    PhongVanEntryCard()
                    ThuatToanEntryCard()
                    MoPhongEntryCard()
                    CVEntryCard()
                    SnippetEntryCard()

                    tieuDeNhanh("Khoá tự biên soạn", "sparkles")
                    categoriesSection
                    featuredCoursesSection
                    allCoursesSection
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Khóa học")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: MyCoursesView()) {
                        Image(systemName: "book.closed")
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadCourses()
                }
            }
            .refreshable {
                await viewModel.loadCourses()
            }
        }
    }

    /// Nhãn phân nhánh, để người dùng thấy rõ phần dưới KHÔNG phải Academy.
    private func tieuDeNhanh(_ chu: String, _ bieuTuong: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: bieuTuong)
                .font(.system(size: 13))
                .foregroundColor(AppColors.primary)
            Text(chu)
                .font(.titleSmall)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
        }
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)

            TextField("Tìm kiếm khóa học", text: $searchQuery)
                .foregroundColor(AppColors.textPrimary)
                .onSubmit {
                    Task {
                        await viewModel.searchCourses(query: searchQuery)
                    }
                }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.medium)
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Danh mục")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(viewModel.categories, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            viewModel.selectedCategory = category
                        }
                    }
                }
            }
        }
    }

    private var featuredCoursesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Khóa học nổi bật")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(viewModel.featuredCourses) { course in
                        NavigationLink(destination: CourseDetailView(slug: course.slug)) {
                            FeaturedCourseCard(course: course)
                        }
                    }
                }
            }
        }
    }

    private var allCoursesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                sectionHeader("Tất cả khóa học")

                Spacer()

                Menu {
                    Button("Mới nhất") { viewModel.sortBy = .newest }
                    Button("Phổ biến nhất") { viewModel.sortBy = .popular }
                } label: {
                    HStack(spacing: 4) {
                        Text("Sắp xếp")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.primary)
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            } else if viewModel.courses.isEmpty {
                emptyCoursesView
            } else {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(viewModel.courses) { course in
                        NavigationLink(destination: CourseDetailView(slug: course.slug)) {
                            CourseRow(course: course)
                        }
                    }

                    if viewModel.hasMore {
                        ProgressView()
                            .padding()
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreCourses()
                                }
                            }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.titleMedium)
            .foregroundColor(AppColors.textPrimary)
    }

    private var emptyCoursesView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(AppColors.textTertiary)

            Text("Không có khóa học nào")
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)

            Text("Thử tìm kiếm với từ khóa khác")
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(category)
                .font(.buttonSmall)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? AppColors.primary : AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.full)
        }
    }
}

// MARK: - Featured Course Card
struct FeaturedCourseCard: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Thumbnail
            ZStack(alignment: .topTrailing) {
                #if canImport(Kingfisher)
                if let thumbnail = course.thumbnailUrl, let url = URL(string: thumbnail) {
                    KFImage(url)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 220, height: 130)
                        .clipped()
                } else {
                    courseThumbnailPlaceholder
                }
                #else
                courseThumbnailPlaceholder
                #endif

                // Price badge
                if !course.isFree {
                    Text(course.isEnrolled == true ? "Đã ghi danh" : formatPrice(course.discountPrice ?? course.price))
                        .font(.captionBold)
                        .foregroundColor(AppColors.onPrimary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 4)
                        .background(course.isEnrolled == true ? AppColors.success : AppColors.primary)
                        .cornerRadius(CornerRadius.small)
                        .padding(Spacing.sm)
                }
            }
            .cornerRadius(CornerRadius.medium)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                if let instructor = course.instructor {
                    Text(instructor.name)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                HStack(spacing: Spacing.sm) {
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppColors.warning)
                        Text(String(format: "%.1f", course.avgRating ?? 0))
                    }
                    .font(.caption)

                    Text("(\(course.totalStudents))")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    // Price
                    if course.isFree {
                        Text("Miễn phí")
                            .font(.buttonSmall)
                            .foregroundColor(AppColors.success)
                    } else if let discount = course.discountPrice {
                        HStack(spacing: 4) {
                            Text(formatPrice(course.price))
                                .strikethrough()
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                            Text(formatPrice(discount))
                                .font(.buttonSmall)
                                .foregroundColor(AppColors.primary)
                        }
                    } else {
                        Text(formatPrice(course.price))
                            .font(.buttonSmall)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
        .frame(width: 220)
    }

    private var courseThumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundTertiary)
            .frame(width: 220, height: 130)
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.textTertiary)
            )
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: NSNumber(value: price)) ?? "\(Int(price))đ"
    }
}

// MARK: - Course Row
struct CourseRow: View {
    let course: Course

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Thumbnail
            #if canImport(Kingfisher)
            if let thumbnail = course.thumbnailUrl, let url = URL(string: thumbnail) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 70)
                    .cornerRadius(CornerRadius.small)
            } else {
                courseRowPlaceholder
            }
            #else
            courseRowPlaceholder
            #endif

            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                if let instructor = course.instructor {
                    Text(instructor.name)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                HStack(spacing: Spacing.sm) {
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppColors.warning)
                        Text(String(format: "%.1f", course.avgRating ?? 0))
                    }
                    .font(.caption)

                    Text("•")
                        .foregroundColor(AppColors.textTertiary)

                    Text("\(course.totalStudents) học viên")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                HStack(spacing: Spacing.sm) {
                    // Level badge
                    Text(course.level)
                        .font(.caption)
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(AppColors.primary.opacity(0.1))
                        .cornerRadius(CornerRadius.small)

                    if let lessons = course.totalLessons {
                        Text("\(lessons) bài học")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            Spacer()

            // Price & CTA
            VStack(alignment: .trailing, spacing: 4) {
                if course.isFree {
                    Text("Miễn phí")
                        .font(.buttonSmall)
                        .foregroundColor(AppColors.success)
                } else if let discount = course.discountPrice {
                    Text(formatPrice(discount))
                        .font(.titleSmall)
                        .foregroundColor(AppColors.primary)
                } else {
                    Text(formatPrice(course.price))
                        .font(.titleSmall)
                        .foregroundColor(AppColors.primary)
                }

                if course.isEnrolled == true {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
    }

    private var courseRowPlaceholder: some View {
        RoundedRectangle(cornerRadius: CornerRadius.small)
            .fill(AppColors.backgroundTertiary)
            .frame(width: 100, height: 70)
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(AppColors.textTertiary)
            )
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: NSNumber(value: price)) ?? "\(Int(price))đ"
    }
}

// MARK: - Course Detail View
struct CourseDetailView: View {
    let slug: String
    @StateObject private var viewModel = CourseDetailViewModel()
    @State private var baiDangMo: CourseLesson?
    @State private var moRongMoTa = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, Spacing.xxl)
                } else if let course = viewModel.course {
                    courseHeader(course)
                    khoiHanhDong(course)
                    courseContent(course)
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        // Nút tải về NẰM Ở ĐÂY, trên chính màn khoá học. Tính năng ngoại
        // tuyến mà chôn trong Cài đặt thì không ai tìm ra — cùng bài học với
        // ô tích nợ và nút đổi giọng IELTS.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let c = viewModel.course {
                    NutTaiVeHoc(id: c.id, slug: slug, ten: c.title)
                }
            }
        }
        .navigationDestination(item: $baiDangMo) { bai in
            if let ct = viewModel.course {
                LessonPlayerView(
                    course: Course(from: ct),
                    sections: viewModel.chuong,
                    lessonId: bai.id,
                )
            }
        }
        .task { await viewModel.loadCourseDetail(slug: slug) }
    }

    /// Thanh tiến độ + nút chính. Chưa ghi danh thì mời ghi danh; ghi danh rồi
    /// thì nhảy thẳng vào bài dở dang gần nhất.
    @ViewBuilder
    private func khoiHanhDong(_ course: CourseDetail) -> some View {
        VStack(spacing: Spacing.sm) {
            if viewModel.daGhiDanh && viewModel.tongSoBai > 0 {
                VStack(spacing: 6) {
                    HStack {
                        Text("\(viewModel.daXong.count)/\(viewModel.tongSoBai) bài")
                        Spacer()
                        Text("\(viewModel.phanTram)%")
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                    ProgressView(value: Double(viewModel.daXong.count),
                                 total: Double(max(viewModel.tongSoBai, 1)))
                        .tint(AppColors.primary)
                }
            }

            Button {
                if viewModel.daGhiDanh {
                    baiDangMo = viewModel.baiTiepTheo
                } else {
                    Task { await viewModel.ghiDanh() }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    if viewModel.dangGhiDanh {
                        ProgressView().tint(AppColors.onPrimary)
                    } else {
                        Image(systemName: viewModel.daGhiDanh ? "play.fill" : "plus.circle")
                    }
                    Text(nhanNutChinh)
                        .font(.buttonText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(AppColors.brandGradient)
                .foregroundColor(AppColors.onPrimary)
                .cornerRadius(CornerRadius.medium)
            }
            .disabled(viewModel.dangGhiDanh || (viewModel.daGhiDanh && viewModel.baiTiepTheo == nil))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    private var nhanNutChinh: String {
        if !viewModel.daGhiDanh { return "Ghi danh học" }
        return viewModel.daXong.isEmpty ? "Bắt đầu học" : "Học tiếp"
    }

    private func courseHeader(_ course: CourseDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            anhBia(course)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Danh mục + cấp độ: hai mẩu nhỏ đặt TRƯỚC tiêu đề, để người
                // đọc biết ngay "đây là khoá gì, cho ai" trong nửa giây.
                HStack(spacing: Spacing.sm) {
                    if let dm = course.categoryName { the(dm, mau: AppColors.primary) }
                    if let cd = course.nhanCapDo { the(cd, mau: AppColors.secondary) }
                    if course.isFree == true { the("Miễn phí", mau: AppColors.success) }
                    Spacer(minLength: 0)
                }

                Text(course.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                hangThongSo(course)

                if let gv = course.instructor {
                    HStack(spacing: Spacing.sm) {
                        UserAvatarView(url: gv.avatarUrl, size: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(gv.name)
                                .font(.buttonSmall)
                                .foregroundColor(AppColors.textPrimary)
                            Text("Giảng viên")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private func anhBia(_ course: CourseDetail) -> some View {
        #if canImport(Kingfisher)
        if let thumbnail = course.thumbnailUrl, let url = URL(string: thumbnail) {
            KFImage(url)
                .resizable()
                .aspectRatio(16 / 9, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                // Vệt tối ở đáy để ảnh bìa không đâm thẳng vào chữ bên dưới.
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, AppColors.backgroundPrimary.opacity(0.9)],
                        startPoint: .top, endPoint: .bottom,
                    )
                    .frame(height: 60)
                }
        }
        #endif
    }

    private func the(_ chu: String, mau: Color) -> some View {
        Text(chu)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(mau)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(mau.opacity(0.14))
            .clipShape(Capsule())
    }

    /// Hàng thông số: số bài · thời lượng · ngôn ngữ · học viên · đánh giá.
    /// Chỉ hiện những mục CÓ dữ liệu — khoá mới chưa ai học thì không việc gì
    /// phải khoe "0 học viên · 0.0 sao".
    private func hangThongSo(_ course: CourseDetail) -> some View {
        let soBai = course.totalLessons ?? viewModel.tongSoBai
        var muc: [(String, String)] = []
        if soBai > 0 { muc.append(("play.rectangle", "\(soBai) bài")) }
        if let t = course.nhanThoiLuong { muc.append(("clock", t)) }
        if let ng = course.language { muc.append(("globe", ng == "Vietnamese" ? "Tiếng Việt" : ng)) }
        if let hv = course.totalStudents, hv > 0 { muc.append(("person.2", "\(hv) học viên")) }
        if let sao = course.avgRating, sao > 0 {
            muc.append(("star.fill", String(format: "%.1f", sao)))
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

    private func courseContent(_ course: CourseDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if let mt = course.description, !mt.isEmpty {
                khoiMoTa(mt)
            }

            danhSachY("Bạn sẽ học được gì", "checkmark.circle.fill",
                      CourseDetail.tachY(course.whatYouLearn), mau: AppColors.success)

            danhSachY("Yêu cầu đầu vào", "info.circle.fill",
                      CourseDetail.tachY(course.requirements), mau: AppColors.secondary)

            danhSachY("Tài liệu tham khảo", "book.fill",
                      CourseDetail.tachY(course.documentsNote), mau: AppColors.primary)

            // Nội dung khoá học
            VStack(alignment: .leading, spacing: Spacing.sm) {
                tieuDeMuc("Nội dung khoá học", "list.bullet")

                if viewModel.chuong.isEmpty {
                    Text("Khoá học này chưa có bài nào.")
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, Spacing.md)
                } else {
                    ForEach(viewModel.chuong.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }) { chuong in
                        CourseSectionRow(
                            section: chuong,
                            daXong: viewModel.daXong,
                            chonBai: { bai in baiDangMo = bai },
                        )
                    }
                }
            }

            // Đánh giá
            if let reviews = course.reviews, !reviews.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    tieuDeMuc("Đánh giá", "star.fill")
                    ForEach(reviews.prefix(3)) { review in
                        ReviewRow(review: review)
                    }
                }
            }
        }
        .padding(.top, Spacing.md)
    }

    /// Mô tả dài thu về 4 dòng, có nút mở rộng.
    ///
    /// Bản cũ đổ nguyên 10 dòng ra màn hình: người đọc chưa kịp biết khoá này
    /// dạy gì đã phải cuộn qua một bức tường chữ, và nút "Bắt đầu học" bị đẩy
    /// xuống tận đáy.
    @ViewBuilder
    private func khoiMoTa(_ chu: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(chu)
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(3)
                .lineLimit(moRongMoTa ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation(.snappy(duration: 0.22)) { moRongMoTa.toggle() }
            } label: {
                HStack(spacing: 3) {
                    Text(moRongMoTa ? "Thu gọn" : "Xem thêm")
                    Image(systemName: moRongMoTa ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.buttonSmall)
                .foregroundColor(AppColors.primary)
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    @ViewBuilder
    private func danhSachY(_ tieuDe: String, _ bieuTuong: String,
                           _ ds: [String], mau: Color) -> some View {
        if !ds.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                tieuDeMuc(tieuDe, bieuTuong)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(Array(ds.enumerated()), id: \.offset) { _, y in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: bieuTuong)
                                .font(.system(size: 13))
                                .foregroundColor(mau)
                                .padding(.top, 2)
                            Text(y)
                                .font(.bodyMedium)
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(Spacing.md)
                .background(AppColors.backgroundSecondary)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    private func tieuDeMuc(_ chu: String, _ bieuTuong: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: bieuTuong)
                .font(.system(size: 14))
                .foregroundColor(AppColors.primary)
            Text(chu)
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Hàng tự xuống dòng
//
// `HStack` không tự ngắt dòng, nên hàng thông số dài sẽ tràn ra ngoài màn hình
// và bị cắt cụt. `Layout` tự xếp: hết chỗ thì xuống hàng.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rong = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, caoHang: CGFloat = 0
        for o in subviews {
            let s = o.sizeThatFits(.unspecified)
            if x > 0, x + s.width > rong {
                x = 0; y += caoHang + spacing; caoHang = 0
            }
            x += s.width + spacing
            caoHang = max(caoHang, s.height)
        }
        return CGSize(width: rong == .infinity ? x : rong, height: y + caoHang)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, caoHang: CGFloat = 0
        for o in subviews {
            let s = o.sizeThatFits(.unspecified)
            if x > bounds.minX, x + s.width > bounds.maxX {
                x = bounds.minX; y += caoHang + spacing; caoHang = 0
            }
            o.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            caoHang = max(caoHang, s.height)
        }
    }
}

// MARK: - Course Section Row
struct CourseSectionRow: View {
    let section: CourseSection
    /// Đã hoàn thành những bài nào — để vẽ dấu tích.
    var daXong: Set<Int> = []
    /// Bấm vào một bài. Nil = chỉ xem, không mở được (chưa ghi danh).
    var chonBai: ((CourseLesson) -> Void)?

    @State private var moRong = false

    private var dsBai: [CourseLesson] {
        (section.lessons ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }

    private var soXong: Int { dsBai.filter { daXong.contains($0.id) }.count }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { moRong.toggle() }
            } label: {
                HStack {
                    Image(systemName: moRong ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title.songNguTheoMay)
                            .font(.titleSmall)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                        if soXong > 0 {
                            Text("\(soXong)/\(dsBai.count) bài đã xong")
                                .font(.caption)
                                .foregroundColor(AppColors.success)
                        }
                    }

                    Spacer()

                    Text("\(dsBai.count) bài")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(Spacing.md)
                .background(AppColors.backgroundCard)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if moRong {
                VStack(spacing: 0) {
                    ForEach(dsBai) { bai in
                        Button {
                            chonBai?(bai)
                        } label: {
                            hangBai(bai)
                        }
                        .buttonStyle(.plain)
                        .disabled(chonBai == nil)
                    }
                }
            }
        }
        .cornerRadius(CornerRadius.medium)
        .padding(.horizontal, Spacing.md)
    }

    private func hangBai(_ bai: CourseLesson) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: bieuTuong(bai))
                .foregroundColor(daXong.contains(bai.id) ? AppColors.success : AppColors.primary)
                .frame(width: 20)

            Text(bai.title.songNguTheoMay)
                .font(.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: Spacing.sm)

            if bai.laQuiz {
                Text("Kiểm tra")
                    .font(.caption)
                    .foregroundColor(AppColors.warning)
            } else if let t = bai.thoiLuong {
                Text(t)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(Spacing.md)
        .padding(.leading, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundSecondary)
        .contentShape(Rectangle())
    }

    private func bieuTuong(_ bai: CourseLesson) -> String {
        if daXong.contains(bai.id) { return "checkmark.circle.fill" }
        return bai.laQuiz ? "square.and.pencil" : "play.circle"
    }
}

struct ReviewRow: View {
    let review: CourseReview

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            UserAvatarView(url: review.user?.avatarUrl, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(review.user?.name ?? "Anonymous")
                        .font(.titleSmall)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < review.rating ? "star.fill" : "star")
                                .foregroundColor(AppColors.warning)
                                .font(.caption)
                        }
                    }
                }

                if let content = review.content {
                    Text(content)
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                }

                Text(TimeFormatter.formatTimeAgo(review.createdAt))
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - My Courses View
struct MyCoursesView: View {
    @StateObject private var viewModel = MyCoursesViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, Spacing.xxl)
                } else if viewModel.enrolledCourses.isEmpty {
                    emptyStateView
                } else {
                    ForEach(viewModel.enrolledCourses) { course in
                        NavigationLink(destination: CourseDetailView(slug: course.slug)) {
                            CourseRow(course: course)
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Khóa học của tôi")
        .onAppear {
            Task {
                await viewModel.loadEnrolledCourses()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)

            Text("Bạn chưa ghi danh khóa học nào")
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)

            Text("Đăng ký khóa học để bắt đầu học tập")
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.top, Spacing.xxl)
    }
}

// MARK: - Courses View Model
@MainActor
class CoursesViewModel: ObservableObject {
    @Published var courses: [Course] = []

    /// App Store 3.1.1: app KHÔNG bán nội dung số ngoài In-App Purchase. Chỉ
    /// hiện khoá MIỄN PHÍ và khoá người dùng ĐÃ ghi danh (mua trên web — được
    /// dùng theo 3.1.3(b)). Khoá trả phí chưa sở hữu mà hiện ra thì sẽ kèm
    /// giá VND và nút ghi danh trả 402 "mua hoặc nhập mã kích hoạt" — đúng thứ
    /// người duyệt trả về. Đo 24/09/2026: 12/12 khoá công khai đều miễn phí,
    /// nên bộ lọc này hiện chưa bỏ khoá nào; nó chặn trước cho khoá sau này.
    nonisolated static func hienDuoc(_ c: Course) -> Bool {
        c.isFree || c.isEnrolled == true
    }
    @Published var featuredCourses: [Course] = []
    @Published var categories: [String] = ["Tất cả", "Lập trình", "Design", "Marketing", "Kinh doanh", "Nghệ thuật"]
    @Published var selectedCategory = "Tất cả"
    @Published var sortBy: CourseSortOption = .newest
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasMore = true

    private var page = 1

    func loadCourses() async {
        isLoading = true

        do {
            // `/courses` phân trang kiểu page/totalPages, KHÔNG phải con trỏ.
            let response: (items: [Course], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getCourses(page: 1, size: 20, keyword: nil))
            courses = response.items.filter(Self.hienDuoc)
            featuredCourses = Array(courses.prefix(5))
            page = 1
            hasMore = response.items.count >= 20
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreCourses() async {
        guard hasMore, !isLoading else { return }

        do {
            let response: (items: [Course], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getCourses(page: page + 1, size: 20, keyword: nil))
            let daCo = Set(courses.map(\.id))
            courses.append(contentsOf: response.items.filter { !daCo.contains($0.id) && Self.hienDuoc($0) })
            page += 1
            hasMore = !response.items.isEmpty
        } catch {
            self.error = error.localizedDescription
        }
    }

    func searchCourses(query: String) async {
        guard !query.isEmpty else {
            await loadCourses()
            return
        }

        isLoading = true

        do {
            let response: (items: [Course], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getCourses(page: 1, size: 20, keyword: query))
            courses = response.items.filter(Self.hienDuoc)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Course Detail View Model
@MainActor
class CourseDetailViewModel: ObservableObject {
    @Published var course: CourseDetail?
    @Published var chuong: [CourseSection] = []
    @Published var daXong: Set<Int> = []
    @Published var daGhiDanh = false
    @Published var isLoading = false
    @Published var dangGhiDanh = false
    @Published var error: String?

    /// Bài học dở dang gần nhất — để nút "Học tiếp" nhảy đúng chỗ.
    var baiTiepTheo: CourseLesson? {
        let tatCa = chuong
            .sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            .flatMap { ($0.lessons ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) } }
        return tatCa.first { !daXong.contains($0.id) } ?? tatCa.first
    }

    var tongSoBai: Int { chuong.reduce(0) { $0 + ($1.lessons?.count ?? 0) } }
    var phanTram: Int {
        guard tongSoBai > 0 else { return 0 }
        return Int((Double(daXong.count) / Double(tongSoBai)) * 100)
    }

    func loadCourseDetail(slug: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let ct: CourseDetail = try await APIClient.shared.request(.getCourseDetail(slug: slug))
            course = ct
            daGhiDanh = ct.isEnrolled

            // Mục lục nằm ở đường RIÊNG. `/courses/:slug` không kèm chương —
            // nên trước đây phần "Nội dung khoá học" luôn trống trơn.
            let ds: (items: [CourseSection], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getCurriculum(courseId: ct.id))
            chuong = ds.items

            await taiTienDo(courseId: ct.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func taiTienDo(courseId: Int) async {
        do {
            let ds: (items: [LessonProgress], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getCourseProgress(courseId: courseId))
            daXong = Set(ds.items.filter(\.isCompleted).map(\.lessonId))
        } catch {
            // Chưa ghi danh thì 401/403 — bình thường, không phải lỗi.
        }
    }

    func ghiDanh() async {
        guard let id = course?.id, !dangGhiDanh else { return }
        dangGhiDanh = true
        defer { dangGhiDanh = false }
        do {
            try await APIClient.shared.send(.enrollCourse(id: id))
            daGhiDanh = true
            Haptics.xong()
            await taiTienDo(courseId: id)
        } catch {
            Haptics.hong()
            self.error = error.localizedDescription
        }
    }
}

// MARK: - My Courses View Model
@MainActor
class MyCoursesViewModel: ObservableObject {
    @Published var enrolledCourses: [Course] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadEnrolledCourses() async {
        isLoading = true

        // Would filter courses by enrollment status
        do {
            let response: (items: [Course], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getCourses(page: 1, size: 50, keyword: nil))
            enrolledCourses = response.items.filter { $0.isEnrolled == true }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Supporting Types
enum CourseSortOption {
    case newest
    case popular
    case priceLow
    case priceHigh
}

// CoursesResponse cũ ({courses, hasMore}) đã GỠ: backend trả
// { success, data: [...], pagination: {page, total, totalPages} } — không có
// khoá `courses` lẫn `hasMore` nào, nên nó giải mã HỎNG mọi lần gọi.

#Preview {
    CoursesView()
}
