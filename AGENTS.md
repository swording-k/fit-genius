# FitGenius 项目 Agent 入口

> 这是 FitGenius 多 agent 协作的入口文档。**任何 agent 在本项目继续开发前必须先读本文件**，
> 然后阅读 `docs/form-coach-roadmap.md`（产品路线）和 `docs/agent-handoff.md`（当前状态）。
>
> ⚠️ **本文件以「线上真实跑的代码」为准**。AGENTS 早期版本写的是 Vercel + Neon 架构，
> 但**当前生产后端已迁移到腾讯云 CloudBase**，Vercel 代码（`api/` + `backend/`）未部署，
> 不代表线上行为。读到不一致时以 `cloudfunctions/fitgenius-api/index.js` 与部署清单 `cloudbaserc.json` 为准。

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
**+** 腾讯云 CloudBase 后端（Event 云函数 `cloudfunctions/fitgenius-api`：Apple Sign in 验证 + AI 代理）
**+** MiniMax-M3 全模态模型（AI 推理，key 仅存于 CloudBase 环境变量）。

> 仓库里仍保留了一套**早期 Vercel + Neon** 实现（`api/` + `backend/`，含 `/api/form-analyses`、`/api/cloud-snapshot`、账户删除），但**当前生产后端已迁移到 CloudBase，Vercel 代码未部署、不代表线上**。以 CloudBase 为准。

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
│              │  WorkoutPlan / MealDay / │  （本地 SQLite，离线优先）│
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
        │   CloudBase 云函数 fitgenius-api (Event, Node18)    │
        │  ┌─────────────┐ ┌─────────────┐                    │
        │  │/api/auth/   │ │/api/ai/     │   (仅这 2 条 +     │
        │  │  apple      │ │  chat       │   /api/health 上线) │
        │  └──────┬──────┘ └──────┬──────┘                    │
        │         │               │                           │
        │   Apple JWKS       MiniMax-M3 转发 (thinking:off)   │
        │   verify (jose)    provider key 仅服务端            │
        │         │               │                           │
        │         └──────┬────────┘                           │
        │                ▼                                    │
        │       ┌──────────────────────┐                     │
        │       │  HS256 Session JWT   │                     │
        │       │  (jose, SESSION_     │                     │
        │       │   SECRET, 30d TTL)  │                     │
        │       └──────────┬───────────┘                     │
        └──────────────────┼─────────────────────────────────┘
                           ▼
             （暂无独立数据库：云同步端点 form-analyses /
              cloud-snapshot 尚未上线 → iOS 端同步目前为 no-op，
              但 App 离线也能完整可用）
```

数据流要点：
- iOS 写 SwiftData 是**第一优先级**，离线/弱网也能用；即使云端同步关闭，App 也完整可用。
- 云同步目前是 **no-op**：iOS 的 `FormAnalysisSyncCoordinator` / `CloudSnapshotCoordinator` 会按 `pending`/`failed` 重试（3 次指数退避 2s/4s/8s）并向 `/api/form-analyses`、`/api/cloud-snapshot` 发请求，但**线上 CloudBase 函数尚未实现这两条路由 + 无数据库**，请求返回 404 被静默吞掉。详见第 9 节「云同步开启条件」。
- AI 走代理：iOS 只发 `Authorization: Bearer <sessionToken>`，**永不**接触 provider key。

---

## 3. 目录结构（真实状态）

```
FitGenius/
├── AGENTS.md                      ← 你正在看的文件（agent 入口）
├── README.md                      ← 对外产品说明（已同步为 CloudBase 架构）
├── cloudbaserc.json               ← CloudBase 部署清单（envId / 路由 / 环境变量）
├── package.json                   ← 历史 Vercel 后端依赖（未部署，仅供参考）
├── vercel.json                    ← 历史 Vercel 配置（未部署）
├── .env.example                   ← 后端环境变量样例（无真实值）
│
├── FitGenius/                     ← iOS App target
│   ├── FitGeniusApp.swift         ← App 入口、ModelContainer、scenePhase
│   ├── ContentView.swift
│   ├── Info.plist                 ← FitGeniusBackendURL = CloudBase 域名
│   ├── PrivacyInfo.xcprivacy      ← App Store 合规
│   ├── Models/
│   │   ├── Plan/                  ← WorkoutPlan / WorkoutDay / Exercise
│   │   ├── Diet/                  ← MealDay / MealEntry / NutritionSummary
│   │   ├── Form/                  ← FormAnalysisRecord / SyncPayload / CloudSnapshot
│   │   ├── UserProfile.swift
│   │   └── FitnessEnums.swift
│   ├── ViewModels/                ← AuthViewModel / DietViewModel /
│   │                                StatsViewModel / FormAnalysisViewModel
│   ├── Views/                     ← SwiftUI
│   │   ├── Plan/  Diet/  Stats/  Profile/  Onboarding/  Assistant/  Components/
│   ├── Services/
│   │   ├── AIService.swift        ← 走 /api/ai/chat 代理 + 直连双模式
│   │   ├── AuthService.swift      ← Apple Sign in
│   │   ├── Keychain.swift
│   │   ├── AppleAuthAPIClient.swift
│   │   ├── NotificationService.swift
│   │   ├── DebugSeedService.swift ← DEBUG-only 测试数据
│   │   └── FormAnalysis/          ← SyncCoordinator / SyncService / SyncSettings
│   ├── Resources/  (en.lproj / zh-Hans.lproj)
│   └── FitGenius.entitlements
│
├── FitGeniusWidget/               ← Widget Extension（独立 target）
├── FitGeniusWatch Watch App/      ← watchOS 训练辅助 target
│
├── cloudfunctions/                ← ★ 当前生产后端（CloudBase Event 函数）
│   └── fitgenius-api/
│       ├── index.js               ← 仅 3 路由：health / auth/apple / ai/chat
│       └── backend/               ← sessionToken / appleTokenVerifier /
│                                     aiProviderConfig（jose + MiniMax）
│
├── api/                           ← ⚠️ 历史 Vercel Functions（未部署）
│   ├── auth/apple.js  ai/chat.js  form-analyses.js
│   ├── cloud-snapshot.js  account.js
├── backend/                       ← ⚠️ 历史 Vercel 共享模块（未部署）
│   ├── neonClient.mjs  database.mjs  migrate.mjs  sessionToken.mjs
│   ├── appleTokenVerifier.mjs  formAnalysisRepository.mjs
│   ├── cloudSnapshotRepository.mjs  README.md  tests/
│
├── scripts/                       ← 运维脚本（部分面向历史 Vercel 后端）
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
- **持久化**: SwiftData（本地 SQLite，CloudKit 已关闭 → 纯本地）
- **认证**: AuthenticationServices（Sign in with Apple）
- **姿态识别**: Apple Vision（`VNDetectHumanBodyPoseRequest`，本地，零网络）
- **Widget**: WidgetKit + App Group（`group.com.swordingk.fitgenius`）
- **AI 通道**: 双模式 —— ① 默认走 `/api/ai/chat` 代理（Bearer session）；② App 内填自有 Key 直连 OpenAI 兼容端点，免后端、免登录
- **架构**: MVVM + `@MainActor` ViewModel + `ObservableObject`

### 后端（生产 = CloudBase）
- **平台**: 腾讯云 CloudBase Event 云函数（envId `fitgenius-d0ghm1rz21cef6594`）
- **Runtime**: Node.js 18.15（云函数运行时）
- **形态**: 纯 Node Event 函数（无 Express），仅 3 路由，无状态、无数据库
- **AI 转发**: provider-neutral OpenAI 兼容代理，当前 `AI_PROVIDER=minimax`（MiniMax-M3），
  `thinking:{type:"disabled"}` 关思考避免超过 50s 云函数超时；key 仅服务端持有
- **认证**: `jose`（Apple JWKS 验签 + HS256 session JWT）
- **历史方案（未部署）**: Vercel Serverless + Neon Postgres（`api/` + `backend/`）

### 部署
- **后端**: 腾讯云 CloudBase（`cloudfunctions/fitgenius-api`，`npx @cloudbase/cli deploy -e fitgenius-d0ghm1rz21cef6594`）
- **iOS**: TestFlight → App Store
- **历史（未部署）**: Vercel（GitHub 集成自动部署）

---

## 5. 关键不变量（破坏任何一条 = P0）

1. **任何 AI provider key 不进 iOS 包**。plist / scheme / build settings / 代码字面量都不得出现真实 key。
2. **SwiftData 是 local source of truth**。网络失败不应阻塞用户操作；云端同步缺失时 App 仍完整可用。
3. **iOS 只发 `Authorization: Bearer <sessionToken>`**。任何 provider key 都不经过 iOS。
4. **Privacy manifest (`PrivacyInfo.xcprivacy`) 必须与 `Info.plist` 真实权限声明一致**。
5. **本地化**：新文案必须同步 `en.lproj` + `zh-Hans.lproj`。变量 key 用 `LocalizedStringKey(...)`。
6. **App Group** 必须在 Main App + Widget 两侧都正确配置。
7. **新文件放进 `FitGenius/` 即可被 Xcode 自动收录**（PBXFileSystemSynchronizedRootGroup）。
8. **CloudBase JSON 请求体有 ~100KB 硬限**（文本类型）；图片压到 ≤50KB 单图、云快照需走 Storage URL 而非直接塞 JSON。

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
4. 历史 Vercel 后端单测（仅供参考，未部署）：
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
| 表单同步协调 | `FormAnalysisSyncCoordinator` | 3 次指数退避；**当前 no-op**（后端无 `/api/form-analyses`） |
| 账户快照同步 | `CloudSnapshotCoordinator` | 按账户隔离；**当前 no-op**（后端无 `/api/cloud-snapshot`） |
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

## 9. 云同步开启条件（iOS 端已就绪，仅差服务端）

**现状**：iOS 端 `FormAnalysisSyncCoordinator`（POST `/api/form-analyses`，payload = `FormAnalysisRecord.syncPayload()`）与 `CloudSnapshotCoordinator`/`CloudSnapshotService`（GET/PUT `/api/cloud-snapshot`，payload = `CloudSnapshot` 全量账户快照）已完整实现并随 scene 回到前台触发。但线上 CloudBase `index.js` 无这 2 条路由、无数据库 → 404 no-op。

**要真正打开，需补三件事（都在 CloudBase 侧）：**

1. **加数据库**：在 CloudBase 环境开通 NoSQL 文档数据库（或 MySQL），建集合 `form_analyses` 与 `cloud_snapshots`，按 `userId` 隔离。云函数用 `@cloudbase/node-sdk` 或 CloudBase HTTP API 读写。
2. **加 2 条路由到 `cloudfunctions/fitgenius-api/index.js`**：
   - `POST /api/form-analyses`：校验 Bearer session → 写 `form_analyses`。
   - `GET|PUT /api/cloud-snapshot`：校验 session → 读/写 `cloud_snapshots`（按 userId）。
3. **绕开 100KB 限制（关键）**：
   - `form-analyses` 单条记录小，直接 JSON 即可。
   - `cloud-snapshot` 是全量账户导出，**远超 100KB**，不能塞进 JSON 请求体。正确做法（与图片管线一致）：把快照 JSON 先上传到 **CloudBase Storage** 拿 `fileID`/临时 URL，再 `PUT /api/cloud-snapshot` 只传 URL 指针（走「其他请求 100MB」通道），后端按 URL 落库。GET 时返回 URL，客户端再下载还原。

**部署约束**：本 agent 沙箱连不上腾讯云控制面（CloudBase MCP `tcb_refresh` ECONNRESET），**无法在此部署**。需在你本机能访问腾讯云的环境执行：
```bash
npx @cloudbase/cli deploy -e fitgenius-d0ghm1rz21cef6594
```
即服务端代码可在此写好、由你部署。

**开启后的影响**：
- 隐私政策必须明确「用户训练/饮食/表单数据存于腾讯云 CloudBase」，否则过不了审核。
- 你个人 CloudBase 环境将存真实用户 PII，需自行承担数据安全与合规责任。
- 不改变「离线优先」：SwiftData 仍是本地主源，同步只是备份/跨设备。

---

如果本文件与你看到的代码不一致，**以代码为准**并提 issue / 改本文件。
