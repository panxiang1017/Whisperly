# Whisperly - Phase 1 Engineering Brief

> Read this fully before writing any code.
> Read also (in this order): PROJECT_BRIEF.md → MONETIZATION.md → TECH_RESEARCH.md → MARKET_RESEARCH.md

## Goal of Phase 1

Create the **Xcode project skeleton + architecture + first end-to-end vertical slice with mocks**. We are NOT shipping the full app in this phase. The goal is:

- Project compiles cleanly for iOS and macOS
- Architecture is correct (protocol-oriented, DI, SwiftData, StoreKit 2)
- An end-to-end happy path works with **mock services** (record → mock transcribe → mock diarize → mock summary → save → list → detail)
- Paywall + 30-min free countdown + "buy mid-recording removes countdown without restart" UX is fully implemented
- Tests cover the state machine

Phase 2 will integrate WhisperKit + FluidAudio. Phase 3 will integrate Apple Foundation Models + MLX. Don't do those now.

## Engineering Principles (NON-NEGOTIABLE)

- **SOLID, SRP, DIP** strictly
- Protocol-oriented: every external dependency (transcription engine, diarization, LLM, storage, store) goes behind a protocol
- Use dependency injection (constructor or environment), no singletons except 1 app-wide @MainActor coordinator
- SwiftUI + Combine/AsyncSequence for reactive flow
- Swift 6 strict concurrency where reasonable
- Swift 5.10+ / iOS 17+ minimum, but use iOS 18/26 features behind `#available` checks
- ALL user-visible strings via `String(localized:)` and `Localizable.xcstrings`
- No force-unwraps in production code
- No silenced errors

## Reference

`/Users/shrimp/Desktop/code/Conduit/Conduit/` — examine the structure and mirror the patterns:
- `StoreKit/` (StoreManager pattern)
- `Theme/` (AppTheme pattern)
- `Localizable.xcstrings`
- Project layout

## Project Layout

```
Whisperly/
  WhisperlyApp.swift              -- @main, AppDependencies wiring
  AppDependencies.swift           -- DI container
  Theme/                          -- AppTheme, colors, typography, spacing
  Models/                         -- SwiftData @Model: Meeting, TranscriptSegment, Speaker, AppSettings
  Services/
    Recording/                    -- RecordingService protocol + AVAudioEngineRecordingService (iOS) + macOS stub
    Transcription/                -- TranscriptionService protocol + MockTranscriptionService
    Diarization/                  -- DiarizationService protocol + MockDiarizationService
    Summarization/                -- SummarizationService protocol + MockSummarizationService
    Storage/                      -- SwiftData stack + MeetingRepository protocol + impl
    Search/                       -- SearchService protocol + stub (real GRDB FTS5 in Phase 2)
    Sync/                         -- SyncCoordinator protocol + stub
    Export/                       -- Exporter protocol + Markdown/Plain impls
    Pipeline/                     -- MeetingPipeline (orchestrates record → transcribe → diarize → summarize → save)
  Store/                          -- StoreKit 2 wrapper
    StoreManager.swift            -- product loading, purchase, restore
    EntitlementService.swift      -- @Published var isPro: Bool, observable
    Products.swift                -- product IDs
  Views/
    Home/HomeView.swift           -- list of meetings + record button
    Recording/RecordingView.swift -- live recording with countdown, audio meter, stop
    Recording/RecordingViewModel.swift
    Detail/MeetingDetailView.swift
    Paywall/PaywallView.swift
    Settings/SettingsView.swift
    Common/                       -- shared components (Button styles, EmptyState, etc.)
  Localization/
    Localizable.xcstrings         -- en + zh-Hans populated; ja, ko, de, es, fr, pt-BR, ru, zh-Hant stubs
  Assets.xcassets/
    AppIcon                       -- placeholder (1x1 colored square is fine)
    AccentColor
    Symbols/                      -- any custom assets
WhisperlyTests/
  StoreManagerTests.swift
  CountdownTimerTests.swift
  MeetingRepositoryTests.swift
  PipelineTests.swift
```

## Project Settings

- **Bundle ID**: `ai.dxy.Whisperly`
- **Deployment**: iOS 17+, iPadOS 17+, macOS 14+ (Apple Silicon only — set arch to `arm64`)
- **Swift**: 6.0
- **App categories**: Productivity (primary), Business (secondary)
- **Capabilities**: Microphone, Speech Recognition, CloudKit (off by default), Background Modes (audio)
- **Entitlements**:
  - `com.apple.security.device.audio-input` (macOS)
  - `com.apple.developer.icloud-services` (CloudKit, optional)
  - App Sandbox enabled (macOS)

## Info.plist

- `NSMicrophoneUsageDescription`: "Whisperly records meetings 100% on-device. Your audio never leaves your Mac, iPad, or iPhone."
- `NSSpeechRecognitionUsageDescription`: "Used to transcribe your meeting audio entirely on-device."
- `UIBackgroundModes`: `audio`

## Data Model (SwiftData)

```swift
@Model
final class Meeting {
    var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var audioFileURL: URL?
    var summary: String
    var keyPoints: [String]      // store as transformable or join model
    var actionItems: [String]
    var language: String          // BCP-47
    @Relationship(deleteRule: .cascade) var segments: [TranscriptSegment]
    @Relationship(deleteRule: .cascade) var speakers: [Speaker]
}

@Model
final class TranscriptSegment {
    var id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var speakerID: UUID?
    var meeting: Meeting?
}

@Model
final class Speaker {
    var id: UUID
    var label: String       // "Speaker 1", or user-edited "Sharp"
    var colorHex: String
    var meeting: Meeting?
}

@Model
final class AppSettings {
    var iCloudSyncEnabled: Bool
    var preferredLanguage: String?
    var summaryStyle: String        // "concise" | "detailed" | "bullet"
    // ...
}
```

## Critical UX: Free Countdown + Mid-Purchase Upgrade

The most important UX detail in Phase 1:

```
RecordingViewModel
  ├─ records timestamp of recording start
  ├─ subscribes to entitlement.isPro publisher
  ├─ if !isPro:
  │    show countdown UI: 30:00 → 0:00
  │    when remainingSeconds == 0 → call recorder.stop() + finalize
  │    when remainingSeconds < 5 min → red + pulsing
  ├─ if user buys mid-recording:
  │    entitlement.isPro flips to true
  │    countdown UI fades out (animation)
  │    recording continues UNINTERRUPTED (no restart, no buffer flush)
  │    new max duration = unlimited
  └─ on stop, all transcript so far is preserved
```

Implementation hints:
- Use a `Combine` publisher or `AsyncStream` for the countdown
- The audio engine itself should NOT be stopped/restarted on entitlement change
- Just toggle the UI overlay

## StoreKit 2

```swift
struct WhisperlyProducts {
    static let lifetime = "ai.dxy.whisperly.lifetime"
    static let all: Set<String> = [lifetime]
}
```

`StoreManager`:
- Loads products on init
- `purchase(_ product: Product) async throws -> Transaction?`
- `restore() async throws`
- Observes `Transaction.updates` and updates `EntitlementService.isPro`

`EntitlementService`:
- `@Published var isPro: Bool`
- Reads from UserDefaults on init for fast UX, then re-validates from StoreKit
- For tests, accept a mock implementation injected

## Pipeline (Mocks)

```swift
protocol RecordingService {
    func start() async throws
    func stop() async throws -> URL
    var levelStream: AsyncStream<Float> { get }
    var isRecording: Bool { get }
}

protocol TranscriptionService {
    func transcribe(audioURL: URL, language: String?) async throws -> [TranscriptSegment]
}

protocol DiarizationService {
    func diarize(audioURL: URL, segments: [TranscriptSegment]) async throws -> ([TranscriptSegment], [Speaker])
}

protocol SummarizationService {
    func summarize(transcript: [TranscriptSegment]) async throws -> MeetingSummary
}

struct MeetingSummary {
    let summary: String
    let keyPoints: [String]
    let actionItems: [String]
}
```

`MockTranscriptionService` returns hardcoded segments after a 2s delay.
`MockDiarizationService` randomly assigns speaker IDs to segments.
`MockSummarizationService` returns hardcoded summary after a 1s delay.

## Tests (Swift Testing)

```swift
import Testing
@testable import Whisperly

@Test("Free user countdown reaches zero stops recording")
func countdownStopsRecording() async throws { ... }

@Test("Pro upgrade mid-countdown removes timer without interrupting")
func proUpgradeMidCountdown() async throws { ... }

@Test("Restore purchases sets isPro=true when transaction found")
func restorePurchases() async throws { ... }

@Test("Repository CRUD")
func repositoryCRUD() async throws { ... }

@Test("Pipeline produces meeting end-to-end with mocks")
func pipelineEndToEnd() async throws { ... }
```

## Build Verification (must pass before you finish)

```bash
cd /Users/shrimp/Desktop/code/Whisperly
xcodebuild -scheme Whisperly -destination 'generic/platform=iOS' -configuration Debug build
xcodebuild -scheme Whisperly -destination 'generic/platform=macOS' -configuration Debug build
xcodebuild test -scheme Whisperly -destination 'platform=iOS Simulator,id=FDD60F1A-B8D6-431C-A055-AC63117E843F'
```

If you hit Xcode signing issues, set the project to "Automatic signing" with team `D8F9APCM27` (matches Conduit). If you can't sign, set `CODE_SIGN_IDENTITY=""` `CODE_SIGNING_REQUIRED=NO` for the build verification step.

## Final Report Format

When done, write a `PHASE1_REPORT.md` in `/Users/shrimp/Desktop/code/Whisperly/` with:

1. **Project structure tree** (`tree -L 3 Whisperly`)
2. **Files created** (count + list of key ones)
3. **Build status** for iOS and macOS (output snippets)
4. **Test pass/fail count** (output snippets)
5. **What works end-to-end** (the manual steps to verify)
6. **What's mocked** + protocol seams ready for Phase 2
7. **Deviations from spec** + reasoning
8. **Open questions for Sharp**

Then commit everything with a clean git history (sensible commit messages).

## Workflow

1. Read all 4 .md docs in `/Users/shrimp/Desktop/code/Whisperly/` (especially TECH_RESEARCH.md)
2. Examine `/Users/shrimp/Desktop/code/Conduit/Conduit/` patterns
3. Create Xcode project (use `xcodegen` if helpful, or hand-craft pbxproj — your call)
4. Implement structure, models, mocks, store, UI, localization, tests
5. Build for iOS + macOS — fix all errors
6. Run tests
7. Write PHASE1_REPORT.md
8. Commit (multiple atomic commits preferred over one giant commit)
9. Notify Sharp via the wake hook below

## Wake Hook (run when COMPLETELY done)

```bash
openclaw system event --text "Whisperly Phase 1 done — see PHASE1_REPORT.md" --mode now
```
