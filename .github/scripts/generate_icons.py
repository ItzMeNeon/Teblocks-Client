#!/usr/bin/env python3
"""
generate_icons.py
Automatically generates all required platform icons (Android, Windows, Linux, runtime)
from a single base icon (e.g. icon.png, logo.png, or media/image/icon.png).
"""

import os
import sys
from pathlib import Path
from PIL import Image

def find_source_icon(project_root: Path) -> Path | None:
    candidates = [
        project_root / "icon.png",
        project_root / "logo.png",
        project_root / "icon_512.png",
        project_root / "media" / "image" / "icon.png",
        project_root / ".github" / "build" / "linux" / "release" / "icon.png",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None

def generate_all(source_path: Path, project_root: Path):
    print(f"=== Generating icons from source: {source_path} ===")
    src_img = Image.open(source_path).convert("RGBA")
    w, h = src_img.size
    print(f"Source image dimensions: {w}x{h}")

    # 1. Runtime In-Game Icon (media/image/icon.png)
    runtime_path = project_root / "media" / "image" / "icon.png"
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_img = src_img.resize((256, 256), Image.Resampling.LANCZOS)
    runtime_img.save(runtime_path, "PNG")
    print(f"Generated runtime icon: {runtime_path} (256x256)")

    # 2. Linux AppImage Icon (.github/build/linux/release/icon.png)
    linux_icon_path = project_root / ".github" / "build" / "linux" / "release" / "icon.png"
    linux_icon_path.parent.mkdir(parents=True, exist_ok=True)
    linux_img = src_img.resize((256, 256), Image.Resampling.LANCZOS)
    linux_img.save(linux_icon_path, "PNG")
    print(f"Generated Linux AppImage icon: {linux_icon_path} (256x256)")

    # 3. Windows Multi-Resolution ICO (.github/build/windows/release/icon.ico)
    win_ico_path = project_root / ".github" / "build" / "windows" / "release" / "icon.ico"
    win_ico_path.parent.mkdir(parents=True, exist_ok=True)
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    src_img.save(win_ico_path, format="ICO", sizes=ico_sizes)
    print(f"Generated Windows .ico: {win_ico_path} with sizes {ico_sizes}")

    # 4. Android Icons (.github/build/android/release/res/...)
    android_res = project_root / ".github" / "build" / "android" / "release" / "res"
    android_res.mkdir(parents=True, exist_ok=True)

    # 4a. Play Store Icon (512x512)
    playstore_path = android_res / "icon-playstore.png"
    src_img.resize((512, 512), Image.Resampling.LANCZOS).save(playstore_path, "PNG")
    print(f"Generated Android Play Store icon: {playstore_path} (512x512)")

    # 4b. Standard mipmaps (legacy icon.png and icon_round.png)
    standard_densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, size in standard_densities.items():
        dir_path = android_res / folder
        dir_path.mkdir(parents=True, exist_ok=True)
        scaled = src_img.resize((size, size), Image.Resampling.LANCZOS)
        scaled.save(dir_path / "icon.png", "PNG")
        scaled.save(dir_path / "icon_round.png", "PNG")
        print(f"Generated Android {folder}/icon.png & icon_round.png ({size}x{size})")

    # 4c. Adaptive Icons (icon_foreground.png & icon_background.png)
    # Adaptive icons total size is 108dp canvas, with safe icon centered in inner 66dp (~61% scale)
    adaptive_densities = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }

    # Detect background color from edge of source image (ignoring transparent corners)
    # Default to modern dark theme if fully transparent
    bg_color = (28, 28, 30, 255)
    for sample_coord in [(w // 2, 10), (10, h // 2), (w - 10, h // 2), (w // 2, h - 10)]:
        px = src_img.getpixel(sample_coord)
        if px[3] > 100:
            # Found non-transparent background color in the logo
            bg_color = (px[0], px[1], px[2], 255)
            break
    print(f"Detected adaptive background color: {bg_color}")

    for folder, total_size in adaptive_densities.items():
        dir_path = android_res / folder
        dir_path.mkdir(parents=True, exist_ok=True)

        # Background
        bg_img = Image.new("RGBA", (total_size, total_size), bg_color)
        bg_img.save(dir_path / "icon_background.png", "PNG")

        # Foreground: scale source down to safe viewport (approx 66/108 = 61% of canvas) and center it
        safe_size = int(total_size * 0.61)
        fg_scaled = src_img.resize((safe_size, safe_size), Image.Resampling.LANCZOS)

        fg_canvas = Image.new("RGBA", (total_size, total_size), (0, 0, 0, 0))
        offset = ((total_size - safe_size) // 2, (total_size - safe_size) // 2)
        fg_canvas.paste(fg_scaled, offset, fg_scaled)
        fg_canvas.save(dir_path / "icon_foreground.png", "PNG")

        print(f"Generated Android {folder}/icon_foreground.png & icon_background.png ({total_size}x{total_size})")

    # Ensure XML files for adaptive icons exist
    anydpi_dir = android_res / "mipmap-anydpi-v26"
    anydpi_dir.mkdir(parents=True, exist_ok=True)
    xml_content = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/icon_background"/>
    <foreground android:drawable="@mipmap/icon_foreground"/>
</adaptive-icon>
"""
    (anydpi_dir / "icon.xml").write_text(xml_content, encoding="utf-8")
    (anydpi_dir / "icon_round.xml").write_text(xml_content, encoding="utf-8")
    print(f"Verified adaptive icon XMLs in {anydpi_dir}")

    print("=== Icon generation complete! ===")

if __name__ == "__main__":
    proj_dir = Path(__file__).resolve().parent.parent.parent
    src = None

    if len(sys.argv) > 1:
        arg1 = Path(sys.argv[1]).resolve()
        if arg1.is_file():
            src = arg1
            # If source is inside a project, detect that project root
            if (arg1.parent / ".github").is_dir():
                proj_dir = arg1.parent
        elif arg1.is_dir():
            proj_dir = arg1

    if len(sys.argv) > 2:
        arg2 = Path(sys.argv[2]).resolve()
        if arg2.is_dir():
            proj_dir = arg2

    if not src:
        src = find_source_icon(proj_dir)

    if not src:
        print(f"No source icon found in {proj_dir} (searched icon.png, logo.png, icon_512.png). Skipping generation.")
        sys.exit(0)

    generate_all(src, proj_dir)
