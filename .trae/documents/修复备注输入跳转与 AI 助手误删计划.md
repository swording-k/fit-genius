## 问题概览
- 备注输入跳转：当前生成流程仅在进入 `GeneratingView` 时触发（Views/Onboarding/EquipmentAndGeneratingViews.swift:215 → `startGeneration()` 在 220 行，成功后设置 `hasOnboarded = true` 于 225 行）。不存在显式的 `onSubmit` 对备注，但使用多行 `TextField` 在中文输入法或键盘“发送/完成”下可能出现隐式提交与焦点切换，造成误入生成页并最终跳至训练计划页。
- AI 助手误删计划：`AIAssistantViewModel.regeneratePlan`（ViewModels/AIAssistantViewModel.swift:114–155）在生成新计划后立即删除旧计划并保存；若解析/保存失败前后处理不当，存在计划丢失风险。此外，`updateExercise`（190–221）与 `removeExercise`（250–272）使用 `contains` 模糊匹配，可能误删/误改多个动作。

## 修复方案（实现细节）
### 1. 备注输入交互稳健化
- 将备注输入从多行 `TextField` 改为 `TextEditor`，避免键盘“提交/发送”触发隐式提交：替换 `EquipmentSelectionView` 的 100–105 行为 `TextEditor(text: $viewModel.notes).frame(minHeight: 80).padding(...).background(...).cornerRadius(...)`（Views/Onboarding/EquipmentAndGeneratingViews.swift:100）。
- 增加焦点控制与提交意图分离：在视图中新增 `@FocusState private var notesFocused: Bool`，给 `TextEditor` 绑定 `.focused($notesFocused)`，仅当用户明确点击“生成计划”按钮（122–133 行）时调用 `nextStep()`，消除隐式提交对导航的影响。
- 可选增强：在点击“生成计划”按钮前，若 `notesFocused == true`，先收起键盘再导航，避免键盘行为干扰。

### 2. 生成流程触发去耦（更稳健）
- 将生成触发从 `GeneratingView.onAppear` 移除，改为“按钮点击→直接调用生成→完成后再导航”：
  - 在 `EquipmentSelectionView` 的按钮点击中直接调用 `viewModel.generatePlan(context: modelContext, completion:)`，成功后再设置 `hasOnboarded = true` 并导航；`GeneratingView` 改为仅展示进度和重试，不承担触发职责（Views/Onboarding/EquipmentAndGeneratingViews.swift:215–229）。
  - 这样避免任何非预期导航导致自动生成，彻底消除“输入中跳转”类问题。

### 3. AI 助手重生成的安全顺序
- 调整 `regeneratePlan(profile:)` 的顺序（ViewModels/AIAssistantViewModel.swift:114–155）：
  - 先调用 AI 生成 `newPlan`（120–123 行）。
  - 插入并关联：`profile.workoutPlan = newPlan`，`modelContext.insert(newPlan)`，`try modelContext.save()`。
  - 保存成功后再安全删除 `oldPlan`（若存在）并再次保存；失败则保留旧计划不删除，返回错误消息。
- 目的：任何失败情况下不丢失用户现有计划。

### 4. 动作级修改的匹配与持久化修正
- 精确匹配：将 `updateExercise` 与 `removeExercise` 的查找由 `contains` 改为大小写不敏感的等值匹配（仅当精确匹配失败且仅找到一个近似候选时，才回退一次 `contains`，避免多项误删）。（ViewModels/AIAssistantViewModel.swift:202–205、261–264）
- 添加动作的持久化：`addExercise` 中在 `day.exercises.append(newExercise)` 后调用 `modelContext.insert(newExercise)` 并在批量操作后统一 `save()`（ViewModels/AIAssistantViewModel.swift:235–247、183–186），确保 SwiftData 正确跟踪变更。
- 操作事务化：`executeCommand` 里围绕循环执行操作后统一 `try modelContext.save()`（现有 183–186 行保留），并在发生异常时回滚（通过错误消息提示，避免半成功状态）。

### 5. 防误操作的额外保护（建议）
- `PlanDashboardView.resetOnboarding()`（Views/Plan/PlanDashboardView.swift:179–188）已经有一次确认弹窗；建议将顶栏“重新设置”入口降级或增加二次确认文案，避免用户误触后认为“所有计划被删除”。

## 验证与回归测试
- 备注输入：在设备上使用中文输入法，持续输入与换行，确保不会自动跳转；仅在点击“生成计划”时触发生成与导航。
- 助手更新：
  - 替换动作（精确名称与模糊名称各测一次），确认只影响目标动作。
  - 删除动作：请求删除含通用词的动作名，确认不会误删其它动作。
  - 重生成：在网络异常/JSON 不合规时，旧计划仍保留；成功时旧计划被安全替换。
- 计划重置：手动触发重置流程，确认 UX 与数据行为一致且无误删误会。

## 进阶建议（更易实现且可靠）
- 将第二页助手的“整体结构修改”与“动作级 CRUD”分离为两个明确入口与文案，分别走：
  - 整体结构：始终弹窗确认并以“生成成功后再替换”的模式执行。
  - 动作级 CRUD：基于上下文的严格名称匹配并限制一次只改/删一个目标。
- 对 AI 指令协议增加字段校验与白名单（如动作名必须来自当前 `planContext`），减少误解读。

请确认上述修复方案，我将按步骤进行代码修改与验证。