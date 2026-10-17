import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// MARK: - User Avatar
struct UserAvatarView: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        Group {
            #if canImport(Kingfisher)
            if let urlString = url, let imageURL = URL(string: urlString) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
            #else
            avatarPlaceholder
            #endif
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(AppColors.backgroundTertiary)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(AppColors.textSecondary)
                    .font(.system(size: size * 0.5))
            )
    }
}
