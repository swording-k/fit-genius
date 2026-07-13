#!/usr/bin/env python3
"""
将本地 staging 的 GIF 上传到腾讯云 COS，供 App 国内直接加载。

前置：
  pip install cos-python-sdk-v5
  export COS_SECRET_ID=xxx
  export COS_SECRET_KEY=xxx
  export COS_BUCKET=your-bucket-1234567890  # 格式: 名称-APPID
  export COS_REGION=ap-guangzhou
  export COS_PREFIX=exercise-gifs          # 可选，默认 exercise-gifs
  export GIF_STAGING=/tmp/fitgenius_gifs   # 与 download_gifs.py 一致

说明：
- 仅上传 GIF 二进制；© Gym visual 署名由 App 端负责显示，本脚本不动。
- 对象设为公有读（public-read），以便 App 直链访问。
- 上传完成后会打印 CDN/源站基础 URL，用于配置 ExerciseMedia 的 COS 基址。
"""
import os
import sys
import json
from pathlib import Path

try:
    from qcloud_cos import CosConfig, CosS3Client
    from qcloud_cos.cos_exception import CosServiceError
except ImportError:
    print("请先安装依赖: pip install cos-python-sdk-v5")
    sys.exit(1)

SECRET_ID = os.environ.get("COS_SECRET_ID")
SECRET_KEY = os.environ.get("COS_SECRET_KEY")
BUCKET = os.environ.get("COS_BUCKET")
REGION = os.environ.get("COS_REGION", "ap-guangzhou")
PREFIX = os.environ.get("COS_PREFIX", "exercise-gifs").strip("/")
STAGING = Path(os.environ.get("GIF_STAGING", "/tmp/fitgenius_gifs"))

for var, val in [("COS_SECRET_ID", SECRET_ID), ("COS_SECRET_KEY", SECRET_KEY),
                 ("COS_BUCKET", BUCKET), ("COS_REGION", REGION)]:
    if not val:
        print(f"缺少环境变量: {var}")
        sys.exit(1)


def main():
    config = CosConfig(Region=REGION, SecretId=SECRET_ID, SecretKey=SECRET_KEY)
    client = CosS3Client(config)

    gifs = sorted(p for p in STAGING.glob("*.gif") if p.is_file())
    print(f"找到 {len(gifs)} 个 GIF，开始上传到 cos://{BUCKET}/{PREFIX}/", flush=True)

    ok = 0
    failed = []
    for i, path in enumerate(gifs, 1):
        key = f"{PREFIX}/{path.name}"
        try:
            client.upload_file(
                Bucket=BUCKET,
                Key=key,
                LocalFilePath=str(path),
                PartSize=1,
                MAXThread=5,
                EnableMD5=False,
                progress_callback=None,
            )
            # 确保公有读
            client.put_object_acl(Bucket=BUCKET, Key=key, ACL="public-read")
            ok += 1
        except CosServiceError as e:
            failed.append((path.name, str(e)))
        if i % 100 == 0 or i == len(gifs):
            print(f"进度 {i}/{len(gifs)}  成功 {ok}  失败 {len(failed)}", flush=True)

    print(f"\n上传完成: 成功 {ok}/{len(gifs)}", flush=True)
    if failed:
        print(f"失败 {len(failed)} 个:", flush=True)
        for n, m in failed[:20]:
            print(f"  - {n}: {m}", flush=True)

    base = f"https://{BUCKET}.cos.{REGION}.myqcloud.com/{PREFIX}"
    print(f"\nCOS 基础 URL: {base}")
    print("→ 把它配置到 ExerciseMedia 的 COS 基址（见下方说明）。")
    print("\n可选：为该 bucket 开启 CDN 加速域名以获得更优国内访问速度。")


if __name__ == "__main__":
    main()
