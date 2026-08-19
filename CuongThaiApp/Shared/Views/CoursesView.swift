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
                    Button("Giá: Thấp đến cao") { viewModel.sortBy = .priceLow }
                    Button("Giá: Cao đến thấp") { viewModel.sortBy = .priceHigh }
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
            // Thumbnail
            #if canImport(Kingfisher)
            if let thumbnail = course.thumbnailUrl, let url = URL(string: thumbnail) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
            }
            #endif

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(course.title)
                    .font(.titleLarge)
                    .foregroundColor(AppColors.textPrimary)

                if let description = course.description {
                    Text(description)
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Instructor
                if let instructor = course.instructor {
                    HStack(spacing: Spacing.md) {
                        UserAvatarView(url: instructor.avatarUrl, size: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Giảng viên")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text(instructor.name)
                                .font(.titleSmall)
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                }

                // Progress
                if course.isEnrolled, let progress = course.progress {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tiến độ: \(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)

                        ProgressView(value: progress)
                            .tint(AppColors.primary)
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    private func courseContent(_ course: CourseDetail) -> some View {
        VStack(spacing: Spacing.md) {
            // Curriculum
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Nội dung khóa học")
                    .font(.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, Spacing.md)

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

            // Reviews
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Đánh giá")
                    .font(.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, Spacing.md)

                if let reviews = course.reviews, !reviews.isEmpty {
                    ForEach(reviews.prefix(3)) { review in
                        ReviewRow(review: review)
                    }
                } else {
                    Text("Chưa có đánh giá nào")
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, Spacing.md)
                }
            }
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
            courses = response.items
            featuredCourses = Array(response.items.prefix(5))
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
            courses.append(contentsOf: response.items.filter { !daCo.contains($0.id) })
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
            courses = response.items
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
