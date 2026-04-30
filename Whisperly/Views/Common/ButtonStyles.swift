import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.headlineFont)
            .foregroundStyle(.white)
            .padding(.vertical, AppTheme.paddingM)
            .padding(.horizontal, AppTheme.paddingL)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.headlineFont)
            .foregroundStyle(AppTheme.accent)
            .padding(.vertical, AppTheme.paddingM)
            .padding(.horizontal, AppTheme.paddingL)
            .background(AppTheme.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
