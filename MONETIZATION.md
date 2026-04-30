# Whisperly - Monetization

> 决策日期：2026-04-30

---

## 商业模式：Freemium + 终身买断

### 免费版 Free

- 每次会议**最多 30 分钟**（硬上限）
- 录音中显示**倒计时 UI**（醒目、不可隐藏）
- 倒计时到 0 自动停止录音 + 转录 + 总结
- 已录的内容保留可查
- 历史记录、导出、说话人识别等核心功能**都能用**（不挡）

### 终身会员 Pro

**$69.99 一次性买断**

- 无限录音时长
- 去掉倒计时 UI
- 所有未来功能更新免费

### ✨ 关键 UX：实时升级

⚠️ **重要**：用户在倒计时进行中购买终身会员，**必须无缝去掉倒计时，录音继续不中断**。

实现要点：
- 监听 StoreKit transaction
- 一旦交易成功（哪怕在录音中）：
  1. 立即更新 `entitlement.isPro = true`
  2. 倒计时 UI 淡出
  3. 录音状态机切换到"无限模式"
  4. 不重启录音，不丢数据

## IAP 商品

| Product ID | 类型 | 价格 |
|---|---|---|
| `com.panxiang1017.whisperly.lifetime` | Non-Consumable | $69.99 |

## App Store Connect 配置

需在 ASC 创建：
- **Subscription Group**：无（不是订阅）
- **In-App Purchase**：1 个 Non-Consumable 商品
- **价格层**：$69.99 USD（中国区按当时汇率自动换算，约 ¥498）

## Restore Purchases

- 必须有"恢复购买"按钮（App Store 审核硬要求）
- 放在设置页 + 付费引导页

## 法律必备

- **Privacy Policy**: https://panxiang1017.github.io/StaticPage/privacy-policy.html
- **Terms of Use (EULA)**: https://panxiang1017.github.io/StaticPage/terms-of-use.html
- ASC App Information 必填
- App Store description 必含
- 设置页面提供入口

## 营销卖点（按优先级）

1. **100% 本地，零云端**（最大差异化）
2. **多人说话人识别**（功能差异化）
3. **一次买断，没有订阅**（与云端竞品差异化）
4. **跨苹果生态同步**（CloudKit 用户私域）
5. **A14+ 老机型也能用**（兜底方案）

## 价格心理

- $69.99 vs Otter Pro $16.99/月 = **5 个月就回本**
- $69.99 vs Granola $10/月 = **7 个月回本**
- 终身用 → 永远不再付费 vs 云端永远续费

## ASC App Review 信息

- first_name: Sharp
- last_name: Pan
- phone: +86 13161349286
- email: panxiang1017@163.com
- demo_user: 空
- demo_password: 空
- notes: `No login required. App is fully on-device. To test Pro features, please use the in-app "Restore Purchases" button or sandbox tester account.`
