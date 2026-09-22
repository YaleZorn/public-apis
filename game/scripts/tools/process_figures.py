#!/usr/bin/env python3
"""Chroma-key figure sprites + normalize lobby portraits for Kongfu v0.9.5."""
from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

SRC = Path("/opt/cursor/artifacts/assets")
FIG_OUT = Path("/workspace/game/assets/textures/figures")
PORT_OUT = Path("/workspace/game/assets/textures/portraits")

FIG_MAP = {
    "fig-qinggong.png": "unit_qinggong.png",
    "fig-feidao.png": "unit_feidao.png",
    "fig-mulan.png": "unit_mulan.png",
    "fig-tiebi.png": "unit_tiebi.png",
    "fig-yishi.png": "unit_yishi.png",
    "fig-zhaoyun.png": "unit_zhaoyun.png",
    "fig-mingwang.png": "unit_mingwang.png",
    "fig-linchong.png": "unit_linchong.png",
    "fig-bandit.png": "enemy_bandit.png",
    "fig-runner.png": "enemy_runner.png",
    "fig-shield.png": "enemy_shield.png",
}

PORT_MAP = {
    "port-qinggong.png": "unit_qinggong.png",
    "port-mulan.png": "unit_mulan.png",
    "port-feidao.png": "unit_feidao.png",
}


def chroma_key(im: Image.Image, key=(10, 18, 16), tol=48, soft=22) -> Image.Image:
    """Remove near-key dark teal bg → RGBA with soft edge."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    kr, kg, kb = key
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            dist = abs(r - kr) + abs(g - kg) + abs(b - kb)
            # Also treat very dark near-black corners as bg
            lum = (r + g + b) / 3.0
            dark = lum < 28 and max(abs(r - g), abs(g - b), abs(r - b)) < 18
            if dark:
                dist = min(dist, 20)
            if dist <= tol:
                px[x, y] = (r, g, b, 0)
            elif dist < tol + soft:
                fade = int(255 * (dist - tol) / soft)
                px[x, y] = (r, g, b, min(a, fade))
    return im


def trim_alpha(im: Image.Image, pad: int = 6) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(im.width, r + pad)
    b = min(im.height, b + pad)
    return im.crop((l, t, r, b))


def fit_canvas(im: Image.Image, size=(192, 256)) -> Image.Image:
    """Fit figure onto transparent canvas, feet near bottom."""
    tw, th = size
    im = im.copy()
    im.thumbnail((tw - 8, th - 8), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (tw - im.width) // 2
    y = th - im.height - 4
    canvas.paste(im, (x, y), im)
    return canvas


def process_figures() -> None:
    FIG_OUT.mkdir(parents=True, exist_ok=True)
    for src_name, dst_name in FIG_MAP.items():
        src = SRC / src_name
        if not src.exists():
            print("MISSING", src)
            continue
        im = Image.open(src)
        keyed = chroma_key(im)
        keyed = trim_alpha(keyed, pad=8)
        # Soft fringe cleanup
        keyed = keyed.filter(ImageFilter.SMOOTH_MORE)
        out = fit_canvas(keyed, (192, 256))
        out_path = FIG_OUT / dst_name
        out.save(out_path, "PNG")
        print("figure", out_path, out.size)


def process_portraits() -> None:
    for src_name, dst_name in PORT_MAP.items():
        src = SRC / src_name
        if not src.exists():
            print("MISSING port", src)
            continue
        im = Image.open(src).convert("RGB")
        # Normalize to 240x288 ship size
        im = im.resize((240, 288), Image.Resampling.LANCZOS)
        im = ImageEnhance.Contrast(im).enhance(1.06)
        im = ImageEnhance.Color(im).enhance(1.05)
        im = ImageEnhance.Brightness(im).enhance(1.02)
        out = PORT_OUT / dst_name
        im.save(out, "PNG", optimize=True)
        print("portrait", out, im.size)


if __name__ == "__main__":
    process_figures()
    process_portraits()
    print("PROCESS_OK")
