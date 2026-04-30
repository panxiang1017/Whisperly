import SwiftUI

struct RecordingView: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    var onMeetingSaved: ((Meeting) -> Void)?

    var body: some View {
        VStack(spacing: AppTheme.paddingL) {
            Spacer()

            // Audio level meter
            AudioLevelView(level: viewModel.audioLevel)
                .frame(height: 120)
                .padding(.horizontal, AppTheme.paddingL)

            // Elapsed time
            Text(viewModel.formattedElapsed)
                .font(AppTheme.countdownFont)
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)

            // Countdown for free users
            if viewModel.showCountdown {
                VStack(spacing: AppTheme.paddingXS) {
                    Text(String(localized: "Free recording limit"))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.secondaryText)

                    Text(viewModel.formattedRemaining)
                        .font(AppTheme.titleFont)
                        .monospacedDigit()
                        .foregroundStyle(viewModel.isCountdownUrgent ? AppTheme.destructive : AppTheme.secondaryText)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.isCountdownUrgent)
                }
                .transition(.opacity.combined(with: .scale))
            }

            Spacer()

            // Pipeline processing indicator
            if viewModel.isProcessing, let stage = viewModel.pipelineStage {
                VStack(spacing: AppTheme.paddingS) {
                    ProgressView()
                    Text(stageDescription(stage))
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .transition(.opacity)
            }

            // Stop button
            if viewModel.isRecording {
                Button {
                    Task {
                        if let meeting = await viewModel.stopRecording() {
                            onMeetingSaved?(meeting)
                            dismiss()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.recording)
                            .frame(width: AppTheme.recordButtonSize, height: AppTheme.recordButtonSize)

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white)
                            .frame(width: 28, height: 28)
                    }
                }
                .accessibilityLabel(String(localized: "Stop recording"))
            }

            Spacer()
                .frame(height: AppTheme.paddingXL)
        }
        .padding()
        .navigationTitle(String(localized: "Recording"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if !viewModel.isRecording && !viewModel.isProcessing {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.startRecording()
        }
        .alert(
            String(localized: "Error"),
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )
        ) {
            Button(String(localized: "OK")) {
                viewModel.error = nil
                dismiss()
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.needsModelDownload },
            set: { viewModel.needsModelDownload = $0 }
        )) {
            NavigationStack {
                ModelDownloadView(modelManager: viewModel.modelManager)
            }
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 500)
            #endif
        }
        .onChange(of: viewModel.modelManager.isReady) { _, isReady in
            if isReady && viewModel.needsModelDownload {
                viewModel.onModelReady()
            }
        }
    }

    private func stageDescription(_ stage: PipelineStage) -> String {
        switch stage {
        case .transcribing: String(localized: "Transcribing audio...")
        case .diarizing: String(localized: "Identifying speakers...")
        case .summarizing: String(localized: "Generating summary...")
        case .saving: String(localized: "Saving meeting...")
        case .completed: String(localized: "Done!")
        }
    }
}

// MARK: - Audio Level Visualization

struct AudioLevelView: View {
    let level: Float
    private let barCount = 30

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let normalizedIndex = Float(index) / Float(barCount)
                    let barHeight = computeBarHeight(
                        index: normalizedIndex,
                        level: level,
                        maxHeight: geometry.size.height
                    )

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(barColor(for: normalizedIndex))
                        .frame(height: barHeight)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func computeBarHeight(index: Float, level: Float, maxHeight: CGFloat) -> CGFloat {
        let distance = abs(index - 0.5) * 2.0
        let amplitude = max(0, level - distance * 0.5)
        let minHeight: CGFloat = 4
        return max(minHeight, CGFloat(amplitude) * maxHeight)
    }

    private func barColor(for position: Float) -> Color {
        if level > 0.7 {
            return AppTheme.destructive
        } else if level > 0.4 {
            return AppTheme.accent
        }
        return AppTheme.accent.opacity(0.6)
    }
}
