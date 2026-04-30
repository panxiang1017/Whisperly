import SwiftUI

struct SettingsView: View {
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
                        .foregroundStyle(AppTheme.accent)
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Label(String(localized: "Upgrade to Pro"), systemImage: "star.fill")
                    }

                    Button {
                        Task { await store.restorePurchases() }
                    } label: {
                        Label(String(localized: "Restore Purchases"), systemImage: "arrow.clockwise")
                    }
                }
            } header: {
                Text(String(localized: "Subscription"))
            }

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
            } header: {
                Text(String(localized: "Sync"))
            }

            #if os(macOS)
            // System audio capture (macOS only)
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
            } header: {
                Text(String(localized: "Audio Capture"))
            }
            #endif

            // Model management
            ModelManagementSection(modelManager: modelManager)

            // About
            Section {
                LabeledContent(String(localized: "Version"), value: appVersion)

                Link(destination: URL(string: "https://panxiang1017.github.io/StaticPage/privacy-policy.html")!) {
                    Label(String(localized: "Privacy Policy"), systemImage: "hand.raised")
                }

                Link(destination: URL(string: "https://panxiang1017.github.io/StaticPage/terms-of-use.html")!) {
                    Label(String(localized: "Terms of Use"), systemImage: "doc.text")
                }
            } header: {
                Text(String(localized: "About"))
            }
        }
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
