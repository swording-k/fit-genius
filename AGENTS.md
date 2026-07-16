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
             （CloudBase NoSQL 集合 form_analyses / cloud_snapshots 已开通，
              云同步端点已上线 → iOS 端同步为实时备份/跨设备；
              App 离线也能完整可用，SwiftData 为本地主源）
```

数据流要点：
- iOS 写 SwiftData 是**第一优先级**，离线/弱网也能用；即使云端同步关闭，App 也完整可用。
- 云同步**已上线**（2026-07-16 经 CloudBase MCP 部署）：iOS 的 `FormAnalysisSyncCoordinator` / `CloudSnapshotCoordinator` 按 `pending`/`failed` 重试（3 次指数退避 2s/4s/8s）并向 `/api/form-analyses`、`/api/cloud-snapshot` 发请求；CloudBase `index.js` 已实现这两条路由（写/读 `form_analyses`、`cloud_snapshots`，按 `userId` 隔离）。网关路由默认关闭「路径透传」，`event.path` 收到 `/`，函数改用 HTTP method 还原路由（POST→form-analyses，GET/PUT→cloud-snapshot），各端点 method 唯一、映射无歧义，**无需改动 iOS 端**。详见第 9 节。
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
| 表单同步协调 | `FormAnalysisSyncCoordinator` | 3 次指数退避；**已上线**（POST `/api/form-analyses`，写 `form_analyses`） |
| 账户快照同步 | `CloudSnapshotCoordinator` | 按账户隔离；**已上线**（GET/PUT `/api/cloud-snapshot`，读写 `cloud_snapshots`） |
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

## 9. 云同步现状（iOS 端 + 服务端均已就绪并上线）

**状态（2026-07-16）**：云同步**已上线**。iOS 端 `FormAnalysisSyncCoordinator`（POST `/api/form-analyses`，payload = `FormAnalysisRecord.syncPayload()`）与 `CloudSnapshotCoordinator`/`CloudSnapshotService`（GET/PUT `/api/cloud-snapshot`，payload = `CloudSnapshot` 全量账户快照）完整实现并随 scene 回到前台触发；服务端 CloudBase `fitgenius-api` 已实现这两条路由，并开通了 NoSQL 集合 `form_analyses` 与 `cloud_snapshots`（按 `userId` 隔离）。端到端已验证：POST 写入、PUT/GET 快照往返、跨用户隔离（404）、无 token 返回 401。

**路由实现细节（重要）**：网关 `createRoute` 默认 `EnablePathTransmission = false`，会把请求路径剥离后转发给 Event 函数（`event.path` 收到 `/`）。三条内置路由（health/auth/apple/ai/chat）在初始化时即以 transmission ON 创建，保留真实路径；两条云同步路由通过 transmission-off 路由暴露到默认域名 `fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com`，函数无法从 `event.path` 区分，因此 `index.js` 在 `event.path === "/"` 时按 HTTP method 还原路由（POST→form-analyses，GET/PUT→cloud-snapshot）。各端点 method 唯一，映射无歧义，**无需改动 iOS 端**。若日后在 CloudBase 控制台把这两个路由的「路径透传」打开，函数优先使用 `event.path`，逻辑向后兼容。

**仍需处理的限制（上线前/后）**：
1. **100KB JSON 上限（关键）**：`form-analyses` 单条记录小，直传 JSON 即可（已验证）。`cloud-snapshot` 是全量账户导出，**对小/新账户可直传**（已验证往返），但大账户会超过 CloudBase HTTP 触发 ~100KB 文本请求体上限（实测超即 `EXCEED_MAX_PAYLOAD_SIZE`）。彻底解法（与图片管线一致）：快照 JSON 先传 **CloudBase Storage** 拿 `fileID`/临时 URL，再 `PUT /api/cloud-snapshot` 只传 URL 指针（走「其他请求 100MB」通道），后端按 URL 落库；GET 返回 URL，客户端再下载还原。该 iOS 端 Storage-first 重构尚未做。
2. **隐私政策**：必须明确「用户训练/饮食/表单数据存于腾讯云 CloudBase」，否则过不了 App Store 审核（见上线核查）。

**部署**：已于 2026-07-16 通过 CloudBase MCP 完成（非 `tcb` CLI）——`updateFunctionCode` 部署 `index.js` + `@cloudbase/node-sdk`，并在默认域名上以 `createRoute` 暴露两条同步路由。此前 `tcb_refresh` ECONNRESET 的连接面问题已绕开（MCP 直连可用）。

**开启后的影响**：不改变「离线优先」——SwiftData 仍是本地主源，同步只是备份/跨设备。你个人 CloudBase 环境存真实用户 PII，需自行承担数据安全与合规责任。

---

如果本文件与你看到的代码不一致，**以代码为准**并提 issue / 改本文件。
