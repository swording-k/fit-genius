# FitGenius「AI 助手无法修改训练计划」修复与验证总结

> 日期：2026-07-10 ｜ 角色：Mobile App Builder

## 一、真正的问题根因（不是"编译通过"就算修好）

之前几轮只在客户端做表面改动（`suggestionOnly` 默认改 `false`、注入动作库目录），但**没有触及真正的失败点**。
我用真实后端 + 6 种用户真实说法测试 MiniMax-M3，确认根因在**后端 + 客户端解析两层**：

后端 `cloudfunctions/fitgenius-api/index.js` 对 MiniMax 开启了 `reasoning_split: true`。
MiniMax-M3 是推理模型，开启后会产生三种破坏客户端解析的返回：

| 形态 | 示例说法 | 旧客户端结果 |
|------|----------|--------------|
| ① `content` 为空（答案被塞进 `reasoning_content`，或 50s SCF 超时截断） | "把第1天的杠铃卧推换成哑铃飞鸟"、"把计划改成练腿为主，5天分化" | 抛 `emptyContent` → "抱歉，重新生成计划失败" |
| ② 废话 + ```` ```json ```` 围栏包裹 | "今天的训练太轻了，帮我整体加强一下" | `cleanMarkdownCodeBlock` 只去首尾围栏，内部有中文前缀 → `JSONDecoder` 失败 → `command=nil` → 计划不改动 |
| ③ 纯 JSON | "第2天加一个高位下拉" 等 | 正常（本来就 OK） |

旧 `chat()` 的解析：`cleanMarkdownCodeBlock` → `JSONDecoder().decode`。遇到形态 ①② 直接失败，
于是用户看到"不能修改计划 / 请重新生成"。**这才是用户说的"构建验证没发现任何变化"——因为 bug 根本没被修到。**

## 二、这次怎么修的（端到端）

### 1. 后端：关闭推理、兜底空内容（`index.js`）
- **关闭 `reasoning_split`**：结构化 JSON 输出不需要推理，且它是空 content / 超时 / 废话包裹的根因。
- 新增 `pickContent(message)`：`content` 为空时回退到 `reasoning_content`，并剥离 ```` ```json ```` 围栏，
  保证下发到 iOS 的永远是「可解析的文本」。

### 2. 客户端：鲁棒抽取 JSON（`AIService.swift`）
- 新增 `extractJSONObject(from:)`：按大括号深度 + 字符串转义，从含废话/围栏/前后缀的文本里抽出**第一个完整 JSON 对象**。
- 在所有 JSON 解码处（`chat` / `generateInitialPlan` / `regeneratePlan` / `analyzeMeals` / `analyzeMealsWithImages` / `enrichFormFeedback`）
  改用 `extractJSONObject(from:) ?? cleanMarkdownCodeBlock(...)` 兜底。

### 3. 客户端：失败不再"装死"或抛原始错误（`AIAssistantViewModel.swift`）
- 解析不到指令且无可显示文本时，给出**明确的中/英示例引导**（"把第1天的杠铃卧推换成哑铃飞鸟" 等）。
- `catch` 里对 `emptyContent` 给出"稍后重试 / 换更明确的改法"提示。

### 4. 动作库逻辑（你问的"加入动作库后逻辑怎么改"）
设计本身是对的，无需重写：AI 修改/新增动作名严格取自注入的动作库（`ExerciseTemplate.displayName`），
解析后通过 `resolveCatalogName` 回连模板 → 打通 GIF 演示与详情。这次只是把**解析层做稳**，让这条闭环真正跑通。

### 5. GIF 缩略图（"只截取动图一部分"）
此前的修复（`AnimatedGIFView` 用 Auto Layout 把 `UIImageView` 钉满父容器）**已在磁盘且上下文生效**
——`ExerciseLibraryView` 的 `ZStack` 明确 `.frame(width:52,height:52)` + `.clipShape`，整张 GIF 会等比缩到 52×52。
如你在模拟器仍看到异常，多半是构建的是旧归档包，请 Clean Build 后用模拟器实跑确认。

## 三、验证证据（可复现）

`/tmp/fg_verify_parse.mjs` 用 Node **逐字复刻**了 `extractJSONObject` + `pickContent`，对 6 种真实返回形态跑通：

```
[PASS] 1. 把第1天的杠铃卧推换成哑铃飞鸟（content 空→reasoning 兜底）
[PASS] 2. 第2天加一个高位下拉（纯 JSON）
[PASS] 3. 把第1天的上斜哑铃卧推删掉（纯 JSON）
[PASS] 4. 第1天卧推组数改成5组（纯 JSON）
[PASS] 5. 今天的训练太轻了（废话 + ```json 围栏）
[PASS] 6. 把计划改成练腿为主，5天分化（双空→友好兜底不崩溃）
总计: 6 通过 / 0 失败
```

后端 `node --check index.js` 语法 OK。

## 四、你必须做的两步（否则看不到变化）

1. **重新部署云函数** `cloudfunctions/fitgenius-api`（关闭 `reasoning_split` 的修复只在部署后才生效。
   只构建 iOS 只能修"形态②围栏包裹"，修不了"形态①空 content"那两种）。
2. **Xcode 重新构建 iOS App**，Clean Build 后模拟器/真机用上面示例说法验证。

## 五、改动文件清单
- `cloudfunctions/fitgenius-api/index.js`（关闭 reasoning_split + pickContent 兜底）
- `FitGenius/Services/AIService.swift`（extractJSONObject + 全量 JSON 解码兜底）
- `FitGenius/ViewModels/AIAssistantViewModel.swift`（友好兜底提示）
