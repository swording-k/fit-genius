# App Store 审核备注（Review Notes）— 应对 Guideline 1.4.4 驳回

> 用途：在 App Store Connect 收到 1.4.4 驳回后，于「解决中心（Resolution Center）」回复并重新提交时，粘贴到「备注（Notes）」字段。
> 中英文两版，建议粘贴英文版（审核员母语为英文），中文版备用。

---

## English（推荐粘贴此版）

Dear App Review Team,

Thank you for your feedback. Regarding Guideline 1.4.4 (Safety — Physical Harm), we have updated the Diet Analysis feature as follows:

1. Added a medical disclaimer banner at the top of the Diet Record screen. On first launch, users see "AI advice is for reference only and does not constitute medical advice"; tapping it opens the full disclaimer.
2. Directly beneath every AI diet-analysis result, we now show clickable links to authoritative data sources (Chinese Nutrition Society at cnsoc.org.cn, USDA Food Data Center, etc.) together with the note "AI-generated nutrition insights are for reference only and do not constitute medical advice."
3. All nutrition and health recommendations list their authoritative references in the in-app "Data Sources" page (Chinese Nutrition Society, USDA, NIH, WHO, CDC, ACSM, NSCA) — all publicly verifiable authoritative institutions.

The app provides no diagnosis or treatment advice of any kind; all AI-generated output is explicitly labeled as reference information only.

---

## 简体中文（备用）

尊敬的审核团队：

感谢您的反馈。针对 Guideline 1.4.4（安全 — 人身伤害），我们已对饮食分析（Diet Analysis）功能做出如下调整：

1. 在饮食记录页顶部增加了医疗免责横幅，用户首次进入即会看到"AI 建议仅供参考，不构成医疗建议"的提示，点击可查看完整免责声明。
2. 在每一项 AI 饮食分析结果下方，直接附上权威数据来源的可点击链接（中国营养学会 cnsoc.org.cn、USDA 等），并标注"AI 生成的营养洞察仅供参考，不构成医疗建议"。
3. 所有营养与健康建议均在 App 内"数据来源"页面列出权威参考机构（中国营养学会、USDA、NIH、WHO、CDC、ACSM、NSCA），均为公开可验证的权威机构。

本 App 不提供任何形式的诊断或治疗建议，所有 AI 输出均明确标注为参考信息。

---

## 提交操作提醒（不上传，仅给你）

- 改完代码后必须**重新 Archive**，构建号从 `20260720` 升到 `20260721`（或任意 +1 唯一值）。
- 在 App Store Connect 中：进入被拒版本的「解决中心」→ 回复并附上本备注 → 上传新 build → 重新提交审核。
- 不要只回复不传新包——代码改动必须进新 build 才会被审核到。
