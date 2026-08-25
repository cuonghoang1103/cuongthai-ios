import SwiftUI
import PhotosUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Create Post View
struct CreatePostView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CreatePostViewModel()
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    @FocusState private var isContentFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    headerSection
                    contentSection
                    mediaSection
                    optionsSection
                    visibilitySection
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Tạo bài viết"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Hủy")) {
                        resetForm()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Đăng")) {
                        Task {
                            await viewModel.createPost()
                        }
                    }
                    .font(.buttonText)
                    .foregroundColor(canPost ? AppColors.primary : AppColors.textTertiary)
                    .disabled(!canPost || viewModel.isLoading)
                }
            }
            // ⚠️ Không có dòng này thì KHÔNG có đường nào tắt bàn phím:
            // `isContentFocused` chưa từng bị đặt `false` ở đâu, và Return
            // trong `TextEditor` là xuống dòng chứ không phải "xong". Bàn
            // phím che mất "Thêm ảnh", thăm dò và cả hàng chọn quyền xem.
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(T("Xong")) { isContentFocused = false }
                }
            }
            .onChange(of: selectedPhotosPickerItems) { _, newItems in
                Task {
                    await viewModel.loadPhotos(from: newItems)
                }
            }
            .alert(T("Thông báo"), isPresented: $viewModel.showAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .onChange(of: viewModel.postCreated) { _, created in
                if created {
                    resetForm()
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: Spacing.md) {
            UserAvatarView(url: appState.currentUser?.avatarUrl, size: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.currentUser?.name ?? "User")
                    .font(.titleSmall)
                    .foregroundColor(AppColors.textPrimary)

                Menu {
                    ForEach(PostVisibility.allCases, id: \.self) { visibility in
                        Button {
                            viewModel.visibility = visibility
                        } label: {
                            Label(visibility.title, systemImage: visibility.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.visibility.icon)
                        Text(viewModel.visibility.title)
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColors.backgroundTertiary)
                    .cornerRadius(CornerRadius.small)
                }
            }

            Spacer()
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TextEditor(text: $viewModel.content)
                .font(.bodyLarge)
                .foregroundColor(AppColors.textPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 150)
                .focused($isContentFocused)
                .overlay(alignment: .topLeading) {
                    if viewModel.content.isEmpty {
                        Text(T("Bạn đang nghĩ gì?"))
                            .font(.bodyLarge)
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Spacer()
                Text("\(viewModel.content.count) / 2000")
                    .font(.caption)
                    .foregroundColor(viewModel.content.count > 2000 ? AppColors.error : AppColors.textTertiary)
            }
        }
        .inputFieldStyle()
    }

    private var mediaSection: some View {
        VStack(spacing: Spacing.md) {
            if !viewModel.selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(platformImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                                Button {
                                    viewModel.removeImage(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppColors.onPrimary)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .padding(4)
                            }
                        }

                        if viewModel.selectedImages.count < 4 {
                            PhotosPicker(
                                selection: $selectedPhotosPickerItems,
                                maxSelectionCount: 4 - viewModel.selectedImages.count,
                                matching: .images
                            ) {
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .fill(AppColors.backgroundTertiary)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.title)
                                            .foregroundColor(AppColors.textSecondary)
                                    )
                            }
                        }
                    }
                }
            } else {
                // Chỉ còn Ảnh. "Video" / "Địa điểm" / "Nhạc" đã GỠ: cả ba đều
                // là nút bấm không ăn — luồng đăng bài chỉ dựng được media
                // kiểu IMAGE, và không có màn chọn địa điểm hay chọn nhạc nào
                // trong app. Thêm lại khi làm thật, đừng để chỗ trống bấm được.
                HStack(spacing: Spacing.md) {
                    PhotosPicker(
                        selection: $selectedPhotosPickerItems,
                        maxSelectionCount: 4,
                        matching: .images
                    ) {
                        mediaButton(icon: "photo", title: T("Thêm ảnh"))
                    }
                }
            }
        }
    }

    /// Chỉ là NHÃN đặt bên trong PhotosPicker — không bọc Button nữa, vì
    /// Button lồng trong PhotosPicker sẽ nuốt mất cú chạm của chính nó.
    private func mediaButton(icon: String, title: String) -> some View {
        Group {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.medium)
        }
    }

    private var optionsSection: some View {
        VStack(spacing: Spacing.sm) {
            // ⚠️ ĐÃ BỎ hai dòng "Nhắc đến" và "Hashtag": chúng gọi
            // `optionRow(...)` KHÔNG truyền `action`, tức là hai cái nút
            // không làm gì — mà vẫn vẽ mũi tên `chevron.right` như thể bấm
            // vào sẽ mở ra màn khác. Nhắc tên và hashtag vốn gõ thẳng `@`
            // và `#` trong nội dung, không cần lối vào riêng.

            if viewModel.isPollEnabled {
                pollSection
            } else {
                optionRow(icon: "chart.bar", title: T("Tạo cuộc thăm dò"), showChevron: false) {
                    viewModel.isPollEnabled = true
                }
            }
        }
        .inputFieldStyle()
    }

    private var pollSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(T("Tạo cuộc thăm dò"))
                    .font(.titleSmall)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button {
                    viewModel.isPollEnabled = false
                    viewModel.pollQuestion = ""
                    viewModel.pollOptions = ["", ""]
                } label: {
                    Text(T("Hủy"))
                        .font(.caption)
                        .foregroundColor(AppColors.primary)
                }
            }

            TextField(T("Câu hỏi của bạn"), text: $viewModel.pollQuestion)
                .font(.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .inputFieldStyle()

            ForEach(viewModel.pollOptions.indices, id: \.self) { index in
                HStack {
                    TextField("Tùy chọn \(index + 1)", text: $viewModel.pollOptions[index])
                        .font(.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)

                    if viewModel.pollOptions.count > 2 {
                        Button {
                            viewModel.pollOptions.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(AppColors.error)
                        }
                    }
                }
                .inputFieldStyle()
            }

            if viewModel.pollOptions.count < 4 {
                Button {
                    viewModel.pollOptions.append("")
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text(T("Thêm tùy chọn"))
                    }
                    .font(.buttonSmall)
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }

    private func optionRow(icon: String, title: String, showChevron: Bool, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppColors.primary)
                    .frame(width: 24)

                Text(title)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.vertical, Spacing.sm)
        }
    }

    private var visibilitySection: some View {
        VStack(spacing: Spacing.sm) {
            Text(T("Ai có thể xem bài viết?"))
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: Spacing.sm) {
                ForEach(PostVisibility.allCases, id: \.self) { visibility in
                    Button {
                        viewModel.visibility = visibility
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: visibility.icon)
                                .font(.title3)
                            Text(visibility.shortTitle)
                                .font(.caption)
                        }
                        .foregroundColor(viewModel.visibility == visibility ? AppColors.primary : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(viewModel.visibility == visibility ? AppColors.primary.opacity(0.1) : AppColors.backgroundTertiary)
                        .cornerRadius(CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(viewModel.visibility == visibility ? AppColors.primary : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var canPost: Bool {
        !viewModel.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        viewModel.content.count <= 2000 &&
        !viewModel.isLoading
    }

    private func resetForm() {
        viewModel.content = ""
        viewModel.selectedImages = []
        viewModel.visibility = .public
        viewModel.isPollEnabled = false
        viewModel.pollQuestion = ""
        viewModel.pollOptions = ["", ""]
        selectedPhotosPickerItems = []
        // ⚠️ PHẢI hạ cờ này. Thiếu nó thì `.onChange(of: postCreated)` chỉ
        // bắn ĐÚNG MỘT LẦN: lần đăng thứ hai `postCreated` đã là `true` sẵn
        // nên không "đổi", form không được dọn, chữ cũ nằm nguyên trong ô.
        // Người dùng tưởng đăng hỏng và bấm Đăng lại ⇒ ĐĂNG TRÙNG.
        // Tái hiện thật 24/08/2026 trên máy ảo.
        viewModel.postCreated = false
    }
}

// MARK: - Post Visibility
/// ⚠️⚠️ `rawValue` là MÃ CỦA MÁY CHỦ, không phải chữ hiện ra màn hình.
///
/// Trước 24/08/2026 nó là chuỗi tiếng Việt ("Công khai"…) và `createPost`
/// gửi thẳng `visibility.rawValue` lên. Cột `Post.visibility` là
/// `String @db.VarChar(20)` chứ KHÔNG phải enum Prisma, nên máy chủ nhận và
/// LƯU NGUYÊN VĂN "Công khai" — không lỗi, không cảnh báo, bài đăng thành
/// công.
///
/// Hậu quả câm: bộ lọc cho người CHƯA đăng nhập là `{ visibility: 'PUBLIC' }`
/// (xem `social.service.ts`), nên mọi bài đăng từ app iOS **chỉ chính tác giả
/// nhìn thấy**. Tác giả mở bảng tin thấy bài mình nằm đó (luật "own posts,
/// any visibility") nên tưởng đã đăng bình thường.
///
/// Đo thật 24/08/2026: bảng tin khách trả 50/50 bài `PUBLIC`, và KHÔNG bài
/// nào do app tạo lọt vào 100 bài lấy về.
///
/// ⚠️ Các bài ĐÃ đăng từ app vẫn mang chuỗi sai trong CSDL — sửa app không
/// chữa được chúng, phải sửa dữ liệu.
enum PostVisibility: String, CaseIterable {
    case `public` = "PUBLIC"
    case friends = "FRIENDS"
    case privateOnly = "PRIVATE"

    var title: String {
        switch self {
        case .public: return T("Công khai")
        case .friends: return T("Bạn bè")
        case .privateOnly: return T("Riêng tư")
        }
    }

    var shortTitle: String { title }

    var icon: String {
        switch self {
        case .public: return "globe"
        case .friends: return "person.2"
        case .privateOnly: return "lock"
        }
    }
}

// MARK: - Create Post View Model
@MainActor
class CreatePostViewModel: ObservableObject {
    @Published var content = ""
    @Published var selectedImages: [PlatformImage] = []
    @Published var visibility: PostVisibility = .public
    @Published var isPollEnabled = false
    @Published var pollQuestion = ""
    @Published var pollOptions = ["", ""]
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var postCreated = false
    private var uploadError: String?

    /// Trần 4 ảnh mỗi bài.
    ///
    /// ⚠️ Bản cũ kiểm `count < 4` BÊN TRONG vòng lặp rồi bỏ qua trong im
    /// lặng — chọn 10 ảnh thì 6 ảnh biến mất mà không ai nói gì. Nay đếm
    /// trước và BÁO số bị bỏ.
    func loadPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var themDuoc = max(0, 4 - selectedImages.count)
        var boQua = 0
        for item in items {
            guard themDuoc > 0 else { boQua += 1; continue }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = PlatformImage(data: data) else { boQua += 1; continue }
            selectedImages.append(image)
            themDuoc -= 1
        }
        if boQua > 0 {
            alertMessage = "Mỗi bài chỉ đăng được 4 ảnh — đã bỏ qua \(boQua) ảnh."
            showAlert = true
        }
    }

    func removeImage(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
    }

    func createPost() async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = T("Vui lòng nhập nội dung bài viết")
            showAlert = true
            return
        }

        isLoading = true

        do {
            var postData: [String: Any] = [
                "content": content,
                "visibility": visibility.rawValue
            ]

            // Upload images if any
            if !selectedImages.isEmpty {
                uploadError = nil
                var mediaUrls: [[String: Any]] = []
                for image in selectedImages {
                    if let url = await uploadImage(image) {
                        mediaUrls.append([
                            "type": "IMAGE",
                            "url": url,
                            "thumbnail": url
                        ])
                    }
                }
                // Never publish a post whose images silently vanished.
                if mediaUrls.count < selectedImages.count {
                    alertMessage = "Không tải được ảnh lên: \(uploadError ?? "lỗi không xác định"). Bài viết chưa được đăng."
                    showAlert = true
                    isLoading = false
                    return
                }
                postData["media"] = mediaUrls
            }

            // Thăm dò. Cùng nguyên tắc với ảnh ở trên: KHÔNG đăng một bài
            // mà cuộc thăm dò biến mất không lời nào.
            //
            // ⚠️ Bản cũ chỉ `if ... { }` rồi thôi — bật thăm dò mà bỏ trống
            // câu hỏi hoặc mới điền 1 lựa chọn thì bài vẫn đăng, thăm dò bốc
            // hơi. Máy chủ cũng đòi 2–10 lựa chọn và không được để trống
            // (`POLL_OPTIONS_RANGE` / `POLL_OPTIONS_BLANK`), nên chặn ở đây
            // luôn cho người dùng biết ngay.
            if isPollEnabled {
                let cauHoi = pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                let luaChon = pollOptions
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                if cauHoi.isEmpty {
                    alertMessage = T("Bạn đang bật thăm dò nhưng chưa nhập câu hỏi. Bài viết chưa được đăng.")
                    showAlert = true; isLoading = false; return
                }
                if luaChon.count < 2 {
                    alertMessage = "Thăm dò cần ít nhất 2 lựa chọn (đang có \(luaChon.count)). Bài viết chưa được đăng."
                    showAlert = true; isLoading = false; return
                }
                postData["poll"] = [
                    "question": cauHoi,
                    "options": luaChon,
                    "multiChoice": false
                ]
            }

            let _: SocialPost = try await APIClient.shared.request(
                .createPost(postData)
            )

            postCreated = true
            alertMessage = T("Bài viết đã được đăng!")
            showAlert = true

        } catch {
            alertMessage = "Đăng bài thất bại: \(error.localizedDescription)"
            showAlert = true
        }

        isLoading = false
    }

    /// Real upload. Returns nil on failure so the caller can report it
    /// instead of posting a broken placeholder URL into the feed.
    private func uploadImage(_ image: PlatformImage) async -> String? {
        guard let data = image.jpegDataForUpload() else { return nil }
        do {
            let file = try await APIClient.shared.upload(
                data: data,
                fileName: "photo-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg",
                category: "social"
            )
            return file.url
        } catch {
            uploadError = error.localizedDescription
            return nil
        }
    }
}

#Preview {
    CreatePostView()
        .environmentObject(AppState.shared)
}
