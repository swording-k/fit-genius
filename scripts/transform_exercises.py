#!/usr/bin/env python3
"""Transform exercises-dataset raw JSON into a trimmed, app-ready seed file.

Source: hasaneyldrm/exercises-dataset (data/exercises.json, MIT for data/text).
Output: FitGenius/Resources/ExerciseLibrary/exercises_seed.json

We keep only the fields FitGenius needs (name, body part, equipment, target,
secondary muscles, zh/en instructions, media reference) and pre-compute the
body-part -> BodyPartFocus mapping and equipment -> category/environment
suitability so the Swift side is a pure decoder.

Media (GIF/thumbnail) is NOT bundled (GymVisual license). The detail view
loads gifUrl on demand; gifUrl points at the dataset repo's raw path.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "exercises_raw.json")
if not os.path.exists(SRC):
    # 允许从 /tmp 读取已下载的原始数据（CI / 临时环境）
    SRC = "/tmp/ex_raw.json"
OUT_DIR = os.path.join(ROOT, "FitGenius", "Resources", "ExerciseLibrary")
OUT = os.path.join(OUT_DIR, "exercises_seed.json")
# 国内可达的 CDN（jsDelivr GitHub CDN）。App 内 AnimatedGIFView 还会把
# raw.githubusercontent.com 作为兜底，任一可用即可播放。
GIF_BASE = "https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/"

# dataset body_part -> BodyPartFocus rawValue (Chinese, matches FitnessEnums.swift)
BODY_PART_MAP = {
    "chest": "胸部",
    "back": "背部",
    "upper legs": "腿部",
    "lower legs": "腿部",
    "waist": "核心",
    "upper arms": "手臂",
    "lower arms": "手臂",
    "shoulders": "肩部",
    "neck": "肩部",
    "cardio": "有氧",
}


def equipment_info(eq: str):
    """Return (ui_category, set_of_suitable_environments)."""
    if eq == "body weight":
        return "bodyweight", {"gym", "home", "outdoor"}
    if eq == "dumbbell":
        return "dumbbell", {"gym", "home"}
    if eq in ("barbell", "ez barbell", "olympic barbell", "trap bar"):
        return "barbell", {"gym"}
    if eq in (
        "cable", "leverage machine", "sled machine", "smith machine",
        "skierg machine", "elliptical machine", "stepmill machine",
        "stationary bike", "upper body ergometer", "assisted",
    ):
        return "machine", {"gym"}
    if eq == "kettlebell":
        return "kettlebell", {"gym", "home"}
    if eq in ("band", "resistance band"):
        return "band", {"gym", "home"}
    # everything else (medicine ball, stability ball, bosu ball, rope, tire,
    # roller, wheel roller, hammer, weighted, ...) -> "other"
    env = {"gym", "home"}
    if eq in ("rope", "tire"):
        env.add("outdoor")
    return "other", env


def main():
    with open(SRC, "r", encoding="utf-8") as f:
        data = json.load(f)

    out = []
    for rec in data:
        instr = rec.get("instructions") or {}
        eq = rec.get("equipment") or "body weight"
        cat, env = equipment_info(eq)
        gif = rec.get("gif_url") or ""
        out.append({
            "id": rec.get("id"),
            "name": rec.get("name"),
            "bodyPart": rec.get("body_part"),
            "focusRaw": BODY_PART_MAP.get(rec.get("body_part") or "", "全身"),
            "equipment": eq,
            "equipmentCategory": cat,
            "target": rec.get("target"),
            "secondaryMuscles": rec.get("secondary_muscles") or [],
            "zh": (instr.get("zh") or "").strip(),
            "en": (instr.get("en") or "").strip(),
            "mediaId": rec.get("media_id"),
            "gifUrl": (GIF_BASE + gif) if gif else None,
            "attribution": rec.get("attribution"),
            "suitableGym": "gym" in env,
            "suitableHome": "home" in env,
            "suitableOutdoor": "outdoor" in env,
        })

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))

    print(f"records: {len(out)}")
    print(f"bytes: {os.path.getsize(OUT)}")
    from collections import Counter
    print("focus:", dict(Counter(d["focusRaw"] for d in out)))
    print("category:", dict(Counter(d["equipmentCategory"] for d in out)))


if __name__ == "__main__":
    main()
