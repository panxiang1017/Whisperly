import SwiftUI

/// Displays model download status and provides controls for downloading,
/// retrying, or deleting the WhisperKit transcription model.
struct ModelDownloadView: View {
    @Bindable var modelManager: ModelManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: AppTheme.paddingL) {
            Spacer()

            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.accent)

            Text(String(localized: "Transcription Model Required"))
                .font(AppTheme.titleFont)
                .multilineTextAlignment(.center)

            Text(String(localized: "Whisperly needs to download a speech recognition model to transcribe your meetings on-device."))
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.paddingL)

            // Model info card
            VStack(spacing: AppTheme.paddingS) {
                HStack {
                    Text(String(localized: "Model"))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                    Text(modelManager.whisperModelName)
                        .font(AppTheme.headlineFont)
                }

                HStack {
                    Text(String(localized: "Size"))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                    Text(ModelManager.estimatedModelSize(for: modelManager.whisperModelName))
                        .font(AppTheme.bodyFont)
                }
            }
            .padding(AppTheme.paddingM)
            .cardStyle()
            .padding(.horizontal, AppTheme.paddingL)

            Spacer()

            // Action area
            switch modelManager.whisperModelState {
            case .notDownloaded:
                Button {
                    Task { await modelManager.downloadWhisperModel() }
                } label: {
                    Label(String(localized: "Download Model"), systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppTheme.paddingL)

            case .downloading(let progress):
                VStack(spacing: AppTheme.paddingS) {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .padding(.horizontal, AppTheme.paddingL)

                    Text(String(localized: "Downloading... \(Int(progress * 100))%"))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.secondaryText)

                    Button {
                        modelManager.cancelDownload()
                    } label: {
                        Text(String(localized: "Cancel"))
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

            case .ready:
                Label(String(localized: "Model ready"), systemImage: "checkmark.circle.fill")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(.green)

            case .failed(let message):
                VStack(spacing: AppTheme.paddingS) {
                    Label(String(localized: "Download failed"), systemImage: "exclamationmark.triangle.fill")
                        .font(AppTheme.headlineFont)
                        .foregroundStyle(AppTheme.destructive)

                    Text(message)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)

                    Button {
                        Task { await modelManager.downloadWhisperModel() }
                    } label: {
                        Label(String(localized: "Retry"), systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, AppTheme.paddingL)
                }
            }

            Spacer()
                .frame(height: AppTheme.paddingXL)
        }
        .padding()
        .navigationTitle(String(localized: "Model Download"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel")) {
                    dismiss()
                }
            }
        }
    }
}

/// Settings section for managing downloaded models.
struct ModelManagementSection: View {
    @Bindable var modelManager: ModelManager

    var body: some View {
        Section {
            LabeledContent(String(localized: "Model"), value: modelManager.whisperModelName)

            switch modelManager.whisperModelState {
            case .ready:
                LabeledContent(
                    String(localized: "Status"),
                    value: String(localized: "Downloaded")
                )

                Button(role: .destructive) {
                    try? modelManager.deleteWhisperModel()
                } label: {
                    Label(String(localized: "Delete Model"), systemImage: "trash")
                }

            case .notDownloaded:
                Button {
                    Task { await modelManager.downloadWhisperModel() }
                } label: {
                    Label(String(localized: "Download Model"), systemImage: "arrow.down.circle")
                }

            case .downloading(let progress):
                HStack {
                    ProgressView(value: progress, total: 1.0)
                    Text("\(Int(progress * 100))%")
                        .font(AppTheme.captionFont)
                        .monospacedDigit()
                }

            case .failed:
                Button {
                    Task { await modelManager.downloadWhisperModel() }
                } label: {
                    Label(String(localized: "Retry Download"), systemImage: "arrow.clockwise")
                }
            }
        } header: {
            Text(String(localized: "Transcription Model"))
        }
    }
}
