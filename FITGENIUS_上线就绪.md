# FitGenius 上线就绪报告（2026-07-13）

## ✅ 后端已部署并验证

- 云函数 `fitgenius-api` 已通过 CloudBase MCP 部署（环境 `fitgenius-d0ghm1rz21cef6594`）。
- 健康检测：`GET /api/health` → `{"ok":true,"status":"healthy"}`。
- AI 链路：云端环境变量含有效 `MINIMAX_API_KEY`，`/api/ai/chat` 可正常调用 MiniMax-M3。

## ✅ Bug 1（AI 改不了计划）端到端修复

三层根因全部解决：

1. **App Store 旧版直连 DashScope 密钥已死** → 当前开发版改用 CloudBase 后端（MiniMax），密钥在服务端。
2. **后端 `reasoning_split` 导致空 content / 废话包裹** → 已关闭，并加 `pickContent` 兜底（content 空时回退 reasoning_content + 剥 Markdown 围栏）。
3. **MiniMax-M3 默认开启 thinking 模式**（`<think>` 标签）→ 模糊多动作请求（如"整体加强"）陷入长推理，超 50s 超时仍吐不出 JSON。**真正关思考需 `thinking: {type:"disabled"}`**（`reasoning_split` 只控制返回方式、不能关思考）。已修复。

客户端配合：`AIService.extractJSONObject` 从 `<think>`/Markdown 围栏中抽出第一个完整 JSON。

### 全场景实测验证（线上后端，3/3 通过）

| 用户说法 | 结果 |
|---|---|
| 把第1天的上斜哑铃卧推删掉 | ✅ `{"action":"remove",...}` |
| 第2天加一个高位下拉 | ✅ `{"action":"add",...}` |
| 今天的训练太轻了，帮我整体加强一下 | ✅ 返回 5 个 `increase_weight` action |

## ✅ Bug 2（GIF 缩略图只显示局部）已修复

纯客户端修复：改用无固有尺寸的宿主 `_GIFHostView` 钉满 52×52 父容器（直接把 UIImageView 当根视图会被其固有尺寸撑大、裁掉一角），`xcodebuild` 已 `BUILD SUCCEEDED`。

## 📦 代码状态

- 分支 `release/v1.3`，HEAD `a5d50b0`。
- 本次 5 个修复提交：`ffffc43`（图片超限+改计划假成功+提示词优先级）、`cc62043`（GIF 全帧解码 OOM 强杀）、`b3689c9`（图片 EXCEED 100KB 硬限）、`694da29`（缩略图约束冲突裁剪）、`a5d50b0`（缩略图固有尺寸撑大裁剪）。
- 已打标签 **`v1.4.0`**（指向 a5d50b0）并 **push 到 GitHub remote（origin/release/v1.3）**。
- 已排除隐私/缓存：`.workbuddy/`、`__pycache__`、`cloudrun/`、`xcuserdata`。

## 🚀 推上线（App Store）待办 — 需你的 Mac

1. Xcode 打开项目，切到 `release/v1.3` 分支。
2. 确认签名：Team = 你的开发者账号，Bundle ID `com.swordingk.fitgenius`。
3. 菜单 Product → Archive（选真机/Any iOS Device 目标）。
4. Organizer → 上传到 App Store Connect。
5. App Store Connect 填版本说明/截图 → 提交审核。

建议：先在真机/模拟器跑 `release/v1.3` 验证 Bug 1/2 真机效果，再送审。
