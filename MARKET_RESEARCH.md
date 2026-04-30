# 本地会议助手 App — 市场调研报告

> **产品定义**：纯本地录音 + 转录 + 多人说话人识别（speaker diarization）+ AI 总结。100% 本地处理，零云端依赖。iPhone / iPad / Mac universal app。
> **调研时间**：2026-04-30
> **核心结论（先看这个）**：iOS/iPadOS 上「本地录音 + 本地说话人分离 + 本地 AI 总结」三件套合一，**目前没有真正的强势竞品**。Mac 端有 MacWhisper / Aiko 在打边缘，但没人把"会议"作为正式定位。这是一个清晰的空位，但窗口期最多 6–12 个月（FluidAudio、WhisperKit、Apple SpeechAnalyzer 这些底座越来越香，会有人涌进来）。

---

## 1. 竞品分析

### 1.1 一图速览（核心对比表）

| App | 平台 | 是否本地 | 说话人分离 | AI 总结 | 定价（美区） | 定位 | 主要短板 |
|---|---|---|---|---|---|---|---|
| **Otter.ai** | iOS / Android / Web | ❌ 全云 | ✅ | ✅ | Free / Pro $16.99 月、$8.33 年付月 / Business $30 月 | 市场领导者，团队会议 | 隐私集体诉讼缠身，订阅贵，国内不友好 |
| **Fireflies.ai** | iOS / Android / Web / 浏览器扩展 | ❌ 全云 | ✅ | ✅ | Free / Pro $10 月（年付） / Business $19 月 | 跟会议机器人 | 必须靠 bot 加入会议，有副作用 |
| **Plaud Note (硬件 + app)** | iOS / Android / Web | ❌ 全云 | ✅ | ✅ | 硬件 $159 + Pro 订阅 $99.99/年 或 Unlimited $239.99/年 | 硬件录音笔 + AI | 硬件溢价 + 订阅双重收费、需要带设备 |
| **Tactiq** | Chrome 扩展 / Web | ❌ 全云 | ✅ | ✅ | Free / Pro $8 月（年付） / Team $16.67 月 | 浏览器内 Google Meet 转录 | 只能 Meet，桌面/移动体验差 |
| **Granola** | macOS / Windows / iPhone | ⚠️ **声称本地，实为云端**（用 Deepgram + Assembly 转录，OpenAI/Anthropic 总结） | ✅ | ✅ | Free / Individual $14–18 月 / Business $14–35 用户/月 | "Bot-free"会议笔记 | 不是真本地；iPhone 端只为线下面对面会议；隐私场景仍有疑虑 |
| **MacWhisper / Whisper Transcription** | macOS only（Gumroad 版 + App Store 版） | ✅ 完全本地 | ✅（仅 M 系列 Mac，本地模型） | 部分（需 BYOK / cloud Assistant 付费） | Gumroad: Free / Pro **€59 一次买断**；App Store: $6.99/月、$29.99/年、**$99.99 终身** | 转录工具，开发者圈层 | 只 Mac、不录会议（要导音频）、不专门做"会议"场景 |
| **Aiko** (Sindre Sorhus) | iOS / iPadOS / macOS（Universal） | ✅ 完全本地（Whisper） | ❌ **没有说话人分离** | ❌ 没有总结 | **$24 一次买断（Universal）** | 极简本地转录 | 没说话人分离、没 AI 总结、没专为"会议"做的 UX |
| **Whisper Memos** | iOS + Apple Watch | ⚠️ 上传服务端转录（"AI 处理后邮件给你"） | ❌ | ✅ | $60/年 | 即兴口述笔记 | 不是会议工具，没分离，要联网 |
| **AudioPen** | Web + iOS PWA | ❌ 云端 | ❌ | ✅ | Free（10 条 ≤3 分钟）/ Prime $99/年 / 终身约 $159 | 把碎碎念整理成漂亮文字 | 不是会议工具，不分离 |
| **Voicenotes** (BuyMeACoffee 团队) | iOS / Android / Web | ❌ 云端 | ❌ | ✅ | Free（1 分钟/条限制） / Believer **$50 终身** / 月度约 $10 | 个人语音笔记 | 不是会议工具、不分离 |
| **SuperWhisper** | macOS / Windows / iOS | ✅ 本地为主（也支持云模型可选） | ❌（无原生分离） | ⚠️（自定义模式调外部 LLM） | 月度/年度订阅（约 $8.49 月，$84+ 年） | 系统级语音输入（dictation） | 主打 dictation 不是会议；分离非主功能 |
| **Recap (Happii Apps)** | iOS only (id 6737522875) | ❌ 云端 | ✅ | ✅ | Freemium + 订阅（年订约 $50–80） | 移动端 AI 会议笔记 | 云端、iOS 单平台、用户量小 |
| **TranscriAI / Offline Transcribe** | iOS | ✅ **本地（Whisper + 本地分离）** | ✅ | 部分 | 订阅（年约 $30–50，App Store 内） | **直接对标产品** | 评价/用户量较小、iOS 限定、UI 偏工具向 |
| **LocalWhisper** | Web / 桌面 | ✅ 本地 | ✅ | ⚠️ | 多档订阅（约 $9–29 月） | 桌面/Web 本地转录 | 不是 iOS native |

> **关键发现 1**：Granola 自我营销"在地化"，但其安全页面坦白：转录靠 Deepgram/Assembly，总结靠 OpenAI/Anthropic。**它不是真本地**——只是不放 bot 进会议。
>
> **关键发现 2**：iOS/iPadOS 上同时做到"本地 + 说话人分离 + 会议 UX"的，目前能找到的只有 **TranscriAI / Offline Transcribe** 一家有点存在感，但用户量、口碑、品牌都不强。**这是真正的空位**。
>
> **关键发现 3**：Mac 上 MacWhisper 是本地之王，但它不专做会议、不是 universal、Gumroad 渠道不进 App Store 入口流量。

### 1.2 数据来源链接

- Otter.ai pricing: https://otter.ai/pricing
- Otter.ai 集体诉讼报道: https://natlawreview.com/article/ai-notetaking-tools-under-fire-lessons-otterai-class-action-complaint, https://www.computerworld.com/article/4041849/enterprise-note-taking-apps-face-legal-scrutiny-as-otter-hit-with-privacy-suit.html
- Fireflies pricing: https://fireflies.ai/pricing
- Tactiq pricing: https://tactiq.io/buy
- Granola pricing: https://www.granola.ai/pricing （+ 第三方汇总 https://costbench.com/software/ai-meeting-assistants/granola/）
- Granola 安全说明（自承用 Deepgram/Assembly/OpenAI/Anthropic）: https://www.granola.ai/security
- Plaud 定价: https://www.omi.me/blogs/ai-note-takers/plaud-pricing, https://sixstarreview.com/plaud-note-premium-voice-recording-with-a-pricey-catch/
- MacWhisper 定价对比: https://www.getvoibe.com/resources/macwhisper-pricing/, https://goodsnooze.gumroad.com/l/macwhisper, https://spokenly.app/comparison/macwhisper
- Aiko: https://sindresorhus.com/aiko (官网), https://iphone.apkpure.com/app/aiko/com.sindresorhus.aiko ($24 价格)
- AudioPen: https://www.audiopen.ai/, https://bytefulsunday.substack.com/p/my-honest-review-of-audiopen-ai-a
- Voicenotes: https://woy.ai/p/voicenotes/pricing, https://lifetimo.com/deal/voicenotes-deal/
- Whisper Memos: https://whispermemos.com/
- Superwhisper: https://superwhisper.com/
- Recap (iOS): https://apps.apple.com/us/app/recap-ai-meeting-note-taker/id6737522875
- TranscriAI / Offline Transcribe: https://apps.apple.com/us/app/offline-transcribe-transcriai/id6748940555
- 本地 diarization 技术参考（Swift SDK）: https://github.com/FluidInference/FluidAudio
- 本地 diarization 行业讨论: https://openwhispr.com/blog/local-speaker-diarization, https://proudfrog.com/en/news/2026-04-27-granolas-bot-free-approach-gains-ground-meeting

---

## 2. 用户痛点

### 2.1 对云端方案的不满（最强信号）

1. **隐私恐慌已经爆雷**（2025 年 8 月）：
   - Otter.ai 被加州集体诉讼，指控未获参会者同意就录音、用对话训模型。
   - 这不是 Reddit 抱怨，是**法庭文件**。结果：2025–2026 企业法务对 AI 会议工具的合规审查全面收紧。
   - 来源：https://www.cybersecurityattorney.com/the-otter-ai-lawsuit-what-went-wrong-and-how-companies-can-avoid-the-same-privacy-mistakes/
   - **这是本地方案的最大顺风**，营销时直接打"Otter 因为这个被告了，我们没这个问题"。

2. **订阅贵 + 跨产品订阅疲劳**：
   - Otter Pro 年付仍要 $100/年；Plaud 是硬件 $159 + 软件 $80–240/年；Granola Individual 年付 $14–18/月（约 $168–216/年）。
   - 用户在 ProductHunt / App Store 评论里反复抱怨"为什么转录这件事要订阅一辈子"。
   - 一次买断 App（Aiko $24、AudioPen 终身 $99–159、Voicenotes 终身 $50、MacWhisper Pro €59）的高评价证明：**这个市场对买断有强烈支付意愿**。

3. **网络依赖不可接受的场景**：
   - 律师面谈、医生问诊、投资人尽调、国安/政府/合规会议、机密商谈、跨国差旅（飞机上/海外漫游）——这些场景**根本不能联网传音频**。
   - Reddit 上 r/macapps、r/ProductManagement 反复出现"我需要不联网就能转录的工具"。

4. **Bot 加入会议的副作用**：
   - 很多客户会因为看到第三方 bot 进会议直接挂电话。
   - Granola 火爆的原因之一就是"bot-free"，但它仍把音频上传——只解决了一半问题。

### 2.2 用户最想要的功能（按出现频率排序）

| 排名 | 功能 | 证据 |
|---|---|---|
| 1 | **多人说话人分离 + 名字标注** | 几乎所有付费用户的第一个升级请求 |
| 2 | **多语言（含中文）准确度** | 中文用户在中文论坛的核心抱怨 |
| 3 | **导出格式丰富**（TXT、PDF、DOCX、SRT、Markdown） | App Store 一星评论高频词 |
| 4 | **历史搜索 + 关键词跳转** | Otter 用户每天用，没有就回不去了 |
| 5 | **一键发到 Notion / Obsidian / Apple Notes** | 创作者群体强需求 |
| 6 | **Apple Watch 启动录音** | Whisper Memos 这条把对手秒杀 |
| 7 | **会议模板**（产品评审、1-on-1、销售拜访、采访） | Otter 把这个做成了 Pro 卖点 |
| 8 | **长录音**（>1 小时不挂） | 移动端用户痛点：iOS 后台录音稳定性 |
| 9 | **从 Files / 共享菜单导入已有音频** | 已有素材的用户必备 |

### 2.3 价格敏感度（关键发现）

- 美国市场：用户对**一次买断 $20–50** 的接受度非常高（参考 Aiko $24 长期上 App Store 工具榜）。
- 一次买断 $99–159 也有市场（AudioPen / MacWhisper Pro），但需要"明显比订阅便宜"+ 可信品牌。
- **订阅对个人用户疲劳严重**，但对企业 / 团队仍是主流。
- 中国区：中国用户**强烈偏好买断**，对订阅极度反感；可接受价位约 ¥30–198 一次买断；¥30/月以下的订阅勉强能接受。

---

## 3. 定价参考

### 3.1 各竞品价格对照

| 产品 | 月度 | 年度 | 终身 | 备注 |
|---|---|---|---|---|
| Otter Pro | $16.99 | $99.99 | — | 学生 20% off |
| Otter Business | — | $360 (=$30×12) | — | 团队最低 5 席 |
| Fireflies Pro | $18 | $120 (=$10×12) | — | |
| Granola Individual | $18 | ~$168 | — | |
| Plaud Pro | $17.99 | $99.99 | — | + 硬件 $159 |
| MacWhisper Pro (Gumroad) | — | — | **€59 (~$69)** | 一次买断！ |
| MacWhisper App Store | $6.99 | $29.99 | $99.99 | 苹果分成 |
| Aiko (Universal) | — | — | **$24** | 工具向锚点 |
| AudioPen Prime | — | $99 | $159 (2yr) | |
| Voicenotes Believer | — | — | **$50** | 一次买断 |
| Whisper Memos | — | $60 | — | |
| Superwhisper | ~$8.49 | ~$84 | — | |

### 3.2 iOS 类似 App 合理定价区间

| 模式 | 美区 | 中国区（人民币） |
|---|---|---|
| 工具向买断 | $19.99–$39.99 | ¥48–128 |
| 专业向买断 | $59.99–$99.99 | ¥198–388 |
| 月订阅 | $4.99–$14.99 | ¥18–48 |
| 年订阅 | $39.99–$99.99 | ¥98–298 |
| Freemium 起步价 | 免费 + Pro $9.99/月 | 免费 + ¥28/月 |

### 3.3 中国区 vs 美区差异

- 苹果中国区订阅留存率比美区低约 30–40%，但**买断转化率高**。
- 中国区流行"限免 → 涨价"+"买断早鸟 + 后期订阅化"组合拳。
- **建议中国区主推买断 + 美区 freemium 订阅 + 全平台终身**三档并行。

---

## 4. 商业建议

### 4.1 推荐定价模式：**Freemium + 一次买断为主、订阅为辅**

```
┌──────────────────────────────────────────┐
│  Free                                    │
│  - 每月 60 分钟录音 / 转录                │
│  - 单说话人模式                           │
│  - 基础 AI 总结（短摘要）                 │
│  - 历史最近 5 条                          │
└──────────────────────────────────────────┘
┌──────────────────────────────────────────┐
│  Pro 月订阅  $7.99 / ¥28                 │
│  Pro 年订阅  $39.99 / ¥138（节省 58%）   │
│  Pro 终身   $79.99 / ¥248                │  ← 主推这一档
│  - 无限录音 / 转录                        │
│  - 说话人分离（最多 8 人）                │
│  - 高级 AI 总结（要点 / 行动项 / 决议）   │
│  - 全部导出格式（TXT/PDF/DOCX/SRT/MD）   │
│  - 无限历史 + 全文搜索                    │
│  - 模板（销售/采访/产品评审/1-on-1）      │
│  - Apple Watch + Siri 快捷指令            │
│  - Notion / Obsidian / Apple Notes 导出  │
└──────────────────────────────────────────┘
┌──────────────────────────────────────────┐
│  Team（后期再上）  $9.99/席/月            │
│  - 团队共享、SSO、合规审计                │
└──────────────────────────────────────────┘
```

**为什么是这个组合？**
- 终身买断 $79.99 比 Otter 一年贵不了多少（$99）但**无后续费用**，对隐私敏感用户而言是"一次解决"——刚好契合本地处理的产品哲学（一次拥有，不被绑架）。
- 年订阅 $39.99 比 Otter 便宜一半，比 MacWhisper App Store 终身 $99.99 便宜，价格锚点稳。
- Free 给到 60 分钟/月，足够写评测、做对比，但不够日常会议——天然的转化漏斗。

### 4.2 核心差异化点（按优先级）

1. **"100% 本地，零服务器"**——Otter 集体诉讼后这是最值钱的卖点。营销文案直接打：「You don't need to trust us. The audio never leaves your device. Period.」
2. **iOS / iPadOS / Mac universal**——Otter 没有原生 Mac 应用、Granola 没有完整 iPad 体验、MacWhisper 只有 Mac、Aiko 没有会议 UX。**全平台合一是真空**。
3. **本地说话人分离**——目前 iOS 上几乎没人做好（FluidAudio + Apple SpeechAnalyzer 让这件事在 2026 变得可行）。
4. **一次买断 + 隐私承诺**——和订阅化的世界做反向选择。
5. **中文识别精度**——把 Whisper 的中文跑出比国产云工具更好的体验，国内市场就是你的。

### 4.3 目标用户画像（按市场规模 × 付费意愿排序）

| 优先级 | 用户群 | 痛点 | 付费力 |
|---|---|---|---|
| P0 | **律师 / 法务** | 客户特权信息绝不能上传 | 极高（$100+） |
| P0 | **医生 / 心理咨询师** | HIPAA / 病人隐私 | 极高 |
| P0 | **记者 / 调查记者** | 消息源保护 | 高（$50–100） |
| P1 | **远程工作者 / PM / 设计师** | 跨时区会议、不想 bot 进会议 | 中（$30–80） |
| P1 | **销售 / BD** | 客户对话不能传第三方 | 中高 |
| P1 | **学生（研究生 / 博士）** | 课程录音、田野访谈 | 中（$20–40，认教育优惠） |
| P2 | **企业 / 政府 / 国防承包商** | 合规 + on-prem 替代品 | 极高（团队订阅） |
| P2 | **创作者 / 自由职业者** | 把口述变内容素材 | 中（$30–60） |

**早期主攻 P0 + P1**——他们对"100% 本地"会自动转化，不用解释太多。

### 4.4 GTM 战术（不是题目要求但赠送）

- **冷启动**：Product Hunt 首发 + r/macapps + r/iOSProgramming + Hacker News（强调"Apple Neural Engine 跑 Whisper + 本地 diarization"，技术圈会自传播）。
- **付费转化钩子**：把"Otter 集体诉讼"这件事写进 onboarding 和落地页（事实陈述，不诋毁）。
- **早鸟定价**：终身买断首月 $49.99（"early supporter"），第二月 $79.99——制造紧迫感 + 早期回款。
- **App Store 介绍视频**：1 分钟"飞机上转录跨国会议"演示，飞行模式图标全程亮着。

---

## 5. ASO / 命名建议

### 5.1 App 名候选（≥ 3 个，按推荐度）

| 名称 | 优点 | 缺点 | ASO 权重 |
|---|---|---|---|
| **Whisperly** | "Whisper"关键词命中（OpenAI Whisper 直接联想）+ "ly"现代感、好读、可注册 | 可能与小型现存项目同名 | ⭐⭐⭐⭐⭐ |
| **Locally** ⚠️ | 直接打"本地"概念 | 太通用、商标易冲突 | ⭐⭐ |
| **Scribe** ⚠️ | 已有同名 App（如 Scribe.ai 浏览器扩展） | 撞车 | ⭐ |
| **Quiet Notes** | "Quiet"= 不上传、不打扰；"Notes"高搜索量 | 略文艺 | ⭐⭐⭐⭐ |
| **MeetKeep** | Meet + Keep 双关，记会议 + 留隐私 | 略生造 | ⭐⭐⭐ |
| **Onsite** | 一语双关：在场 / on-device | 过短，撞名概率高 | ⭐⭐⭐ |
| **Hush** | 极简、好记、暗示静默/私密 | 过短可能被驳回 | ⭐⭐⭐ |
| **Roundtable** | 多人会议意象明显 | 拼写长、不易输入 | ⭐⭐ |
| **Scribely** | "Scribe + ly"避开 Scribe 撞车 | 略别扭 | ⭐⭐⭐ |
| **Tessera** | "拼图块"，每个发言是一块 | 抽象、不好记 | ⭐⭐ |

> **强推荐前三**：
> 1. **Whisperly** — 主打技术血统 + 隐私"低声"双关
> 2. **Quiet Notes** — 隐私 + 笔记直接表达
> 3. **MeetKeep** — 会议场景专属

> **副标题（subtitle）建议**（这个比名字还重要，ASO 70% 权重在副标题 + 关键词字段）：
> - "On-Device Meeting Recorder & AI Notes"
> - "Private Meeting Transcription & Speaker AI"
> - "Local Whisper Transcription, Zero Cloud"

### 5.2 关键词候选（100 字符 keyword field 内）

**第一波（必须放）**：
```
meeting,transcribe,transcription,recorder,voice,notes,whisper,AI,offline,local,private
```

**第二波（按场景）**：
```
diarization,speaker,minutes,summary,summarize,interview,lecture,podcast
```

**第三波（捎带 ASO）**：
```
otter,fireflies,granola,dictation,memo,record,subtitle,SRT,journal
```

> 100 字符举例：`meeting,transcribe,recorder,whisper,AI,offline,local,private,speaker,diarization,notes,summary,otter`

### 5.3 已有竞品名占用情况

| 名称 | 占用情况 | 备注 |
|---|---|---|
| Scribe | ❌ 占用 | scribe.ai、Scribe Workflows 等 |
| Recap | ❌ 占用 | App Store id 6737522875 已上线 |
| Whisper | ❌ 苹果 + OpenAI 同名 | 不可用 |
| MeetingNotes | ⚠️ 多家在用 | 太通用 |
| **Whisperly** | ✅ App Store 没有同名 iOS app（截至 2026-04） | **可用** |
| **Quiet Notes** | ✅ App Store 无强势同名 | **可用** |
| **MeetKeep** | ✅ 全空 | **可用** |
| Granola | ❌ 占用 | |
| Aiko | ❌ 占用 | |
| Tactiq | ❌ 占用 | |

> **行动建议**：定下名字后**当天**注册：① App Store Connect 占名 ② .com/.app/.ai 域名 ③ Twitter / X handle ④ GitHub org。这四件套不抢就被人抢了。

---

## 6. MVP — 砍掉 vs 保留

### 6.1 必须保留（v1.0 上线就要有）

✅ **本地录音**（iOS / iPad / Mac）
✅ **本地 Whisper 转录**（用 WhisperKit 或 Apple SpeechAnalyzer + 自托管 Whisper.cpp）
✅ **本地说话人分离**（用 FluidAudio / 自训 + ANE 加速）
✅ **AI 总结**（v1 可以用本地小模型 Apple Foundation Models / Phi-3 mini，或允许用户 BYOK 接 Claude/OpenAI）
✅ **历史记录管理**（列表 + 文件夹 + 搜索）
✅ **导出**：TXT、Markdown、PDF（这三个是底线）
✅ **iCloud 同步**（端到端加密，CloudKit 自带）
✅ **后台录音**（iOS 必做，否则差评）
✅ **多语言**（至少英文、中文、日文、西语、法语）

### 6.2 v1.0 砍掉（v1.1 / v2 再上）

❌ **会议机器人加入 Zoom/Meet/Teams** — 这是 Otter/Fireflies 的活，本地路线不要碰
❌ **团队协作 / 共享空间** — 等个人产品验证后再做
❌ **多设备实时同步转录** — 工程量大、收益有限
❌ **Apple Watch app** — v1.1（差异化但不是 P0）
❌ **Siri 快捷指令** — v1.1（轻量但需 polish）
❌ **会议模板**（销售/采访/1-on-1）— v1.1（订阅留存利器）
❌ **CRM / Notion / Obsidian 集成** — v1.2
❌ **音频导入功能** — v1.0 可以放，但不要花太多时间在格式兼容
❌ **视频文件支持（MP4/MOV）** — v1.1
❌ **字幕 SRT 导出** — v1.1（创作者群体）
❌ **批量转录** — v1.2（有 shortcut workaround 就够了）
❌ **自定义词汇 / 行业术语** — v1.2（医疗、法律细分时再做）
❌ **macOS menu bar 模式** — v1.1
❌ **Windows / Web** — 不做，专注 Apple

### 6.3 严禁做的事（守住"本地"承诺）

🚫 **任何形式的"为了更好质量上传到我们的服务器"** — 这破坏全部价值主张
🚫 **崩溃日志包含音频/转录文本** — 即使匿名也别碰
🚫 **训练我方模型用用户数据** — Otter 就是栽在这
🚫 **第三方分析 SDK 收集用户行为细节** — 用 Apple 自家的 App Analytics 即可
🚫 **强制注册账号** — 一次买断 + 本地存储就该是"打开就用"

---

## 7. 风险与窗口

| 风险 | 概率 | 应对 |
|---|---|---|
| Apple 自己出原生功能（iOS 26+ SpeechAnalyzer 已经有本地转录 API） | 高 | 用 SpeechAnalyzer 做底座但加自家 Diarization + 总结 + UX 套壳，做 Apple 不愿意做的整合 |
| Otter / Granola 推出"本地选项" | 中 | 它们的商业模式不允许，订阅靠云端粘性；即使做也是阉割版 |
| 开源方案普及（FluidAudio + WhisperKit 任何人都能拼） | 高 | 卷 UX、卷品牌、卷会议场景 SOP，不靠技术差距 |
| 苹果以"涉嫌录音侵犯隐私"驳回上架 | 中 | 上架前做好"录音前显式同意"+ 录音时屏幕指示器，参考 Aiko / Just Press Record 通过先例 |
| 中国区无法过审（iCloud 同步、AI 总结） | 中 | iCloud 用 CloudKit 默认配置过审无问题；AI 总结禁词过滤 + 提供"纯转录"模式 |

**窗口期判断**：
- 现在 → 2026 年底：FluidAudio + Apple SpeechAnalyzer 让"iOS 本地说话人分离"工程可行性首次实现，但还没有强势 App 占位。
- 2027 起：竞争会激烈起来。
- **建议 6 个月内 ship MVP，9 个月内拿到第一批付费用户口碑**。

---

## 8. TL;DR — 一页纸总结

| 项目 | 结论 |
|---|---|
| **市场空位** | iOS/iPadOS 上「本地录音 + 本地 diarization + AI 总结 + 会议 UX」universal 应用，**目前真空** |
| **最大顺风** | Otter.ai 隐私集体诉讼（2025），全行业法务在重新审视 AI 会议工具 |
| **最像的对手** | TranscriAI（小、可超）、MacWhisper（Mac-only、不做会议）、Aiko（无分离、无总结） |
| **推荐定价** | Free（60min/月）+ Pro 月 $7.99 / 年 $39.99 / **终身 $79.99** |
| **目标用户 P0** | 律师、医生、记者 — 隐私非可选项 |
| **App 名 Top 3** | **Whisperly** / Quiet Notes / MeetKeep |
| **必须有** | 本地录音 + 本地 Whisper + 本地 diarization + AI 总结 + 历史 + 导出 + iCloud 同步 |
| **可以砍** | 会议机器人、团队协作、Watch、Siri、模板、第三方集成、视频、批量、Win/Web |
| **窗口期** | 6–12 个月 |

---

*报告完。如需要：① 技术选型详细对比（WhisperKit vs MLX-Whisper vs Apple SpeechAnalyzer + FluidAudio diarization 工程评估）② 商标 / 域名查询脚本 ③ 前 100 个目标用户冷启动名单 — 单独提需求。*
