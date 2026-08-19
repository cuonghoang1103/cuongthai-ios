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
            .navigationTitle("Tạo bài viết")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        resetForm()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đăng") {
                        Task {
                            await viewModel.createPost()
                        }
                    }
                    .font(.buttonText)
                    .foregroundColor(canPost ? AppColors.primary : AppColors.textTertiary)
                    .disabled(!canPost || viewModel.isLoading)
                }
            }
            .onChange(of: selectedPhotosPickerItems) { _, newItems in
                Task {
                    await viewModel.loadPhotos(from: newItems)
                }
            }
            .alert("Thông báo", isPresented: $viewModel.showAlert) {
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
                        Text("Bạn đang nghĩ gì?")
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
                                        .foregroundColor(.white)
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
                HStack(spacing: Spacing.md) {
                    PhotosPicker(
                        selection: $selectedPhotosPickerItems,
                        maxSelectionCount: 4,
                        matching: .images
                    ) {
                        mediaButton(icon: "photo", title: "Ảnh")
                    }

                    mediaButton(icon: "video", title: "Video")

                    mediaButton(icon: "location", title: "Địa điểm")

                    mediaButton(icon: "music.note", title: "Nhạc")
                }
            }
        }
    }

    private func mediaButton(icon: String, title: String) -> some View {
        Button {
            // Action for each media type
        } label: {
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
            optionRow(icon: "at", title: "Nhắc đến", showChevron: true)
            optionRow(icon: "tag", title: "Hashtag", showChevron: true)

            Divider().background(AppColors.divider)

            if viewModel.isPollEnabled {
                pollSection
            } else {
                optionRow(icon: "chart.bar", title: "Tạo cuộc thăm dò", showChevron: false) {
                    viewModel.isPollEnabled = true
                }
            }
        }
        .inputFieldStyle()
    }

    private var pollSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Tạo cuộc thăm dò")
                    .font(.titleSmall)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button {
                    viewModel.isPollEnabled = false
                    viewModel.pollQuestion = ""
                    viewModel.pollOptions = ["", ""]
                } label: {
                    Text("Hủy")
                        .font(.caption)
                        .foregroundColor(AppColors.primary)
                }
            }

            TextField("Câu hỏi của bạn", text: $viewModel.pollQuestion)
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
                        Text("Thêm tùy chọn")
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
            Text("Ai có thể xem bài viết?")
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
    }
}

// MARK: - Post Visibility
enum PostVisibility: String, CaseIterable {
    case `public` = "Công khai"
    case friends = "Bạn bè"
    case privateOnly = "Riêng tư"

    var title: String { rawValue }

    var shortTitle: String {
        switch self {
        case .public: return "Công khai"
        case .friends: return "Bạn bè"
        case .privateOnly: return "Riêng tư"
        }
    }

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

    func loadPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = PlatformImage(data: data) {
                await MainActor.run {
                    if selectedImages.count < 4 {
                        selectedImages.append(image)
                    }
                }
            }
        }
    }

    func removeImage(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
    }

    func createPost() async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Vui lòng nhập nội dung bài viết"
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

            // Add poll if enabled
            if isPollEnabled && !pollQuestion.isEmpty {
                let validOptions = pollOptions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if validOptions.count >= 2 {
                    postData["poll"] = [
                        "question": pollQuestion,
                        "options": validOptions,
                        "multiChoice": false
                    ]
                }
            }

            let _: SocialPost = try await APIClient.shared.request(
                .createPost(postData)
            )

            postCreated = true
            alertMessage = "Bài viết đã được đăng!"
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
