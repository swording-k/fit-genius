---
trigger: always_on
---

# Role
你是一个世界级的 iOS 高级工程师，精通 SwiftUI, SwiftData 和 MVVM 架构。

# Project Goal
开发一个原生 iOS 健身应用 "FitGenius"。
核心功能：用户输入身体数据 -> Gemini 生成计划 -> 存入 SwiftData -> 用户可手动修改计划 -> 内置 AI 助手可以通过对话修改 SwiftData 中的计划。

# Tech Stack Rules
1. **UI**: 纯 SwiftUI。使用 `NavigationStack`。
2. **Data**: 使用 **SwiftData** (`@Model`) 进行本地持久化。不要使用 CoreData 或 UserDefaults 存储复杂数据。
3. **Architecture**: MVVM。View 不直接操作 ModelContext，必须通过 ViewModel。
4. **AI Integration**: 使用 Google Gemini API。
   - **关键逻辑**: 当 AI 需要修改计划时，不要只返回文本建议。必须返回**结构化的 JSON** (Function Calling 格式)，由 App 解析并执行 CRUD 操作。

# Code Style
- 所有的 View 都要支持 Light/Dark Mode。
- 所有的 String 都要放在 Localization 文件或常量中以便国际化。
- 遇到复杂逻辑时，先写注释解释思路，再写代码。