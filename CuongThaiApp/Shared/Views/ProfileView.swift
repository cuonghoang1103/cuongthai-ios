import SwiftUI
import PhotosUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Profile View
struct ProfileView: View {
    /// `nil` = hồ sơ CỦA MÌNH. Có giá trị = hồ sơ người khác.
    ///
    /// ⚠️ Trước đây `UserProfileView` tạo một ProfileViewModel RIÊNG rồi gán
    /// `userId` vào đó, nhưng bên trong lại dựng `ProfileView()` — mà
    /// `ProfileView` tự tạo view model KHÁC. Cái userId kia không ai đọc, nên
    /// bấm vào ai cũng ra hồ sơ của chính mình.
    var userIdKhac: Int? = nil

    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @State private var sheet: ProfileSheet?
    @State private var avatarItem: PhotosPickerItem?
    @State private var coverItem: PhotosPickerItem?

    // MỘT `.sheet(item:)` cho cả hai màn: hai `.sheet(isPresented:)` trên cùng
    // một view thì chỉ cái cuối chạy, cái kia bấm im lặng.
    enum ProfileSheet: String, Identifiable {
        case settings, editProfile
        var id: String { rawValue }
    }

    /// KHÔNG BAO GIỜ vẽ hồ sơ khi chưa có hồ sơ.
    ///
    /// Bản cũ vẽ thẳng `profileHeader` với `?? "User"` / `?? "username"`, nên
    /// mọi lúc dữ liệu chưa về — đang tải, mạng hỏng, token hết hạn — người
    /// dùng thấy một hồ sơ GIẢ đầy đủ nút bấm. Xem `HoSoTrangThaiView.swift`.
    @ViewBuilder private var than: some View {
        if viewModel.profile != nil {
            VStack(spacing: 0) {
                profileHeader
                profileStats
                profileActions
                contentTabs
                noiDungTheoTab
                // Thanh tab là một viên nổi đè lên nội dung. Không chừa chỗ
                // thì mục cuối cùng vĩnh viễn nằm dưới nó, không cuộn tới được.
                Color.clear.frame(height: 96)
            }
        } else if !appState.isAuthenticated && userIdKhac == nil {
            HoSoTrongView(
                bieuTuong: "person.crop.circle",
                tieuDe: T("Đăng nhập để xem hồ sơ"),
                moTa: T("Hồ sơ lưu bài viết, khoá học và tiến độ học của bạn trên mọi thiết bị."),
                nhanNut: T("Đăng nhập"),
                hanhDong: { appState.logout() }
            )
        } else if case .loi(let e) = appState.trangThaiHoSo, userIdKhac == nil {
            HoSoTrongView(
                bieuTuong: "wifi.exclamationmark",
                tieuDe: T("Không tải được hồ sơ"),
                moTa: e,
                nhanNut: T("Thử lại"),
                hanhDong: { Task { await appState.fetchProfile(); await viewModel.loadProfile() } },
                nhanPhu: T("Đăng xuất"),
                hanhDongPhu: { appState.logout() }
            )
        } else if viewModel.error != nil {
            HoSoTrongView(
                bieuTuong: "exclamationmark.triangle",
                tieuDe: T("Không tải được hồ sơ"),
                moTa: viewModel.error ?? "",
                nhanNut: T("Thử lại"),
                hanhDong: { Task { await viewModel.loadProfile() } }
            )
        } else {
            HoSoDangTaiView()
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                than
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Hồ sơ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sheet = .settings
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .sheet(item: $sheet) { which in
                switch which {
                case .settings: SettingsView()
                case .editProfile: NavigationStack { ChinhSuaHoSoView() }
                }
            }
            // Đổi ảnh: chọn xong là tải lên rồi ghi vào hồ sơ ngay, không có
            // bước "Lưu" riêng — người dùng chọn ảnh là đã quyết định rồi.
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task { await viewModel.doiAnh(item, truong: .avatar) }
            }
            .onChange(of: coverItem) { _, item in
                guard let item else { return }
                Task { await viewModel.doiAnh(item, truong: .bia) }
            }
            .alert(T("Không đổi được ảnh"), isPresented: .constant(viewModel.loiDoiAnh != nil)) {
                Button("OK") { viewModel.loiDoiAnh = nil }
            } message: {
                Text(viewModel.loiDoiAnh ?? "")
            }
            // `init()` của ViewModel gọi loadProfile() ngay lập tức, nhưng
            // lúc đó `currentUser` thường CHƯA về (fetchProfile chạy bất đồng
            // bộ sau đăng nhập). Khi đó `if let userId = ...` trong loadProfile
            // trượt, hàm im lặng không làm gì, và màn hình đứng nguyên ở dữ
            // liệu mẫu "User / @username / 0 bài viết". Đặt userId KHÔNG tự
            // nạp lại, nên phải gọi tay.
            .task(id: userIdKhac ?? appState.currentUser?.id) {
                // Hồ sơ người khác thì KHÔNG chờ `currentUser` — người dùng có
                // thể xem hồ sơ người khác ngay cả khi hồ sơ mình chưa về.
                guard let id = userIdKhac ?? appState.currentUser?.id else { return }
                if viewModel.userId != id || viewModel.profile == nil {
                    viewModel.userId = id
                    await viewModel.loadProfile()
                }
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 0) {
            // Cover Photo
            ZStack(alignment: .bottom) {
                // (lớp tối chân ảnh nằm ở overlay bên dưới ZStack này)
                if let coverUrl = viewModel.profile?.coverPhotoUrl,
                   let url = URL(string: coverUrl) {
                    // ⚠️ Ảnh bìa phải vẽ dạng LỚP PHỦ, không được nằm thẳng
                    // trong bố cục.
                    //
                    // `aspectRatio(.fill)` + `frame(height: 180)` TỰ BÁO bề
                    // rộng theo tỉ lệ ảnh: ảnh 1600×600 cao 180pt thì rộng
                    // 480pt — rộng hơn màn iPhone XR (414) đúng 66pt. Cả khối
                    // hồ sơ bị kéo rộng 480 rồi căn giữa trong màn 414, nên
                    // chữ bị cắt cả hai bên. Máy 440pt chỉ tràn 40 nên dễ bỏ
                    // qua; máy XR thì lộ hẳn.
                    //
                    // `.clipped()` KHÔNG cứu được: nó chỉ cắt phần VẼ RA, kích
                    // thước bố cục vẫn là 480. Thêm `.frame(maxWidth:.infinity)`
                    // cũng KHÔNG — đo thật vẫn báo 480.
                    //
                    // Lớp phủ thì KHÔNG BAO GIỜ ảnh hưởng kích thước bố cục.
                    // Khung do `Color.clear` quyết định: cao cố định, rộng co
                    // theo cha. Đo thật: 480pt → 10pt.
                    Color.clear
                        .frame(height: 180)
                        .overlay {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.primaryDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                        .clipped()
                } else {
                    // Chưa có ảnh bìa: KHÔNG để một mảng tím phẳng. Thêm hai
                    // quầng sáng lệch tâm cho có chiều sâu — vẫn thuần mã, không
                    // tốn tài nguyên, và không bao giờ hỏng vì thiếu ảnh.
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 180)
                        .overlay(alignment: .topTrailing) {
                            Circle().fill(Color.white.opacity(0.14))
                                .frame(width: 190, height: 190).blur(radius: 44)
                                .offset(x: 54, y: -74)
                        }
                        .overlay(alignment: .bottomLeading) {
                            Circle().fill(AppColors.secondary.opacity(0.28))
                                .frame(width: 160, height: 160).blur(radius: 50)
                                .offset(x: -50, y: 58)
                        }
                        .clipped()
                }

                // Edit Cover Button
                if viewModel.isCurrentUser {
                    PhotosPicker(selection: $coverItem, matching: .images) {
                        Group {
                            if viewModel.dangTaiAnhBia {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "camera.fill").foregroundColor(AppColors.onPrimary)
                            }
                        }
                        .padding(Spacing.sm)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                    }
                    .disabled(viewModel.dangTaiAnhBia)
                    .padding(.trailing, Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(y: -20)
                }
            }

            // Avatar and Info
            HStack(alignment: .bottom, spacing: Spacing.md) {
                ZStack(alignment: .bottomTrailing) {
                    // Viền dày cùng màu nền: chuẩn Facebook/X — tách avatar
                    // khỏi ảnh bìa dù ảnh bìa sáng hay tối.
                    UserAvatarView(url: viewModel.profile?.avatarUrl, size: 96)
                        .overlay(Circle().stroke(AppColors.backgroundPrimary, lineWidth: 4))
                        .shadow(color: .black.opacity(0.28), radius: 8, y: 3)

                    if viewModel.isCurrentUser {
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            Group {
                                if viewModel.dangTaiAvatar {
                                    ProgressView().tint(.white).scaleEffect(0.7)
                                } else {
                                    Image(systemName: "camera.fill").font(.caption).foregroundColor(AppColors.onPrimary)
                                }
                            }
                            .padding(6)
                            .background(AppColors.primary)
                            .clipShape(Circle())
                        }
                        .disabled(viewModel.dangTaiAvatar)
                    }
                }
                .offset(y: -46)

                Spacer()
            }
            .padding(.horizontal, Spacing.md)

            // User Info
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // KHÔNG có `?? "User"` ở đây nữa. Khối này chỉ được vẽ khi
                // `viewModel.profile != nil` (xem `than`), nên giá trị giữ
                // chỗ vừa thừa vừa là thứ đã tạo ra màn hình hồ sơ giả.
                HStack(spacing: 6) {
                    Text(viewModel.profile?.name ?? "")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if viewModel.profile?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 17))
                            .foregroundColor(AppColors.primary)
                    }
                }

                Text("@\(viewModel.profile?.username ?? "")")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)

                if let ngay = ngayThamGia {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar").font(.system(size: 11))
                        Text(ngay).font(.system(size: 12.5))
                    }
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.top, 1)
                }

                if let bio = viewModel.profile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.top, Spacing.xs)
                }

                // Social Links
                if let links = viewModel.profile?.socialLinks, !links.isEmpty {
                    HStack(spacing: Spacing.md) {
                        ForEach(links, id: \.self) { link in
                            Link(destination: URL(string: link) ?? URL(string: "https://example.com")!) {
                                Image(systemName: "link")
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                    .padding(.top, Spacing.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .offset(y: -20)

            // Hàng nút TOÀN CHIỀU RỘNG, đặt DƯỚI tên — chuẩn Facebook/X.
            //
            // ⚠️ Trước đây nút nằm cùng hàng với avatar, căn phải. Trên máy
            // hẹp (iPhone SE/mini) một cái tên dài đẩy thẳng vào nút, và nút
            // "Chỉnh sửa hồ sơ" dài hơn "Chỉnh sửa" cũ nên khoảng thở gần như
            // không còn. Xuống hàng riêng thì tên dài bao nhiêu cũng không
            // chạm nút.
            hangNut
                .padding(.horizontal, Spacing.md)
                .offset(y: -12)
        }
    }

    @ViewBuilder private var hangNut: some View {
                    if !viewModel.isCurrentUser {
                        if viewModel.profile?.isFollowing == true {
                            Button {
                                Task { await viewModel.toggleFollow() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                                    Text(T("Đang theo dõi")).font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppColors.backgroundTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                                .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .stroke(AppColors.border, lineWidth: 1))
                            }
                        } else {
                            Button {
                                Task { await viewModel.toggleFollow() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.badge.plus").font(.system(size: 13, weight: .semibold))
                                    Text(T("Theo dõi")).font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(AppColors.onPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                            }
                            .disabled(viewModel.isLoading)
                        }
                    } else {
                        Button {
                            sheet = .editProfile
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.pencil").font(.system(size: 13, weight: .semibold))
                                Text(T("Chỉnh sửa hồ sơ")).font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(AppColors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        }
                    }
                
    }

    private var profileStats: some View {
        HStack(spacing: 0) {
            statItem(value: viewModel.profile?.postsCount ?? 0, label: T("Bài viết"))
            Divider().frame(height: 30)
            statItem(value: viewModel.profile?.followersCount ?? 0, label: T("Người theo dõi"))
            Divider().frame(height: 30)
            statItem(value: viewModel.profile?.followingCount ?? 0, label: T("Đang theo dõi"))
        }
        .padding(.vertical, Spacing.md)
        .background(AppColors.backgroundSecondary)
        .padding(.top, -Spacing.md)
    }

    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Text(formatCount(value))
                .font(.system(size: 19, weight: .bold).monospacedDigit())
                .foregroundColor(AppColors.textPrimary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    /// "Tham gia tháng 3, 2025" — mốc quen thuộc trên mọi mạng xã hội, và là
    /// thứ duy nhất trong đầu trang chứng minh đây là tài khoản THẬT.
    private var ngayThamGia: String? {
        guard let raw = viewModel.profile?.createdAt else { return nil }
        let vao = ISO8601DateFormatter()
        vao.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = vao.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let d else { return nil }
        let ra = DateFormatter()
        ra.locale = Locale(identifier: QuanLyNgonNguApp.shared.ngonNgu == .anh ? "en_US" : "vi_VN")
        ra.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return (QuanLyNgonNguApp.shared.ngonNgu == .anh ? "Joined " : "Tham gia ") + ra.string(from: d)
    }

    private var profileActions: some View {
        HStack(spacing: Spacing.sm) {
            actionButton(icon: "square.grid.2x2", title: T("Bài viết"), isActive: viewModel.selectedTab == .posts) {
                viewModel.selectedTab = .posts
            }

            // "Đã lưu" và "Khoá học" là thông tin RIÊNG TƯ — chỉ hiện ở hồ sơ
            // của chính mình, không khoe ở hồ sơ người khác.
            if viewModel.isCurrentUser {
                actionButton(icon: "bookmark", title: T("Đã lưu"), isActive: viewModel.selectedTab == .saved) {
                    viewModel.selectedTab = .saved
                }

            // Tab Nhạc đã GỠ: module nhạc bị bỏ khỏi app vì App Store
            // Guideline 5.2.3 (rút audio từ YouTube). Để lại một tab mở ra
            // màn trống còn tệ hơn không có tab.
                actionButton(icon: "graduationcap", title: T("Khoá học"), isActive: viewModel.selectedTab == .courses) {
                    viewModel.selectedTab = .courses
                }
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private func actionButton(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.bodyMedium)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isActive ? AppColors.primary : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(isActive ? AppColors.primary.opacity(0.1) : Color.clear)
            .cornerRadius(CornerRadius.small)
        }
    }

    private var contentTabs: some View {
        Divider()
            .background(AppColors.divider)
    }

    /// Phần dưới hồ sơ, đổi theo tab đang chọn.
    /// Trước đây LUÔN vẽ `viewModel.posts` bất kể tab nào — nên hai tab kia
    /// bấm vào chỉ đổi màu biểu tượng, nội dung y nguyên.
    @ViewBuilder
    private var noiDungTheoTab: some View {
        switch viewModel.selectedTab {
        case .posts: postsGrid
        case .saved: khoiDaLuu
        case .courses: khoiKhoaHoc
        }
    }

    private var khoiDaLuu: some View {
        LazyVStack(spacing: Spacing.md) {
            if viewModel.dangTaiDaLuu && viewModel.baiDaLuu.isEmpty {
                ProgressView().padding(.top, Spacing.xxl)
            } else if viewModel.baiDaLuu.isEmpty {
                khoiRong(icon: "bookmark", tieuDe: T("Chưa lưu bài nào"),
                         phu: T("Chạm ••• trên một bài viết rồi chọn Lưu để đọc lại sau."))
            } else {
                ForEach(viewModel.baiDaLuu) { post in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink(destination: PostDetailView(post: post)) {
                            PostCard(post: post)
                        }
                        .buttonStyle(.plain)
                        PostModerationMenu(post: post) {
                            withAnimation { viewModel.boBaiKhoiDanhSach(post.id) }
                        }
                            .padding(.top, Spacing.md)
                            .padding(.trailing, Spacing.md)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .task { await viewModel.taiBaiDaLuu() }
    }

    private var khoiKhoaHoc: some View {
        LazyVStack(spacing: Spacing.sm) {
            if viewModel.dangTaiKhoa && viewModel.khoaDaHoc.isEmpty {
                ProgressView().padding(.top, Spacing.xxl)
            } else if viewModel.khoaDaHoc.isEmpty {
                khoiRong(icon: "graduationcap", tieuDe: T("Chưa ghi danh khoá nào"),
                         phu: T("Vào tab Học, chọn một khoá và bấm Ghi danh."))
            } else {
                ForEach(viewModel.khoaDaHoc) { gd in
                    NavigationLink(destination: CourseDetailView(slug: gd.courseSlug)) {
                        hangKhoaHoc(gd)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .task { await viewModel.taiKhoaDaHoc() }
    }

    private func hangKhoaHoc(_ gd: Enrollment) -> some View {
        HStack(spacing: Spacing.md) {
            #if canImport(Kingfisher)
            if let t = gd.courseThumbnail, let url = URL(string: t) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(width: 96, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            #endif

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let ma = gd.courseCode {
                        Text(ma)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.secondary)
                    }
                    Text(gd.nhanTrangThai)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(gd.daXong ? AppColors.success : AppColors.textTertiary)
                }

                Text(gd.courseTitle)
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Thanh tiến độ + phần trăm, đều do máy chủ tính sẵn.
                HStack(spacing: Spacing.sm) {
                    ProgressView(value: Double(gd.progressPercent ?? 0), total: 100)
                        .tint(gd.daXong ? AppColors.success : AppColors.primary)
                    Text("\(gd.progressPercent ?? 0)%")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
        .contentShape(Rectangle())
    }

    private func khoiRong(icon: String, tieuDe: String, phu: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(AppColors.textTertiary)
            Text(tieuDe)
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)
            Text(phu)
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, Spacing.lg)
    }

    private var postsGrid: some View {
        LazyVStack(spacing: Spacing.md) {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView()
                    .padding(.top, Spacing.xxl)
            } else if viewModel.posts.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.posts) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        PostCard(post: post)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if post == viewModel.posts.last {
                            Task {
                                await viewModel.loadMorePosts()
                            }
                        }
                    }
                }

                if viewModel.hasMore {
                    ProgressView()
                        .padding()
                }
            }
        }
        .padding(Spacing.md)
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundColor(AppColors.textTertiary)

            Text(T("Chưa có bài viết nào"))
                .font(.titleMedium)
                .foregroundColor(AppColors.textPrimary)

            Text(viewModel.isCurrentUser ? T("Tạo bài viết đầu tiên của bạn") : T("Người dùng này chưa đăng bài viết nào"))
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            if viewModel.isCurrentUser {
                Button {
                    appState.selectedTab = .create
                } label: {
                    Text(T("Tạo bài viết"))
                        .primaryButtonStyle()
                }
                .padding(.top, Spacing.md)
            }
        }
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, Spacing.xl)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - User Profile View (for other users)
struct UserProfileView: View {
    let userId: Int

    var body: some View {
        // Truyền THẲNG vào `ProfileView`. Bản cũ giữ một view model riêng ở
        // đây rồi hy vọng `ProfileView` dùng nó — nó không dùng.
        ProfileView(userIdKhac: userId)
            .environmentObject(AppState.shared)
    }
}

// MARK: - Profile View Model
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userId: Int?
    @Published var profile: UserProfile?
    @Published var posts: [SocialPost] = []

    /// Bỏ một bài khỏi danh sách đang hiện — gọi sau khi xoá bài trên máy chủ.
    func boBaiKhoiDanhSach(_ id: Int) {
        posts.removeAll { $0.id == id }
    }
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasMore = true
    @Published var selectedTab: ProfileTab = .posts

    private var cursor: Int?

    // ── Bài đã lưu & khoá đã ghi danh ─────────────────────────────
    @Published var baiDaLuu: [SocialPost] = []
    @Published var khoaDaHoc: [Enrollment] = []
    @Published var dangTaiDaLuu = false
    @Published var dangTaiKhoa = false

    /// Nạp một lần rồi thôi — người dùng gạt qua gạt lại giữa các tab liên
    /// tục, gọi lại mỗi lần là phí. Kéo-để-làm-mới vẫn nạp lại được.
    func taiBaiDaLuu(batBuoc: Bool = false) async {
        guard batBuoc || (baiDaLuu.isEmpty && !dangTaiDaLuu) else { return }
        dangTaiDaLuu = true
        defer { dangTaiDaLuu = false }
        do {
            // `/social/saves` trả HÀNG LƯU bọc bài viết, không phải bài viết.
            let ds: (items: [HangDaLuu], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getSavedPosts(cursor: nil, limit: 30))
            baiDaLuu = ds.items.map(\.post)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func taiKhoaDaHoc(batBuoc: Bool = false) async {
        guard batBuoc || (khoaDaHoc.isEmpty && !dangTaiKhoa) else { return }
        dangTaiKhoa = true
        defer { dangTaiKhoa = false }
        do {
            let ds: (items: [Enrollment], nextCursor: Int?, hasMore: Bool) =
                try await APIClient.shared.requestList(.getMyCourses)
            // Khoá đang học lên trước, xong rồi xuống dưới; cùng nhóm thì cái
            // vừa học gần nhất lên trên.
            khoaDaHoc = ds.items.sorted {
                if $0.daXong != $1.daXong { return !$0.daXong }
                return ($0.lastAccessedAt ?? "") > ($1.lastAccessedAt ?? "")
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // ── Đổi ảnh đại diện / ảnh bìa ────────────────────────────────
    @Published var dangTaiAvatar = false
    @Published var dangTaiAnhBia = false
    @Published var loiDoiAnh: String?

    enum TruongAnh {
        case avatar, bia
        /// Tên trường trong `PUT /api/v1/profile`.
        var khoa: String { self == .avatar ? "avatarUrl" : "coverPhotoUrl" }
        var thuMuc: String { self == .avatar ? "avatar" : "cover" }
    }

    func doiAnh(_ item: PhotosPickerItem, truong: TruongAnh) async {
        if truong == .avatar { dangTaiAvatar = true } else { dangTaiAnhBia = true }
        defer { if truong == .avatar { dangTaiAvatar = false } else { dangTaiAnhBia = false } }
        loiDoiAnh = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let anh = PlatformImage(data: data),
                  let jpeg = anh.jpegDataForUpload()
            else {
                loiDoiAnh = T("Không đọc được ảnh vừa chọn.")
                return
            }

            let file = try await APIClient.shared.upload(
                data: jpeg,
                fileName: "\(truong.thuMuc)-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg",
                category: truong.thuMuc,
            )
            try await APIClient.shared.send(.updateProfile([truong.khoa: file.url]))

            // Nạp lại từ máy chủ thay vì tự sửa `profile` tại chỗ: máy chủ có
            // thể đổi URL (đưa qua CDN, thêm hậu tố kích cỡ), và nếu ta đoán
            // sai thì ảnh hiện đúng cho tới lần mở app sau rồi biến mất.
            await loadProfile()
            await AppState.shared.fetchProfile()
        } catch {
            loiDoiAnh = error.localizedDescription
        }
    }

    var isCurrentUser: Bool {
        guard let profileId = profile?.id, let currentId = AppState.shared.currentUser?.id else {
            return userId == AppState.shared.currentUser?.id
        }
        return profileId == currentId
    }

    init() {
        // Load profile on init
        Task {
            await loadProfile()
        }
    }

    func loadProfile() async {
        isLoading = true
        error = nil

        // ⚠️ Bản cũ chỉ có `if let userId = ...` không kèm `else`: không có
        // id thì hàm im lặng không làm gì, `error` vẫn nil, `isLoading` về
        // false — màn hình đứng yên mà không ai biết vì sao. Phải NÓI RA.
        guard let userId = userId ?? AppState.shared.currentUser?.id else {
            error = T("Chưa xác định được tài khoản. Thử lại hoặc đăng nhập lại.")
            isLoading = false
            return
        }
        do {
            let user: User = try await APIClient.shared.request(.getUserProfile(id: userId))
            profile = UserProfile(from: user)
            cursor = nil
            posts = []
            hasMore = true
            await loadPosts(reset: true)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadPosts(reset: Bool = false) async {
        guard let userId = userId ?? AppState.shared.currentUser?.id else { return }

        if reset {
            cursor = nil
            posts = []
            hasMore = true
        }

        guard hasMore else { return }

        do {
            let response: FeedResponse = try await APIClient.shared.request(
                .getUserPosts(id: userId, cursor: cursor, limit: 10)
            )

            if reset {
                posts = response.items
            } else {
                posts.append(contentsOf: response.items)
            }

            cursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadMorePosts() async {
        guard !isLoading && hasMore else { return }
        await loadPosts()
    }

    func toggleFollow() async {
        guard let userId = profile?.id else { return }

        do {
            if profile?.isFollowing == true {
                let _: EmptyResponse = try await APIClient.shared.request(.unfollowUser(id: userId))
                profile?.isFollowing = false
            } else {
                let _: EmptyResponse = try await APIClient.shared.request(.followUser(id: userId))
                profile?.isFollowing = true
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Profile Tab
enum ProfileTab {
    case posts
    case saved
    case courses
}

// MARK: - User Profile (extended user info)
struct UserProfile {
    let id: Int
    let username: String
    let email: String?
    let fullName: String?
    let displayName: String?
    let avatarUrl: String?
    let coverPhotoUrl: String?
    let bio: String?
    var isFollowing: Bool?
    let isFollowedBy: Bool?
    let followersCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let isVerified: Bool?
    let socialLinks: [String]?
    let createdAt: String?

    var name: String {
        displayName ?? fullName ?? username
    }

    init(from user: User) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
        self.fullName = user.fullName
        self.displayName = user.displayName
        self.avatarUrl = user.avatarUrl
        self.coverPhotoUrl = user.coverPhotoUrl
        self.bio = user.bio
        self.isFollowing = user.isFollowing
        self.isFollowedBy = user.isFollowedBy
        self.followersCount = user.followersCount
        self.followingCount = user.followingCount
        self.postsCount = user.postsCount
        self.isVerified = false
        self.socialLinks = nil
        self.createdAt = user.createdAt
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var giaoDien = QuanLyGiaoDien.shared
    @StateObject private var quanLyNN = QuanLyNgonNguApp.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Giao diện — đặt TRÊN CÙNG vì đây là thứ người dùng vào
                // Cài đặt để đổi nhiều nhất, và họ thấy kết quả ngay lập tức.
                Section {
                    ForEach(CheDoGiaoDien.allCases) { c in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                giaoDien.cheDo = c
                            }
                            Haptics.cham()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: c.bieuTuong)
                                    .font(.system(size: 15))
                                    .foregroundColor(giaoDien.cheDo == c ? AppColors.primary : AppColors.textSecondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.ten)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text(c.moTa)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColors.textTertiary)
                                }
                                Spacer(minLength: 0)
                                if giaoDien.cheDo == c {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        // Nhiều Button trong MỘT hàng Form gộp thành một nút —
                        // mỗi cái phải có `.plain` riêng.
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(T("Giao diện"))
                } footer: {
                    if giaoDien.cheDo == .theoGio {
                        Text("Đang \(QuanLyGiaoDien.dangLaBanNgay() ? "sáng" : "tối"). Tự đổi vào \(QuanLyGiaoDien.gioSang)h và \(QuanLyGiaoDien.gioToi)h mỗi ngày.")
                    }
                }

                // Ngôn ngữ — ngay dưới Giao diện, cùng nhóm "đổi là thấy
                // ngay". Tên mỗi lựa chọn viết bằng CHÍNH thứ tiếng đó, để
                // người đang lạc trong giao diện tiếng lạ vẫn tìm được đường về.
                Section {
                    ForEach(NgonNguApp.allCases) { n in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                quanLyNN.ngonNgu = n
                            }
                            Haptics.cham()
                        } label: {
                            HStack(spacing: 12) {
                                Text(n.co).font(.system(size: 17))
                                    .frame(width: 24)
                                Text(n.ten)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer(minLength: 0)
                                if quanLyNN.ngonNgu == n {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(T("Ngôn ngữ"))
                } footer: {
                    // Nói THẲNG giới hạn. Bật English mà bài viết, nghĩa từ
                    // vựng và lời phê của AI vẫn tiếng Việt thì người dùng sẽ
                    // tưởng app hỏng — trong khi đó là nội dung do máy chủ
                    // trả về và vốn viết bằng tiếng Việt.
                    Text(quanLyNN.ngonNgu == .anh
                         ? "Menus and buttons switch to English. Content written in Vietnamese — posts, word meanings, grammar notes, AI feedback — stays as it is."
                         : "Đổi chữ của giao diện. Nội dung do máy chủ trả về (bài viết, nghĩa từ vựng, giải thích ngữ pháp, lời phê của AI) vẫn giữ nguyên tiếng Việt.")
                }

                // Account
                Section(T("Tài khoản")) {
                    NavigationLink(T("Chỉnh sửa hồ sơ")) { ChinhSuaHoSoView() }
                    NavigationLink(T("Đổi mật khẩu")) { ChangePasswordView() }
                }

                // Safety & privacy — App Store Guideline 1.2 surfaces
                Section {
                    NavigationLink(T("Danh sách chặn")) { BlockedUsersView() }
                    NavigationLink(T("Quy tắc cộng đồng & Điều khoản")) { TermsView() }
                    NavigationLink(T("Chính sách bảo mật")) { PrivacyPolicyView() }
                } header: {
                    Text(T("An toàn & quyền riêng tư"))
                } footer: {
                    Text(T("Chúng tôi không khoan nhượng với nội dung phản cảm. Mọi báo cáo được xử lý trong 24 giờ."))
                }

                // Support
                Section(T("Hỗ trợ")) {
                    NavigationLink(T("Trợ giúp & liên hệ")) { HelpView() }
                    HStack {
                        Text(T("Email hỗ trợ"))
                        Spacer()
                        Text(SupportContact.email)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .textSelection(.enabled)
                    }
                }

                // About
                Section(T("Giới thiệu")) {
                    HStack {
                        Text(T("Phiên bản"))
                        Spacer()
                        Text(Bundle.main.appVersionString)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Session
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        HStack { Spacer(); Text(T("Đăng xuất")); Spacer() }
                    }
                }

                // Account erasure — App Store Guideline 5.1.1(v)
                Section {
                    NavigationLink {
                        DeleteAccountView()
                    } label: {
                        Text(T("Xoá tài khoản"))
                            .foregroundColor(AppColors.error)
                    }
                } footer: {
                    Text(T("Xoá vĩnh viễn tài khoản và dữ liệu cá nhân của bạn."))
                }
            }
            .navigationTitle(T("Cài đặt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Đóng")) { dismiss() }
                }
            }
            .alert(T("Đăng xuất"), isPresented: $showLogoutAlert) {
                Button(T("Hủy"), role: .cancel) { }
                Button(T("Đăng xuất"), role: .destructive) {
                    appState.logout()
                    dismiss()
                }
            } message: {
                Text(T("Bạn có chắc muốn đăng xuất không?"))
            }
        }
    }
}

extension Bundle {
    /// "1.0.0 (12)" — reviewers ask for the build number, and a hard-coded
    /// string here would drift from the one in Info.plist.
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState.shared)
}
