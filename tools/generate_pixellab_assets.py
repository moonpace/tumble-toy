#!/usr/bin/env python3
"""Generate the approved PixelLab asset set from the recorded request manifest."""

from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import time
import urllib.error
import urllib.request

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs" / "pixellab-generation-prompts.json"
SOURCE_DIR = ROOT / "artifacts" / "pixellab-originals"
RESULT_PATH = ROOT / "artifacts" / "pixellab-generation-results.json"


def palette_image_base64(colors: list[str]) -> str:
    image = Image.new("RGB", (len(colors), 1))
    image.putdata([tuple(bytes.fromhex(color.removeprefix("#"))) for color in colors])
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return base64.b64encode(buffer.getvalue()).decode("ascii")


def decode_image(value: str) -> bytes:
    encoded = value.split(",", 1)[1] if value.startswith("data:") else value
    return base64.b64decode(encoded, validate=True)


def generate(endpoint: str, token: str, payload: dict) -> dict:
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"PixelLab returned HTTP {error.code}: {detail}") from error


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", action="append", dest="ids", help="Generate only this asset ID; repeatable")
    parser.add_argument("--resume", action="store_true", help="Reuse PixelLab originals already recorded in the result file")
    args = parser.parse_args()

    token = os.environ.get("PIXELLAB_API_KEY") or os.environ.get("PIXELLAB_TOKEN")
    if not token:
        print("Set PIXELLAB_API_KEY or PIXELLAB_TOKEN in the local shell; do not store it in the project.", file=sys.stderr)
        return 2

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    requested = set(args.ids or [])
    assets = [asset for asset in manifest["assets"] if not requested or asset["id"] in requested]
    unknown = requested - {asset["id"] for asset in manifest["assets"]}
    if unknown:
        print(f"Unknown asset IDs: {', '.join(sorted(unknown))}", file=sys.stderr)
        return 2

    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    palette = palette_image_base64(manifest["forced_palette"])
    previous = {}
    if RESULT_PATH.exists():
        previous = {item["id"]: item for item in json.loads(RESULT_PATH.read_text(encoding="utf-8"))["results"]}
    selected_ids = {asset["id"] for asset in assets}
    results = [item for item_id, item in previous.items() if item_id not in selected_ids]
    for asset in assets:
        description = f'{manifest["common_prompt"]} {asset["prompt"]}'
        request_size = asset.get("request_size", asset["size"])
        payload = {
            "description": description,
            "image_size": {"width": request_size[0], "height": request_size[1]},
            "text_guidance_scale": 8,
            "isometric": asset["isometric"],
            "no_background": asset["no_background"],
            "color_image": {"type": "base64", "base64": palette},
            "seed": asset["seed"],
        }
        if asset.get("init_image"):
            init_path = ROOT / asset["init_image"]
            payload["init_image"] = {
                "type": "base64",
                "base64": base64.b64encode(init_path.read_bytes()).decode("ascii"),
            }
            payload["init_image_strength"] = asset.get("init_image_strength", 750)
        source_path = SOURCE_DIR / f'{asset["id"]}.png'
        target = ROOT / asset["path"]
        if args.resume and source_path.exists() and target.exists():
            if asset["id"] in previous:
                results.append(previous[asset["id"]])
            else:
                results.append({
                    "id": asset["id"], "path": asset["path"],
                    "source": str(source_path.relative_to(ROOT)),
                    "description": description, "request": payload,
                    "usage": None, "recovered_from_completed_file": True,
                    "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
                    "final_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                })
            print(f'Reused {asset["id"]} from the existing PixelLab result')
            continue
        response = generate(manifest["endpoint"], token, payload)
        raw = decode_image(response["image"]["base64"])
        if source_path.exists():
            version = 1
            while (SOURCE_DIR / f'{asset["id"]}-v{version}.png').exists():
                version += 1
            source_path.replace(SOURCE_DIR / f'{asset["id"]}-v{version}.png')
        source_path.write_bytes(raw)

        with Image.open(io.BytesIO(raw)) as image:
            image.load()
            expected = tuple(request_size)
            if image.size != expected:
                raise RuntimeError(f'{asset["id"]}: expected {expected}, received {image.size}')
            final = image.convert("RGBA")
            if request_size != asset["size"]:
                left = (request_size[0] - asset["size"][0]) // 2
                top = (request_size[1] - asset["size"][1]) // 2
                final = final.crop((left, top, left + asset["size"][0], top + asset["size"][1]))
            if asset["id"] == "VIS-101":
                final = ImageOps.expand(final, border=(0, 5, 0, 5), fill=final.getpixel((0, 0)))
            target.parent.mkdir(parents=True, exist_ok=True)
            final.save(target, format="PNG", optimize=False)

        results.append({
            "id": asset["id"],
            "path": asset["path"],
            "source": str(source_path.relative_to(ROOT)),
            "description": description,
            "request": payload,
            "usage": response.get("usage"),
            "source_sha256": hashlib.sha256(raw).hexdigest(),
            "final_sha256": hashlib.sha256((ROOT / asset["path"]).read_bytes()).hexdigest(),
        })
        print(f'Generated {asset["id"]} -> {asset["path"]}')
        order = {item["id"]: index for index, item in enumerate(manifest["assets"])}
        results.sort(key=lambda item: order[item["id"]])
        RESULT_PATH.write_text(json.dumps({"generated_at_unix": time.time(), "results": results}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    order = {item["id"]: index for index, item in enumerate(manifest["assets"])}
    results.sort(key=lambda item: order[item["id"]])
    RESULT_PATH.write_text(json.dumps({"generated_at_unix": time.time(), "results": results}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {RESULT_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
