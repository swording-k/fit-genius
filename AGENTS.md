# FitGenius 项目 Agent 入口

> 这是 FitGenius 多 agent 协作的入口文档。**任何 agent 在本项目继续开发前必须先读本文件**，
> 然后阅读 `docs/form-coach-roadmap.md`（产品路线）和 `docs/agent-handoff.md`（当前状态）。

---

## 1. 项目一句话

**品牌名（App Store 用户可见，对外）**
- 中文区：**FitGenius**
- 英文区：**Fit-Genius**（带连字符变体，避开英文区同名占用）
- Slogan：让每一次训练都不白费

**工程层（永远不变）**
- Bundle ID：`com.swordingk.fitgenius`（已上架，锁死，不可改）
- App Group：`group.com.swordingk.fitgenius`（同上）
- URL Scheme：`fitgenius://`（同上）

> Brand 与工程标识分离：用户看到的名字改了不影响工程内部任何东西，**老用户照常升级**。连字符变体对 App Store 搜索零影响（搜索是 token 模糊匹配，会忽略标点）。

FitGenius = iOS 健身 App（SwiftUI + SwiftData，训练 + 饮食双模式）
**+** Apple Watch 训练辅助 App（训练进度 + 休息计时 + 心率 + HealthKit）
**+** Vercel Serverless 后端（Apple Sign in 验证 + AI 代理 + 云同步 + 账户删除）
**+** Neon Postgres（用户、表单分析与账户快照持久化）。

iOS 包内**不携带**任何 AI provider 真实 key；所有第三方 key 全部在后端 env vars。

---

## 2. 端到端架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                          iOS App (SwiftUI)                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │ Training │  │   Diet   │  │  Stats   │  │  Form Analysis   │ │
│  │  Plan    │  │  Logs    │  │  Charts  │  │  (Vision + Rule) │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────┬─────────┘ │
│       │             │              │                 │           │
│       └─────────────┴──────┬───────┴─────────────────┘           │
│                            ▼                                     │
│              ┌──────────────────────────┐                       │
│              │   SwiftData (local DB)   │  ◄── primary source   │
│              │  WorkoutPlan / MealDay / │                       │
│              │  FormAnalysisRecord      │                       │
│              └────────────┬─────────────┘                       │
│                            │                                     │
│       ┌────────────────────┼────────────────────┐                │
│       ▼                    ▼                    ▼                │
│  ┌─────────┐        ┌──────────────┐    ┌──────────────┐         │
│  │ Widget  │        │  AIAssistant │    │ FormAnalysis │         │
│  │(AppGrp) │        │   (proxy)    │    │SyncCoord.    │         │
│  └─────────┘        └──────┬───────┘    └──────┬───────┘         │
│                            │                   │                 │
└────────────────────────────┼───────────────────┼─────────────────┘
                             │ Bearer session    │ Bearer session
                             ▼                   ▼
        ┌────────────────────────────────────────────────────┐
        │        Vercel Serverless Backend (Node 22)         │
        │  ┌─────────────┐ ┌─────────────┐ ┌───────────────┐  │
        │  │/api/auth/   │ │/api/ai/     │ │/api/form-     │  │
        │  │  apple      │ │  chat       │ │  analyses     │  │
        │  └──────┬──────┘ └──────┬──────┘ └───────┬───────┘  │
        │         │               │                │          │
        │   Apple JWKS       AI provider       buildInsert     │
        │   verify (jose)    compatible API    SQL → Neon      │
        │         │               │                │          │
        │         └──────┬────────┴────────────────┘          │
        │                ▼                                    │
        │       ┌──────────────────────┐                     │
        │       │  HS256 Session JWT   │                     │
        │       │  (jose, SESSION_     │                     │
        │       │   SECRET, 30d TTL)  │                     │
        │       └──────────┬───────────┘                     │
        └──────────────────┼─────────────────────────────────┘
                           ▼
                  ┌──────────────────┐
                  │   Neon Postgres  │
                  │  users           │
                  │  form_analysis_  │
                  │    records       │
                  │  cloud_snapshots │
                  └──────────────────┘
```

数据流要点：
- iOS 写 SwiftData 是**第一优先级**，离线/弱网也能用。
- 同步是**尽力而为**：sync coordinator 拿 `pending` / `failed` 记录重试，3 次指数退避（2s/4s/8s）。
- AI 走代理：iOS 只发 `Authorization: Bearer <sessionToken>`，**永不**接触 provider key。

---

## 3. 目录结构（真实状态）

```
FitGenius/
├── AGENTS.md                      ← 你正在看的文件（agent 入口）
├── README.md
├── package.json                   ← Vercel 后端依赖 + scripts
├── vercel.json                    ← Vercel 构建/路由配置
├── .env.example                   ← 后端环境变量样例（无真实值）
│
├── FitGenius/                     ← iOS App target
│   ├── FitGeniusApp.swift         ← App 入口、ModelContainer、scenePhase
│   ├── ContentView.swift
│   ├── Info.plist
│   ├── PrivacyInfo.xcprivacy      ← App Store 合规
│   ├── Models/
│   │   ├── Plan/                  ← WorkoutPlan / WorkoutDay / Exercise
│   │   ├── Diet/                  ← MealDay / MealEntry / NutritionSummary
│   │   ├── Form/                  ← FormAnalysisRecord / SyncPayload
│   │   ├── UserProfile.swift
│   │   └── FitnessEnums.swift
│   ├── ViewModels/                ← AuthViewModel / DietViewModel /
│   │                                StatsViewModel / FormAnalysisViewModel
│   ├── Views/                     ← SwiftUI
│   │   ├── Plan/                  ← PlanDashboard / WorkoutDayDetail /
│   │   │                            FormAnalysisView
│   │   ├── Diet/
│   │   ├── Stats/
│   │   ├── Profile/               ← ProfileView / SourcesInfoView
│   │   ├── Onboarding/
│   │   ├── Assistant/             ← AIAssistantView
│   │   └── Components/            ← VideoCameraPicker
│   ├── Services/
│   │   ├── AIService.swift        ← 走 /api/ai/chat 代理
│   │   ├── AuthService.swift      ← Apple Sign in
│   │   ├── Keychain.swift
│   │   ├── AppleAuthAPIClient.swift
│   │   ├── NotificationService.swift
│   │   ├── DebugSeedService.swift ← DEBUG-only 测试数据
│   │   └── FormAnalysis/          ← SyncCoordinator / SyncService / SyncSettings
│   ├── Resources/
│   │   ├── en.lproj/              ← English
│   │   └── zh-Hans.lproj/         ← 简体中文
│   └── FitGenius.entitlements
│
├── FitGeniusWidget/               ← Widget Extension（独立 target）
├── FitGeniusWatch Watch App/      ← watchOS 训练辅助 target
│
├── api/                           ← Vercel Serverless Functions
│   ├── auth/apple.js
│   ├── ai/chat.js
│   ├── form-analyses.js
│   ├── cloud-snapshot.js
│   └── account.js
│
├── backend/                       ← 后端共享模块（被 api/ 引用）
│   ├── neonClient.mjs
│   ├── database.mjs
│   ├── migrate.mjs
│   ├── sessionToken.mjs
│   ├── appleTokenVerifier.mjs
│   ├── formAnalysisPayload.mjs
│   ├── formAnalysisRepository.mjs
│   ├── cloudSnapshotRepository.mjs
│   ├── README.md                  ← 部署/环境配置说明
│   └── tests/                     ← node --test 后端单测
│
├── scripts/                       ← 运维脚本
│   ├── apply-schema.sh            ← node backend/migrate.mjs 包装
│   └── run-form-analysis-tests.sh
│
├── docs/
│   ├── form-coach-roadmap.md      ← 产品阶段路线
│   └── agent-handoff.md           ← 当前状态 / 验证记录 / 下一步
│
└── .claude/                       ← Claude Code 本地配置（不入库）
    └── settings.local.json
```

---

## 4. 技术栈

### iOS 端
- **UI**: SwiftUI（iOS 17+），SwiftUI Charts
- **持久化**: SwiftData
- **认证**: AuthenticationServices（Sign in with Apple）
- **姿态识别**: Apple Vision（`VNDetectHumanBodyPoseRequest`，本地，零网络）
- **Widget**: WidgetKit + App Group（`group.com.swordingk.fitgenius`）
- **AI 通道**: 永远走 `/api/ai/chat` 代理；`URLSession` SSE 流式
- **架构**: MVVM + `@MainActor` ViewModel + `ObservableObject`

### 后端
- **Runtime**: Node.js 22（Vercel 默认）
- **框架**: 纯 Vercel Serverless Functions（无 Express）
- **数据库**: Neon Serverless Postgres（`@neondatabase/serverless`）
- **认证**: `jose`（Apple JWKS 验签 + HS256 session JWT）
- **AI 转发**: provider-neutral OpenAI 兼容代理（MiniMax 主用，Aliyun 紧急回滚；仅服务端持有 key）

### 部署
- **后端**: Vercel（GitHub 集成自动部署；环境变量在 dashboard 配）
- **数据库**: Neon（免费层；`DATABASE_URL` 给 Vercel）
- **iOS**: TestFlight → App Store

---

## 5. 关键不变量（破坏任何一条 = P0）

1. **任何 AI provider key 不进 iOS 包**。plist / scheme / build settings / 代码字面量都不得出现真实 key。
2. **SwiftData 是 local source of truth**。网络失败不应阻塞用户操作。
3. **iOS 只发 `Authorization: Bearer <sessionToken>`**。任何 provider key 都不经过 iOS。
4. **Privacy manifest (`PrivacyInfo.xcprivacy`) 必须与 `Info.plist` 真实权限声明一致**。
5. **本地化**：新文案必须同步 `en.lproj` + `zh-Hans.lproj`。变量 key 用 `LocalizedStringKey(...)`。
6. **App Group** 必须在 Main App + Widget 两侧都正确配置。
7. **新文件放进 `FitGenius/` 即可被 Xcode 自动收录**（PBXFileSystemSynchronizedRootGroup）。

---

## 6. Agent 协作规范

### 接手流程
1. 读本文件 → 读 `docs/form-coach-roadmap.md` → 读 `docs/agent-handoff.md`。
2. 检查 `git status` 与最近 5 个 commit，确认没有未跟踪的关键文件。
3. 构建验证命令：
   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
     xcodebuild -project FitGenius.xcodeproj -scheme FitGenius \
     -destination 'generic/platform=iOS Simulator' \
     -derivedDataPath /tmp/FitGeniusDerivedData \
     CODE_SIGNING_ALLOWED=NO build
   ```
4. 后端单测：
   ```bash
   npm run test:backend
   ```

### 推进流程
- 阶段性进展必须写入 `docs/agent-handoff.md` 三段：`Current Status` / `Latest Validation` / `Next Recommended Work`。
- 改产品/技术路线 → 同步 `docs/form-coach-roadmap.md`。
- 新增/修改用户可见文案 → 同步两个 `Localizable.strings`。

### 禁止
- 覆盖或回滚未确认来源的本地改动。
- 重新引入真实 API key 到仓库任何位置。
- 凭聊天记录作为唯一上下文——一切可恢复的状态写进 docs。
- 提交 `Config.plist`、`.env`、`*.p12`、`*.mobileprovision`、`.claude/settings.local.json`（已在 `.gitignore`）。

---

## 7. 关键概念速查

| 概念 | 位置 | 备注 |
|---|---|---|
| App Mode 切换 | `ContentView.swift` `@AppStorage("appMode")` | `training` / `diet` |
| Widget 数据桥 | `FitGeniusApp.swift WidgetDataManager` | App Group: `group.com.swordingk.fitgenius` |
| Apple 登录 token 交换 | `AppleAuthAPIClient.exchange(...)` | POST `/api/auth/apple` |
| Session 存储 | `SyncSettings.setSessionToken(...)` | `UserDefaults`，iOS 端零 Keychain 依赖 |
| AI 代理 URL | `AIService.resolveBaseURL()` | `backendBaseURL + "/api/ai/chat"` |
| 表单同步协调 | `FormAnalysisSyncCoordinator` | 3 次指数退避；`sleepProvider` 可注入 |
| 账户快照同步 | `CloudSnapshotCoordinator` | 按账户隔离；SwiftData 仍是本地主数据源 |
| Watch 同步 | `WatchSyncService` | 今日训练、逐组完成、休息计时与完成状态 |
| 数据模型（动作分析） | `Models/Form/FormAnalysisRecord` | `syncStatusRaw` ∈ `pending`/`failed`/`synced` |
| 规则引擎 | `Services/FormAnalysis/FormRuleEngine` | 平台无关：`PoseFrame` / `JointPoint` / `FormMetric` / `FormIssue` |
| 设备内动作与姿态协议 | `Models/Form/PoseModels.swift` | 深蹲/硬拉/卧推/站姿推举；未知动作拒绝自动评分 |
| 隐私清单 | `FitGenius/PrivacyInfo.xcprivacy` | Required Reason API 字典 |

---

## 8. 变更时的回滚锚点

| 想回滚 | 找这里 |
|---|---|
| 旧版 Aliyun 直连 | `git log --diff-filter=D -- AIService.swift` |
| 旧版 Keychain 存 user id | `git log --diff-filter=D -- AuthViewModel.swift` |
| 旧版 plist 携带 key | `git log --diff-filter=D -- Info.plist` |
| 旧版 Scheme env var | `git log --diff-filter=D -- FitGenius.xcscheme` |

---

如果本文件与你看到的代码不一致，**以代码为准**并提 issue / 改本文件。
