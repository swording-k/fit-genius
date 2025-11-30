## 目标

* 新增“饮食模式”，一键切换后底部 Tab 为：饮食、AI 助手、统计（饮食）。

* 支持按日期记录每餐（文字/图片），提交后由 AI 粗略解析并计算当日宏量与热量，统计页展示当日与趋势。

* 默认建议模式，编辑模式才写入记录，避免误改。

## 你的外部操作

* 提供 DashScope API Key（Qwen 文本与 Qwen-VL 视觉，国内可用）

  * 我读取环境变量 `ALIYUN_API_KEY`（已在工程使用）

* Xcode → Targets → Info 添加相册/相机权限文案：

  * `NSPhotoLibraryAddUsageDescription`、`NSPhotoLibraryUsageDescription`、`NSCameraUsageDescription`

* Apple 开发者订阅生效后：开启 `Sign In with Apple` 和 `iCloud（CloudKit）`（本阶段云端可选，不阻塞）

## 数据模型（SwiftData）

* `MealDay`: `date: Date`, `meals: [Meal]`, `analysis: NutritionSummary?`, `updatedAt: Date`

* `Meal`: `name: String`（早餐/午餐/晚餐/加餐或自定义）, `entries: [MealEntry]`

* `MealEntry`: `type: enum {text, photo}`, `text?: String`, `photoLocalURL?: String`, `quantity?: String`, `notes?: String`

* `NutritionSummary`: `calories: Double`, `protein: Double`, `carbs: Double`, `fat: Double`, `details: [FoodBreakdown]`

## 应用结构与模式切换

* 新增 `AppMode`（`training`/`diet`），`@AppStorage("appMode")` 保存

* 主页 TabView 动态：

  * 训练模式：训练、AI 助手、统计（已存在）

  * 饮食模式：`DietLogView`、`AIAssistantView(diet)`、`DietStatsView`

* 在主页添加训练/饮食切换按钮（不影响训练模式数据）

## 饮食记录页（DietLogView）

* 日期选择（今日/左右切换）

* 列表展示当日 `meals` 与 `entries`

* 添加一餐：选择餐名→添加“文字条目”或“图片条目”（图片保存在沙盒，记录本地 URL）

* “提交分析”按钮：

  * 文本→`AIService.parseDietText(entries)`

  * 图片→`AIService.parseDietImage(photoURLs)`（调用 Qwen-VL 粗识食物与份量）

  * 返回 `NutritionSummary`，写入 `MealDay.analysis`

## 饮食 AI 助手（AIAssistant 扩展）

* 默认“建议模式”：仅输出建议文本

* 编辑模式：输出结构化 JSON 指令（例如 `add_meal_entries`），写入 `MealDay/Meal`，遵循一次只改一个目标并弹窗确认

## 饮食统计页（DietStatsView）

* 当日四项：热量、蛋白质、碳水、脂肪（来自 `MealDay.analysis`）

* 近 7 天折线/柱状趋势（使用本地聚合）

## AIService 扩展（v2）

* 新增视觉路由：`parseDietImage` 调用 DashScope Qwen-VL（兼容模式），返回 JSON（食物名、份量、粗略宏量估算）

* 新增文本路由：`parseDietText` 解析用户描述为结构化饮食条目与粗略宏量

* 统一输出协议与 JSON 解析；失败时回退为纯文本建议

## 云同步（可选）

* 本阶段仅本地保存；若你开启 CloudKit，我们序列化 `MealDay`/`Meal`/`MealEntry`/`NutritionSummary` 为 JSON 存储，图片 Asset 可留到阶段 2

## 验证用例

* 文本录入一日三餐→提交分析→统计页显示当日宏量

* 图片录入常见菜品→粗略估算成功且可编辑修正

* 助手建议模式与编辑模式切换，编辑模式只影响唯一目标

* 模式切换不影响训练数据

## 风险与取舍

* 图片估算误差较大（MVP 粗估 + 手动校正），阶段 2 接营养数据库提高精度

* 视觉模型需要稳定 API Key；我们加重试与提示

## 交付内容（阶段一结束）

* 新数据模型与 UI 框架、AI 管道（文本/图片粗解析）、统计页基础图表、模式切换入口

* 外部依赖：仅 DashScope Key 与权限文案；CloudKit 可选

请确认，我将开始按上述方案编码（从数据模型与 UI 骨架入手，同时扩展 AIService 的文本/图像解析接口）。
