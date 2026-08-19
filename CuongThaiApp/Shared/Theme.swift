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
struct AppColors {
    // Primary Brand Colors
    static let primary = Color(red: 0.55, green: 0.35, blue: 0.96) // #8C5AF0 - Purple
    static let primaryDark = Color(red: 0.45, green: 0.25, blue: 0.86)
    static let primaryLight = Color(red: 0.65, green: 0.45, blue: 1.0)

    // Secondary Colors
    static let secondary = Color(red: 0.13, green: 0.83, blue: 0.93) // Cyan
    static let accent = Color(red: 1.0, green: 0.6, blue: 0.2) // Orange

    // Background Colors
    static let backgroundPrimary = Color(red: 0.04, green: 0.04, blue: 0.08) // #0a0a14
    static let backgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.12) // #141420
    static let backgroundTertiary = Color(red: 0.1, green: 0.1, blue: 0.14) // #1a1a24
    static let backgroundCard = Color(red: 0.1, green: 0.1, blue: 0.14)

    // Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.6, green: 0.6, blue: 0.65)
    static let textTertiary = Color(red: 0.45, green: 0.45, blue: 0.5)

    // Status Colors
    static let success = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let error = Color(red: 0.93, green: 0.26, blue: 0.26)
    static let warning = Color(red: 0.98, green: 0.82, blue: 0.16)

    // UI Elements
    static let divider = Color.gray.opacity(0.2)
    static let border = Color.gray.opacity(0.15)
    static let overlay = Color.black.opacity(0.5)

    // Reaction Colors
    static let like = Color(red: 0.55, green: 0.35, blue: 0.96)
    static let love = Color(red: 0.96, green: 0.26, blue: 0.21)
    static let haha = Color(red: 0.98, green: 0.82, blue: 0.16)
    static let sad = Color(red: 0.25, green: 0.55, blue: 0.98)
    static let angry = Color(red: 0.93, green: 0.26, blue: 0.26)
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
