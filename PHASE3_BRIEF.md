# Whisperly - Phase 3 Engineering Brief

> Status: Phase 1 ✅ | Phase 2 ✅ | Code Review Fixes ✅
> Phase 3 任务：真本地 AI 总结（Apple Foundation Models + MLX 兜底 + 抽取式兜底）
> 16/16 tests pass, iOS + macOS build clean

## Phase 3 目标

替换 `MockSummarizationService`，实现三级本地总结方案：
1. **Apple Foundation Models**（iOS 26+ / macOS 26+，A17 Pro+ / M1+）—— 最优选
2. **MLX Swift + Qwen2.5-3B 4-bit**（iOS 17+ / macOS 14+，A14+）—— 兜底
3. **抽取式总结**（纯算法，零模型）—— 终极兜底（任何设备都能跑）

## 必做

### 1. Apple Foundation Models 集成（主力方案）

**Framework**: `FoundationModels` (iOS 26+, macOS 26+)
- 仅限 Apple Intelligence 兼容设备（A17 Pro+ / M1+）
- 系统级本地 LLM，不用下载模型，不用管理内存
- 支持 15 种语言含中文

**实现**：
- `AppleFoundationModelsSummarizationService: SummarizationServiceProtocol`
- 用 `#available(iOS 26, macOS 26, *)` 守卫
- Prompt 设计（用 `@Generable` macro 如果支持，否则纯 text prompt）：
  - 输入：转录文本 + 说话人标签
  - 输出：结构化的 `MeetingSummaryDTO`（summary + keyPoints + actionItems）
  - 中英双语 prompt（根据转录语言自动切换）
- Token 限制：Apple Foundation Models 有 context window 限制，如果转录太长需要分块 → 分块总结 → 最终汇总
- 调研 `FoundationModels` 的实际 API：`LanguageModelSession`, `GenerationOptions`, structured output via `@Generable`

### 2. MLX Swift + Qwen2.5-3B 兜底

**Package**: `https://github.com/ml-explore/mlx-swift-examples` 或 `mlx-swift`
- 用于 Apple Intelligence 不可用的设备（A14-A16, M1 但 iOS < 26 等）
- 模型：Qwen2.5-3B-Instruct 4-bit quantized（~1.5 GB）

**实现**：
- `MLXSummarizationService: SummarizationServiceProtocol`
- 模型按需下载（复用 `ModelManager` 的下载框架，或扩展它）
- 推理限制：max_tokens 合理设置，避免 OOM
- 温度 0.3（总结任务需要确定性）
- 同样的 prompt 策略（分块 + 汇总）
- 性能防护：设置超时，推理太慢就 fallback 到抽取式

### 3. 抽取式总结（终极兜底）

**纯算法，零依赖**：
- `ExtractiveSummarizationService: SummarizationServiceProtocol`
- 算法：TF-IDF 句子权重 + TextRank 变体
  - 计算每句 TF-IDF 向量
  - 按句子重要性排序
  - 取 top-K 句作为摘要
  - keyPoints = top 句子
  - actionItems = 包含动作动词的句子（"will", "need to", "should", "action", "要", "需要", "计划" 等模式匹配）
- 不依赖任何 ML 模型
- 任何设备都能跑，即时返回

### 4. SummarizationEngine（三级调度器）

新类：`SummarizationEngine`
- 自动检测设备能力，选择最优方案：
  ```
  if #available(iOS 26, macOS 26, *), FoundationModels.isAvailable {
      → AppleFoundationModelsSummarizationService
  } else if MLXModelManager.isModelDownloaded("qwen2.5-3b-4bit") {
      → MLXSummarizationService
  } else {
      → ExtractiveSummarizationService
  }
  ```
- 如果上层失败（OOM、超时），自动降级到下一层
- 返回 `MeetingSummaryDTO` + 标注用哪个引擎生成的（UI 可选显示）
- Conforming to `SummarizationServiceProtocol`，无缝替换

### 5. Summary UI 增强

**MeetingDetailView** 更新：
- 总结区域显示：摘要 + 要点 + 行动项
- 行动项带 checkbox（本地勾选，存 SwiftData）
- 如果总结是抽取式的，显示小 badge "基础总结"（暗示升级设备/下载模型可获得更好总结）
- 重新生成总结按钮（切换引擎或重新跑）
- 总结生成中显示 loading + 预估时间

**Settings** 更新：
- 显示当前总结引擎（Apple AI / MLX Qwen / 基础）
- MLX 模型管理（下载/删除，类似 WhisperKit 模型管理）
- 总结语言偏好

### 6. 总结 Prompt 设计

#### 英文 Prompt
```
You are a meeting assistant. Summarize the following meeting transcript.

Transcript (with speaker labels):
{transcript}

Provide:
1. A concise summary (2-3 paragraphs)
2. Key points (bullet list, 3-7 items)
3. Action items with assignees if identifiable (bullet list)

Format as JSON:
{"summary": "...", "keyPoints": ["..."], "actionItems": ["..."]}
```

#### 中文 Prompt
```
你是一个会议助手。请总结以下会议记录。

会议记录（含说话人标签）：
{transcript}

请提供：
1. 简洁摘要（2-3 段）
2. 关键要点（3-7 条）
3. 待办事项（如能识别则标注负责人）

以 JSON 格式输出：
{"summary": "...", "keyPoints": ["..."], "actionItems": ["..."]}
```

### 7. 长文本分块策略

当转录超过 context window 时：
- 按说话人 turn 边界切块（不在句子中间切）
- 每块独立总结
- 最后一次汇总调用，输入所有块的摘要，输出最终总结
- 如果汇总也超长 → 递归（最多 2 层）

### 8. Tests

新测试：
- `SummarizationEngineTests`：验证三级降级逻辑
- `ExtractiveSummarizationTests`：验证 TF-IDF + 动作动词提取
- `ChunkingTests`：验证长文本分块在 speaker turn 边界切割
- 更新 `PipelineTests`：用新 engine 跑端到端

所有测试用 mock/extractive，**不在 CI 拉 MLX 模型**。

## 不做（Phase 4）

- ❌ App 图标（Sharp 提供/AI 生成）
- ❌ 其他 8 语翻译
- ❌ fastlane + 截图 + 上架
- ❌ App Store 宣传图

## 工程要求

- Swift 6 strict concurrency
- 所有 user-facing strings 走 `String(localized:)`
- 新依赖走 SPM
- `#available` 守卫所有 iOS 26 / macOS 26 API
- 每个新功能至少一个测试
- 构建 + 测试通过：

```bash
xcodebuild -scheme Whisperly -destination 'platform=iOS Simulator,id=FDD60F1A-B8D6-431C-A055-AC63117E843F' build
xcodebuild -scheme Whisperly -destination 'platform=macOS' EXCLUDED_ARCHS=x86_64 build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
xcodebuild test -scheme Whisperly -destination 'platform=iOS Simulator,id=FDD60F1A-B8D6-431C-A055-AC63117E843F'
```

## Workflow

1. `cd /Users/shrimp/Desktop/code/Whisperly && git status`（确认干净）
2. 通读 PHASE2_REPORT.md + PHASE1_REVIEW.md（了解现状 + 代码质量标准）
3. 通读 TECH_RESEARCH.md 第 4 节（总结方案详细技术背景）
4. 先实现 ExtractiveSummarizationService（最简单，不需要外部依赖）
5. 实现 AppleFoundationModelsSummarizationService（iOS 26 #available）
6. 添加 MLX Swift SPM + 实现 MLXSummarizationService
7. 实现 SummarizationEngine 三级调度
8. 更新 UI（Detail 总结增强 + Settings 引擎显示）
9. 实现分块策略
10. 测试
11. 构建验证
12. 写 PHASE3_REPORT.md
13. 多个原子 git 提交
14. Wake hook：

```bash
openclaw system event --text "Whisperly Phase 3 done — see PHASE3_REPORT.md" --mode now
```

## 风险点

- **Apple Foundation Models API 可能在 Xcode 18 beta 才有**：如果当前 Xcode 不支持 `FoundationModels` framework，写好代码结构但用 `#if canImport(FoundationModels)` 条件编译，不影响构建
- **MLX Swift 包体大**：模型 ~1.5GB 按需下载，不打进 ipa
- **OOM 风险**：MLX 在 iPhone 12 (4GB RAM) 跑 3B 模型可能 OOM → 超时保护 + 降级
- **总结质量**：抽取式总结质量不如 LLM，但作为兜底可接受
