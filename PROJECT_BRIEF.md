# Whisperly - Project Brief

> 创建日期：2026-04-30
> 决策人：Sharp
> 状态：✅ 立项

---

## 一句话

**100% 本地处理的苹果全平台会议助手**——录音、转录、说话人分离、AI 总结全部不出设备。

## 名字

**Whisperly**

- 暗合 Whisper 技术（信任感）
- "-ly" 后缀暗示"轻松、流畅"
- ASO 友好，独特性高
- 域名/商标无明显冲突（待最终核实）

## 平台

- **iOS 17+**（iPhone 12 及以上）
- **iPadOS 17+**
- **macOS 14+，Apple Silicon only**
- **Universal App**，一套代码三端

⚠️ Intel Mac 不支持，跳过。

## MVP 功能（V1.0 必做）

1. ✅ 本地录音（iOS/iPad/Mac）
2. ✅ 实时/会后本地转录（多语言，中英为主）
3. ✅ **本地说话人识别**（核心差异化）
4. ✅ 本地 AI 总结（关键点 + 行动项）
5. ✅ 历史记录 + 全文搜索
6. ✅ iCloud 同步（用户可关）
7. ✅ 导出（Markdown / TXT / SRT）
8. ✅ 多语言 UI（10+ 语言）
9. ✅ 暗黑模式

## V2.0 候选（不在 MVP）

- AI Q&A（基于历史会议）
- 自定义术语库
- 实时翻译
- Apple Watch 控制（开始/暂停录音）
- Shortcuts 集成
- 标签、收藏、分组管理

## 严禁做

- ❌ 云端备份（除 iCloud 用户私域）
- ❌ 把数据上传我们的服务器
- ❌ 调用 OpenAI/Anthropic 等任何云端 API
- ❌ 用户行为追踪
- ❌ 付费墙挡核心功能

## 时间表

| 阶段 | 时长 | 内容 |
|---|---|---|
| Week 1-2 | 2 周 | Xcode 工程 + 录音 + WhisperKit 集成 |
| Week 3-4 | 2 周 | FluidAudio diarization + 数据模型 |
| Week 5-6 | 2 周 | 总结 + UI + 历史记录 |
| Week 7 | 1 周 | macOS/iPad 适配 + 多语言 |
| Week 8 | 1 周 | 测试 + 截图 + 提交审核 |

**目标：8 周内 ship MVP。**

## 详细参考

- 市场调研：`MARKET_RESEARCH.md`
- 技术调研：`TECH_RESEARCH.md`
- 商业模式：`MONETIZATION.md`
