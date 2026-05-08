import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.headlineFont)
            .foregroundStyle(.white)
            .padding(.vertical, AppTheme.paddingM)
            .padding(.horizontal, AppTheme.paddingL)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous)
                    .fill(AppTheme.tealPurpleGradient)
                    .brightness(configuration.isPressed ? -0.05 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.headlineFont)
            .foregroundStyle(AppTheme.accentTeal)
            .padding(.vertical, AppTheme.paddingM)
            .padding(.horizontal, AppTheme.paddingL)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous)
                    .fill(AppTheme.accentTeal.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous)
                    .strokeBorder(AppTheme.accentTeal.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
