## 方案概述
- 采用“手机号 + 短信验证码（OTP）”登录，兼容中国国内常规登录体验。
- 认证提供方优先推荐：LeanCloud（国内可用，内置短信与用户系统）。备选：腾讯云短信 + 轻后端（Cloudflare Workers）自建验证。
- 继续使用 CloudKit 存储训练/饮食数据；认证仅用于识别用户与颁发会话。

## 你需要先完成的事项（不改代码）
- 在 LeanCloud 创建应用，开启短信服务，获取 `AppID` 与 `AppKey`、REST 域名；在短信模板中设置“登录验证码”模板。
- 在苹果开发者账户 → App 的 ATS 允许访问该 REST 域名（默认 HTTPS 无额外设置）。
- 将密钥放入 Xcode 的 `XCConfig`/`Info.plist` 占位，不提交到仓库。

## 技术实现（代码改动）
- 新建 `PhoneAuthService`：
  - `requestCode(phone)` → 调用 LeanCloud `requestSmsCode`；
  - `verifyCode(phone, code)` → 调用 `verifySmsCode` 并登录/注册用户，返回 `userId` 与 `sessionToken`；
  - 本地保存到 `Keychain` 与 `UserDefaults`。
- 登录 UI：
  - 在“设置”页新增“手机号登录”分区：输入手机号、获取验证码按钮、验证码输入与登录按钮；显示倒计时与错误提示。
  - 登录成功后：写入 `UserProfile.userId` 并提示“已登录”。
- 与 CloudKit 关联：
  - 若 `userId` 变更，`WorkoutPlanRecord`/`UserProfileRecord` 使用新的 `userId` 上传/拉取。
  - 维持“本地优先 + 手动同步”的策略。

## 安全与风控
- 密钥通过 `XCConfig`/`Info.plist` 读取，不写入仓库；
- 验证码按钮做 60s 倒计时与频控；
- 失败与网络错误明确提示；
- 会话统一存 Keychain（`sessionToken`）。

## 迭代步骤
1) 我添加 `PhoneAuthService`、设置页 UI、Keychain 存储、与 CloudKit 的 `userId` 绑定；
2) 你在 LeanCloud后台配置短信与密钥，并提供给我（本地 `XCConfig`）；
3) 联调：请求验证码 → 验证登录 → 上传/拉取云端；
4) 后续扩展：
   - 自动同步（前台激活拉取）；
   - 饮食板块模型与同步；
   - 将 AI Key 迁移到服务端代理。

确认后我将直接开始实现上述登录流程与设置页改动（密钥使用占位读取，待你填充）。