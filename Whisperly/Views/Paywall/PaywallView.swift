import SwiftUI

struct PaywallView: View {
    private static let privacyPolicyURL = URL(string: "https://panxiang1017.github.io/StaticPage/privacy-policy.html")
    private static let termsOfUseURL = URL(string: "https://panxiang1017.github.io/StaticPage/terms-of-use.html")

    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var heroGlow: Double = 0.4
    @State private var buttonHovered = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.paddingL) {
                // Hero
                VStack(spacing: AppTheme.paddingM) {
                    ZStack {
                        // Glow background
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        AppTheme.accentTeal.opacity(heroGlow * 0.2),
                                        AppTheme.accentPurple.opacity(heroGlow * 0.1),
                                        Color.clear,
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)

                        // Shield + waveform
                        ZStack {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 64, weight: .thin))
                                .foregroundStyle(AppTheme.tealPurpleGradient)

                            Image(systemName: "waveform")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(AppTheme.accentTeal)
                                .offset(x: 2, y: 2)
                        }
                        .shadow(color: AppTheme.accentTeal.opacity(0.3), radius: 20)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                            heroGlow = 1.0
                        }
                    }

                    // Gradient title
                    Text(String(localized: "Whisperly Pro"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.tealPurpleGradient)

                    Text(String(localized: "Unlock unlimited recording time"))
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppTheme.paddingXL)

                // Features in premium glass card
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
                .premiumGlassCard()
                .padding(.horizontal, AppTheme.paddingM)

                // Price + Purchase button
                VStack(spacing: AppTheme.paddingM) {
                    if let product = store.product {
                        Text(product.displayPrice)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.tealPurpleGradient)

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
                                .font(.system(.headline, design: .default, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous)
                                        .fill(AppTheme.tealPurpleGradient)
                                        .brightness(buttonHovered ? 0.1 : 0)
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusM, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isLoading)
                        .onHover { hovering in buttonHovered = hovering }
                        .padding(.horizontal, AppTheme.paddingL)
                    } else if store.isLoading {
                        ProgressView()
                            .tint(AppTheme.accentTeal)
                    }

                    // Restore
                    Button {
                        Task { await store.restorePurchases() }
                    } label: {
                        Text(String(localized: "Restore Purchases"))
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.accentTeal)
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
                    if let url = Self.privacyPolicyURL {
                        Link(String(localized: "Privacy Policy"), destination: url)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.inactiveText)
                    }
                    if let url = Self.termsOfUseURL {
                        Link(String(localized: "Terms of Use"), destination: url)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.inactiveText)
                    }
                }
                .padding(.bottom, AppTheme.paddingL)
            }
        }
        .background(AppTheme.backgroundGradient)
        .navigationTitle(String(localized: "Go Pro"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Close")) { dismiss() }
                    .foregroundStyle(AppTheme.secondaryText)
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
            // Glowing icon circle
            ZStack {
                Circle()
                    .fill(AppTheme.accentTeal.opacity(0.12))
                    .frame(width: 40, height: 40)
                Circle()
                    .strokeBorder(AppTheme.accentTeal.opacity(0.2), lineWidth: 0.5)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.accentTeal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.primaryText)
                Text(subtitle)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}
