#!/usr/bin/env python3
"""
下载 exercises-dataset 的 GIF 演示素材到本地 staging 目录。

说明（重要）：
- 仓库 LICENSE 的 MEDIA EXCEPTION 明确：GIF 媒体 © Gym visual，不在 MIT 范围内；
  clone 仓库不等于获得授权。下载与后续托管须由项目方自行评估授权风险。
- 本脚本只负责把素材抓到本地，并保留种子 JSON 中的 attribution 字段
  （"© Gym visual — https://gymvisual.com/"），署名不可去除。
- 下载源：GitHub raw（脚本运行环境可直连）。托管目标（COS / Vercel 等）由上游脚本决定。
"""
import json
import os
import sys
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED = ROOT / "FitGenius" / "Resources" / "ExerciseLibrary" / "exercises_seed.json"
OUT = Path(os.environ.get("GIF_STAGING", "/tmp/fitgenius_gifs"))
GITHUB_RAW = "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/videos/"

CONCURRENCY = 16
TIMEOUT = 60
RETRIES = 3


def github_url_from_gifurl(gif_url: str, fallback_id: str, fallback_media: str) -> str:
    # 优先用 gifUrl 的文件名（robust，兼容 jsDelivr / github 两种形式）
    if gif_url:
        name = gif_url.rstrip("/").split("/")[-1]
        if name.endswith(".gif"):
            return GITHUB_RAW + name
    # 兜底：{id}-{mediaId}.gif
    return GITHUB_RAW + f"{fallback_id}-{fallback_media}.gif"


def download_one(item):
    gid = item.get("id", "?")
    media = item.get("mediaId", "")
    gif_url = item.get("gifUrl", "")
    url = github_url_from_gifurl(gif_url, gid, media)
    name = url.split("/")[-1]
    dest = OUT / name
    if dest.exists() and dest.stat().st_size > 0:
        return name, True, "cached"
    for attempt in range(1, RETRIES + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "FitGenius/1.0"})
            with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
                data = r.read()
            if not data or len(data) < 200:
                raise ValueError(f"too small: {len(data)}")
            dest.write_bytes(data)
            return name, True, f"ok({len(data)})"
        except Exception as e:  # noqa: BLE001
            last = e
            continue
    return name, False, f"FAILED: {last}"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    records = json.load(open(SEED))
    print(f"待下载: {len(records)} 个, 输出目录: {OUT}", flush=True)

    ok = 0
    failed = []
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as ex:
        futs = [ex.submit(download_one, r) for r in records]
        done = 0
        for f in as_completed(futs):
            name, success, msg = f.result()
            done += 1
            if success:
                ok += 1
            else:
                failed.append((name, msg))
            if done % 100 == 0 or done == len(records):
                print(f"进度 {done}/{len(records)}  成功 {ok}  失败 {len(failed)}", flush=True)

    print(f"\n完成: 成功 {ok}/{len(records)}", flush=True)
    if failed:
        print(f"失败 {len(failed)} 个:", flush=True)
        for n, m in failed[:30]:
            print(f"  - {n}: {m}", flush=True)
    # 写一份清单，方便上游上传脚本使用
    manifest = {
        "count": ok,
        "failed": [n for n, _ in failed],
        "dir": str(OUT),
    }
    (OUT / "_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    print(f"清单已写入 {OUT / '_manifest.json'}", flush=True)


if __name__ == "__main__":
    main()
