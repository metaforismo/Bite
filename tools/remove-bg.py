#!/usr/bin/env python3
"""
Remove the near-white background from a folder of PNGs and write the
transparent results into a sibling directory.

Usage:
    python3 tools/remove-bg.py <input_dir> <output_dir>

Files in `KEEP_BACKGROUND` are skipped (copied as-is may be desired,
but for now we just don't process them — the import script in C2
references the source files directly).

Tunable: `THRESHOLD` (default 240). Pixels with R, G, B all >= threshold
are flagged as background and have their alpha set to 0. Drop the value
if some icons have soft white shadows that get over-clipped.
"""
import os
import sys
from PIL import Image

KEEP_BACKGROUND = {"trackingcharts.png", "allergieshield.png"}
THRESHOLD = 240


def remove_white_bg(path: str) -> Image.Image:
    img = Image.open(path).convert("RGBA")
    new_data = []
    for r, g, b, a in img.getdata():
        if r >= THRESHOLD and g >= THRESHOLD and b >= THRESHOLD:
            new_data.append((r, g, b, 0))
        else:
            new_data.append((r, g, b, a))
    img.putdata(new_data)
    return img


def main(src: str, dst: str) -> None:
    os.makedirs(dst, exist_ok=True)
    for name in sorted(os.listdir(src)):
        if not name.endswith(".png"):
            continue
        if name in KEEP_BACKGROUND:
            print(f"skip (kept): {name}")
            continue
        out = remove_white_bg(os.path.join(src, name))
        out.save(os.path.join(dst, name))
        print(f"ok: {name}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
