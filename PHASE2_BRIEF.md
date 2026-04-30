# Whisperly - Phase 2 Engineering Brief

> Status: Phase 1 ✅ 完成（44 files, 8/8 tests, iOS+macOS clean build）
> Phase 2 任务：把 mock 全部换成真实集成
> Reference docs: PROJECT_BRIEF.md, MONETIZATION.md, TECH_RESEARCH.md, PHASE1_REPORT.md

## Phase 2 目标

把 Phase 1 留下的所有 mock / stub 替换成真实实现，端到端跑通"真录音 → 真转录 → 真 diarization → 历史搜索 → 同步"。

## 必做

### 1. WhisperKit 集成（真转录）

**包**：`https://github.com/argmaxinc/argmax-oss-swift` (≥ 0.9.0)
- License: MIT
- 提供 WhisperKit (转录) + SpeakerKit (diarization) + TTSKit
- 我们这阶段只用 WhisperKit；Phase 2 也试试 SpeakerKit 看是否比 FluidAudio 更好

**实现**：
- `WhisperKitTranscriptionService: TranscriptionServiceProtocol`
- 模型按设备分级（参考 TECH_RESEARCH.md）：
  - 默认：`large-v3-turbo` (压缩版)
  - 老机型 (A14): `small`
  - 顶配 (M3+): `large-v3`
- 模型按需下载（首次用时拉取）+ 进度回调
- 支持流式 / 增量转录（边录边转）
- 多语言：自动检测 + 用户可手动选

**模型存储**：
- iOS: `Application Support/WhisperKit/Models/`
- macOS: 同上
- 不打进 .ipa（用 BackgroundAssets framework 后台下载，或首次启动时下载）

**默认替换**：`AppDependencies` 默认从 `MockTranscriptionService` → `WhisperKitTranscriptionService`，但保留 mock 给测试用

### 2. FluidAudio 集成（真说话人分离）

**包**：`https://github.com/FluidInference/FluidAudio`
- License: Apache 2.0
- Sortformer + Core ML，跑 ANE

**实现**：
- `FluidAudioDiarizationService: DiarizationServiceProtocol`
- 输入：音频文件 + WhisperKit 出来的 segments（带 timestamp）
- 输出：每个 segment 标记 speakerID + Speaker 列表
- 至少识别 2-6 个说话人
- 模型按需下载

**对比 Argmax SpeakerKit**：
- 同时调研 Argmax SpeakerKit（基于 pyannote 4，2026 开源）
- 用谁更好取决于：iOS 17 兼容性、模型大小、准确度、ANE 支持
- 在 brief 里给出最终决定 + 理由

### 3. macOS Core Audio Tap（系统音频抓取）

**API**：`AudioHardwareCreateProcessTap` (macOS 14.4+)
- 用于：开会时同时录"自己的麦克风 + 系统输出（对方说话）"两路
- 不用 ScreenCaptureKit（污染审核 + UX 不好）

**实现**：
- 扩展 `AVAudioEngineRecordingService`，加一个 macOS-only 路径
- 返回两路音频混合（mic + system）或分离（看哪个更好做 diarization）
- 用户可在设置里开关"录系统声音"
- 需要 entitlement：`com.apple.security.device.audio-input`

### 4. GRDB FTS5 全文搜索

**包**：`https://github.com/groue/GRDB.swift`

**实现**：
- `GRDBSearchService: SearchServiceProtocol`
- SQLite + FTS5 索引
- 写入：每次 Meeting 保存时同步到 FTS5 表（segment text + summary + keyPoints + actionItems）
- 查询：支持关键词、词组、按时间过滤
- 与 SwiftData 并行（FTS5 只做索引，原始数据还在 SwiftData）

**HomeView 改造**：
- 加搜索栏（iOS 16+ `.searchable`）
- 实时搜索（debounce 300ms）
- 高亮命中词

### 5. CloudKit 同步

**实现**：
- 启用 SwiftData 的 `cloudKitDatabase: .private(...)`
- 默认**关**（隐私优先）
- Settings 里加开关 `iCloudSyncEnabled`
- 开关切换时：迁移现有数据到带 CloudKit 的 ModelContainer
- 处理 CloudKit 错误（quota、network、account）
- 注意：开启后 Meeting 的 audioFileURL 不能直接同步（CloudKit 不存大文件），改成只同步 metadata + transcript + summary，audio 文件留本地

### 6. 模型下载 UI

新组件：`ModelDownloadView`
- 首次进入录音页时检查模型是否存在
- 不存在 → 弹下载页：模型大小、预计时间、进度条
- 下载完成自动开始
- Settings 里能查看 / 重下 / 删除模型
- 显示当前模型版本

### 7. 测试更新

- 单元测试保持 mock（不要在 CI 拉模型）
- 加集成测试套件 `WhisperlyIntegrationTests`，跑真模型，**默认 skip**，本地手动跑
- 模型下载测试（mock URLSession）

## 不做（留 Phase 3）

- ❌ Apple Foundation Models（真总结）
- ❌ MLX Qwen 兜底
- ❌ 真总结（总结仍用 Mock）
- ❌ App 图标真品（占位即可）
- ❌ fastlane（Phase 4）

## 工程要求

- 所有新代码遵守 Phase 1 的 SOLID / DI 原则
- 包依赖统一走 Swift Package Manager
- 不引入 Cocoapods / Carthage
- 每个新功能 → 至少一个测试
- 多端构建 + 测试 必须全过：

```bash
xcodebuild -scheme Whisperly -destination 'generic/platform=iOS' build
xcodebuild -scheme Whisperly -destination 'generic/platform=macOS' build
xcodebuild test -scheme Whisperly -destination 'platform=iOS Simulator,id=FDD60F1A-B8D6-431C-A055-AC63117E843F'
```

## 默认决策（来自 Sharp）

1. IAP Product ID: **`ai.dxy.whisperly.lifetime`** （写进 ASC 时用这个）
2. **`EXCLUDED_ARCHS = x86_64`** 加上，砍 Intel Mac
3. iCloud 同步默认关，Settings 可开
4. 默认录音服务切到真 AVAudioEngine
5. 其他 8 语翻译 Phase 4 再补

## Workflow

1. `cd /Users/shrimp/Desktop/code/Whisperly && git pull --rebase 2>/dev/null || true && git status`（确认干净）
2. 通读 PHASE1_REPORT.md 了解现状
3. 通读 TECH_RESEARCH.md（特别第 2/3/5 节）
4. 添加 SPM 依赖：argmax-oss-swift, FluidAudio, GRDB.swift
5. 实现 WhisperKitTranscriptionService（先这个，验证 SPM + 模型下载流程）
6. 实现 FluidAudioDiarizationService
7. 实现 macOS Core Audio Tap
8. 实现 GRDBSearchService
9. 实现 CloudKit toggle + 数据迁移
10. 实现 ModelDownloadView
11. 加搜索栏到 HomeView
12. 跑构建 + 测试
13. 写 PHASE2_REPORT.md
14. 多个原子提交
15. Wake hook：

```bash
openclaw system event --text "Whisperly Phase 2 done — see PHASE2_REPORT.md" --mode now
```

## 风险点 & 应对

- **WhisperKit 包大**：模型不打进 ipa，用 BackgroundAssets 或首次下载
- **FluidAudio iOS 17 兼容性**：如果只支持 iOS 18+，需要降级到 Argmax SpeakerKit 或 pyannote-via-CoreML
- **Core Audio Tap macOS 14.4+**：14.0-14.3 用户兜底用 ScreenCaptureKit
- **CloudKit + audio 文件**：明确告知用户音频不同步、只同步文字
- **模型下载失败**：清晰错误 UI + 重试

## 最终交付

- `PHASE2_REPORT.md`，结构同 PHASE1_REPORT.md
- 所有 mock 默认换成真实实现（mock 仍保留供测试）
- iOS + macOS 双端构建 + 测试通过
- 至少 5 个原子 git 提交
- 通知 wake hook
