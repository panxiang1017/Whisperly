import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AppTheme.paddingM) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(AppTheme.inactiveText)

            Text(title)
                .font(AppTheme.titleFont)
                .foregroundStyle(AppTheme.primaryText)

            Text(message)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.paddingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
