import SwiftUI

struct SettingsView: View {
    @Environment(StoreManager.self) private var store
    @State private var showPaywall = false

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
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
