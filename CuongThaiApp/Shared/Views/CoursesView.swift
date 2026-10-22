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

// MARK: - Chi tiết môn / Khoá của tôi
// `CourseDetailView`, `CourseSectionRow`, `MyCoursesView` và hai ViewModel của
// chúng đã CHUYỂN sang `Academy/HocBai/ChiTietMonView.swift` (22/10/2026) —
// tách khỏi tệp này để nhánh sửa phần lối vào ở đầu tệp không giẫm nhau.

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
