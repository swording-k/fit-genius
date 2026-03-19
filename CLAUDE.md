# FitGenius App 文档

## 项目概述

FitGenius 是一款iOS健身应用，支持训练计划和饮食追踪双模式。主要功能包括：
- 训练计划管理（训练动作、组数、重量、休息日）
- 饮食记录与AI营养分析
- iOS Widget小组件展示
- Apple登录与数据持久化

## 技术栈

- **UI框架**: SwiftUI + SwiftUI Charts
- **数据持久化**: SwiftData
- **Widget**: WidgetKit
- **AI服务**: 阿里云通义千问API
- **架构**: MVVM

## 项目结构

```
FitGenius/
├── FitGeniusApp.swift          # App入口，ModelContainer配置，Widget数据管理
├── Views/
│   ├── MainView.swift          # 主TabView（训练/饮食模式切换）
│   ├── Plan/                   # 训练计划相关视图
│   │   ├── PlanDashboardView.swift
│   │   ├── WorkoutDayDetailView.swift
│   │   └── ...
│   ├── Diet/                   # 饮食相关视图
│   │   ├── DietHomeView.swift
│   │   ├── DietAIAssistantView.swift
│   │   └── ...
│   ├── Stats/                  # 统计视图
│   ├── Profile/                # 个人中心
│   │   └── ProfileView.swift   # 包含Widget背景设置
│   └── Assistant/              # AI助手
├── ViewModels/                 # 业务逻辑
├── Models/
│   ├── Plan/WorkoutModels.swift    # WorkoutPlan, WorkoutDay, Exercise
│   ├── Diet/MealModels.swift       # MealDay, MealEntry, NutritionSummary
│   ├── UserProfile.swift           # 用户档案
│   └── FitnessEnums.swift          # BodyPartFocus, MealType等枚举
├── Services/
│   ├── AIService.swift             # AI分析服务
│   ├── NotificationService.swift   # 推送通知
│   └── Keychain.swift              # 密钥存储
└── Components/                     # 可复用组件

FitGeniusWidget/                    # Widget Extension
└── FitGeniusWidget.swift          # Widget实现
```

## 核心数据模型

### 训练模型 (Models/Plan/WorkoutModels.swift)
- **WorkoutPlan**: 训练计划，包含多个WorkoutDay
- **WorkoutDay**: 训练日（胸、背、腿等），包含多个Exercise
- **Exercise**: 单个动作（名称、组数、重量、是否完成）
- **ExerciseLog**: 训练记录

### 饮食模型 (Models/Diet/MealModels.swift)
- **MealDay**: 一天的饮食记录
- **MealEntry**: 单餐记录（早餐/午餐/晚餐/零食）
- **NutritionSummary**: 营养汇总（卡路里、蛋白质、碳水、脂肪）

### 用户模型
- **UserProfile**: 用户档案（身高、体重、年龄、目标），关联WorkoutPlan

## Widget机制

### 数据共享
- 使用App Group: `group.com.swordingk.fitgenius`
- 主App通过`UserDefaults(suiteName:)`写入数据
- Widget通过相同方式读取数据

### 关键数据键
- `widgetWorkout`: 训练计划数据 (WidgetWorkoutData)
- `widgetDiet`: 饮食数据 (WidgetDietData)
- `widgetBackgroundType`: 背景类型 (system/gradient/customImage)
- `widgetCustomBackground`: 自定义背景图片Data
- `widgetContent`: Small Widget显示偏好 (workout/diet)

### Widget数据更新时机
- App启动时 (MainView.onAppear)
- 完成训练动作时 (WorkoutDayDetailView)
- 提交饮食分析时 (DietViewModel)
- 切换appMode时

### URL Scheme
- `fitgenius://completeExercise?id=xxx` - 从Widget跳转完成动作

## App模式

通过`@AppStorage("appMode")`切换：
- `training`: 训练模式（Tab: 训练、AI助手、统计、个人）
- `diet`: 饮食模式（Tab: 饮食、AI助手、统计、个人）

## 关键函数

### WidgetDataManager (FitGeniusApp.swift)
```swift
static func updateWorkoutData(modelContext: ModelContext)
static func updateDietData(modelContext: ModelContext)
static func setBackgroundType(_ type: String)
static func setCustomBackground(_ imageData: Data?)
```

### 常用通知
- `dietSummaryUpdated`: 饮食汇总更新后刷新Widget
- `completeExerciseFromWidget`: 从Widget完成动作

## 注意事项

1. Widget Extension和主App必须配置相同的App Group
2. SwiftData ModelContainer配置在FitGeniusApp中
3. 训练计划需要关联到UserProfile才能在Widget中显示
4. 自定义背景图片需要转为Data存储
