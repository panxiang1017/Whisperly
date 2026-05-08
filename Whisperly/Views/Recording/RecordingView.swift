import SwiftUI

struct RecordingView: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    var onMeetingSaved: ((Meeting) -> Void)?

    var body: some View {
        ZStack {
            // Background with center glow
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            RadialGradient(
                colors: [AppTheme.accentTeal.opacity(0.03), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: AppTheme.paddingL) {
                Spacer()

                // Circular waveform visualizer
                CircularWaveformView(level: viewModel.audioLevel)
                    .frame(width: 220, height: 220)

                // Elapsed time
                Text(viewModel.formattedElapsed)
                    .font(.system(size: 56, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.9))

                // Free tier progress bar
                if viewModel.showCountdown {
                    RecordingProgressBar(
                        progress: Double(viewModel.elapsedSeconds) / Double(AppTheme.freeRecordingLimitSeconds),
                        remainingText: viewModel.formattedRemaining,
                        isUrgent: viewModel.isCountdownUrgent
                    )
                    .padding(.horizontal, AppTheme.paddingXL)
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
        }
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

// MARK: - Circular Waveform Visualizer

struct CircularWaveformView: View {
    let level: Float
    @State private var breathe: Double = 0.3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 2.0

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius = min(size.width, size.height) / 2 * 0.6
                let normalizedLevel = CGFloat(max(0.05, min(1.0, level)))
                let amplitude = normalizedLevel * baseRadius * 0.3

                // Outer glow ring
                let glowPath = wavyCirclePath(
                    center: center,
                    baseRadius: baseRadius + 6,
                    amplitude: amplitude * 0.4,
                    phase: phase * 0.8,
                    segments: 100
                )
                context.stroke(
                    glowPath,
                    with: .color(Color(red: 0.0, green: 0.898, blue: 0.8).opacity(0.15)),
                    lineWidth: 10
                )

                // Main waveform ring
                let mainPath = wavyCirclePath(
                    center: center,
                    baseRadius: baseRadius,
                    amplitude: amplitude,
                    phase: phase,
                    segments: 120
                )
                let gradient = Gradient(colors: [
                    Color(red: 0.0, green: 0.898, blue: 0.8),
                    Color(red: 0.486, green: 0.227, blue: 0.929),
                ])
                context.stroke(
                    mainPath,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    ),
                    lineWidth: 3
                )

                // Inner subtle ring
                let innerPath = wavyCirclePath(
                    center: center,
                    baseRadius: baseRadius * 0.82,
                    amplitude: amplitude * 0.2,
                    phase: phase * 1.3,
                    segments: 80
                )
                context.stroke(
                    innerPath,
                    with: .color(Color.white.opacity(0.06)),
                    lineWidth: 1
                )

                // Center dot
                let dotRect = CGRect(
                    x: center.x - 3,
                    y: center.y - 3,
                    width: 6,
                    height: 6
                )
                context.fill(
                    Circle().path(in: dotRect),
                    with: .color(Color(red: 0.0, green: 0.898, blue: 0.8).opacity(0.5))
                )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                breathe = 0.7
            }
        }
    }

    private func wavyCirclePath(
        center: CGPoint,
        baseRadius: CGFloat,
        amplitude: CGFloat,
        phase: Double,
        segments: Int
    ) -> Path {
        Path { p in
            for i in 0...segments {
                let angle = Double(i) / Double(segments) * 2 * .pi
                let wave = sin(angle * 6 + phase) * Double(amplitude)
                    + sin(angle * 3 + phase * 0.7) * Double(amplitude) * 0.5
                let r = Double(baseRadius) + wave
                let point = CGPoint(
                    x: Double(center.x) + r * cos(angle),
                    y: Double(center.y) + r * sin(angle)
                )
                if i == 0 {
                    p.move(to: point)
                } else {
                    p.addLine(to: point)
                }
            }
            p.closeSubpath()
        }
    }
}

// MARK: - Recording Progress Bar

struct RecordingProgressBar: View {
    let progress: Double
    let remainingText: String
    var isUrgent: Bool = false

    var body: some View {
        HStack(spacing: AppTheme.paddingS) {
            Circle()
                .fill(isUrgent ? AppTheme.destructive : AppTheme.accentTeal)
                .frame(width: 6, height: 6)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.divider)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            isUrgent
                                ? LinearGradient(colors: [AppTheme.destructive, AppTheme.destructive.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [AppTheme.accentTeal, AppTheme.accentPurple], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(0, geo.size.width * min(1.0, progress)), height: 4)
                }
            }
            .frame(height: 4)

            Text(remainingText)
                .font(AppTheme.timestampFont)
                .monospacedDigit()
                .foregroundStyle(isUrgent ? AppTheme.destructive : AppTheme.inactiveText)
                .fixedSize()
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
        .padding(.horizontal, AppTheme.paddingM)
        .padding(.vertical, AppTheme.paddingS)
        .premiumGlassCard(cornerRadius: AppTheme.cornerRadiusL)
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

                // Glow ring (teal-purple gradient)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [AppTheme.accentTeal.opacity(0.5), AppTheme.accentPurple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: AppTheme.recordButtonSize + 8, height: AppTheme.recordButtonSize + 8)

                // Red fill (slightly desaturated)
                Circle()
                    .fill(Color(red: 0.85, green: 0.2, blue: 0.2))
                    .frame(width: AppTheme.recordButtonSize, height: AppTheme.recordButtonSize)

                // Stop square (smaller)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.white)
                    .frame(width: 20, height: 20)
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
        .premiumGlassCard(cornerRadius: AppTheme.cornerRadiusL)
    }
}
