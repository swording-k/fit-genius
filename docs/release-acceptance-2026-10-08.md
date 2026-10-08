# 1.6.0 发布候选验收

版本：Main / Widget / Watch 均为 **1.6.0 (20261008)**。

## 已完成的修复

- 空首页草稿不再覆盖云计划；只有明确404才代表没有云备份。
- 云读取失败不上传、不建立错误基线；在途编辑或退出登录使旧恢复失效。
- AI 缺登录、无效JSON或空计划明确报错，不再伪装成固定个性化计划。
- 账户删除：生产接口、旧会话撤销、失败安全重试、本地14种用户模型清理。
- 大快照：48KiB认证分块，完整后原子提交，下载验身份/顺序/SHA256；上限24MiB。
- 旧客户端≤96KiB直传/直返兼容；新客户端>64KiB开始分块。
- API使用现代HTTP域名；已有旧默认配置升级，其他自定义地址保留。
- 云端43个教学节选保持developmentOnly；Release包不带开发MP4。

## 验证证据

- 生产CloudBase代码已更新，provider/session环境变量未覆盖。
- 新集合 account_states / cloud_snapshot_chunks 为ADMINONLY，未开放客户端直读。
- 新HTTP网关health/auth/AI、账户删除与原快照/分析路由可用。
- 180122字节中文/emoji快照4块真实往返，半途保旧、跨账户404、删除200、
  重复删除200、旧会话GET/PUT401通过。使用随机隔离账户，未触碰真实用户。
- 生产删除500的真实根因已定位：同事务并发remove失败；顺序remove后真探针通过。
- 后端13项、真实AIService8项、SwiftData恢复/清理、分块/网关迁移、
  原表单同步协调器及双语检查通过。复现入口：`bash scripts/run-release-repair-tests.sh`。
- Simulator构建与签名Release Archive成功；三目标版本一致，deep codesign验证通过。
- 最终归档：`/Users/baojian/Library/Developer/Xcode/Archives/2026-10-08/FitGenius-1.6.0-20261008-RC.xcarchive`。
- 本次没有合并主分支、上传TestFlight或提交商店审核。
- 已安装并启动Debug验收版到所有者iPhone14Pro；设备清单确认1.6.0(20261008)。
  Debug可以加载43个云端教学，最终Release归档不会播放未授权素材。

## 你要检查的流程

1. 升级安装后旧计划、饮食、历史仍在；首次使用可直接进空首页并手动添加动作。
2. 未登录生成计划显示明确登录提示；登录后生成腿/胸/肩/背四分化+休息，
   核对5天、动作与备注。修改现有计划先预览，取消不改变旧计划。
3. 新空设备登录恢复云计划；网络失败保持本地数据。两个设备验证恢复，
   云同步并非自动冲突合并，不同时编辑两台进行验收。
4. 在专用测试账号验证删除；不要为了测试删除真实训练账户。失败时本地保留，
   成功后训练/饮食/健康报告/聊天清空，动作参考库仍在。
5. Debug中检查43个教学、声音、拖动和Photos同屏对比；正式包不显示未授权片段。
6. 真机Apple登录、Photos权限、Watch/HealthKit确认；模拟器/隔离JWT不能替代这些验收。

## 正式提交前仍未完成的门槛

**必须更换生产凭据**：2026-10-08在内存中比对生产与旧Git历史，确认
MINIMAX_API_KEY、SESSION_SECRET均未变化。没有打印或写入这些值，也未擅自轮换。
请所有者在MiniMax撤销旧Key/创建新Key，并在CloudBase生产函数更新这两项；
新的SESSION_SECRET将要求用户重新登录。完成后再检查真实AI请求。

App Store Connect最高已上传版本/build尚未读取核对；归档编号不等于已上传。
当前无素材授权确认，不能把developmentOnly改成licensed。

结论：源码、后端与归档已交付供验收；不是已提交/已发布，也不能在凭据轮换前直接上线。

## 架构参考

腾讯云[HTTP域名与静态域名说明](https://docs.cloudbase.net/ai/cloudbase-ai-toolkit/mcp-tools)
及[数据库集合权限接口](https://cloud.tencent.com/document/api/876/127968)。
