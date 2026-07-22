# App Store Guideline 4 权限本地化问题 — 应对策略与回复文案

## 问题本质（苹果截图所示）

第二张截图中的麦克风权限弹窗：
- **系统标题（跟随设备语言，英文）**："FitGenius" would like to access the Microphone.
- **应用描述（来自 InfoPlist.strings）**：中文 "FitGenius 需要访问您的麦克风以实现语音转文字功能"

这就是苹果说的 **"permissions requests are not written in the same language as the app's localization"**——弹窗内中英文混用，违反 Guideline 4。

根因：`NSMicrophoneUsageDescription` 和 `NSSpeechRecognitionUsageDescription` 有中文描述，但**缺少英文本地化**（`en.lproj/InfoPlist.strings` 里没有这两个 key）。当审核员用英文设备测试时，系统标题自动变英文，但描述 fallback 到中文。

---

## 苹果这次给了「不修复也能过」的绿色通道

邮件原文：
> "The issue we've identified below is eligible to be resolved on your next update. If this submission includes bug fixes and you'd like to have it approved at this time, reply to this message and let us know. You do not need to resubmit your app for us to proceed."

翻译：这个问题可以**留到下次更新再修**。如果你这次提交主要是修 bug，**直接回复这条消息请求批准即可，不需要重新传包**。

---

## 方案 A：最快上线（推荐，如果你急）

**不修改代码、不传新包**，直接在 App Store Connect 解决中心回复苹果，说明这是 bug-fix 版本，并承诺下版修复权限本地化。

### 英文回复（复制粘贴）

```
Thank you for your continued review.

This submission (1.5 build 2) is primarily a bug-fix update that addresses the medical-citation issue raised under Guideline 1.4.4 in our previous exchange. We acknowledge the permission-description localization concern raised under Guideline 4 and will resolve it comprehensively in the next update by localizing NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription in both English and Simplified Chinese InfoPlist.strings.

We would appreciate it if this bug-fix submission could be approved at this time, and we will address the remaining Guideline 4 issue in our next release.
```

### 中文回复（备用）

```
感谢您的持续审核。

本次提交（1.5 build 2）主要是修复此前 Guideline 1.4.4 中提出的医疗引用问题。我们承认 Guideline 4 中提到的权限描述本地化问题，并将在下一次更新中完善：在英文和简体中文的 InfoPlist.strings 中同时本地化 NSMicrophoneUsageDescription 和 NSSpeechRecognitionUsageDescription。

如果本次 bug-fix 版本可以先予通过，我们将不胜感激；剩余 Guideline 4 问题会在下一版中解决。
```

**优点**：今天就能回复，不用重新 Archive/上传/等审核。
**风险**：很低——苹果自己都说了可以这样做。下版记得真修。

---

## 方案 B：彻底修复后再提交（如果你不想留尾巴）

我已经在代码里补上了缺失的权限本地化：

- `FitGenius/Info.plist`：新增 `NSMicrophoneUsageDescription` 和 `NSSpeechRecognitionUsageDescription`（中文兜底）
- `FitGenius/en.lproj/InfoPlist.strings`：新增英文版麦克风 + 语音识别描述
- `FitGenius/zh-Hans.lproj/InfoPlist.strings`：新增简体中文版麦克风 + 语音识别描述

**你要做的**：
1. Xcode → 更新 `CURRENT_PROJECT_VERSION`（比如从当前 build 号 +1）
2. Product → Archive → 上传新 build（1.5 build 3）
3. App Store Connect 解决中心回复苹果：已修复权限本地化，并上传了新 build

### 英文回复

```
Thank you for your feedback.

We have localized all permission request descriptions to match the app's supported languages. Specifically, we added English and Simplified Chinese strings for NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription in both InfoPlist.strings files. A new build has been uploaded and is ready for your review.
```

### 中文回复

```
感谢您的反馈。

我们已对所有权限请求描述进行本地化处理，使其与 App 支持的语言保持一致。具体而言，我们在英文和简体中文的 InfoPlist.strings 中为 NSMicrophoneUsageDescription 和 NSSpeechRecognitionUsageDescription 补充了对应文案，并已上传新 build 供审核。
```

**优点**：一次性清掉 Guideline 4 问题，不留技术债。
**代价**：需要重新打包上传，再等一轮审核。

---

## 建议

如果你急着让这一版上线，**走方案 A**。苹果邮件里明确给了这个通道，不用硬刚。但务必在下一版（v1.5.1 或 v1.6）里把权限本地化彻底修好——这次代码改动我已经替你做好了，下次直接带着提交就行。
