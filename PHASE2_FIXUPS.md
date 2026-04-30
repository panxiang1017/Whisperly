# PHASE 2 FIXUPS — Must Fix (from Phase 1 Code Review)

> These bugs were found in Phase 1 code review. Fix them AS PART of Phase 2 work.
> Full review: PHASE1_REVIEW.md

## 🔴 Critical (Fix First)

### 1. Data Race in AVAudioEngineRecordingService
- **File:** `Whisperly/Services/Recording/AVAudioEngineRecordingService.swift`
- **Problem:** `@unchecked Sendable` with mutable state (`audioFile`, `levelContinuation`, `_isRecording`) accessed from both caller thread AND audio tap callback thread without synchronization.
- **Fix:** Use `NSLock` or convert to actor. The audio tap closure must not access unsynchronized mutable state.

### 2. No Microphone Permission Request
- **File:** `AVAudioEngineRecordingService.swift`, `start()` method
- **Problem:** Never checks or requests `AVAudioSession.recordPermission`. First-time users get cryptic error.
- **Fix:** Check permission before starting engine. Show system dialog if undetermined. Throw `RecordingError.permissionDenied` if denied.

### 3. Silent Audio Data Loss
- **File:** `AVAudioEngineRecordingService.swift:67`
- **Problem:** `try? self?.audioFile?.write(from: buffer)` silently drops write errors (disk full, etc.)
- **Fix:** Accumulate write errors, surface when `stop()` is called.

## 🟡 Major (Fix in Phase 2)

### 4. Countdown Timer Drift
- **File:** `RecordingViewModel.swift`
- **Problem:** Uses `elapsedSeconds += 1` per `Task.sleep(for: .seconds(1))`. Drifts from wall clock.
- **Fix:** Use `Date()` arithmetic: `elapsedSeconds = Int(Date().timeIntervalSince(startDate))`

### 5. Force Unwraps
- **Files:** `PaywallView.swift:117-118`, `SettingsView.swift:35,39`
- **Problem:** `URL(string: ...)!` — spec says no force-unwraps
- **Fix:** Define as `static let` constants or `guard let`

### 6. MeetingRepositoryProtocol @MainActor Constraint
- **File:** `MeetingRepository.swift:4`
- **Problem:** Forces all DB ops to main thread. Blocks Phase 2 background processing.
- **Fix:** Remove `@MainActor` from protocol. Use background `ModelContext` for heavy writes.

### 7. SettingsView Says "Subscription"
- **File:** `SettingsView.swift:28`
- **Problem:** Section header says "Subscription" but product is lifetime purchase
- **Fix:** Change to "Purchase" or "Pro Status"

### 8. Missing Countdown-Reaches-Zero Test
- **File:** `CountdownTimerTests.swift`
- **Problem:** Test named "countdown reaches zero stops recording" only tests initial state
- **Fix:** Inject configurable time limit (e.g. 3 seconds for tests), verify recording actually stops

## 🟢 Minor (Fix if time permits)

### 9. AppSettings Model Unused — Remove or wire up
### 10. MeetingDetailView creates ExportService() directly — Use DI
### 11. ExportService DateFormatter no explicit locale
### 12. StoreManager.checkVerified duplicated — Make static
### 13. MockRecordingService same @unchecked Sendable race
