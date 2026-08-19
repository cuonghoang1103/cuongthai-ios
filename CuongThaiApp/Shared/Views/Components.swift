import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - Avatar Components

struct AvatarStackView: View {
    let users: [User]
    let maxDisplay: Int
    let size: CGFloat

    init(users: [User], maxDisplay: Int = 3, size: CGFloat = 32) {
        self.users = users
        self.maxDisplay = maxDisplay
        self.size = size
    }

    var body: some View {
        HStack(spacing: -size / 3) {
            ForEach(Array(users.prefix(maxDisplay).enumerated()), id: \.offset) { index, user in
                UserAvatarView(url: user.avatarUrl, size: size)
                    .overlay(
                        Circle()
                            .stroke(AppColors.backgroundPrimary, lineWidth: 2)
                    )
                    .zIndex(Double(maxDisplay - index))
            }

            if users.count > maxDisplay {
                ZStack {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: size, height: size)

                    Text("+\(users.count - maxDisplay)")
                        .font(.system(size: size * 0.35, weight: .semibold))
                        .foregroundColor(AppColors.onPrimary)
                }
            }
        }
    }
}

// MARK: - Badge Components

struct BadgeView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(AppColors.onPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(CornerRadius.small)
    }
}

struct NotificationBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.onPrimary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(AppColors.error)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Loading Components

struct LoadingView: View {
    let message: String

    init(_ message: String = "Đang tải...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primary)

            Text(message)
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundPrimary)
    }
}

struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: CornerRadius.small)
            .fill(
                LinearGradient(
                    colors: [
                        AppColors.backgroundTertiary,
                        AppColors.backgroundTertiary.opacity(0.5),
                        AppColors.backgroundTertiary
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(isAnimating ? 0.5 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Empty State Components

struct AppEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.titleMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text(message)
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle = buttonTitle, let action = buttonAction {
                Button(action: action) {
                    Text(buttonTitle)
                        .primaryButtonStyle()
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.md)
            }
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Error View Components

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(AppColors.error)

            VStack(spacing: Spacing.sm) {
                Text("Đã xảy ra lỗi")
                    .font(.titleMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text(message)
                    .font(.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: retryAction) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Thử lại")
                }
                .secondaryButtonStyle()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.md)
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Segmented Control

struct SegmentedControl<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = option.value
                    }
                } label: {
                    Text(option.label)
                        .font(.buttonSmall)
                        .foregroundColor(selection == option.value ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(selection == option.value ? AppColors.primary : Color.clear)
                }
            }
        }
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Toast / Snackbar

struct ToastView: View {
    let message: String
    let type: ToastType

    enum ToastType {
        case success, error, info

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return AppColors.success
            case .error: return AppColors.error
            case .info: return AppColors.primary
            }
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)

            Text(message)
                .font(.bodyMedium)
                .foregroundColor(AppColors.textPrimary)

            Spacer()
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: Color.theoCheDo(sang: .black.opacity(0.14), toi: .black.opacity(0.45)), radius: 8, y: 4)
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Pull to Refresh

struct RefreshableScrollView<Content: View>: View {
    let content: Content
    let onRefresh: () async -> Void

    init(onRefresh: @escaping () async -> Void, @ViewBuilder content: () -> Content) {
        self.onRefresh = onRefresh
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            await onRefresh()
        }
    }
}

// MARK: - Image Picker
// UIImagePickerController is UIKit-only — guard so the macOS target compiles.
#if os(iOS)
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif

// MARK: - Rating Stars

struct RatingView: View {
    let rating: Double
    let maxRating: Int
    let size: CGFloat

    init(rating: Double, maxRating: Int = 5, size: CGFloat = 16) {
        self.rating = rating
        self.maxRating = maxRating
        self.size = size
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maxRating, id: \.self) { index in
                Image(systemName: starType(for: index))
                    .font(.system(size: size))
                    .foregroundColor(AppColors.warning)
            }
        }
    }

    private func starType(for index: Int) -> String {
        let threshold = Double(index) + 0.5
        if rating >= Double(index + 1) {
            return "star.fill"
        } else if rating >= threshold {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Chip/Tag View

struct ChipView: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? AppColors.primary : AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.full)
        }
    }
}

// MARK: - Divider with Text

struct LabeledDivider: View {
    let text: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)

            Text(text)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)

            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)
        }
    }
}

// MARK: - Quantity Stepper

struct QuantityStepper: View {
    @Binding var value: Int
    let minValue: Int
    let maxValue: Int

    var body: some View {
        HStack(spacing: 0) {
            Button {
                if value > minValue {
                    value -= 1
                }
            } label: {
                Image(systemName: "minus")
                    .foregroundColor(value > minValue ? AppColors.textPrimary : AppColors.textTertiary)
                    .frame(width: 36, height: 36)
            }
            .disabled(value <= minValue)

            Text("\(value)")
                .font(.titleSmall)
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 44)

            Button {
                if value < maxValue {
                    value += 1
                }
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(value < maxValue ? AppColors.textPrimary : AppColors.textTertiary)
                    .frame(width: 36, height: 36)
            }
            .disabled(value >= maxValue)
        }
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

#Preview {
    VStack(spacing: 20) {
        AvatarStackView(users: [
            User(id: 1, username: "user1", email: nil, fullName: "User 1", displayName: nil, avatarUrl: nil, coverPhotoUrl: nil, bio: nil, isFollowing: nil, isFollowedBy: nil, followersCount: nil, followingCount: nil, postsCount: nil, createdAt: nil),
            User(id: 2, username: "user2", email: nil, fullName: "User 2", displayName: nil, avatarUrl: nil, coverPhotoUrl: nil, bio: nil, isFollowing: nil, isFollowedBy: nil, followersCount: nil, followingCount: nil, postsCount: nil, createdAt: nil),
            User(id: 3, username: "user3", email: nil, fullName: "User 3", displayName: nil, avatarUrl: nil, coverPhotoUrl: nil, bio: nil, isFollowing: nil, isFollowedBy: nil, followersCount: nil, followingCount: nil, postsCount: nil, createdAt: nil),
        ])

        RatingView(rating: 4.5)

        ChipView(text: "SwiftUI", isSelected: true) {}
        ChipView(text: "iOS", isSelected: false) {}

        AppEmptyStateView(
            icon: "doc.text",
            title: "Không có dữ liệu",
            message: "Thử tải lại trang",
            buttonTitle: "Tải lại",
            buttonAction: {}
        )
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}
