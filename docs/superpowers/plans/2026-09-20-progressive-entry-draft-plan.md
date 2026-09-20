# 渐进式进入与草稿训练计划实施计划

> **目标：** 新用户首启直接进入可操作的训练首页；没有资料时仍可创建训练日、添加动作，并在之后填写资料时保留已有计划。

## 完成标准

- `ContentView` 不再用 `hasOnboarded` 阻塞主界面。
- 没有任何计划时只创建一份独立空 `WorkoutPlan`，不伪造 `UserProfile`。
- 老用户优先使用已关联 Profile 的计划；否则使用最新独立计划。
- 首页、动作库加入计划、Widget 使用同一套当前计划解析规则。
- 个性化资料流程不删除旧 Profile，不丢弃手动添加的训练内容。
- 中英文文案同步，模拟器构建通过。

## Task 1：建立统一的当前计划解析策略

**文件**

- 新建：`FitGenius/Services/CurrentWorkoutPlanStore.swift`
- 新建：`scripts/current-workout-plan-tests.swift`

**步骤**

1. 先写策略测试，覆盖：Profile 已关联计划优先、无关联时取最新独立计划、完全无计划时返回空。
2. 运行测试，确认实现前失败。
3. 实现纯策略选择逻辑，以及 `ModelContext` 下的 `ensureCurrentPlan`：仅在没有候选计划时插入一份空计划并保存。
4. 再运行测试，确认通过。

**验证命令**

```bash
xcrun swift scripts/current-workout-plan-tests.swift
```

## Task 2：首启直达主界面并安全创建草稿

**文件**

- 修改：`FitGenius/ContentView.swift`

**步骤**

1. 移除 `hasOnboarded` 对 `MainView`/`OnboardingView` 的根级分支。
2. 在主界面首次出现时调用统一 store，保证存在当前计划。
3. 草稿创建失败时保留主界面并显示可重试错误，不循环插入计划。
4. 保留旧 `hasOnboarded` 值但不再以它控制准入，避免无意义迁移。

## Task 3：让空训练首页成为可编辑状态

**文件**

- 修改：`FitGenius/Views/Plan/PlanDashboardView.swift`
- 修改：`FitGenius/ViewModels/PlanDashboardViewModel.swift`（按实际路径）
- 修改：`FitGenius/Views/Onboarding/OnboardingView.swift`

**步骤**

1. Dashboard 同时查询 `UserProfile` 与 `WorkoutPlan`，通过统一 store 解析当前计划。
2. 空计划展示两个明确操作：“生成个性化训练计划”和“自己创建计划”。
3. “自己创建计划”和右上角加号都打开现有新增训练日流程。
4. “生成个性化训练计划”以 sheet/full-screen flow 打开资料设置，不离开主导航。
5. 删除“重新开始 = 删除所有 Profile 并回到强制 onboarding”的耦合；资料更新与数据清除分开。

## Task 4：让所有计划消费者支持独立草稿

**文件**

- 修改：`FitGenius/Views/ExerciseLibrary/ExerciseDetailView.swift`（以实际路径为准）
- 修改：`FitGenius/FitGeniusApp.swift`
- 修改：其他仍读取 `profiles.first?.workoutPlan` 的计划入口

**步骤**

1. 搜索所有 `profiles.first?.workoutPlan` 与同类取值。
2. 动作库“加入计划”改用统一当前计划。
3. Widget 数据桥改为：Profile 计划优先，否则独立草稿计划。
4. 保证没有 Profile 时可添加训练日与动作；有 Profile 的老用户行为不变。

**验证命令**

```bash
rg -n 'profiles\.first\?\.workoutPlan|profile\?\.workoutPlan' FitGenius
```

## Task 5：把资料设置改成非破坏性流程

**文件**

- 修改：`FitGenius/ViewModels/OnboardingViewModel.swift`
- 修改：`FitGenius/Views/Onboarding/OnboardingView.swift`
- 修改：`FitGenius/Views/Onboarding/EquipmentAndGeneratingViews.swift`

**步骤**

1. 为资料流程注入当前计划和完成回调。
2. 删除生成前批量删除 `UserProfile` 的逻辑。
3. 已有 Profile 时更新它；没有时创建真实 Profile，并将当前独立计划关联过去。
4. 资料保存和 AI 候选计划生成分离：先保存有效资料，再把当前计划作为生成上下文交给 AI 提案流程。
5. 用户取消资料流程时不改当前计划。

## Task 6：本地化、回归与文档

**文件**

- 修改：`FitGenius/zh-Hans.lproj/Localizable.strings`
- 修改：`FitGenius/en.lproj/Localizable.strings`
- 修改：`docs/form-coach-roadmap.md`
- 修改：`docs/agent-handoff.md`

**验证场景**

1. 全新数据：直接进入空训练页。
2. 不填资料：新增训练日，添加动作库动作和自定义动作。
3. 填资料后：原有手动内容仍存在，计划已关联 Profile。
4. 老用户：继续展示原计划，不产生重复草稿。
5. Widget：无 Profile 时也能读到草稿计划。

**构建命令**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project FitGenius.xcodeproj -scheme FitGenius \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/FitGeniusDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

