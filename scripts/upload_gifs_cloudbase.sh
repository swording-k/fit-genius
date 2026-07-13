#!/bin/bash
# 将本地 staging 的 GIF 上传到 CloudBase 静态网站托管(公开可读, 国内直连)。
#
# 前置:
#   - 已通过 WorkBuddy CloudBase 连接器授权(本机 tcb CLI 可用)
#   - 已用 scripts/download_gifs.py 把 GIF 下到本地
# 用法:
#   bash scripts/upload_gifs_cloudbase.sh [envId] [localDir]
#
# 说明:
#   - 静态网站托管默认公开服务, 域名形如
#     https://<envId>-<appid>.tcloudbaseapp.com
#   - 本脚本将本地目录整包上传到云端 exercise-gifs/ 路径
#   - App 端 ExerciseMedia 读 Info.plist 的 ExerciseGIFBaseURL 作为首选源
#   - GIF 媒体版权 © Gym visual, 仅托管二进制, 署名由 App 端展示, 不得去除
set -e

TCB=/Users/baojian/.workbuddy/binaries/node/cli-connector-packages/bin/tcb
ENV="${1:-fitgenius-d0ghm1rz21cef6594}"
LOCAL="${2:-/tmp/fitgenius_gifs}"
APPID=1441969311   # 本账号 Tencent Cloud AppID, 静态托管域名后缀固定

if [ ! -d "$LOCAL" ]; then
  echo "本地目录不存在: $LOCAL (先跑 scripts/download_gifs.py)" >&2
  exit 1
fi

echo "上传 $LOCAL -> 静态托管 exercise-gifs/ (env=$ENV) ..."
"$TCB" hosting deploy "$LOCAL" exercise-gifs --env-id "$ENV" --concurrency 20 --retry-count 5

echo "完成。公开基础 URL:"
echo "https://${ENV}-${APPID}.tcloudbaseapp.com/exercise-gifs"
echo "→ 确认 App 的 Info.plist 中 ExerciseGIFBaseURL 与此一致。"
