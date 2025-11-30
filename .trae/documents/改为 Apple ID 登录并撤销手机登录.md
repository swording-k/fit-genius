## 变更目标
- 登录模式统一为 Apple ID 登录（ASAuthorizationAppleID），与 CloudKit 同步搭配。
- 移除刚添加的“手机号+验证码”登录相关代码与配置占位，避免后续维护成本与审核要求。

## 代码改动
- 删除文件：`FitGenius/Services/PhoneAuthService.swift`、`FitGenius/Services/KeychainHelper.swift`（短信会话不再使用）。
- 恢复设置页为 Apple 登录：
  - `SettingsView.swift`：还原为 `SignInWithAppleButton` 登录，去掉手机号/验证码 UI。
  - `SettingsViewModel.swift`：移除与短信相关的状态与方法（`phoneNumber/smsCode/countdown`、`requestSmsCode`、`verifySmsCode`），保留 `AuthService.signInWithApple()` 与 CloudKit 同步代码。
- 保留：`AuthService.swift`（Apple 登录）、`CloudKitSyncManager.swift`（同步）、`MainView.swift` 中“设置”标签。
- 不修改：AI 助手与训练/饮食相关代码。

## 你需要做的操作（账号侧）
- 等待 Apple 开发者订阅生效（邮件确认）。
- 开发者后台创建 App ID 与开启 Capabilities：Sign In with Apple、iCloud（CloudKit）。
- 在 Xcode：选择付费 Team，设置 Bundle Identifier 与添加上述 Capabilities。

## 验证
- 真机上点击“设置 → Sign in with Apple”完成登录，设置页显示“已登录”。
- 手动执行“上传到云端/拉取最新”，确认 CloudKit 同步可工作。