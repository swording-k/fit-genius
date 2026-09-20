# AI 训练计划协作助手实施计划

> **目标：** 让 AI 在无 Profile/无计划时也能回答通用健身问题；涉及计划的请求统一返回可验证提案，展示差异并由用户确认后原子应用。

## 完成标准

- 通用问答不再依赖 Profile 或 WorkoutPlan。
- 当前计划和用户资料按实际存在情况渐进注入上下文。
- AI 不再通过本地关键词正则猜测修改类型，也不直接写 SwiftData。
- 局部修改与完整重构都有结构化提案、确定性验证和差异预览。
- 取消、解析失败、验证失败、保存失败均不改变现有计划。
- 首次个性化生成会考虑用户已经手动添加的内容。

## Task 1：定义纯数据快照与提案协议

**文件**

- 新建：`FitGenius/Models/Plan/WorkoutPlanSnapshot.swift`
- 新建：`FitGenius/Models/Plan/PlanChangeProposal.swift`
- 新建：`scripts/plan-proposal-tests.swift`

**步骤**

1. 先写失败测试，覆盖 answer/patch/replacement 解码、稳定标识、增删改摘要。
2. 定义不依赖 SwiftData 的 plan/day/exercise snapshot。
3. 定义 `FitnessAssistantResult`、局部操作、完整替换提案与用户可读摘要。
4. JSON 解码失败必须成为显式错误，不能回退为直接执行。

## Task 2：实现确定性质量门与差异计算

**文件**

- 新建：`FitGenius/Services/PlanProposalValidator.swift`
- 新建：`FitGenius/Services/PlanProposalDiffBuilder.swift`
- 扩展：`scripts/plan-proposal-tests.swift`

**测试覆盖**

- 训练日编号唯一、连续。
- 至少一个非休息训练日；休息日无动作。
- 动作名非空，同一天无重复稳定 ID/名称。
- 组数 `1...20`、重量非负、次数非空。
- 删除/修改目标必须唯一存在。
- 任一操作无效则整个提案不可应用。
- diff 正确区分保留、新增、删除、调整前后。

## Task 3：重构 AIService 为可选上下文与结构化结果

**文件**

- 修改：`FitGenius/Services/AIService.swift`
- 修改：相关请求/响应 DTO
- 新建或扩展：AI prompt 合同测试脚本

**步骤**

1. `chat` 接受可选 `UserProfile` 与可选 `WorkoutPlan`。
2. 基础问题只注入对话；存在计划/资料/健康授权时再追加对应段落。
3. 动作库上下文统一为 `externalId | nameEn | chineseName`，不依赖当前语言的 `displayName`。
4. 要求模型只返回 `answer`、`patch` 或 `replacement` 之一。
5. 首次生成与整体重构共用 replacement 协议，并包含当前手动计划快照。
6. 模型输出不可解析时返回可理解错误，保留原计划。

## Task 4：ViewModel 只管理对话与待确认提案

**文件**

- 修改：`FitGenius/ViewModels/AIAssistantViewModel.swift`
- 修改：`FitGenius/Models/ChatMessage.swift`

**步骤**

1. 删除 `detectModificationType` 及计划级关键词路由。
2. 删除收到 action command 后立即执行的路径。
3. 新增 `pendingProposal`、验证结果、预览开关与 apply 状态。
4. `answer` 直接进入对话；`patch/replacement` 验证后只进入 pending 状态。
5. 提案无效时在对话中给出具体错误，不触碰 SwiftData。

## Task 5：实现确认后的原子应用

**文件**

- 新建：`FitGenius/Services/PlanProposalApplier.swift`
- 扩展：`scripts/plan-proposal-tests.swift`

**步骤**

1. 应用前再次针对最新计划快照验证，防止预览期间计划已变化。
2. 局部 patch 先在纯快照上完整演算，再一次性映射到 SwiftData。
3. replacement 先构建完整候选对象，保存成功后再切换 Profile 关联。
4. 失败时不显示成功反馈，并保留 pending proposal 供重试。
5. 成功后清空 pending proposal，并在对话里记录实际变更摘要。

## Task 6：加入差异预览 UI

**文件**

- 新建：`FitGenius/Views/Assistant/PlanChangePreviewSheet.swift`
- 修改：`FitGenius/Views/Assistant/AIAssistantView.swift`

**步骤**

1. 展示 AI 摘要、保留、新增、删除、调整前后。
2. 使用 SF Symbols、文字和颜色三重表达状态。
3. 提供“取消”和“应用修改”；验证失败时禁用应用并显示原因。
4. 没有 Profile/Plan 时仍显示聊天输入，个性化请求才引导资料设置。

## Task 7：连接个性化资料流程

**文件**

- 修改：`FitGenius/ViewModels/OnboardingViewModel.swift`
- 修改：`FitGenius/Views/Onboarding/EquipmentAndGeneratingViews.swift`
- 修改：`FitGenius/Views/Plan/PlanDashboardView.swift`

**步骤**

1. 资料保存后，用 Profile + 当前计划请求 replacement proposal。
2. 当前计划为空时生成完整候选；非空时明确要求保留适用的手动动作。
3. 从首页直接进入相同预览；不在“正在生成”页面直接覆盖计划。
4. 用户取消预览时保留资料和当前计划，仅丢弃候选提案。

## Task 8：本地化、构建与真机验收

**文件**

- 修改：`FitGenius/zh-Hans.lproj/Localizable.strings`
- 修改：`FitGenius/en.lproj/Localizable.strings`
- 修改：`docs/form-coach-roadmap.md`
- 修改：`docs/agent-handoff.md`

**验收场景**

1. 无资料、空计划：通用问答可发送并获得回答。
2. 手动计划：“把周三侧平举改为 4 组”先出现精确 diff，取消后数据不变。
3. 同一请求确认应用后，计划只改变一次。
4. 无效 AI 输出、越界组数、重复动作、网络失败都不改变计划。
5. 填写资料后生成：已有手动动作出现在保留/调整说明中。
6. 整体重构：显示完整 replacement diff，确认后再切换。

**构建命令**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project FitGenius.xcodeproj -scheme FitGenius \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/FitGeniusDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

