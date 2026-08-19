import SwiftUI

// MARK: - Design System

// MARK: Spacing
struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: Corner Radius
struct CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: Colors

/// Màu đổi theo chế độ sáng/tối của hệ thống.
///
/// Trước 19/08/2026 app ép chế độ tối cứng (`UIUserInterfaceStyle: Dark` +
/// `.preferredColorScheme(.dark)`), nên mọi màu ghi thẳng số RGB là đủ. Bỏ ép
/// rồi thì từng màu phải tự biết mình đang ở chế độ nào — nếu không, người
/// dùng để máy ở chế độ sáng sẽ thấy chữ trắng trên nền trắng.
extension Color {
    static func theoCheDo(sang: Color, toi: Color) -> Color {
        #if os(iOS)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(toi) : UIColor(sang)
        })
        #elseif os(macOS)
        return Color(NSColor(name: nil) { hinhThuc in
            hinhThuc.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(toi) : NSColor(sang)
        })
        #endif
    }

    /// Dựng từ mã hex `0xRRGGBB` — dễ đối chiếu với bảng màu của web hơn là
    /// ba số thập phân.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
        )
    }
}

struct AppColors {
    // Primary Brand Colors — tím thương hiệu giữ nguyên ở cả hai chế độ, chỉ
    // đậm hơn một nấc ở nền sáng cho đủ tương phản chữ trắng (WCAG AA).
    static let primary = Color.theoCheDo(sang: Color(hex: 0x7A45E8), toi: Color(hex: 0x8C5AF0))
    static let primaryDark = Color.theoCheDo(sang: Color(hex: 0x6535D0), toi: Color(hex: 0x7340DB))
    static let primaryLight = Color.theoCheDo(sang: Color(hex: 0x9B6BFF), toi: Color(hex: 0xA673FF))

    // Secondary Colors
    static let secondary = Color.theoCheDo(sang: Color(hex: 0x0E93A6), toi: Color(hex: 0x21D4ED))
    static let accent = Color.theoCheDo(sang: Color(hex: 0xD97706), toi: Color(hex: 0xFF9933))

    // Background Colors
    static let backgroundPrimary = Color.theoCheDo(sang: Color(hex: 0xF6F6F9), toi: Color(hex: 0x0A0A14))
    static let backgroundSecondary = Color.theoCheDo(sang: Color(hex: 0xFFFFFF), toi: Color(hex: 0x141420))
    static let backgroundTertiary = Color.theoCheDo(sang: Color(hex: 0xEDEDF2), toi: Color(hex: 0x1A1A24))
    static let backgroundCard = Color.theoCheDo(sang: Color(hex: 0xFFFFFF), toi: Color(hex: 0x1A1A24))

    // Text Colors
    static let textPrimary = Color.theoCheDo(sang: Color(hex: 0x14141C), toi: Color(hex: 0xFFFFFF))
    static let textSecondary = Color.theoCheDo(sang: Color(hex: 0x56565F), toi: Color(hex: 0x9999A6))
    static let textTertiary = Color.theoCheDo(sang: Color(hex: 0x81818C), toi: Color(hex: 0x737380))

    /// Chữ/biểu tượng đặt TRÊN nền thương hiệu (nút tím, huy hiệu đỏ, lớp phủ
    /// đen trên ảnh). Luôn trắng ở cả hai chế độ — đừng thay bằng textPrimary,
    /// ở chế độ sáng textPrimary là màu gần đen và sẽ chìm vào nền tím.
    static let onPrimary = Color.white

    // Status Colors
    static let success = Color.theoCheDo(sang: Color(hex: 0x1A8F35), toi: Color(hex: 0x33C759))
    static let error = Color.theoCheDo(sang: Color(hex: 0xD32F2F), toi: Color(hex: 0xEE4444))
    static let warning = Color.theoCheDo(sang: Color(hex: 0xB47600), toi: Color(hex: 0xFAD129))

    // UI Elements
    static let divider = Color.theoCheDo(sang: Color.black.opacity(0.10), toi: Color.white.opacity(0.12))
    static let border = Color.theoCheDo(sang: Color.black.opacity(0.08), toi: Color.white.opacity(0.10))
    static let overlay = Color.black.opacity(0.5)

    // Reaction Colors
    static let like = primary
    static let love = Color.theoCheDo(sang: Color(hex: 0xD32F2F), toi: Color(hex: 0xF54336))
    static let haha = Color.theoCheDo(sang: Color(hex: 0xB47600), toi: Color(hex: 0xFAD129))
    static let sad = Color.theoCheDo(sang: Color(hex: 0x2E6FD9), toi: Color(hex: 0x408CFA))
    static let angry = Color.theoCheDo(sang: Color(hex: 0xD32F2F), toi: Color(hex: 0xEE4444))

    /// Dải gradient thương hiệu — dùng ở nút chính và logo.
    static let brandGradient = LinearGradient(
        colors: [primary, secondary],
        startPoint: .leading,
        endPoint: .trailing,
    )
}

// MARK: Typography
extension Font {
    // Display
    static let displayLarge = Font.system(size: 34, weight: .bold)
    static let displayMedium = Font.system(size: 28, weight: .bold)
    static let displaySmall = Font.system(size: 24, weight: .semibold)

    // Title
    static let titleLarge = Font.system(size: 22, weight: .semibold)
    static let titleMedium = Font.system(size: 18, weight: .semibold)
    static let titleSmall = Font.system(size: 16, weight: .semibold)

    // Body
    static let bodyLarge = Font.system(size: 16, weight: .regular)
    static let bodyMedium = Font.system(size: 14, weight: .regular)
    static let bodySmall = Font.system(size: 12, weight: .regular)
    static let bodyText = Font.system(size: 16, weight: .regular)

    // Button & Caption
    static let buttonText = Font.system(size: 16, weight: .semibold)
    static let buttonSmall = Font.system(size: 14, weight: .medium)
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionBold = Font.system(size: 12, weight: .semibold)
}

// MARK: Shadows
struct Shadows {
    static let small = (color: Color.black.opacity(0.1), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
    static let medium = (color: Color.black.opacity(0.15), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    static let large = (color: Color.black.opacity(0.2), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    static let glow = (color: AppColors.primary.opacity(0.3), radius: CGFloat(20), x: CGFloat(0), y: CGFloat(0))
}

// MARK: - View Modifiers
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.backgroundCard)
            .cornerRadius(CornerRadius.large)
    }
}

struct PrimaryButtonModifier: ViewModifier {
    let isLoading: Bool
    func body(content: Content) -> some View {
        content
            .font(.buttonText)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(CornerRadius.medium)
            .opacity(isLoading ? 0.7 : 1.0)
    }
}

struct SecondaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.buttonText)
            .foregroundColor(AppColors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(AppColors.primary, lineWidth: 1)
            )
    }
}

struct InputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    func primaryButtonStyle(isLoading: Bool = false) -> some View {
        modifier(PrimaryButtonModifier(isLoading: isLoading))
    }

    func secondaryButtonStyle() -> some View {
        modifier(SecondaryButtonModifier())
    }

    func inputFieldStyle() -> some View {
        modifier(InputFieldModifier())
    }
}

// MARK: - Animations
struct AppAnimations {
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let easeOut = Animation.easeOut(duration: 0.25)
    static let easeInOut = Animation.easeInOut(duration: 0.3)
    static let quick = Animation.easeInOut(duration: 0.15)
}

// MARK: - Platform Helpers
#if os(iOS)
typealias PlatformColor = Color
typealias PlatformFont = Font
#elseif os(macOS)
typealias PlatformColor = Color
typealias PlatformFont = Font
#endif
