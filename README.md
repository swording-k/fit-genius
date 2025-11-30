# FitGenius - AI 健身计划管理 iOS 应用

<div align="center">

**一款基于 AI 的智能健身计划管理应用**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017.0+-blue.svg)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-Latest-purple.svg)](https://developer.apple.com/xcode/swiftdata/)

</div>

---

## 📱 应用简介

FitGenius 是一款原生 iOS 健身应用，通过 AI 技术为用户生成个性化训练计划，并提供智能训练管理和数据统计功能。

### ✨ 核心特性

#### 训练模块
- 🤖 **AI 智能生成**：根据用户身体数据和健身目标，自动生成个性化训练计划
- 🔄 **灵活循环系统**：支持任意天数的训练循环（3天、4天、5天、7天等）
- 📊 **数据统计分析**：训练容量趋势、重量增长曲线、坚持天数统计
- 💬 **AI 助手对话**：通过自然语言与 AI 交流，随时调整训练计划
- ✏️ **手动编辑**：支持手动修改训练动作、组数、次数和重量
- 🔥 **坚持天数追踪**：自动统计连续训练天数，激励用户坚持

#### 饮食模块 🆕
- 🍽️ **饮食记录**：支持文字和图片两种方式记录每日饮食
- 🤖 **AI 营养分析**：自动分析饮食内容，计算热量和三大营养素
- 📈 **营养趋势图表**：可视化展示每日热量、蛋白质、碳水、脂肪摄入趋势
- 💡 **饮食建议**：AI 根据训练目标提供个性化饮食建议
- 📸 **多模态识别**：支持拍照识别食物并自动分析营养成分

---

## 🎯 功能详解

### 1. Onboarding 流程

用户首次使用时，通过简洁的引导流程输入：
- 基本信息（姓名、年龄、身高、体重）
- 健身目标（增肌、减脂、塑形、提升力量）
- 训练环境（健身房、家庭）
- 可用器械
- 身体限制/伤病

AI 根据这些信息生成定制化训练计划。

### 2. 训练计划页面

**循环展示系统**：
- 显示完整的训练循环（不限于7天）
- 每天显示对应的日期和星期
- 自动定位到今天的训练
- 支持休息日标记
- 显示"循环第 X 周 · 第 Y 天"

**训练详情**：
- 每个动作显示：名称、组数、次数、重量、备注
- 一键标记完成状态
- 实时更新训练进度
- 支持手动编辑动作参数

### 3. AI 助手

**智能对话**：
- 自然语言交流
- 理解用户意图（修改计划、调整重量等）
- 返回结构化建议

**功能支持**：
- 修改训练动作
- 调整训练强度
- 解答健身问题
- 提供训练建议

### 4. 统计分析

**坚持天数统计**：
- 显示"你坚持训练计划已经 X 天"
- 今日全部完成 → 天数 +1
- 连续 2 天未完成 → 清零

**训练数据可视化**：
- 训练天数、完成动作数、总组数、训练容量
- 按日期的训练坚持情况（柱状图）
- 训练容量趋势（折线图）
- 每个力量动作的重量增长曲线

**智能容量计算**：
- 有重量动作：容量 = Sets × Reps × Weight
- 自重动作（如引体向上）：容量 = Sets × Reps

### 5. 饮食记录模块 🆕

**饮食记录方式**：
- **文字记录**：直接输入饮食内容（如"早餐：鸡蛋2个，牛奶250ml，全麦面包2片"）
- **图片记录**：拍照上传食物图片，AI 自动识别并分析

**AI 营养分析**：
- 自动识别食物种类和份量
- 计算总热量（kcal）
- 分析三大营养素：蛋白质（g）、碳水化合物（g）、脂肪（g）
- 提供详细的食物营养成分分解

**饮食统计**：
- 今日营养摄入概览
- 近 7 天营养趋势图表
- 热量、蛋白质、碳水、脂肪的独立趋势线
- 宏量营养素对比图表

**AI 饮食助手**：
- 根据训练目标提供饮食建议
- 分析当前饮食是否合理
- 推荐调整方案

---

## 🏗️ 技术架构

### 技术栈

- **UI 框架**：SwiftUI
- **数据持久化**：SwiftData
- **架构模式**：MVVM
- **AI 集成**：阿里云通义千问 API
- **导航**：NavigationStack
- **图表**：Swift Charts

### 项目结构

```
FitGenius/
├── Models/                    # 数据模型
│   ├── UserProfile.swift     # 用户资料
│   ├── WorkoutModels.swift   # 训练计划模型
│   ├── ChatMessage.swift     # 聊天消息
│   └── FitnessEnums.swift    # 健身相关枚举
│
├── ViewModels/               # 视图模型
│   ├── OnboardingViewModel.swift
│   ├── AIAssistantViewModel.swift
│   ├── StatsViewModel.swift
│   └── UserProfileViewModel.swift
│
├── Views/                    # 视图
│   ├── Onboarding/          # 引导流程
│   ├── Plan/                # 训练计划
│   ├── Assistant/           # AI 助手
│   ├── Stats/               # 统计分析
│   └── MainView.swift       # 主视图
│
├── Services/                 # 服务层
│   └── AIService.swift      # AI 服务
│
└── Utilities/               # 工具类
    └── Extensions.swift     # 扩展
```

### 核心数据模型

#### WorkoutPlan（训练计划）
```swift
- name: String                    // 计划名称
- days: [WorkoutDay]             // 训练日列表
- cycleDays: Int                 // 循环天数
- getTodayWorkout()              // 获取今天的训练
- getCurrentCycleWeek()          // 获取当前循环周期
```

#### WorkoutDay（训练日）
```swift
- dayNumber: Int                 // 第几天
- focus: BodyPartFocus          // 训练部位
- isRestDay: Bool               // 是否休息日
- exercises: [Exercise]         // 动作列表
```

#### Exercise（训练动作）
```swift
- name: String                   // 动作名称
- sets: Int                      // 组数
- reps: String                   // 次数（如 "8-12"）
- weight: Double                 // 重量
- isCompleted: Bool             // 是否完成
- logs: [ExerciseLog]           // 训练记录
```

#### UserProfile（用户资料）
```swift
- name, age, height, weight     // 基本信息
- goal: FitnessGoal             // 健身目标
- environment: WorkoutEnvironment // 训练环境
- streakDays: Int               // 坚持天数
- workoutPlan: WorkoutPlan?     // 训练计划
```

---

## 🚀 快速开始

### 环境要求

- macOS 14.0+
- Xcode 15.0+
- iOS 17.0+

### 安装步骤

1. **克隆仓库**
```bash
git clone https://github.com/swording-k/fit-genius.git
cd fit-genius
```

2. **配置 API 密钥**

在 Xcode 中设置环境变量：
- Product → Scheme → Edit Scheme
- Run → Arguments → Environment Variables
- 添加：`ALIYUN_API_KEY` = `你的阿里云API密钥`

3. **运行项目**
```bash
open FitGenius.xcodeproj
```
在 Xcode 中按 `Cmd + R` 运行

---

## 🔑 API 配置

### 获取阿里云 API 密钥

1. 访问 [阿里云控制台](https://dashscope.console.aliyun.com/)
2. 开通通义千问服务
3. 创建 API Key
4. 在 Xcode 中配置环境变量

### API 使用说明

- **模型**：`qwen-plus`
- **功能**：训练计划生成、AI 对话
- **请求格式**：JSON
- **响应处理**：结构化解析

---

## 📊 数据流程

### 训练计划生成流程

```
用户输入身体数据
    ↓
AIService.generateInitialPlan()
    ↓
调用阿里云 API
    ↓
解析 JSON 响应
    ↓
创建 WorkoutPlan 对象
    ↓
保存到 SwiftData
    ↓
显示在 UI
```

### 训练完成流程

```
用户点击完成 ✓
    ↓
Exercise.toggleCompletion()
    ↓
创建 ExerciseLog
    ↓
保存到 SwiftData
    ↓
更新统计数据
    ↓
更新坚持天数
```

---

## 🎨 UI 设计

### 设计原则

- **简洁直观**：清晰的信息层级
- **数据可视化**：图表展示训练数据
- **即时反馈**：操作后立即更新 UI
- **适配深色模式**：支持 Light/Dark Mode

### 主要页面

1. **Onboarding**：引导用户输入信息
2. **训练计划**：显示循环训练计划
3. **AI 助手**：智能对话界面
4. **统计分析**：数据可视化展示

---

## 🔄 循环系统设计

### 灵活循环

支持任意天数的训练循环：
- **3分化 + 1休息** = 4天循环
- **推拉腿 + 休息** = 4天循环
- **5天分化 + 2休息** = 7天循环
- **全身训练 + 休息** = 2天循环

### 日期匹配

根据计划创建日期自动计算：
```swift
今天在循环中的位置 = (今天 - 创建日期) % 循环天数
当前循环周期 = (今天 - 创建日期) / 循环天数 + 1
```

---

## 📈 未来规划

### 短期计划

- [ ] 添加用户登录系统（LeanCloud）
- [ ] 支持多设备数据同步
- [ ] AI 智能重量建议（渐进式超负荷）
- [ ] 训练视频教程集成

### 长期计划

- [ ] 社区功能（分享训练计划）
- [ ] 营养计划生成
- [ ] Apple Watch 集成
- [ ] 训练提醒推送

---

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

### 开发流程

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 👨‍💻 作者

**宝剑** - [swording-k](https://github.com/swording-k)

---

## 🙏 致谢

- [阿里云通义千问](https://tongyi.aliyun.com/) - AI 服务支持
- [Swift Charts](https://developer.apple.com/documentation/charts) - 数据可视化
- [SwiftData](https://developer.apple.com/xcode/swiftdata/) - 数据持久化

---

<div align="center">

**如果这个项目对你有帮助，请给个 ⭐️ Star 支持一下！**

</div>
