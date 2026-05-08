import SwiftUI

struct SettingsView: View {
    private static let privacyPolicyURL = URL(string: "https://panxiang1017.github.io/StaticPage/privacy-policy.html")
    private static let termsOfUseURL = URL(string: "https://panxiang1017.github.io/StaticPage/terms-of-use.html")

    @Environment(StoreManager.self) private var store
    @State private var showPaywall = false
    @State private var showRestartAlert = false
    @Bindable var modelManager: ModelManager

    var body: some View {
        Form {
            // Pro status
            Section {
                if store.isPro {
                    Label(String(localized: "Whisperly Pro"), systemImage: "checkmark.seal.fill")
                        .foregroundStyle(AppTheme.accentTeal)
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Label(String(localized: "Upgrade to Pro"), systemImage: "star.fill")
                            .foregroundStyle(AppTheme.accentTeal)
                    }

                    Button {
                        Task { await store.restorePurchases() }
                    } label: {
                        Label(String(localized: "Restore Purchases"), systemImage: "arrow.clockwise")
                    }
                }
            } header: {
                Text(String(localized: "Pro Status"))
            }

            // Summarization engine
            SummarizationEngineSection()

            // iCloud Sync
            Section {
                Toggle(isOn: Binding(
                    get: { CloudKitSyncCoordinator.isSyncEnabled },
                    set: { newValue in
                        let coordinator = CloudKitSyncCoordinator()
                        Task {
                            if newValue {
                                try? await coordinator.enableSync()
                            } else {
                                try? await coordinator.disableSync()
                            }
                            showRestartAlert = true
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: AppTheme.paddingXS) {
                        Text(String(localized: "iCloud Sync"))
                        Text(String(localized: "Syncs meeting text across your devices. Audio files stay on-device only."))
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .tint(AppTheme.accentTeal)
            } header: {
                Text(String(localized: "Sync"))
            }

            #if os(macOS)
            Section {
                Toggle(isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "captureSystemAudio") },
                    set: { UserDefaults.standard.set($0, forKey: "captureSystemAudio") }
                )) {
                    VStack(alignment: .leading, spacing: AppTheme.paddingXS) {
                        Text(String(localized: "Record System Audio"))
                        Text(String(localized: "Capture audio from video calls (Zoom, Meet, etc.) alongside your microphone."))
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .tint(AppTheme.accentTeal)
            } header: {
                Text(String(localized: "Audio Capture"))
            }
            #endif

            // MLX model management
            MLXModelManagementSection(modelManager: modelManager)

            // About
            Section {
                LabeledContent(String(localized: "Version"), value: appVersion)

                if let url = Self.privacyPolicyURL {
                    Link(destination: url) {
                        Label(String(localized: "Privacy Policy"), systemImage: "hand.raised")
                    }
                }

                if let url = Self.termsOfUseURL {
                    Link(destination: url) {
                        Label(String(localized: "Terms of Use"), systemImage: "doc.text")
                    }
                }
            } header: {
                Text(String(localized: "About"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.windowBackground)
        .navigationTitle(String(localized: "Settings"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView()
            }
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 600)
            #endif
        }
        .alert(
            String(localized: "Restart Required"),
            isPresented: $showRestartAlert
        ) {
            Button(String(localized: "OK")) {}
        } message: {
            Text(String(localized: "Please restart Whisperly for the sync change to take effect."))
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Summarization Engine Section

struct SummarizationEngineSection: View {
    var body: some View {
        Section {
            LabeledContent(String(localized: "Active Engine"), value: SummarizationEngine.currentEngineName)

            VStack(alignment: .leading, spacing: AppTheme.paddingXS) {
                Text(String(localized: "Whisperly automatically uses the best available summarization engine for your device."))
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)

                if !SummarizationEngine.isAppleFoundationModelsAvailable && !SummarizationEngine.isMLXAvailable {
                    Text(String(localized: "Download the MLX model below for AI-powered summaries, or upgrade to a device with Apple Intelligence."))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text(String(localized: "Summarization"))
        }
    }
}

// MARK: - MLX Model Management Section

struct MLXModelManagementSection: View {
    @Bindable var modelManager: ModelManager

    var body: some View {
        Section {
            LabeledContent(String(localized: "Model"), value: modelManager.mlxModelName)
            LabeledContent(String(localized: "Size"), value: ModelManager.estimatedMLXModelSize)

            switch modelManager.mlxModelState {
            case .ready:
                LabeledContent(
                    String(localized: "Status"),
                    value: String(localized: "Downloaded")
                )

                Button(role: .destructive) {
                    try? modelManager.deleteMLXModel()
                } label: {
                    Label(String(localized: "Delete Model"), systemImage: "trash")
                }

            case .notDownloaded:
                VStack(alignment: .leading, spacing: AppTheme.paddingXS) {
                    Text(String(localized: "Not downloaded"))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.secondaryText)

                    Text(String(localized: "The MLX summarization model will be downloaded automatically when first needed, or you can pre-download it here."))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.secondaryText)
                }

            case .downloading(let progress):
                HStack {
                    ProgressView(value: progress, total: 1.0)
                        .tint(AppTheme.accentTeal)
                    Text("\(Int(progress * 100))%")
                        .font(AppTheme.captionFont)
                        .monospacedDigit()
                }

            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.destructive)
            }
        } header: {
            Text(String(localized: "Summarization Model (MLX)"))
        }
    }
}
