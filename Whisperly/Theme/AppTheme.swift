import SwiftUI

enum AppTheme {
    // MARK: - Colors

    static let accent = Color.accentColor
    #if os(iOS)
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    #else
    static let background = Color(.windowBackgroundColor)
    static let secondaryBackground = Color(.controlBackgroundColor)
    static let primaryText = Color(.labelColor)
    static let secondaryText = Color(.secondaryLabelColor)
    #endif
    static let destructive = Color.red
    static let recording = Color.red
    static let proGradientStart = Color.purple
    static let proGradientEnd = Color.blue

    // MARK: - Typography

    static let largeTitleFont = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let titleFont = Font.system(.title2, design: .rounded, weight: .semibold)
    static let headlineFont = Font.system(.headline, design: .rounded, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .rounded)
    static let captionFont = Font.system(.caption, design: .rounded, weight: .medium)
    static let monoFont = Font.system(.body, design: .monospaced)
    static let countdownFont = Font.system(size: 48, weight: .bold, design: .rounded)

    // MARK: - Spacing

    static let paddingXS: CGFloat = 4
    static let paddingS: CGFloat = 8
    static let paddingM: CGFloat = 16
    static let paddingL: CGFloat = 24
    static let paddingXL: CGFloat = 32

    // MARK: - Corner Radius

    static let cornerRadiusS: CGFloat = 8
    static let cornerRadiusM: CGFloat = 12
    static let cornerRadiusL: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 20

    // MARK: - Shadows

    static let cardShadow = Color.black.opacity(0.06)
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 2

    // MARK: - Tap Targets

    static let minTapTarget: CGFloat = 44
    static let recordButtonSize: CGFloat = 72

    // MARK: - Free Tier

    static let freeRecordingLimitSeconds: Int = 1800 // 30 minutes
}

// MARK: - Card Style Modifier

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusL, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, y: AppTheme.cardShadowY)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
