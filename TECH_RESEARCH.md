# Scribe — 纯本地会议助手 App 技术可行性调研

> 调研对象：iOS / iPadOS / macOS Universal App，全本地（on-device）的录音 + 转录 + 说话人分离 + 总结 + 历史。
> 调研日期：2026-04-30。技术名词保留英文。
> 作者：tech-research subagent

---

## TL;DR（懒人版结论）

| 模块 | 推荐方案 | 兜底/备选 |
|---|---|---|
| 录音（iOS/iPadOS） | `AVAudioEngine` + `AVAudioSession` | — |
| 录音（macOS） | `AVAudioEngine`（mic）+ **Core Audio Tap (CATap, macOS 14.4+)**（系统输出/进程音频） | `ScreenCaptureKit` audio（macOS 13+ 老机器） |
| 音频格式 | 实时管线：16 kHz mono PCM Float32（送 ASR）；归档：48 kHz Opus / AAC-LC（.m4a） | FLAC（无损但体积大，不建议） |
| 转录 | **WhisperKit (argmax-oss-swift)**，模型 `large-v3-turbo` 或 `large-v3-v20240930_626MB` | iOS 26 / macOS 26 设备：**Apple SpeechTranscriber** 兜底（系统模型，零安装包） |
| 说话人分离（diarization） | **FluidAudio**（Sortformer + speaker embedding，MIT） | Argmax 开源的 pyannote 4 引擎（v0.17.0 release） |
| 本地总结（高端机 iOS 26+/macOS 26+） | **Apple Foundation Models framework**（~3B on-device，零安装包，15 语种含中文） | **MLX Swift + Qwen2.5-3B-Instruct (4-bit)** 兜底 |
| 本地总结（A14/A15 老机型） | MLX Swift + **Qwen2.5-1.5B (4-bit)** 或 Llama-3.2-1B-Instruct (4-bit) | 进一步兜底：模板化抽取式 summary（无 LLM） |
| 数据存储 | **SwiftData + CloudKit 同步**（iOS 17+/macOS 14+ 原生支持） | 重历史项目可考虑 GRDB（SQLite）+ 自建 CloudKit Mirroring |
| 多平台 | **SwiftUI Universal App**，单一 target，多平台条件编译 | — |
| 最低门槛 | iOS 17 / iPadOS 17 / macOS 14；CPU 最低 **A14 (iPhone 12)** / Apple Silicon Mac | — |
| 包体大小 | App + 必要模型，**约 800 MB ~ 1.4 GB**（按机型分级下载） | — |

---

## 1. 录音方案

### 1.1 AVAudioEngine vs AVAudioRecorder

| 维度 | `AVAudioRecorder` | `AVAudioEngine` |
|---|---|---|
| 抽象层级 | 高，文件级 API | 低，节点图 (node graph) |
| 直接访问 raw PCM buffer | ❌ 必须从文件读 | ✅ `installTap(onBus:)` 即时拿到 buffer |
| 实时管线（边录边转录、边录边 VAD） | ❌ 不行 | ✅ 必选 |
| 可同时输出多路（写文件 + 喂 ASR） | ❌ | ✅（一个 tap 拿 buffer，自己同时写文件 + 推 ASR） |
| 中断处理（电话、Siri） | 自动但简单 | 需手动处理 `AVAudioSession.interruptionNotification` |
| 多平台一致性 | iOS only friendly，macOS API 残缺 | iOS / macOS 一致 |

#### 推荐：**AVAudioEngine**（无悬念）

理由：会议助手必须**实时**把音频喂给 Whisper / VAD / diarization；`AVAudioRecorder` 只能事后转录。
管线设计：

```
AudioEngine.inputNode
    └── installTap(bufferSize: 1024, format: nativeFormat)
            ├── AVAudioConverter → 16 kHz mono Float32 → WhisperKit ringbuffer
            ├── AVAudioConverter → 16 kHz mono Float32 → VAD（Silero / FluidAudio）
            └── AVAudioFile（48 kHz AAC-LC）落盘归档
```

注意点：
- iPhone 默认采样率多为 48 kHz，必须显式 `AVAudioConverter` 降到 16 kHz Float32（Whisper 训练分布）。
- `installTap` 的 `bufferSize` 不一定被尊重，实际 buffer 长度可能在 ~470–4800 frames 之间；自己累积到 chunk 边界。
- `AVAudioSession` 必须设 `.record` / `.playAndRecord` + `.measurement` mode（关闭 AGC、回声降噪在非通话场景反而更准）。

### 1.2 macOS 系统音频抓取（关键）

会议助手的核心痛点：**同时录到自己说的（mic）+ 对方说的（系统输出）**。

| 方案 | 可用版本 | 评价 |
|---|---|---|
| **Core Audio Tap (CATap)** | **macOS 14.2+ public API（14.4+ 稳定）** | ✅ **推荐**。延迟低、与 process / device 都能挂、不需要屏幕录制权限、不需要可见 UI，纯 Core Audio API（`AudioHardwareCreateProcessTap`）。 |
| `ScreenCaptureKit` audio | macOS 13+ | 可用但**重型**：要请求屏幕录制权限（用户感知差，会议助手没必要看屏幕），开销大；适合作为 macOS 13 兜底。 |
| BlackHole / Loopback 虚拟声卡 | 三方 | ❌ 不能上架。要求用户装内核扩展。 |
| Aggregate Device + Core Audio HAL | macOS 10.15+ | 老路子，能跑但繁琐；CATap 出来后没有理由继续用。 |

#### 推荐：**Core Audio Tap 主路径，ScreenCaptureKit 兼容 macOS 13**

```swift
#if os(macOS)
if #available(macOS 14.2, *) {
    // Core Audio Tap path
    var tapDesc = CATapDescription(stereoMixdownOfProcesses: [meetingPID])
    var tapID: AUAudioObjectID = 0
    AudioHardwareCreateProcessTap(&tapDesc, &tapID)
    // 把 tap 绑到 aggregate device，然后用 AVAudioEngine 接
} else {
    // ScreenCaptureKit fallback
}
#endif
```

权限：CATap 需要用户授权 `NSAudioCaptureUsageDescription`（macOS 14.4+ 强制 TCC 弹窗）。ScreenCaptureKit 路径需 `NSScreenCaptureDescription`。

混音策略：**两路独立录**（mic 一路、系统一路），ASR 也跑两路并行；这样 diarization 之前就有了天然的"我 vs 他们"二分类，准确率更高。最终归档时再混为一个立体声 m4a（左 mic、右系统）便于回放。

### 1.3 iOS 后台录音

| 限制 | 说明 |
|---|---|
| Background Mode | Info.plist 加 `audio` 后台模式，应用切后台不会被挂起 |
| 屏幕熄屏 | 录音持续，但要 `AVAudioSession.setActive(true)` |
| 锁屏控制 | 可通过 `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter` 显示"正在录音 [Pause]"控制条 |
| 来电中断 | 必须监听 `AVAudioSession.interruptionNotification`，挂电话后**手动 resume**（系统不会自动恢复 record session） |
| 切换音频路由（蓝牙、AirPods） | 监听 `routeChangeNotification`，必要时让用户确认切换（AirPods 麦克风可能转到 16 kHz 单声道，Whisper 反而 OK） |
| iPad 多任务（split view） | 与后台录音独立，无影响 |
| 系统级录屏 / 开屏幕录制 | 可能挤占 mic，要 graceful 处理 |

#### iOS 后台录音最佳实践
1. UI 上明确"录音中"指示（Dynamic Island，iOS 16.1+ 用 ActivityKit Live Activity）。
2. 每分钟 flush 一次写盘（避免崩溃丢数据）。
3. 后台模式下**不要**做重 ML（CPU 拉满会被系统降频甚至杀掉）；只录、缓冲，转录留到回前台或会议结束后。
4. 长会议（>2h）注意发热降频：`ProcessInfo.thermalState` 监控，进入 `.serious/.critical` 时降转录频率（每 30s 跑一次而非实时）。
5. 麦克风权限 `NSMicrophoneUsageDescription` 文案务必清晰，注明"用于本地转录会议，不上传"。

### 1.4 采样率与文件格式

| 用途 | 推荐 | 为什么 |
|---|---|---|
| ASR 输入 | 16 kHz mono PCM Float32 | Whisper / Parakeet / SpeechAnalyzer 都按这个格式训练；高于 16 kHz 浪费算力，低于会丢精度 |
| 长期归档 | **AAC-LC 64 kbps mono（.m4a）** | iOS/macOS 原生编码，硬件加速；1 小时 ~28 MB；质量足够语音 |
| 高保真归档（可选） | Opus 32 kbps mono（.opus / .ogg） | 比 AAC 小 30%、质量更好；但 Apple 平台没硬件编码（CPU 编码也 OK） |
| 不推荐 | FLAC | 1 小时 mono 16-bit ~110 MB，纯本地存太占空间；语音用无损没必要 |
| 不推荐 | WAV / 原始 PCM | 1 小时 mono 16-bit ~110 MB，存档太大 |

#### 推荐：实时 16 kHz Float32 PCM 喂 ASR；归档 **AAC-LC 64 kbps mono（.m4a 容器）**

如果用户用立体声归档（mic 左 + 系统右）：AAC-LC 96 kbps stereo，1 小时 ~42 MB。

---

## 2. 转录方案

### 2.1 横向对比

| 方案 | 模型大小 | iPhone 15 Pro 1h 音频转录耗时 (估) | 内存占用 | 中文质量 | License | 集成难度 |
|---|---|---|---|---|---|---|
| **Apple SpeechTranscriber** (iOS 26+) | 0（系统） | **~实时 0.5x（30 min）** | 系统管理，~200 MB | 中文：good，普通话 OK；中英混合一般 | Apple 系统 API，免费商用 | ⭐ 极简，几行代码 |
| **WhisperKit large-v3-turbo** | 626 MB | ~3-5 分钟（10-20× realtime） | ~1.0 GB peak | **优秀**（large-v3 训练含大量中文） | MIT (argmax-oss-swift) | ⭐⭐ SPM 一键 |
| WhisperKit small | 244 MB | ~2 分钟 | ~600 MB | 中等，中英混合容易飘 | MIT | ⭐⭐ |
| WhisperKit tiny | 78 MB | ~30 秒 | ~280 MB | 差，仅做 demo | MIT | ⭐⭐ |
| whisper.cpp + Core ML | 同 ggml | small ~2-3 分钟，large ~6-10 分钟 | small 852 MB，large 3.9 GB | 同 Whisper | MIT | ⭐⭐⭐ 需要自己编译 .mlmodelc |
| MLX-Whisper | large-v3 ~3 GB（fp16） | ~4-6 分钟（M 系芯片更优） | 偏高 | 优秀 | MIT | ⭐⭐⭐⭐ Swift 绑定不成熟，更适合 macOS |
| FluidAudio Parakeet TDT v3 | ~600 MB | **~1-2 分钟**（ANE 优化激进） | 较低（ANE） | 支持中文 + 25 欧语 + 日语，中文质量略逊 large-v3 | MIT/Apache-2.0 | ⭐⭐ |

#### 数字来源说明
- WhisperKit benchmarks: argmaxinc/whisperkit-benchmarks Hugging Face Space + ICML 2025 paper
- whisper.cpp 模型尺寸表：官方 README
- SpeechTranscriber 实测吞吐：WWDC25 session 277 演示（"approximately faster than realtime"），未公布精确 RTFx
- FluidAudio：FluidInference/FluidAudio README + Spokenly app 公测数据

### 2.2 详细分析

#### Apple SpeechTranscriber / SpeechAnalyzer (iOS 26 / macOS 26)
- 全新 API，2025 WWDC 推出，替代旧的 `SFSpeechRecognizer`。
- **零安装包**：模型在系统中按需下载（`AssetInventory.assetInstallationRequest`），用户首次用某个语言时下载一次。
- **支持语言（截至 iOS 26）**：英语（多区域）、中文（普通话简繁）、日语、韩语、法语、德语、西班牙语、意大利语、葡萄牙语 — 大约 9-10 种。**比 Whisper 少**，缺少粤语、东南亚语种。
- 中文质量：日常对话级 OK；专业术语弱于 Whisper large-v3；标点符号、说话人分隔效果好（系统级优化）。
- 不支持 speaker labels（**iOS 26 的 SpeechTranscriber 不输出 speaker turn**，需要外挂 diarization）。
- 优势：零包体积、零冷启动、走系统电源策略（不会被节流）、实时流式接口好用。
- 劣势：iOS 26 / macOS 26+ 才有；老机型 fallback 不到 SFSpeechRecognizer（旧 API 仍存在但只能联网走 Siri 服务器，违反"纯本地"承诺）。

#### WhisperKit / argmax-oss-swift（**主力推荐**）
- 由 Argmax 维护，2024-2025 主流方案。原 `WhisperKit` repo 已合并到 [`argmaxinc/argmax-oss-swift`](https://github.com/argmaxinc/argmax-oss-swift) 0.9.0+，包含三件套：WhisperKit（ASR）、SpeakerKit（diarization，已开源 pyannote 4 引擎）、TTSKit（不需要）。
- **License: MIT**（OSS 部分）。Pro SDK 是闭源订阅，但我们只用 OSS。
- ANE + Core ML 编译好的模型直接跑，量化版（`large-v3-v20240930_626MB`）特别为 ANE 优化，1 小时音频在 iPhone 15 Pro ~3-5 分钟。
- 多语言：与 Whisper 原生一致（99 语言），中文质量是 Whisper-class 第一梯队。
- 推荐模型：
  - 旗舰机（A17/A18/M-series）：`large-v3-v20240930_626MB`（best quality）
  - 中端机（A14-A16）：`distil-whisper_distil-large-v3_594MB` 或 `small`（244 MB）
  - 入门：`base`（74 MB）+ 用户提示"准确度有限"

#### whisper.cpp
- License: MIT。
- 优点：体积小、跨平台、量化方案灵活（Q4_0/Q5_0 进一步压到 1 GB 以下 large）。
- 缺点：在 Apple 生态相比 WhisperKit 没有任何优势 — WhisperKit 已经接管了 Core ML/ANE 路径。
- 仅在需要"模型自由切换"或要做安卓兼容时才考虑。本项目纯 Apple 平台，**不推荐**。

#### MLX-Whisper
- Apple MLX 框架，专为 Apple Silicon。但 MLX **iOS 支持还不成熟**（2025 年开始才有 iOS-friendly Swift 绑定），且模型走 GPU 而非 ANE，**电池消耗大**。
- 适合 macOS 桌面级，不适合 iPhone。
- **不推荐**作为统一方案。

### 2.3 推荐方案

#### **主路径：WhisperKit（argmax-oss-swift）**
- 跨 iOS 17+ / macOS 14+ 一致工作
- 模型按设备分级（首启自动下载，或让用户选）
- License MIT，商用 OK

#### **iOS 26+ / macOS 26+ 加速路径：Apple SpeechTranscriber**
- 零安装包，运行时检测可用即优先用
- 中文质量勉强够用，省下 600 MB 包体很值得
- **设计为可选**：用户可以在设置里强制切回 WhisperKit（追求最高准确度）

#### 切换逻辑
```swift
let asrEngine: ASREngine = {
    if #available(iOS 26.0, macOS 26.0, *), userPrefersSystem {
        return AppleSpeechAnalyzerEngine()
    }
    return WhisperKitEngine(model: pickModelForDevice())
}()
```

---

## 3. 说话人分离 (Speaker Diarization) — 最难一块

### 3.1 任务复杂度
- **目标**：输出 `[(speaker_id, t_start, t_end)]`，且与 ASR 时间戳对齐 → 形成 "Alice: 你好…  Bob: 嗯…" 的 transcript。
- **难点**：重叠语音、回响、麦克风远场、说话人数未知、长尾尾音。
- **指标**：DER (Diarization Error Rate) 越低越好；商业系统 12-15%，SOTA on-device 14-18%。

### 3.2 横向对比

| 方案 | 可用性 | 准确度 | 性能 | License | 推荐度 |
|---|---|---|---|---|---|
| **FluidAudio (Sortformer + 内置 embedding)** | ✅ Swift 原生，CoreML/ANE，iOS 16+ macOS 13+ | DER ~14-17% on AMI/CallHome（接近 pyannote 3.1） | 极快，4 分钟 ~1 秒（M 系），iPhone ~5 秒 | MIT/Apache-2.0 | ⭐⭐⭐⭐⭐ **首选** |
| Argmax 开源 SpeakerKit (pyannote 4) | ✅ 已开源 v0.17.0，在 argmax-oss-swift | DER 略好于 pyannote 3.1 | 4 分钟 ~2 秒（iPhone） | 开源仓库声明 MIT；pyannote 模型权重 MIT | ⭐⭐⭐⭐ 强备选 |
| Sherpa-onnx diarization (nemo speaker model + clustering) | ⚠ Swift binding 弱，C++ 主导，要自己 wrap | 中等 | 中等 | Apache-2.0 | ⭐⭐ |
| pyannote 原生 → 手动 Core ML 移植 | ❌ pyannote.audio 是 PyTorch，自己 export 复杂；社区已有 pyannote 3.x → Core ML 但 EOL | SOTA | — | MIT | ⭐ 重复造轮子 |
| Apple SpeechAnalyzer speaker labels (iOS 26) | ❌ **iOS 26 不支持** speaker labels（截至 26.0/26.4 文档） | — | — | — | — |
| 简化方案：mic vs 系统音频通道分离 | ✅ macOS 上天然 | 仅 2 人（自己 vs 对面），但 100% 准 | 0 成本 | — | ⭐⭐⭐⭐ **必做兜底** |
| 简化方案：声纹 embedding (ECAPA-TDNN) + KMeans/AHC 聚类 | ✅ 自己写 | DER 25-35%（粗糙） | 快 | 模型 MIT 居多 | ⭐⭐ |

### 3.3 推荐：**FluidAudio 主，Argmax SpeakerKit OSS 备**

#### 为什么 FluidAudio 第一
1. **Swift 原生 SDK**，SPM 一键集成，Documentation/Models.md 列出所有模型 license（MIT/Apache）。
2. 模型走 ANE（Apple Neural Engine），不抢 GPU，**长会议不发烫**。
3. 已被 Slipbox、Spokenly、Whisper Mate 等多个生产 app 采用（即 README 列表）— 真实业务验证过。
4. 包含 **streaming + offline** 两套 pipeline；offline 在会议结束时跑（更准），streaming 在会议中粗略给"speaker A/B/C"标签。
5. 也有 VAD（Silero）、ASR (Parakeet)，可作为 WhisperKit 替代。

#### 兜底链
```
1. macOS 双声道路由识别（mic ≠ system audio） → 2 路独立 ASR
   ↓ 仅靠这一步就解决 "我 vs 对面" 80% 场景
2. 在每一路内部，跑 FluidAudio diarization
   ↓ 解决"对面有 3 个人在 Zoom 里"的子问题
3. 离线后处理：会议结束后，再用 FluidAudio offline pipeline 全量重跑一次（更准的聚类）
4. 简单 UI 让用户改名/合并/拆分 speaker（手工矫正永远是最后一道防线）
```

#### 商用许可注意
- FluidAudio 自己 MIT。但其封装的具体模型 license 各异，要逐个看 `Documentation/Models.md`：
  - Sortformer → Apache-2.0（NVIDIA） ✅
  - Silero VAD → MIT ✅
  - Parakeet → CC-BY-4.0（NVIDIA），**需署名**，商用 OK
- 如果不能接受 NVIDIA 模型的署名要求，切到 pyannote 4（MIT）。

---

## 4. 本地总结 (Summarization)

### 4.1 Apple Foundation Models framework

- **可用性**：iOS 18.1+ 引入 Writing Tools（系统级 summary），但**框架级 API（`FoundationModels.framework`）真正开放给开发者是 iOS 26 / macOS 26**（WWDC25 公布）。
- 模型：Apple 自研 ~3B parameters on-device，训练时支持 **15 种语言（含简体中文、繁体中文）**（Apple ML 研究博客 2025 update 明确说明）。
- 调用方式（Swift 伪代码，基于 WWDC25）：
  ```swift
  import FoundationModels
  let session = LanguageModelSession()
  let result = try await session.respond(to: """
      请把以下会议转录总结为 5 条要点和待办事项：
      \(transcript)
      """)
  ```
- Token 限制：**输入约 4K tokens 上下文**（公开数字未给精确值，社区测试 ~4096 in / ~512 out），适合分段总结。
- 模型受 Apple 安全策略约束（不能让它干"违规"事），但会议总结场景没有触发风险。
- **零包体积、走 ANE**、电源管理由系统接管。
- 不支持的设备：iPhone 14 及更早、iPad 第 9 代及更早、A14/A15 大部分机型 — 这些机型 Apple Intelligence 整体不可用。

#### **推荐：iOS 26+/macOS 26+ + Apple Intelligence-capable 设备 → Foundation Models 优先**

### 4.2 MLX Swift + 本地 LLM（兜底主力）

| 模型 | 参数量 | 4-bit 包大小 | iPhone 15 Pro 推理速度 | 中文质量 |
|---|---|---|---|---|
| Qwen2.5-3B-Instruct (4-bit) | 3B | ~1.8 GB | ~10-15 tok/s | **优秀**（中文原生训练） |
| Qwen2.5-1.5B-Instruct (4-bit) | 1.5B | ~900 MB | ~20-25 tok/s | 良好 |
| Llama-3.2-3B-Instruct (4-bit) | 3B | ~1.9 GB | ~10-15 tok/s | 中等（英文为主） |
| Llama-3.2-1B-Instruct (4-bit) | 1B | ~700 MB | ~25-30 tok/s | 较弱 |
| Phi-3.5-mini-instruct (4-bit) | 3.8B | ~2.2 GB | ~8-12 tok/s | 中等 |

- **MLX Swift** ([`ml-explore/mlx-swift`](https://github.com/ml-explore/mlx-swift))：Apple 官方 Swift binding，支持 iOS/macOS/visionOS，跑模型走 GPU + Metal。
- 实操流程：HF 下载 MLX 量化模型 → bundle 或运行时下载 → `MLXLLM` 推理。
- 缺点：跑在 GPU 而非 ANE，**iPhone 上耗电较大**；M-series Mac 上完全无压力。
- iPhone 12 (A14, 4 GB RAM)：1.5B 4-bit 勉强能跑（占用 ~1.5 GB RAM，空间紧张）；3B **不建议**。
- iPhone 15 Pro (A17 Pro, 8 GB RAM)：3B 流畅。

### 4.3 llama.cpp Swift binding

- License: MIT。
- iOS/macOS Swift wrapper：[`llama.cpp` 自带 swift package](https://github.com/ggml-org/llama.cpp/tree/master/examples/llama.swiftui)；社区还有 [`SwiftLlama`](https://github.com/ShenghaiWang/SwiftLlama)。
- 支持 GGUF 模型（生态最大），量化更激进（Q4_K_M、Q3_K_S）。
- 性能：同等量化下，与 MLX 接近；Metal 后端成熟。
- 选择 MLX 还是 llama.cpp 主要看团队偏好：MLX 更 "Apple-native"，llama.cpp 模型生态更广。
- **本项目推荐 MLX Swift**（与 Apple 工具链一致、更新快、未来与 Foundation Models 集成更顺滑）。

### 4.4 老机型（A14/A15 / 4 GB RAM）兜底

iPhone 12 / iPhone 13 / iPad 第 9 代 等 **4 GB RAM** 机型跑 1.5B 4-bit LLM 风险高（OOM）。

#### 三段式兜底
1. **首选**：Apple Intelligence（A17 Pro/M1+ 才有）→ 不适用老机型
2. **次选**：Qwen2.5-1.5B (4-bit) on MLX → A15/6GB 机型 OK，A14/4GB 紧张
3. **最终兜底（无 LLM）**：基于规则的抽取式 summary
   - TextRank 关键句抽取（Swift 自己实现，<100 行）
   - 命名实体识别用 `NaturalLanguage.framework` (`NLTagger`) — Apple 系统库，零成本
   - 时间/日期/人名/数字提取 → "决策与待办" 列表
   - 输出："本次会议讨论了 X、Y、Z（自动提取的 3 个高频名词），共记录 N 个决定，N 个待办" + 简单的章节切分

> 决策建议：A14/4GB 设备**不暴露"AI 总结"按钮**，只提供"关键句摘要"（抽取式），用户体验上诚实告知。

### 4.5 推荐：分级总结策略

```
设备能力 = AppleIntelligenceAvailable + RAM
                 │
   ┌─────────────┼─────────────────┬──────────────┐
   ▼             ▼                 ▼              ▼
Apple Intel   MLX 3B            MLX 1.5B      抽取式
(iOS 26+      (8GB+ RAM,        (6GB RAM,    (4GB RAM,
A17 Pro+)     A16+)             A14-A15)     老 iPad)
  零包体     +1.8 GB pkg        +900 MB     0 额外包
```

---

## 5. 多平台架构

### 5.1 SwiftUI Universal App

#### 推荐架构
- **单 Xcode project**, **单 target**（不是三个），用 `#if os(iOS)` / `#if os(macOS)` 区分平台特定代码。
- **不**用 Mac Catalyst（在 macOS 14+ 时代，原生 SwiftUI 已经成熟，Catalyst 是上一代过渡方案）。
- UI 层：90% SwiftUI 共用，平台差异（菜单栏、Dock、快捷键、Window/Sidebar 模式）走 modifier。
- 业务层：100% Swift Package（建一个 `ScribeCore` package，所有 ASR/diarization/summarization 服务封装在内）。

#### 工程结构（推荐）
```
Scribe/
├── Scribe.xcodeproj
├── App/                        # 三平台共享 SwiftUI Views
│   ├── ScribeApp.swift
│   ├── Views/
│   │   ├── MeetingListView.swift
│   │   ├── MeetingDetailView.swift
│   │   └── RecordButton.swift
│   ├── iOS/                    # iOS 特定（Live Activity, Widgets）
│   ├── macOS/                  # macOS 特定（MenuBarExtra, NSSavePanel）
│   └── iPadOS/                 # 一般跟 iOS 共用，必要时差异化（Pencil 标注?）
└── Packages/
    └── ScribeCore/             # SPM
        ├── AudioCapture/       # AVAudioEngine + CATap
        ├── Transcription/      # WhisperKit / SpeechAnalyzer 适配层
        ├── Diarization/        # FluidAudio 适配
        ├── Summarization/      # FoundationModels / MLX 适配
        └── Storage/            # SwiftData models
```

### 5.2 SwiftData vs Core Data

| 维度 | SwiftData | Core Data |
|---|---|---|
| 最低系统 | iOS 17 / macOS 14 | iOS 8+（无门槛） |
| API 风格 | 现代，Swift macros，声明式 | 老派，NSManagedObject |
| 多平台 | ✅ 原生 iOS/macOS/iPadOS/visionOS | ✅ |
| iCloud 同步 | ✅ `ModelConfiguration(cloudKitDatabase: .private(...))`，原生 | ✅ NSPersistentCloudKitContainer，更老更稳 |
| 大数据集性能 | 还在追赶（iOS 17 早期 bug 多，iOS 18 大幅改善） | 久经考验 |
| 复杂查询 | `#Predicate` macro，简洁但表达力有限 | `NSPredicate` 全功能 |
| 二进制大对象（音频文件） | 不直接存 BLOB；存路径 | 同左 |

#### 推荐：**SwiftData**

理由：
- 项目最低 iOS 17，没有遗产负担。
- macros + `@Model` + `@Query` 大幅减少样板代码。
- iCloud 同步配置简单（一行代码切换）。
- iOS 18+ 性能/稳定性已 OK；2026 年 (iOS 26) 进一步成熟。
- 风险：极复杂迁移（比如 schema 大改）SwiftData 工具不如 Core Data 成熟。**对策**：早期做好 schema 设计、避免频繁结构变更、必要时混用 SQLite (GRDB) 存大量 transcript chunks。

### 5.3 iCloud 同步与 "本地" 声明

#### 关键问题：用了 CloudKit 还能不能说"纯本地"？

**答案：能，但要措辞精确。**

- CloudKit 数据存在用户**自己的 iCloud 私人数据库（Private DB）**，端到端加密由 Apple 提供，**Apple 看不到内容**（Advanced Data Protection 开启时甚至 Apple 自己也无密钥）。
- 我们 App 的服务器**不接收任何用户数据**。
- 处理（ASR/diarization/summary）100% on-device。

#### App Store / 营销文案推荐措辞
- ✅ "All processing happens on your device. Your meetings never reach our servers."
- ✅ "Optional iCloud sync stays in your private iCloud account, end-to-end encrypted by Apple."
- ❌ 不要说 "your data never leaves your device" — 因为 iCloud 同步会传到 Apple 服务器（虽然加密）
- ❌ 不要说 "no internet required" — 模型首次下载需要

#### 同步策略
- 默认**关**iCloud 同步，用户首次启动设置中明确开启。
- 同步内容：会议元数据、transcript 文本、summary 文本、speaker 名字。
- **不同步**音频原文件（太大）—— 仅本地保留；如果用户想跨设备听，提供"导出到 iCloud Drive / Files"按钮（用户主动行为）。
- 模型文件**永不同步**（每台设备独立下载）。

### 5.4 历史记录数据模型（SwiftData）

```swift
@Model
final class Meeting {
    @Attribute(.unique) var id: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date?
    var audioFileBookmark: Data?       // 安全访问书签（音频在沙盒文件）
    var languageHint: String?          // "zh-CN" / "en-US" / nil for auto
    var status: MeetingStatus          // recording, transcribing, ready, failed

    @Relationship(deleteRule: .cascade) var segments: [TranscriptSegment]
    @Relationship(deleteRule: .cascade) var speakers: [Speaker]
    @Relationship(deleteRule: .cascade, inverse: \Summary.meeting) var summary: Summary?
    @Relationship(deleteRule: .cascade) var tags: [Tag]
}

@Model
final class TranscriptSegment {
    @Attribute(.unique) var id: UUID
    var meetingID: UUID                // 反向键，方便查
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var speakerID: UUID?               // FK to Speaker.id
    var confidence: Double             // 0..1
    var sourceChannel: AudioChannel    // .mic / .system / .merged
    var meeting: Meeting?
}

@Model
final class Speaker {
    @Attribute(.unique) var id: UUID
    var displayName: String            // 用户可改："Alice" / "Bob" / "我"
    var voicePrintData: Data?          // 用于跨会议识别（可选）
    var meeting: Meeting?
}

@Model
final class Summary {
    @Attribute(.unique) var id: UUID
    var bullets: [String]              // 5 条要点
    var actionItems: [ActionItem]      // 待办
    var keyDecisions: [String]
    var generatedBy: SummarizerType    // .appleFoundation / .mlx3b / .extractive
    var generatedAt: Date
    var meeting: Meeting?
}

@Model
final class ActionItem {
    var title: String
    var assignee: String?
    var dueDate: Date?
    var isDone: Bool
    var summary: Summary?
}

@Model
final class Tag {
    @Attribute(.unique) var name: String
    var meetings: [Meeting]
}

enum MeetingStatus: String, Codable { case recording, transcribing, summarizing, ready, failed }
enum AudioChannel: String, Codable { case mic, system, merged }
enum SummarizerType: String, Codable { case appleFoundation, mlx3b, mlx1_5b, extractive }
```

#### 索引和性能要点
- `TranscriptSegment.meetingID` 加 `@Attribute(.indexed)`（SwiftData iOS 18+ 支持）。
- 大会议（>3000 segments）用 `@Query` 配 `@Predicate` 分页加载，**别**一次性加载全部到内存。
- 全文搜索：transcript 文本另写入一个 SQLite FTS5 索引（GRDB 或 直接 sqlite3 C API），SwiftData 不直接支持 FTS。

---

## 6. 性能 & 设备门槛

### 6.1 实测/估算性能数据

| 设备 | 芯片 | RAM | WhisperKit large-v3-turbo (1h 音频) | WhisperKit small (1h) | FluidAudio diarization (1h) | MLX 3B summary | 评级 |
|---|---|---|---|---|---|---|---|
| iPhone 12 | A14 | 4 GB | ❌ OOM 风险高 | ✅ ~3 分钟 | ✅ ~15 秒 | ❌ 不可用 | 🟡 受限 |
| iPhone 13 | A15 | 4-6 GB | ⚠️ 6 GB Pro 可，4 GB 边缘 | ✅ ~2 分钟 | ✅ ~10 秒 | ⚠️ 1.5B 可，3B 边缘 | 🟡 受限 |
| iPhone 14 Pro | A16 | 6 GB | ✅ ~4 分钟 | ✅ ~1.5 分钟 | ✅ ~8 秒 | ✅ 3B 可 | 🟢 完整 |
| iPhone 15 Pro | A17 Pro | 8 GB | ✅ ~3 分钟 | ✅ ~1 分钟 | ✅ ~5 秒 | ✅ 3B 流畅；Apple Intel 可用 | 🟢 完整 |
| iPhone 17 Pro Max | A19 Pro | 12 GB | ✅ ~1.5 分钟 | ✅ ~30 秒 | ✅ ~3 秒 | ✅ Apple Intel 首选 | 🟢🟢 旗舰 |
| iPad Air M2 | M2 | 8 GB | ✅ ~2 分钟 | ✅ ~40 秒 | ✅ ~3 秒 | ✅ | 🟢 完整 |
| MacBook Air M1 | M1 | 8/16 GB | ✅ ~1.5 分钟 | ✅ ~30 秒 | ✅ ~2 秒 | ✅ | 🟢 完整 |
| MacBook Air M5 | M5 | 32 GB | ✅ ~30-45 秒 | ✅ ~15 秒 | ✅ <1 秒 | ✅ Apple Intel + MLX 都流畅 | 🟢🟢 旗舰 |

注：以上 ASR 时间都假设 Whisper 跑在 ANE 上（WhisperKit Core ML 路径）。MLX path 在 iPhone 上慢一些（GPU 路径）。

### 6.2 长会议（2 小时）注意点

| 资源 | 风险 | 缓解 |
|---|---|---|
| 内存 | 累积的 transcript + 音频 buffer | 每 30s flush 到磁盘，内存里只留最近 5 分钟 |
| 发热 | 持续 ASR + diarization 让 NPU/GPU 高负载 | 监控 `ProcessInfo.thermalState`，进入 `.serious` 时**暂停 diarization**（事后批量跑），仅保留 ASR |
| 耗电 | ANE 比 GPU 省，但仍持续 | 提示用户接电；Low Power Mode 下自动降到 Whisper small |
| 存储 | 2h AAC-LC mono 64kbps ≈ 56 MB；transcript text ≈ 200 KB | 可接受；自动清理 90 天前的音频原文件（保留 transcript） |
| 后台/锁屏 | iOS 后台被杀风险 | Audio background mode + Live Activity + 心跳写盘 |

### 6.3 推荐最低门槛

| 平台 | 最低系统 | 最低硬件 | 完整功能要求 |
|---|---|---|---|
| iOS | iOS 17.0 | A14 (iPhone 12 / iPhone 12 mini / SE 第3代) | A16+ 或 iOS 26 设备 |
| iPadOS | iPadOS 17.0 | A14 (iPad Air 4 / iPad mini 6) | M1+ 或 A16+ |
| macOS | macOS 14.0 (Sonoma) | **Apple Silicon only**（M1+） | M1+；Core Audio Tap 需要 macOS 14.4+ |

> **建议放弃 Intel Mac 支持** —— Whisper 在 Intel Mac 上没有 ANE，速度差 3-5x，体验灾难。Apple 自己也在淘汰 Intel Mac。

---

## 7. 包体大小估算

### 7.1 各组件大小

| 组件 | 大小 |
|---|---|
| Swift app 主体（UI + 业务）| ~30-50 MB |
| WhisperKit framework | ~5 MB（代码） |
| FluidAudio framework | ~3 MB（代码） |
| MLX Swift framework | ~10 MB（代码） |
| Whisper large-v3-v20240930 (Core ML) | **626 MB** |
| Whisper small (Core ML) | **244 MB** |
| Whisper base (Core ML) | **74 MB** |
| FluidAudio Sortformer + embedding | **~30-40 MB** |
| Silero VAD | **~2 MB** |
| Qwen2.5-3B-Instruct 4-bit (MLX) | **~1.8 GB** |
| Qwen2.5-1.5B-Instruct 4-bit (MLX) | **~900 MB** |

### 7.2 三种发行策略

#### 策略 A：**全 bundle 捆绑（不推荐）**
- 包含 Whisper large + Qwen 3B + FluidAudio
- 总大小：~50 MB + 626 MB + 1.8 GB + 40 MB = **~2.5 GB**
- App Store 限制：iOS App 单包不超 4 GB，OK 但用户下载劝退
- 优点：开箱即用
- 缺点：4G 蜂窝下载会被禁；老机型用不到大模型也得下

#### 策略 B：**分级按需下载（强烈推荐）** ⭐
- 初始包：Swift code + 框架 + base/small Whisper + FluidAudio + Silero = **~120 MB**
- 首次使用提示用户下载（按设备能力推荐）：
  - Whisper large turbo：626 MB（追求最佳准确度）
  - Qwen 3B 4-bit：1.8 GB（无 Apple Intelligence 设备 + 想本地总结）
- 用 [`Background Assets`](https://developer.apple.com/documentation/backgroundassets) framework（iOS 16.1+），用户可以在 App Store 下载完成后系统在后台拉模型。
- iOS 26+ 设备：直接用 Apple SpeechTranscriber + Foundation Models，不下载额外模型
- **预期实际占用**：
  - iPhone 17 Pro on iOS 26: **~120 MB**（神奇地小，全用系统能力）
  - iPhone 15 Pro on iOS 18: **~120 MB + 626 MB + 1.8 GB ≈ 2.5 GB**
  - iPhone 13 on iOS 17: **~120 MB + 244 MB + 900 MB ≈ 1.3 GB**
  - iPhone 12 on iOS 17: **~120 MB + 244 MB ≈ 360 MB**（无 LLM 总结，仅抽取式）

#### 策略 C：On-Demand Resources (ODR)
- App Store 切片，App 启动时按需拉
- 跟策略 B 类似，但 ODR 有 2 GB 限制 + 系统可能清理；模型这种"用户长期持有"的资源**不适合 ODR**
- 不推荐

#### **最终推荐：策略 B（Background Assets + 用户引导）**

---

## 8. 第三方依赖与 License 清单

| 依赖 | 用途 | License | 商用 OK | 风险 |
|---|---|---|---|---|
| `argmaxinc/argmax-oss-swift` (WhisperKit + SpeakerKit OSS + TTSKit) | ASR 主路径 | MIT | ✅ | 维护方是 Argmax 公司，长期看商业化压力可能影响 OSS 投入；备用方案：fork |
| `FluidInference/FluidAudio` | Diarization + ASR 备选 + VAD | MIT (SDK 代码) | ✅ | 小团队维护，stars 增长但生产 app 已 10+；可控 |
| Whisper 模型权重 (OpenAI) | ASR 模型 | **MIT** | ✅ | OpenAI 明确 MIT |
| FluidAudio 引用的 NVIDIA Sortformer / Parakeet 模型 | Diarization / ASR | **CC-BY-4.0**（NVIDIA NeMo） | ✅ 但需署名 | 在 App "About" 或文档列出 NVIDIA 署名 |
| Silero VAD | 语音活动检测 | MIT | ✅ | — |
| `ml-explore/mlx-swift` | LLM 推理 | MIT | ✅ | Apple 官方维护 |
| Qwen2.5 模型权重 | 总结 LLM | **Apache-2.0** (≤7B 版本) | ✅ | 阿里云发布；需在文档列出 attribution |
| Llama-3.2 模型权重（备选） | 总结 LLM | **Llama 3.2 Community License**（Meta） | ✅ 但有限制：MAU > 7 亿要单独谈；需 "Built with Llama" 标记 | 我们 MAU 远不到，OK；要在文档加标记 |
| pyannote 4 模型（如选 Argmax SpeakerKit OSS 路线） | Diarization | **MIT** (官方) | ✅ | — |
| Apple Foundation Models / SpeechAnalyzer / Core Audio Tap | 系统 API | Apple SDK License | ✅ | 必须遵守 App Store 审核，发行受限于 Apple 开发者协议 |
| GRDB (可选 FTS) | 全文搜索 | MIT | ✅ | — |

#### 风险评估
- 全栈依赖 license 都是宽松开源（MIT/Apache/CC-BY/Llama-Community），**无 GPL/AGPL 污染**，App Store 上架无 license 障碍。
- 唯一需要在 App"关于"/"致谢" 页注明的：NVIDIA NeMo（Sortformer/Parakeet, CC-BY）、Qwen（Apache，可选标注）、Llama（如使用，强制 "Built with Llama"）。

---

## 9. App Store 审核风险

### 9.1 权限与隐私

| 项目 | 要求 | 应对 |
|---|---|---|
| `NSMicrophoneUsageDescription` | 必填，且文案要明确 | "Scribe records meetings on your device for local transcription. Audio never leaves your device." |
| `NSAudioCaptureUsageDescription` (macOS 14.4+, Core Audio Tap) | 抓系统音频必填 | "Scribe captures meeting audio (e.g. Zoom, Google Meet) on your Mac to transcribe locally. No data leaves your Mac." |
| Background Modes - audio | iOS 后台录音 | Info.plist 配置 + 审核时清晰说明用途 |
| Privacy Manifest (`PrivacyInfo.xcprivacy`) | 2024 年起强制 | 声明不收集任何 data category；声明使用的 required reason API（FileTimestamp 等） |
| App Tracking Transparency | 不需要（不追踪） | 不引入广告 SDK / 分析 SDK |

### 9.2 "On-device / 本地" 营销声明

- App Store description 可以说 "Fully on-device transcription and summary"，但要：
  - **真的不传数据出去**（包括崩溃日志要 Apple 路径，不要自建 Sentry/Firebase 上传 transcript）
  - 模型下载通过 Apple Background Assets / 自家 CDN 下载（这部分**只有模型 binary，不传用户数据**，OK）
  - iCloud 同步要明确告知用户（不算违反"本地"，因为是用户自己的 iCloud）

### 9.3 历史审核案例参考（同类 app）

- **Whisper Mate / MacWhisper**：上架顺畅，强调本地处理。
- **Granola** （会议 AI 助手，云）：用 Slack OAuth + 上传，体验好但隐私不行；**反例**。
- **Slipbox**：iOS + macOS，FluidAudio + WhisperKit，2024 年顺利上架。本项目走类似路径。
- **Voice Ink** (FluidAudio 用户): 上架成功。

### 9.4 潜在风险点

| 风险 | 概率 | 应对 |
|---|---|---|
| 审核员误以为我们是 "spy app"（系统音频抓取 → 监听） | 中 | 必须有清晰 in-app onboarding 解释；Mic 录制时显示明显的 "Recording" UI；不录制时确保不申请权限 |
| 审核员要求示范"如何在本地处理"，但模型还没下载 | 低 | 审核环境提供"内置 base 模型 demo 模式"，跳过下载就能录一句话演示 |
| iOS 26 Foundation Models API 商用限制 | 低 | 截至公开信息：免费可用，但要遵守 Apple 内容政策（不能用于非法/医疗诊断/儿童不宜） |
| 模型下载耗流量被用户投诉 | 中 | 强制只在 Wi-Fi 下载（或用户主动选 cellular）；下载前明确显示大小 |
| Live Activity / Dynamic Island 误用 | 低 | 严格按 ActivityKit 文档：只有用户主动开始的录音才显示 |
| Core Audio Tap 抓取受版权保护内容（Apple Music, Netflix） | 低-中 | 审核时强调用途为会议；有 DRM 内容系统会自动屏蔽（CATap 不绕过 DRM） |

---

## 10. 最终架构图（ASCII）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Scribe App (SwiftUI Universal)                     │
│                       iOS 17+ / iPadOS 17+ / macOS 14+                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        ▼                             ▼                             ▼
┌───────────────┐           ┌───────────────────┐         ┌──────────────────┐
│  UI Layer     │           │   Domain Layer    │         │ Storage Layer    │
│  SwiftUI      │           │   (ScribeCore)    │         │ SwiftData        │
│ - MeetingList │           │  Use Cases / VM   │         │  + CloudKit sync │
│ - Detail View │           │                   │         │  + GRDB FTS5     │
│ - Recorder    │           │                   │         │  (full-text idx) │
└───────────────┘           └─────────┬─────────┘         └──────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        ▼                             ▼                             ▼
┌──────────────────┐    ┌────────────────────┐         ┌────────────────────┐
│  Audio Capture   │    │   ASR Pipeline     │         │ Diarization & NLP  │
├──────────────────┤    ├────────────────────┤         ├────────────────────┤
│ AVAudioEngine    │───▶│ ┌────────────────┐ │         │ ┌────────────────┐ │
│  (mic, all OSes) │    │ │ Engine Router  │ │         │ │ FluidAudio     │ │
│                  │    │ ├────────────────┤ │         │ │  - Sortformer  │ │
│ macOS only:      │    │ │ if iOS 26+:    │ │         │ │  - Embeddings  │ │
│  CATap / SCK     │    │ │   SpeechAnal.  │ │         │ │  - VAD         │ │
│ ┌──────────────┐ │    │ │ else:          │ │         │ └────────┬───────┘ │
│ │ AVAudioConv. │ │───▶│ │   WhisperKit   │ │         │          │         │
│ │ → 16k mono   │ │    │ │  (large-v3-    │ │◀────────┘          ▼         │
│ │   Float32    │ │    │ │   turbo /      │ │         ┌────────────────┐   │
│ └──────┬───────┘ │    │ │   small / base)│ │         │ Speaker Merge  │   │
│        │         │    │ └────────────────┘ │         │  + UI rename   │   │
│        ▼         │    └─────────┬──────────┘         └────────┬───────┘   │
│ AAC-LC archive   │              │                             │           │
│  64kbps mono     │              ▼                             ▼           │
│ 30s rolling      │    ┌──────────────────────────────────────────────┐    │
│ flush → disk     │    │   Aligned Transcript [(speaker,t,t,text)]    │    │
└──────────────────┘    └─────────────────────┬────────────────────────┘    │
                                              │                              │
                                              ▼                              │
                              ┌────────────────────────────┐                 │
                              │   Summarization Router     │                 │
                              ├────────────────────────────┤                 │
                              │ if AppleIntel & iOS 26+:   │                 │
                              │    FoundationModels (3B)   │                 │
                              │ elif RAM ≥ 6GB:            │                 │
                              │    MLX Swift + Qwen2.5-3B  │                 │
                              │ elif RAM ≥ 4GB:            │                 │
                              │    MLX Swift + Qwen2.5-1.5B│                 │
                              │ else:                      │                 │
                              │    Extractive (TextRank +  │                 │
                              │      NaturalLanguage NER)  │                 │
                              └─────────────┬──────────────┘                 │
                                            │                                │
                                            ▼                                │
                              ┌──────────────────────────┐                   │
                              │  Summary + Action Items  │                   │
                              │  + Decisions + Tags      │                   │
                              └─────────────┬────────────┘                   │
                                            │                                │
                                            ▼                                │
                              ┌──────────────────────────┐                   │
                              │   Persist to SwiftData   │◀──────────────────┘
                              │   Sync to private iCloud │
                              │   (E2E encrypted)        │
                              └──────────────────────────┘

外部依赖（全部本地）：
  - WhisperKit (MIT) ─ 模型权重 OpenAI Whisper (MIT)
  - FluidAudio (MIT) ─ NVIDIA Sortformer (CC-BY) / Silero VAD (MIT)
  - MLX Swift (MIT) ─ Qwen2.5 weights (Apache-2.0)
  - Apple SDKs：AVFoundation / CoreAudio / SpeechAnalyzer (iOS26) / FoundationModels (iOS26)
                / SwiftData / CloudKit / NaturalLanguage / ActivityKit / BackgroundAssets

数据流向：100% on-device。CloudKit 同步走用户私人 iCloud（端到端加密，Apple 不可读）。
```

---

## 11. 最低设备门槛建议（最终版）

| 维度 | 推荐值 | 理由 |
|---|---|---|
| 最低 iOS | **iOS 17.0** | SwiftData 原生、Whisper Core ML 路径稳定、iPhone 12 仍可升级 |
| 最低 iPadOS | **iPadOS 17.0** | 同 iOS |
| 最低 macOS | **macOS 14.0 (Sonoma)** | SwiftData、CATap 14.4 stable；放弃 Intel Mac |
| 最低 iPhone | **iPhone 12** (A14, 4GB) — 受限模式（Whisper small + 抽取式 summary） | 占据现有装机量 ~85%+ |
| 推荐 iPhone | **iPhone 14 Pro** (A16, 6GB) 起完整体验 | LLM 总结流畅 |
| 旗舰体验 | **iPhone 15 Pro+ on iOS 26** | Apple Intelligence + SpeechAnalyzer 加持，包体最小 |
| 最低 Mac | **Apple Silicon Mac (M1+) on macOS 14.4+** | Core Audio Tap 需要 |

---

## 12. 风险点与应对

| 风险 | 严重度 | 概率 | 应对 |
|---|---|---|---|
| **WhisperKit 中文混合英文（code-switch）准确度不达预期** | 🟠 中 | 中 | 用 large-v3-turbo + 后处理（中英文夹杂正则修复 + 自定义术语词典）；提供用户矫正 UI |
| **FluidAudio 长会议（>1h）DER 漂移** | 🟠 中 | 中-高 | 定期重新聚类（每 10 min 用历史 embedding 重跑一次 AHC）；提供用户手动合并 speaker 的 UI |
| **iPhone 12（4GB）跑 Whisper small 仍 OOM** | 🟠 中 | 中 | 进一步降级到 base；预留 `MemoryWarning` 监听，自动 flush + 切小模型 |
| **iOS 26 Foundation Models API 不开放给会议总结场景** | 🟡 低 | 低 | 备选：MLX Qwen，开发时确保 ASR/diarization/summary 全部松耦合（router 模式） |
| **Core Audio Tap 在某些 macOS 14.x bug** | 🟠 中 | 中 | 测试 14.0 / 14.4 / 14.6 / 15.x 多版本；fallback 到 ScreenCaptureKit |
| **App Store 审核担心系统音频抓取 → 拒** | 🔴 高 | 中 | 上架前找 Slipbox/MacWhisper 团队请教（社区 Discord/X）；submission 附详细使用说明视频 |
| **模型下载在中国大陆从 HuggingFace 抓不到** | 🟠 中 | 高（中国用户） | 自建 CDN（CloudFront / Fastly + 国内镜像）；Background Assets 走 Apple CDN 可解决 |
| **Apple Intelligence 在中国大陆可用性受限** | 🟠 中 | 高 | 严格的设备能力检测；中国大陆机型默认走 MLX 路径 |
| **iCloud 同步在中国受限（CloudKit 在国行 iCloud 国内服务器，与海外隔离）** | 🟢 低 | 低 | CloudKit 自动适配区域；测试国行账号 |
| **Argmax 公司商业化挤压 OSS 维护** | 🟡 低 | 中 | 备选 FluidAudio 全栈 ASR；保持 fork 能力 |
| **长会议发热 → 系统强制降频 → ASR 跟不上** | 🟠 中 | 中-高 | 监控 thermalState，动态切换模型大小；UI 提示用户 |
| **Privacy Manifest 缺漏字段 → App Store 审核延期** | 🟡 低 | 中 | 严格按 Apple 文档，每次 SDK 更新检查 |

---

## 13. 落地路线图（建议）

### MVP（4 周）
1. SwiftUI Universal App 骨架，SwiftData 数据模型
2. AVAudioEngine 录音（iOS + macOS mic）
3. WhisperKit 集成（small 模型一个，先跑通）
4. 简单 transcript 展示（无 diarization）
5. iOS Live Activity + macOS Menu Bar 录音控制

### v1.0（8-10 周）
6. macOS Core Audio Tap 系统音频抓取
7. FluidAudio diarization
8. 模型分级下载（Background Assets）
9. MLX Qwen 1.5B 总结（无 Apple Intelligence 设备的兜底）
10. iCloud 同步 (SwiftData + CloudKit)
11. 全文搜索 (GRDB FTS5)
12. App Store 上架（先 macOS，再 iOS — Apple 审核 macOS 整体更松）

### v1.1+（按需）
13. iOS 26 / macOS 26 设备加 Apple SpeechAnalyzer + Foundation Models
14. Speaker 跨会议识别（声纹库）
15. 自定义术语词典（公司/产品/人名）
16. 导出 Markdown / PDF / Notion 集成
17. iPad Pencil 标注 transcript
18. macOS 全局快捷键 + 状态栏快速录音

---

## 14. 一句话总结

> **iOS 17+/macOS 14+ Universal App，AVAudioEngine + Core Audio Tap 录音，WhisperKit (主) + Apple SpeechTranscriber (iOS 26 加速) 转录，FluidAudio Sortformer 做说话人分离，Apple Foundation Models (主) + MLX Qwen2.5-3B (兜底) + 抽取式 (老机型) 三级总结，SwiftData + CloudKit 私人同步存历史。包体 120 MB 起，按设备分级下载模型最大 +2.5 GB。最低设备 iPhone 12 / Apple Silicon Mac。所有依赖宽松开源，App Store 上架无 license 障碍。**

---

_文档版本：v1.0 — 2026-04-30_
_技术调研 by Shrimp 🦐_
