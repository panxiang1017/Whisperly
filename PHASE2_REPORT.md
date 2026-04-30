# Whisperly — Phase 2 Report

> Date: 2026-04-30
> Author: Claude (Phase 2 implementation)

---

## 1. Project Structure (Phase 2 additions)

```
Whisperly/
├── Services/
│   ├── Transcription/
│   │   ├── WhisperKitTranscriptionService.swift  ★ NEW — real WhisperKit ASR
│   │   ├── TranscriptionServiceProtocol.swift
│   │   └── MockTranscriptionService.swift
│   ├── Diarization/
│   │   ├── FluidAudioDiarizationService.swift    ★ NEW — real speaker diarization
│   │   ├── DiarizationServiceProtocol.swift
│   │   └── MockDiarizationService.swift
│   ├── Recording/
│   │   ├── AVAudioEngineRecordingService.swift    ★ UPDATED — Core Audio Tap (macOS)
│   │   ├── RecordingServiceProtocol.swift
│   │   └── MockRecordingService.swift
│   ├── Search/
│   │   ├── GRDBSearchService.swift                ★ NEW — FTS5 full-text search
│   │   └── SearchService.swift
│   ├── Sync/
│   │   ├── CloudKitSyncCoordinator.swift          ★ NEW — CloudKit toggle
│   │   └── SyncCoordinator.swift                  (gutted, code moved)
│   ├── ModelManager/
│   │   └── ModelManager.swift                     ★ NEW — model download/management
│   └── Pipeline/
│       └── MeetingPipeline.swift                  ★ UPDATED — FTS5 indexing
├── Views/
│   ├── ModelDownload/
│   │   └── ModelDownloadView.swift                ★ NEW — download progress UI
│   ├── Home/
│   │   └── HomeView.swift                         ★ UPDATED — .searchable + FTS5
│   ├── Recording/
│   │   ├── RecordingView.swift                    ★ UPDATED — model readiness check
│   │   └── RecordingViewModel.swift               ★ UPDATED — model gate
│   └── Settings/
│       └── SettingsView.swift                     ★ UPDATED — sync + model + audio sections
├── Models/
│   ├── Meeting.swift                              ★ UPDATED — CloudKit-safe defaults
│   ├── TranscriptSegment.swift                    ★ UPDATED — CloudKit-safe defaults
│   ├── Speaker.swift                              ★ UPDATED — CloudKit-safe defaults
│   └── AppSettings.swift                          ★ UPDATED — CloudKit-safe defaults
├── AppDependencies.swift                          ★ UPDATED — real service defaults
├── WhisperlyApp.swift                             ★ UPDATED — CloudKit-aware container
└── Whisperly.entitlements                         ★ UPDATED — CloudKit + network

WhisperlyTests/
├── GRDBSearchServiceTests.swift                   ★ NEW — 5 FTS5 tests
├── ModelManagerTests.swift                        ★ NEW — 3 model manager tests
├── TestHelpers.swift                              ★ UPDATED — CloudKit-safe container
├── CountdownTimerTests.swift
├── MeetingRepositoryTests.swift
├── PipelineTests.swift
└── StoreManagerTests.swift
```

## 2. Files Created / Modified

**10 new files** + **13 modified files** = 23 files changed

### New Files (10)
| File | Purpose |
|---|---|
| `WhisperKitTranscriptionService.swift` | Real transcription via WhisperKit 0.18.0 |
| `FluidAudioDiarizationService.swift` | Real diarization via FluidAudio 0.14.3 Sortformer |
| `GRDBSearchService.swift` | SQLite FTS5 full-text search via GRDB 7.10.0 |
| `CloudKitSyncCoordinator.swift` | CloudKit sync toggle (default OFF, UserDefaults) |
| `ModelManager.swift` | WhisperKit model download/delete/device-selection |
| `ModelDownloadView.swift` | Download progress UI + Settings model section |
| `GRDBSearchServiceTests.swift` | 5 tests: search, empty, re-index, remove, prefix |
| `ModelManagerTests.swift` | 3 tests: recommended model, sizes, init states |
| (project files) | `project.pbxproj` + `Package.resolved` updated |

### Modified Files (13)
| File | Change |
|---|---|
| `AppDependencies.swift` | Default services: AVAudioEngine, WhisperKit, FluidAudio, GRDB |
| `WhisperlyApp.swift` | CloudKit-aware ModelContainer (`cloudKitDatabase: .none` or `.private(...)`) |
| `MeetingPipeline.swift` | Accepts SearchServiceProtocol, indexes meetings in FTS5 after save |
| `HomeView.swift` | `.searchable` modifier, debounced FTS5 search, filtered results |
| `SettingsView.swift` | iCloud toggle, system audio toggle (macOS), model management section |
| `RecordingView.swift` | Model readiness check, ModelDownloadView sheet |
| `RecordingViewModel.swift` | `needsModelDownload` gate, `onModelReady()` callback |
| `AVAudioEngineRecordingService.swift` | macOS Core Audio Tap (`AudioHardwareCreateProcessTap`) |
| `Meeting.swift` | Explicit property defaults (CloudKit compatibility) |
| `TranscriptSegment.swift` | Explicit property defaults |
| `Speaker.swift` | Explicit property defaults |
| `AppSettings.swift` | Explicit property defaults |
| `Whisperly.entitlements` | Added CloudKit + outgoing network entitlements |

## 3. SPM Dependencies

| Package | Version | Product | License | Purpose |
|---|---|---|---|---|
| [WhisperKit](https://github.com/argmaxinc/WhisperKit) | 0.18.0 | `WhisperKit` | MIT | On-device transcription (Whisper large-v3-turbo / small) |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | 0.14.3 | `FluidAudio` | MIT | Speaker diarization (Sortformer + embedding) |
| [GRDB.swift](https://github.com/groue/GRDB.swift) | 7.10.0 | `GRDB` | MIT | SQLite FTS5 full-text search |

Transitive dependencies: swift-transformers, swift-argument-parser, swift-collections, swift-crypto, swift-asn1, swift-jinja, yyjson.

## 4. Build Status

### iOS (arm64, Simulator)
```
xcodebuild -scheme Whisperly -destination 'platform=iOS Simulator,id=FDD60F1A-B8D6-431C-A055-AC63117E843F' build
** BUILD SUCCEEDED **
```

### macOS (arm64)
```
xcodebuild -scheme Whisperly -destination 'platform=macOS' build
** BUILD SUCCEEDED **
```

Both platforms compile cleanly with Swift 6 strict concurrency.
`EXCLUDED_ARCHS = x86_64` set on all configurations (Intel Mac dropped).

## 5. Test Results

```
✔ Test run with 16 tests in 6 suites passed after 7.588 seconds.

Suite "Countdown Timer Tests" (2 tests)
  ✔ Free user countdown reaches zero stops recording — 0.002s
  ✔ Pro upgrade mid-countdown removes timer without interrupting — 1.504s

Suite "GRDB Search Service Tests" (5 tests)                    ★ NEW
  ✔ Index and search returns matching meeting IDs — 0.009s
  ✔ Empty query returns empty results — 0.001s
  ✔ Re-indexing replaces previous content — 0.001s
  ✔ Remove index clears meeting from search — 0.001s
  ✔ Prefix search matches partial words — 0.001s

Suite "Meeting Repository Tests" (1 test)
  ✔ Repository CRUD — 0.032s

Suite "Model Manager Tests" (3 tests)                          ★ NEW
  ✔ Recommended model is based on device memory — 0.001s
  ✔ Estimated model size returns known values — 0.001s
  ✔ Test initializer sets state correctly — 0.001s

Suite "Pipeline Tests" (2 tests)
  ✔ Pipeline produces meeting end-to-end with mocks — 3.018s
  ✔ Pipeline stages fire in correct order — 3.011s

Suite "Store Manager Tests" (3 tests)
  ✔ Restore purchases sets isPro=true when transaction found — 0.001s
  ✔ Products are defined correctly — 0.001s
  ✔ EntitlementProviding protocol conformance — 0.001s

** TEST SUCCEEDED ** (16/16 pass, 0 failures)
```

## 6. What's Real Now vs Still Mock

| Service | Phase 1 | Phase 2 | Implementation |
|---|---|---|---|
| Recording | Real (AVAudioEngine) | **Real** (default in DI) | `AVAudioEngineRecordingService` + macOS Core Audio Tap |
| Transcription | Mock | **Real** | `WhisperKitTranscriptionService` (WhisperKit 0.18.0) |
| Diarization | Mock | **Real** | `FluidAudioDiarizationService` (FluidAudio Sortformer) |
| Summarization | Mock | **Mock** (Phase 3: Apple Foundation Models) | `MockSummarizationService` |
| Storage | Real (SwiftData) | **Real** | `SwiftDataMeetingRepository` |
| Search | Stub (empty) | **Real** | `GRDBSearchService` (SQLite FTS5) |
| Sync | Stub (no-op) | **Real** | `CloudKitSyncCoordinator` (toggle, default OFF) |
| Export | Real | Real | `ExportService` (unchanged) |
| StoreKit | Real | Real | `StoreManager` (unchanged) |

Mocks preserved for all services — used by unit tests and can be toggled for development.

## 7. Implementation Details

### WhisperKit Transcription
- Model selection by device RAM: ≥6 GB → `large-v3-turbo` (626 MB), <6 GB → `small` (244 MB)
- Models downloaded on-demand from Hugging Face via `WhisperKit.download(variant:downloadBase:)`
- Stored in `Application Support/WhisperKit/Models/`
- Lazy pipeline initialization (`WhisperKit(modelFolder:)`)
- Maps `TranscriptionSegment` (start/end/text) → `TranscriptSegmentDTO`

### FluidAudio Diarization
- Uses `OfflineDiarizerManager` (most accurate, runs post-recording)
- Loads models via `OfflineDiarizerModels.load()`
- Maps `TimedSpeakerSegment` (speakerId/startTimeSeconds/endTimeSeconds) to DTOs
- Speaker assignment: overlap-based matching between diarization segments and transcript segments
- Supports 2–6 speakers with color palette

### FluidAudio vs Argmax SpeakerKit Decision
Both evaluated. **FluidAudio chosen** because:
1. iOS 16+ support (SpeakerKit needs iOS 17+) — wider compatibility
2. Sortformer architecture optimized for ANE — better battery on long meetings
3. Independent package — not coupled to WhisperKit version upgrades
4. Production-validated (Slipbox, Spokenly, Voice Ink, Whisper Mate)

SpeakerKit (pyannote 4) is a viable backup if FluidAudio accuracy proves insufficient in user testing.

### macOS Core Audio Tap
- `AudioHardwareCreateProcessTap` (macOS 14.2+)
- Creates global stereo tap excluding own process
- Separate `AVAudioEngine` instance captures system audio to a second `.m4a` file
- User-toggleable in Settings ("Record System Audio")
- Falls back gracefully on macOS < 14.2 (mic-only)

### GRDB FTS5 Search
- Parallel SQLite database (`Application Support/Whisperly/search.sqlite`)
- `meeting_search` FTS5 virtual table with `unicode61` tokenizer
- Indexed on save: segment text + summary + key points + action items
- Prefix search supported (`"term"*` syntax)
- HomeView debounces 300ms before querying

### CloudKit Sync
- Default **OFF** (privacy-first)
- Toggle in Settings → stored in `UserDefaults`
- `WhisperlyApp` creates `ModelContainer` with `cloudKitDatabase: .private(...)` or `.none`
- Toggle requires app restart (documented in UI)
- Audio files excluded from sync (only metadata + transcript text)
- All models have explicit property defaults for CloudKit compatibility

### Model Download UI
- `ModelDownloadView`: download progress, retry on failure, cancel
- `ModelManagementSection`: Settings integration for model info + delete
- Recording blocked until model is ready (`needsModelDownload` gate)
- Auto-opens download sheet when recording attempted without model

## 8. Build Settings Changes

| Setting | Before | After |
|---|---|---|
| `EXCLUDED_ARCHS` | (not set) | `x86_64` (all configs) |
| SPM packages | None | WhisperKit 0.18.0, FluidAudio 0.14.3, GRDB 7.10.0 |
| Entitlements | sandbox + audio-input | + network.client + icloud-container + icloud-services |

## 9. Sharp's Default Decisions Applied

1. ✅ IAP Product ID: `ai.dxy.whisperly.lifetime` (unchanged from Phase 1)
2. ✅ `EXCLUDED_ARCHS = x86_64` added to all build configurations
3. ✅ iCloud sync default OFF, user-toggleable in Settings
4. ✅ Default recording service: real `AVAudioEngineRecordingService` (was MockRecordingService)
5. ✅ Translations deferred to Phase 4 (en + zh-Hans only)

## 10. What's Left for Phase 3

- ❌ Apple Foundation Models (real summarization) — still mock
- ❌ MLX Qwen fallback for older devices
- ❌ Real app icons (placeholder only)
- ❌ fastlane (Phase 4)

---

*Phase 2 complete. Real transcription (WhisperKit) + real diarization (FluidAudio) + real search (FTS5) + CloudKit sync toggle + model download UI. iOS + macOS builds + 16/16 tests pass.*
