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
                PipelineStageIndicator(stage: stage)
                    .transition(.opacity)
            }

            // Stop button
            if viewModel.isRecording {
                RecordingStopButton {
                    Task {
                        if let meeting = await viewModel.stopRecording() {
                            onMeetingSaved?(meeting)
                            dismiss()
                        }
                    }
                }
            }

            // Privacy hint
            PrivacyHintCard()
                .padding(.horizontal, AppTheme.paddingM)

            Spacer()
                .frame(height: AppTheme.paddingM)
        }
        .padding()
        .background(AppTheme.appBackground)
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
                    .foregroundStyle(AppTheme.secondaryText)
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
    }
}

// MARK: - Pipeline Stage Indicator

struct PipelineStageIndicator: View {
    let stage: PipelineStage
    @State private var glowPulse = false

    var body: some View {
        HStack(spacing: AppTheme.paddingS) {
            Circle()
                .fill(AppTheme.accentTeal)
                .frame(width: 8, height: 8)
                .shadow(color: AppTheme.accentTeal.opacity(glowPulse ? 0.8 : 0.3), radius: glowPulse ? 8 : 4)

            Text(stageDescription)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var stageDescription: String {
        switch stage {
        case .transcribing: String(localized: "Transcribing audio...")
        case .diarizing: String(localized: "Identifying speakers...")
        case .summarizing: String(localized: "Generating summary...")
        case .saving: String(localized: "Saving meeting...")
        case .completed: String(localized: "Done!")
        }
    }
}

// MARK: - Recording Stop Button

struct RecordingStopButton: View {
    let action: () -> Void
    @State private var pulseRing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulse ring
                Circle()
                    .strokeBorder(AppTheme.recording.opacity(pulseRing ? 0.0 : 0.4), lineWidth: 2)
                    .frame(width: AppTheme.recordButtonSize + 16, height: AppTheme.recordButtonSize + 16)
                    .scaleEffect(pulseRing ? 1.3 : 1.0)

                // Glow ring
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [AppTheme.accentTeal.opacity(0.4), AppTheme.accentPurple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: AppTheme.recordButtonSize + 8, height: AppTheme.recordButtonSize + 8)

                // Red fill
                Circle()
                    .fill(AppTheme.recording)
                    .frame(width: AppTheme.recordButtonSize, height: AppTheme.recordButtonSize)

                // Stop square
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white)
                    .frame(width: 26, height: 26)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Stop recording"))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseRing = true
            }
        }
    }
}

// MARK: - Privacy Hint Card

struct PrivacyHintCard: View {
    var body: some View {
        HStack(spacing: AppTheme.paddingS) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.body)
                .foregroundStyle(AppTheme.accentTeal)

            Text(String(localized: "On-device processing — your data never leaves this Mac"))
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, AppTheme.paddingM)
        .padding(.vertical, AppTheme.paddingS)
        .glassCard()
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
                        .shadow(color: barGlow(for: normalizedIndex), radius: 6)
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
        }
        // Gradient from teal to purple based on position
        let teal = AppTheme.accentTeal
        let purple = AppTheme.accentPurple
        return position < 0.5
            ? teal.opacity(Double(1.0 - position))
            : purple.opacity(Double(position))
    }

    private func barGlow(for position: Float) -> Color {
        if level > 0.7 {
            return AppTheme.destructive.opacity(0.4)
        }
        return position < 0.5
            ? AppTheme.accentTeal.opacity(0.5)
            : AppTheme.accentPurple.opacity(0.5)
    }
}
