#!/usr/bin/env python3
"""
MajuRun — Bulk upload assets to Cloudinary (unsigned preset, no API secret needed)

Reads from:  assets/{category}/...
Uploads to:  Cloudinary under majurun/{category}/...
Outputs:     scripts/output/asset_urls.json      (URL map, used by seed script)
             lib/core/constants/asset_urls.dart  (Flutter constants)

Usage:
    python scripts/upload_assets.py
    python scripts/upload_assets.py --reset   (re-upload everything)

Safe to re-run — skips already-uploaded files using progress JSON.
"""

import os
import json
import time
import sys
import requests
from pathlib import Path
from datetime import datetime

# ─── CONFIG ──────────────────────────────────────────────────────────────────
CLOUD_NAME    = "ddo14sbqv"
UPLOAD_PRESET = "majurun"
ASSETS_ROOT   = Path(__file__).parent.parent / "assets"
OUTPUT_DIR    = Path(__file__).parent / "output"
PROGRESS_FILE = OUTPUT_DIR / "asset_urls.json"
DART_OUTPUT   = Path(__file__).parent.parent / "lib" / "core" / "constants" / "asset_urls.dart"

IMAGE_EXTS = {'.jpg', '.jpeg', '.png', '.webp'}
VIDEO_EXTS = {'.mp4', '.mov', '.webm'}

# Skip app icon/logo — those aren't content assets
SKIP_TOP_DIRS = {'icon', 'images', 'workouts'}


# ─── CLOUDINARY FOLDER MAPPING ───────────────────────────────────────────────
def get_cloudinary_folder(rel_path: Path) -> str:
    """
    Map local asset path to Cloudinary folder.
    Special case: plan_covers/badges/ → majurun/badges/  (top-level badges folder)
    All others:   assets/{a}/{b}/  → majurun/{a}/{b}/
    """
    parts = rel_path.parts
    if len(parts) >= 2 and parts[0] == "plan_covers" and parts[1] == "badges":
        return "majurun/badges"
    folder_parts = parts[:-1]  # everything except filename
    return "majurun/" + "/".join(folder_parts)


def get_url_key(rel_path: Path) -> str:
    """Key used in asset_urls.json — relative path without extension."""
    return str(rel_path.with_suffix("")).replace("\\", "/")


# ─── FILE DISCOVERY ───────────────────────────────────────────────────────────
def collect_files() -> list[Path]:
    files = []
    for path in sorted(ASSETS_ROOT.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix.lower() not in IMAGE_EXTS | VIDEO_EXTS:
            continue
        rel = path.relative_to(ASSETS_ROOT)
        if rel.parts[0] in SKIP_TOP_DIRS:
            continue
        files.append(path)
    return files


# ─── UPLOAD ───────────────────────────────────────────────────────────────────
def upload_file(path: Path) -> str:
    rel          = path.relative_to(ASSETS_ROOT)
    folder       = get_cloudinary_folder(rel)
    public_id    = path.stem
    is_video     = path.suffix.lower() in VIDEO_EXTS
    resource_type = "video" if is_video else "image"

    upload_url = f"https://api.cloudinary.com/v1_1/{CLOUD_NAME}/{resource_type}/upload"

    with open(path, "rb") as f:
        response = requests.post(
            upload_url,
            data={
                "upload_preset": UPLOAD_PRESET,
                "folder":        folder,
                "public_id":     public_id,
            },
            files={"file": (path.name, f)},
            timeout=180,
        )

    if response.status_code == 200:
        return response.json()["secure_url"]

    # Cloudinary returns 400 if the asset already exists with overwrite=false
    if response.status_code == 400 and "already exists" in response.text:
        return f"https://res.cloudinary.com/{CLOUD_NAME}/{resource_type}/upload/{folder}/{public_id}"

    raise Exception(f"HTTP {response.status_code}: {response.text[:300]}")


# ─── DART GENERATOR ───────────────────────────────────────────────────────────
def generate_dart(url_map: dict) -> str:
    lines = [
        "// AUTO-GENERATED — do not edit manually.",
        "// Run: python scripts/upload_assets.py to regenerate.",
        f"// Generated: {datetime.now().isoformat()}",
        "",
        "// ignore_for_file: constant_identifier_names",
        "class AssetUrls {",
        "  AssetUrls._();",
        "",
    ]

    # Group by top-level category
    groups: dict[str, list[tuple]] = {}
    for key, url in sorted(url_map.items()):
        category = key.split("/")[0]
        groups.setdefault(category, []).append((key, url))

    for category, items in sorted(groups.items()):
        label = category.upper().replace("_", " ")
        lines.append(f"  // ─── {label} ───")
        for key, url in items:
            const_name = key.replace("/", "_").replace("-", "_")
            lines.append(f"  static const String {const_name} = '{url}';")
        lines.append("")

    # Convenience map for plan covers
    plan_keys = {k: v for k, v in url_map.items() if k.startswith("plan_covers/images/")}
    if plan_keys:
        lines.append("  // ─── PLAN COVER MAP (planTitle → imageUrl) ───")
        lines.append("  static const Map<String, String> planCovers = {")
        plan_name_map = {
            "plan_5k_beginner":    "5K Beginner Plan",
            "plan_10k_builder":    "10K Builder",
            "plan_half_marathon":  "Half Marathon",
            "plan_marathon":       "Full Marathon",
            "plan_hiit_blast":     "HIIT Blast",
            "plan_strength":       "Strength for Runners",
            "plan_indoors":        "Indoor Workout",
            "plan_speed_intervals": "Speed Intervals",
        }
        for key, url in sorted(plan_keys.items()):
            stem = Path(key).stem
            plan_title = plan_name_map.get(stem, stem)
            lines.append(f"    '{plan_title}': '{url}',")
        lines.append("  };")
        lines.append("")

    # Badge map
    badge_keys = {k: v for k, v in url_map.items() if k.startswith("plan_covers/badges/")}
    if badge_keys:
        lines.append("  // ─── BADGE MAP (badgeId → imageUrl) ───")
        lines.append("  static const Map<String, String> badges = {")
        for key, url in sorted(badge_keys.items()):
            badge_id = Path(key).stem  # e.g. badge_5k
            lines.append(f"    '{badge_id}': '{url}',")
        lines.append("  };")
        lines.append("")

    lines.append("}")
    return "\n".join(lines)


# ─── MAIN ─────────────────────────────────────────────────────────────────────
def main():
    reset = "--reset" in sys.argv
    print("MajuRun Asset Uploader")
    print(f"   Cloud: {CLOUD_NAME}  |  Preset: {UPLOAD_PRESET}\n")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Load previous progress
    url_map: dict = {}
    if PROGRESS_FILE.exists() and not reset:
        url_map = json.loads(PROGRESS_FILE.read_text(encoding="utf-8"))
        print(f"Resuming -- {len(url_map)} already uploaded\n")
    elif reset:
        print("--reset: re-uploading everything\n")

    files = collect_files()
    print(f"{len(files)} files found in assets/\n")

    uploaded = skipped = failed = 0

    for i, path in enumerate(files):
        rel = path.relative_to(ASSETS_ROOT)
        key = get_url_key(rel)

        if key in url_map:
            skipped += 1
            continue

        folder = get_cloudinary_folder(rel)
        is_video = path.suffix.lower() in VIDEO_EXTS
        label = "video" if is_video else "image"
        size_kb = path.stat().st_size // 1024

        print(f"[{i+1}/{len(files)}] {key}  ({label}, {size_kb}KB)... ", end="", flush=True)

        try:
            url = upload_file(path)
            url_map[key] = url
            PROGRESS_FILE.write_text(json.dumps(url_map, indent=2), encoding="utf-8")
            print("OK")
            uploaded += 1
            # Slight delay: images 0.2s, videos 0.5s (larger, more API pressure)
            time.sleep(0.5 if is_video else 0.2)
        except Exception as e:
            print(f"FAILED: {e}")
            failed += 1

    # Regenerate Dart file
    DART_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    DART_OUTPUT.write_text(generate_dart(url_map), encoding="utf-8")

    print(f"\n{'-'*50}")
    print(f"Uploaded : {uploaded}")
    print(f"Skipped  : {skipped}")
    print(f"Failed   : {failed}")
    print(f"Total    : {len(url_map)} URLs in JSON")
    print(f"JSON     : {PROGRESS_FILE}")
    print(f"Dart     : {DART_OUTPUT}")
    print(f"{'-'*50}")
    print("\nDone! Now run the seed script:")
    print("   cd scripts && npm install firebase-admin && node seed_firestore.js")


if __name__ == "__main__":
    main()
