import SwiftUI

enum AppTheme {
    // MARK: - Background Layers (outermost → innermost)

    static let appBackground      = Color(red: 0.051, green: 0.055, blue: 0.078)  // #0D0E14
    static let windowBackground   = Color(red: 0.075, green: 0.078, blue: 0.110)  // #13141C
    static let sidebarBackground  = Color(red: 0.086, green: 0.090, blue: 0.125)  // #161720
    static let contentBackground  = Color(red: 0.102, green: 0.106, blue: 0.149)  // #1A1B26
    static let cardBackground     = Color(red: 0.118, green: 0.122, blue: 0.180)  // #1E1F2E

    // MARK: - Accent Colors

    static let accentTeal         = Color(red: 0.0, green: 0.898, blue: 0.800)    // #00E5CC
    static let accentPurple       = Color(red: 0.486, green: 0.227, blue: 0.929)  // #7C3AED
    static let speakerTeal        = Color(red: 0.0, green: 0.898, blue: 0.800)    // #00E5CC
    static let speakerPurple      = Color(red: 0.659, green: 0.333, blue: 0.969)  // #A855F7

    // MARK: - Legacy Aliases (keep existing call sites working)

    static let accent             = accentTeal
    static let background         = appBackground
    static let secondaryBackground = cardBackground

    // MARK: - Text

    static let primaryText        = Color.white.opacity(0.95)
    static let secondaryText      = Color.white.opacity(0.50)
    static let inactiveText       = Color.white.opacity(0.35)

    // MARK: - Semantic Colors

    static let destructive        = Color.red
    static let recording          = Color.red

    // MARK: - Gradients

    static let proGradientStart   = accentTeal
    static let proGradientEnd     = accentPurple

    static let tealPurpleGradient = LinearGradient(
        colors: [accentTeal, accentPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Divider

    static let divider            = Color.white.opacity(0.08)

    // MARK: - Typography

    static let largeTitleFont     = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let titleFont          = Font.system(.title2, design: .rounded, weight: .semibold)
    static let headlineFont       = Font.system(.headline, design: .default, weight: .semibold)
    static let bodyFont           = Font.system(.body, design: .default)
    static let captionFont        = Font.system(.caption, design: .default, weight: .medium)
    static let monoFont           = Font.system(.body, design: .monospaced)
    static let timestampFont      = Font.system(.caption, design: .monospaced, weight: .regular)
    static let countdownFont      = Font.system(size: 48, weight: .bold, design: .rounded)

    // MARK: - Spacing

    static let paddingXS: CGFloat  = 4
    static let paddingS: CGFloat   = 8
    static let paddingM: CGFloat   = 16
    static let paddingL: CGFloat   = 24
    static let paddingXL: CGFloat  = 32

    // MARK: - Corner Radius

    static let cornerRadiusS: CGFloat  = 8
    static let cornerRadiusM: CGFloat  = 12
    static let cornerRadiusL: CGFloat  = 16
    static let cornerRadiusXL: CGFloat = 20

    // MARK: - Shadows

    static let cardShadow         = Color.black.opacity(0.25)
    static let cardShadowRadius: CGFloat = 12
    static let cardShadowY: CGFloat = 4

    // MARK: - Tap Targets

    static let minTapTarget: CGFloat    = 44
    static let recordButtonSize: CGFloat = 72

    // MARK: - Free Tier

    static let freeRecordingLimitSeconds: Int = 1800 // 30 minutes
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [AppTheme.accentTeal.opacity(0.06), Color.clear],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 120
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Legacy Card Modifier (preserves .cardStyle() call sites)

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .modifier(GlassCardModifier())
            .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, y: AppTheme.cardShadowY)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
