# FitGenius AI 升级 — 开发目标与思想

> **作者**: Mavis(mavis Agent)
> **完成时间**: 2026-06-06
> **接手对象**: CodeX
> **本仓库**: `/Users/baojian/Desktop/Xcode项目/FitGenius`
> **当前 git 状态**: main 分支干净;我做的 WIP 在 `stash@{0}`(也可以 `git apply /tmp/fitgenius-hybrid-wip.patch` 看 1746 行 diff)

---

## 0. 背景

用户正在迭代 FitGenius(已上架的 iOS 健身/饮食 App),当前 AI 部分能力用 `qwen3-omni-flash` 撑,但有两个用户明确表达过的不满意:

1. **饮食识别不够准** — 食物种类、克重、营养估算偏差大
2. **训练动作分析反馈单调** — 之前纯本地 Vision + 硬编码英文模板,反馈文字僵、不能看全流程、不能精准指出"哪一帧哪个关节有问题"

CodeX 的工作是把这两块升级到"能明显感觉到提升"的程度。

我之前已经把方案做完、跑通编译,但**栽在 Vercel 代理上没有 `qwen-vl-max` 模型** — 我没有直接操作 Vercel Dashboard 的能力。CodeX 拿到这个文档后,**第一步先解决 Vercel 代理侧的问题**,否则我留下的 WIP(包括所有 prompt、enrichment 链路)在你那边一样会超时失败。

---

## 1. 目标(用户能感知到的成功)

### 1.1 饮食识别
- 用户拍一张混合中餐(米饭 + 菜 + 肉)→ AI 识别出 3+ 种食物,**克重在合理范围**(而不是 100g 起步拍脑袋)
- 提交后 5-10 秒内返回结果
- 失败时(网络/模型挂了)降级,用户不卡死

### 1.2 训练动作分析
- 用户上传 20-30 秒训练视频 → 5-15 秒看到本地反馈图(白底 + 火柴人 + 评分)
- 5-25 秒看到 **AI 教练解读**:1-2 张带红色高亮/箭头/角度标注的火柴人图
- cues 列表 2-3 条,带"证据 / 为什么重要 / 怎么改 / 小练习"4 段
- 整链路 ≤ 30s
- 大模型挂了 / 解析失败 → 降级到本地模板,UI 显式提示"AI 教练解读暂不可用,已展示本地模板反馈",**不阻塞用户**

### 1.3 不动其他 AI 功能
- 训练计划生成 / AI 聊天 / 饮食纯文字对话 / 健身视频问答 — **用户明确要求不要影响这些**
- 升级要"局部",不要"顺手改了其他东西"

---

## 2. 核心思想(为什么这么做)

### 2.1 饮食:用更准的视觉模型 + 强化 prompt
- Omni-Flash 是统一多模态,容量被音频/视频分支稀释;在中文食物细颗粒度识别上**不如**专精视觉的旗舰模型
- 阿里云百炼有 `qwen-vl-max`(专精视觉),适合看食物照片
- 但模型再强,prompt 没约束也写不出好克重和好营养估算 → 要给 prompt 加:
  - **克重参照表**(米饭 1 碗=200g、鸡胸 1 块=100-150g、油 1 勺=10g=90kcal…几十种常见锚点)
  - **推理链要求**(在每个 entry 的 notes 里简述判断依据,迫使模型不瞎猜)
  - **典型场景示例**(5 个常见组合的标准答案)
  - **热量宏量自检公式**(`calories ≈ (protein*4 + carbs*4 + fat*9) ± 10%`)

### 2.2 训练:Hybrid(端 + 云)而不是全云端
- 现状是**纯端侧**:Apple Vision 抽 19 关节 + 规则引擎算指标 + 模板化文案
- 全云端(把视频传给大模型)是**降级**:慢、贵、隐私差、对"逐帧连续姿态分析"不如 Vision 精确
- 正确升级是 **hybrid**:
  - **端**:Vision 抽帧 + 算精确指标(实时 / $0 / 隐私 / 离线 / 逐帧 19 关节坐标)
  - **云**:大模型负责"教学设计"(挑典型帧 + 给文字反馈 + 给标注指令)
- 大模型不能直接"改图"——所有主流多模态(包含 qwen-vl-max、gpt-4o、claude)都只能"看图说"
- **变通**:大模型返回结构化 JSON(`bodyPart` 关节名 + 标注类型) → iOS 用原始关节坐标精确渲染红框/箭头/角度弧
- 这是 Figma AI / tldraw AI 都是这套

### 2.3 多帧 → 6 张 → 大模型挑 1-2 张
- 全传 16 帧 = 5-10MB(顶到 API 20MB 上限)+ 成本 5x + 注意力分散(连续几帧几乎一样)
- **本地先按时间均匀分桶 6 张**(关节完整度优先)→ 大模型只看到最有代表性的几张
- **大模型再挑 1-2 张**(基于具体指标挑最能说明问题的那张)→ iOS 用原始 PoseFrame 重画"AI 标注图"
- 全程不传原始视频,只传骨架图 + 指标文本,符合隐私

### 2.4 失败降级是底线
- 大模型可能超时 / 解析失败 / Vercel 代理 5xx / API key 没余额 / 用户断网
- **任何环节失败,UI 都要有兜底,不能白屏**
- 本地反馈图永远显示
- cues 列表降级到本地模板
- 显式提示用户"AI 教练解读暂不可用",不要让用户疑惑"是没出结果还是 bug"

---

## 3. 硬性约束(CodeX 必须遵守)

### 3.1 不动的模块
| 模块 | 原因 |
|------|------|
| 训练计划生成(generateInitialPlan / regeneratePlan) | 纯文字,omni-flash 够用 |
| AI 聊天(chat) | 纯文字,不需要视觉 |
| 饮食纯文字对话(dietChat) | 纯文字 |
| 饮食纯文字分析(analyzeMeals) | 纯文字 |
| 健身视频问答(analyzeFitnessMedia) | 用户没要求改 |

如果 CodeX 想"顺手优化",**先停下来问用户** — 用户明确说过"不要影响其他使用 AI 的地方"。

### 3.2 性能
- 视频 < 3s 或 > 90s → 报错不调大模型(已有逻辑,别动)
- enrichment 整体超时 ≤ 30s(用户等不及更长)
- 移动网络下用户可能先看到本地反馈图(快),1-2 秒后再看到 AI 解读(慢)— 这是预期体验

### 3.3 隐私
- 不传原始训练视频到云端(只传骨架图)
- 饮食照片是用户主动拍的产品核心功能,本来就传,不算新隐私问题

### 3.4 用户偏好
- **不要一步一步问** — 用户原话"全部做完再让我验证,大不了回退到当前版本就行了"
- 一次给完整方案,失败可 git revert,不要中间打断

---

## 4. Vercel 代理侧任务(CodeX 必做,这步不做后面都白搭)

我搞砸那次就是因为这步我没做。CodeX 你有 Vercel Dashboard 权限,这是你的核心优势。

### 4.1 确认视觉模型可用性
```bash
# 1. 登录 Vercel Dashboard
# 2. 找 FitGenius 项目
# 3. 看 /api/ai/chat 路由代码
# 4. 确认转发到阿里云百炼的 model 字段支持 qwen-vl-max
# 5. 实际 curl 一下:
curl -X POST $YOUR_VERCEL_URL/api/ai/chat \
  -H "Authorization: Bearer $SESSION_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen-vl-max","messages":[{"role":"user","content":"hi"}]}'
# 看返回 200 还是 404
```

**大概率 `qwen-vl-max` 在百炼需要带日期后缀**(如 `qwen-vl-max-2025-04-08`),**先在百炼控制台确认实际支持的名字**,再决定 iOS 端写哪个字符串。

### 4.2 加 model 路由 / 调 timeout
```typescript
// api/ai/chat.ts 里的 model 字段处理
// 直接透传即可(百炼 API 兼容 OpenAI 协议)
const modelMap = {
  'qwen3-omni-flash': 'qwen3-omni-flash',
  'qwen-vl-max': 'qwen-vl-max-2025-04-08',  // ← 试一下
}

// 延长 timeout(多图 6 张 + 大模型可能 15-25s)
export const config = {
  maxDuration: 60,
}
```

### 4.3 API key / 余额
- 阿里云百炼 API key 余额
- 权限是否覆盖 qwen-vl-max(可能要单独开通)
- 百炼控制台 → 模型广场 → 找 qwen-vl-max → 开通

---

## 5. 现有 WIP(CodeX 自己判断要不要用)

我之前做的 WIP 在 `stash@{0}`,**CodeX 三种选择**:

### 5.1 选择 A:觉得行,直接用
```bash
git stash pop
# 9 个 M + 2 个 ??(Models/Form/FormCoachEnrichmentResult.swift, Services/FormAnalysis/FormCoachEnrichmentService.swift)
# 编译应该 BUILD SUCCEEDED
xcodebuild -project FitGenius.xcodeproj -scheme FitGenius -destination 'platform=iOS Simulator,name=iPhone 16e' -configuration Debug build
```

### 5.2 选择 B:参考我的思路,自己重写
```bash
git stash drop  # 丢掉
# 然后从零开始 — 但建议先 git stash show -p stash@{0} 看一遍我做了什么,避免重复造轮子
```

### 5.3 选择 C:把我的当 scaffold,删掉重写
```bash
git stash pop
# 但只保留思路,代码全部 git restore 掉
git restore Services/AIService.swift Services/AppLanguagePolicy.swift Services/FormAnalysis/LocalFormAnalysisPipeline.swift ...
rm Models/Form/FormCoachEnrichmentResult.swift Services/FormAnalysis/FormCoachEnrichmentService.swift
# 然后从干净基线开始写
```

WIP 内容简介(参考用):
- 饮食 prompt 强化:克重参照表 + 推理链 + 多图映射 + 典型场景 + 自检公式
- 训练动作 enrichment:16 帧 → 6 骨架图 → 大模型挑 1-2 张 → iOS 重画 4 种标注(高亮/箭头/角度/圆圈)
- 失败降级:每个环节 try-catch,失败时 enrichment 全 nil
- UI:本地反馈图(永远有)+ AI 教练解读区(紫色)+ cues 列表(带紫色/灰色标签区分 AI/本地)

### 5.4 我栽过的坑(供参考,不是 CodeX 的坑)
- `qwen-vl-max` 改了但 Vercel 代理没部署 — 一次请求超时一次
- 编译时 `FormCoachCue` 缺 `Codable` — 已修
- `@MainActor struct` 的 default param `AIService()` 在 nonisolated context 求值失败 — 已修(改成函数体内 `??`)
- `subscript(safe:)` 重复声明(`Utilities/Extensions.swift` 已有) — 已修

这些坑**不一定**会绊到 CodeX(你可能用完全不同的写法),但**值得快速 grep 一下**确认没踩同款。

---

## 6. 验收(CodeX 完成后用户怎么测)

### 6.1 饮食
- 拍一张混合中餐(米饭 + 菜 + 肉) → 5-10 秒内返回 → 克重在合理范围(不是拍脑袋的 100g)
- 看每个 entry 的 notes 是否包含"食物识别 / 份量依据 / 关键假设"3 段
- 故意断网测试 → 应该降级到本地汇总,UI 友好提示

### 6.2 训练动作
- 选一个 squat / bench 视频(20-30 秒)→ 5-15 秒看到本地反馈图 → 5-25 秒看到 AI 教练解读
- AI 解读区有 1-2 张带红色高亮/箭头/角度的火柴人图
- cues 列表 2-3 条,右上角紫色"AI 教练"标签(不是灰色"本地模板")
- 故意让 Vercel 代理返回 500 → 应该降级到本地模板,UI 显式提示

### 6.3 边界
- 视频 < 3s 或 > 90s → 报错不调大模型
- 关节检测不到 → 跳过该帧
- 大模型返回 invalid JSON → 降级

### 6.4 其他 AI 功能
- 训练计划生成 / AI 聊天 / 饮食纯文字对话 → **行为不变**
- 这是硬性验收,用户会测

---

## 7. 提交建议

完整跑通后拆 2 个 commit(便于单独 revert):

```bash
# 饮食 prompt
git add Services/AppLanguagePolicy.swift Services/AIService.swift
git commit -m "feat: upgrade diet prompt with portion reference + reasoning chain"

# 训练动作 enrichment
git add Services/FormAnalysis/ Services/FormAnalysis/ ViewModels/Forms/ Views/Plan/FormAnalysisView.swift
git add Models/Form/FormCoachEnrichmentResult.swift
git commit -m "feat: hybrid training form analysis with AI coach enrichment"
```

---

## 8. 用户的两个核心信息(CodeX 干活时心里有数)

1. **用户期望 = 明显感觉到提升**(不是"代码改了 1000 行但效果差不多")
2. **用户对失败很敏感** — 不要让用户当 Vercel 代理的 beta tester,**CodeX 自己先在 Vercel 上 curl 跑通再交付**

---

完成时间: 2026-06-06 21:56
作者: Mavis(mavis Agent)
给: CodeX
