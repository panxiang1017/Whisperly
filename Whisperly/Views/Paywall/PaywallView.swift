import SwiftUI

struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.paddingL) {
                // Hero
                VStack(spacing: AppTheme.paddingM) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.proGradientStart, AppTheme.proGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(String(localized: "Whisperly Pro"))
                        .font(AppTheme.largeTitleFont)

                    Text(String(localized: "Unlock unlimited recording time"))
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppTheme.paddingXL)

                // Features
                VStack(alignment: .leading, spacing: AppTheme.paddingM) {
                    FeatureRow(
                        icon: "infinity",
                        title: String(localized: "Unlimited recording"),
                        subtitle: String(localized: "No time limits on your meetings")
                    )
                    FeatureRow(
                        icon: "arrow.up.circle",
                        title: String(localized: "All future updates"),
                        subtitle: String(localized: "New features included forever")
                    )
                    FeatureRow(
                        icon: "lock.shield",
                        title: String(localized: "100% on-device"),
                        subtitle: String(localized: "Your data never leaves your device")
                    )
                    FeatureRow(
                        icon: "dollarsign.circle",
                        title: String(localized: "One-time purchase"),
                        subtitle: String(localized: "No subscription, no recurring fees")
                    )
                }
                .padding(AppTheme.paddingL)
                .cardStyle()
                .padding(.horizontal, AppTheme.paddingM)

                // Price + Purchase button
                VStack(spacing: AppTheme.paddingM) {
                    if let product = store.product {
                        Text(product.displayPrice)
                            .font(AppTheme.largeTitleFont)

                        Text(String(localized: "One-time purchase. Forever."))
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.secondaryText)

                        Button {
                            Task {
                                try? await store.purchase()
                                if store.isPro {
                                    dismiss()
                                }
                            }
                        } label: {
                            Text(String(localized: "Purchase"))
                                .font(AppTheme.headlineFont)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.paddingM)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.proGradientStart, AppTheme.proGradientEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous))
                        }
                        .disabled(store.isLoading)
                        .padding(.horizontal, AppTheme.paddingL)
                    } else if store.isLoading {
                        ProgressView()
                    }

                    // Restore
                    Button {
                        Task { await store.restorePurchases() }
                    } label: {
                        Text(String(localized: "Restore Purchases"))
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.accent)
                    }

                    if let error = store.purchaseError {
                        Text(error)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.destructive)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.paddingL)
                    }
                }

                // Legal links
                VStack(spacing: AppTheme.paddingS) {
                    Link(String(localized: "Privacy Policy"), destination: URL(string: "https://panxiang1017.github.io/StaticPage/privacy-policy.html")!)
                        .font(AppTheme.captionFont)
                    Link(String(localized: "Terms of Use"), destination: URL(string: "https://panxiang1017.github.io/StaticPage/terms-of-use.html")!)
                        .font(AppTheme.captionFont)
                }
                .padding(.bottom, AppTheme.paddingL)
            }
        }
        .navigationTitle(String(localized: "Go Pro"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Close")) { dismiss() }
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AppTheme.paddingM) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.headlineFont)
                Text(subtitle)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}
