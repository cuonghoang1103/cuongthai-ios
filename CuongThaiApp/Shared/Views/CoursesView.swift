import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Courses View
struct CoursesView: View {
    @EnvironmentObject private var appState: AppState
    /// Chương trình đào tạo (thẻ lối vào + màn tổng dùng CHUNG một VM ⇒ mở màn tổng không tải lại từ đầu).
    @StateObject private var chuongTrinh = ChuongTrinhDaoTaoVM()
    @State private var searchQuery = ""
    @State private var moTimKhoa = false

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
                    // có viền. Ngay sau nó là CHƯƠNG TRÌNH ĐÀO TẠO (22/10/2026) —
                    // thay cho "Khoá tự biên soạn" + lưới khoá cũ: hai chương
                    // trình theo kỳ đứng cạnh nhau, một theo giáo trình trường,
                    // một là lộ trình 4 năm của CuongThai.
                    AcademyEntryCard()

                    TheChuongTrinh(vm: chuongTrinh)

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
                }
                .padding(Spacing.md)
            }
            .nenChuDe(tieuDeLon: true)
            // Tiêu đề TRÙNG nhãn tab ("Học") — bản cũ: tab "Học", màn "Khóa học".
            .navigationTitle(T("Học"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Tìm TOÀN CỤC (tính năng + khoá + bài + người) — ô tìm trên
                    // đầu trang chỉ tìm trong chương trình đào tạo.
                    Button { appState.bangGoc = .timKiem } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .accessibilityLabel(T("Tìm kiếm"))
                    NavigationLink(destination: MyCoursesView()) {
                        Image(systemName: "book.closed")
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .accessibilityLabel(T("Khoá học của tôi"))
                }
            }
            // Ô tìm của tab Học ⇒ chế độ "Tất cả" của Chương trình đào tạo, đã điền sẵn từ khoá
            // (tìm không dấu ngay trên máy, gồm cả khoá Sắp ra mắt).
            .navigationDestination(isPresented: $moTimKhoa) {
                ChuongTrinhView(vm: chuongTrinh, cheDo: .tatCa,
                                tuKhoa: searchQuery.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .task { await chuongTrinh.taiNeuCu() }
            .refreshable { await chuongTrinh.tai() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)

            TextField(T("Tìm kiếm khoá học"), text: $searchQuery)
                .foregroundColor(AppColors.textPrimary)
                .submitLabel(.search)
                .onSubmit {
                    guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    moTimKhoa = true
                }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.medium)
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

// MARK: - Khoá tự biên soạn: đã chuyển
// "Khoá tự biên soạn" + lưới khoá (CategoryChip, FeaturedCourseCard, CourseRow, CoursesViewModel)
// đã GỠ 22/10/2026 — thay bằng Chương trình đào tạo (`Shared/ChuongTrinh/`). Luật App Store 3.1.1
// của bộ lọc cũ (`hienDuoc`: chỉ khoá miễn phí hoặc đã sở hữu) sống tiếp ở `MonChuongTrinh.hienDuoc`.

// CoursesResponse cũ ({courses, hasMore}) đã GỠ: backend trả
// { success, data: [...], pagination: {page, total, totalPages} } — không có
// khoá `courses` lẫn `hasMore` nào, nên nó giải mã HỎNG mọi lần gọi.

#Preview {
    CoursesView()
}
