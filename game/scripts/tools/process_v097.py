#!/usr/bin/env python3
"""v0.9.7: process pushed art + build walk/attack SpriteFrame sheets."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageOps

SRC = Path("/opt/cursor/artifacts/assets")
FIG_OUT = Path("/workspace/game/assets/textures/figures")
PORT_OUT = Path("/workspace/game/assets/textures/portraits")
SHEET_OUT = Path("/workspace/game/assets/textures/figures/sheets")

FIG_SRC = {
    "figure_qinggong_v097.png": "unit_qinggong.png",
    "figure_feidao_v097.png": "unit_feidao.png",
    "figure_tiebi_v097.png": "unit_tiebi.png",
    "figure_yishi_v097.png": "unit_yishi.png",
    "figure_zhaoyun_v097.png": "unit_zhaoyun.png",
    "figure_linchong_v097.png": "unit_linchong.png",
    "figure_mingwang_v097.png": "unit_mingwang.png",
    "figure_bandit_v097.png": "enemy_bandit.png",
    "figure_shield_v097.png": "enemy_shield.png",
    "figure_runner_v097.png": "enemy_runner.png",
}

PORT_SRC = {
    "portrait_qinggong_v097.png": "unit_qinggong.png",
    "portrait_bandit_v097.png": "enemy_bandit.png",
    "portrait_shield_v097.png": "enemy_shield.png",
    "portrait_runner_v097.png": "enemy_runner.png",
}

# Existing figures kept but brightened for TD fog (mulan already readable).
BRIGHTEN_EXISTING = ["unit_mulan.png"]

MALE_IDS = {
    "unit_feidao",
    "unit_tiebi",
    "unit_yishi",
    "unit_zhaoyun",
    "unit_linchong",
    "unit_mingwang",
    "enemy_bandit",
    "enemy_shield",
    "enemy_runner",
}

ALL_FIGURE_IDS = [
    "unit_qinggong",
    "unit_mulan",
    "unit_feidao",
    "unit_tiebi",
    "unit_yishi",
    "unit_zhaoyun",
    "unit_linchong",
    "unit_mingwang",
    "enemy_bandit",
    "enemy_shield",
    "enemy_runner",
]


def chroma_key(im: Image.Image, key=(8, 10, 10), tol=42, soft=24) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    kr, kg, kb = key
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            dist = abs(r - kr) + abs(g - kg) + abs(b - kb)
            lum = (r + g + b) / 3.0
            dark = lum < 26 and max(abs(r - g), abs(g - b), abs(r - b)) < 16
            if dark:
                dist = min(dist, 18)
            if dist <= tol:
                px[x, y] = (r, g, b, 0)
            elif dist < tol + soft:
                fade = int(255 * (dist - tol) / soft)
                px[x, y] = (r, g, b, min(a, fade))
    return im


def trim_alpha(im: Image.Image, pad: int = 8) -> Image.Image:
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
    tw, th = size
    im = im.copy()
    im.thumbnail((tw - 8, th - 8), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (tw - im.width) // 2
    y = th - im.height - 4
    canvas.paste(im, (x, y), im)
    return canvas


def add_rim(im: Image.Image, strength: float = 0.55, color=(180, 230, 220)) -> Image.Image:
    """Bright cyan rim from alpha edge — TD fog readability."""
    im = im.convert("RGBA")
    alpha = im.split()[-1]
    edge = alpha.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(3))
    edge = ImageEnhance.Brightness(edge).enhance(1.4)
    rim = Image.new("RGBA", im.size, (*color, 0))
    rim.putalpha(edge.point(lambda v: min(255, int(v * strength))))
    return Image.alpha_composite(im, rim)


def lift_male(im: Image.Image) -> Image.Image:
    rgb = im.convert("RGBA")
    r, g, b, a = rgb.split()
    rgb_only = Image.merge("RGB", (r, g, b))
    rgb_only = ImageEnhance.Brightness(rgb_only).enhance(1.12)
    rgb_only = ImageEnhance.Contrast(rgb_only).enhance(1.08)
    rgb_only = ImageEnhance.Color(rgb_only).enhance(1.05)
    r2, g2, b2 = rgb_only.split()
    out = Image.merge("RGBA", (r2, g2, b2, a))
    return add_rim(out, strength=0.65, color=(190, 235, 225))


def process_figure(src: Path, dst: Path, male: bool) -> None:
    im = Image.open(src)
    keyed = chroma_key(im)
    keyed = trim_alpha(keyed, pad=8)
    keyed = keyed.filter(ImageFilter.SMOOTH)
    out = fit_canvas(keyed, (192, 256))
    if male:
        out = lift_male(out)
    else:
        out = add_rim(out, strength=0.35, color=(200, 230, 210))
        out = ImageEnhance.Brightness(out).enhance(1.04)
    out.save(dst, "PNG")
    print("figure", dst.name, out.size)


def process_portrait(src: Path, dst: Path) -> None:
    im = Image.open(src).convert("RGB")
    # Cover-fit 240x288
    tw, th = 240, 288
    scale = max(tw / im.width, th / im.height)
    nw, nh = int(im.width * scale), int(im.height * scale)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = max(0, (nh - th) // 5)  # bias upward for face
    im = im.crop((left, top, left + tw, top + th))
    im = ImageEnhance.Contrast(im).enhance(1.06)
    im = ImageEnhance.Color(im).enhance(1.05)
    im = ImageEnhance.Brightness(im).enhance(1.03)
    im.save(dst, "PNG", optimize=True)
    print("portrait", dst.name, im.size)


def _warp_walk_frame(base: Image.Image, phase: float) -> Image.Image:
    """Procedural walk: lean + lower-body shear + squash (4-phase cycle)."""
    w, h = base.size
    # Stronger amplitudes so frames read as real walk, not micro-bob.
    lean = math.sin(phase * math.tau) * 0.12
    squash = 1.0 + math.sin(phase * math.tau * 2) * 0.08
    shear = math.sin(phase * math.tau) * 22.0
    bounce = abs(math.sin(phase * math.tau)) * 6.0

    nh = max(8, int(h * squash))
    scaled = base.resize((w, nh), Image.Resampling.BILINEAR)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    y_off = h - nh - int(bounce)
    canvas.paste(scaled, (0, max(0, y_off)), scaled)

    px = canvas.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    split = int(h * 0.38)
    for y in range(h):
        t = 0.0 if y < split else (y - split) / max(1, h - split)
        # Opposite leg shift: alternate by phase half
        leg = math.sin(phase * math.tau + (0.0 if t < 0.5 else math.pi))
        dx = int(shear * t * t + leg * t * 8.0)
        dx += int(lean * (h - y) * 0.55)
        for x in range(w):
            sx = x - dx
            if 0 <= sx < w:
                opx[x, y] = px[sx, y]
    return out


def _warp_attack_frame(base: Image.Image, phase: float) -> Image.Image:
    """Attack: wind-up → strike → recover. phase 0..1."""
    w, h = base.size
    if phase < 0.35:
        lean = -0.16
        stretch_x, stretch_y = 0.9, 1.1
        shift = -14
    elif phase < 0.7:
        lean = 0.22
        stretch_x, stretch_y = 1.22, 0.84
        shift = 18
    else:
        lean = 0.06
        stretch_x, stretch_y = 1.04, 0.96
        shift = 4

    nw = max(8, int(w * stretch_x))
    nh = max(8, int(h * stretch_y))
    scaled = base.resize((nw, nh), Image.Resampling.BILINEAR)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x0 = (w - nw) // 2 + int(lean * 28) + shift
    y0 = h - nh
    canvas.paste(scaled, (x0, y0), scaled)

    angle = -lean * 36.0
    return canvas.rotate(
        angle, resample=Image.Resampling.BILINEAR, center=(w // 2, h - 4), fillcolor=(0, 0, 0, 0)
    )


def build_sheets(fig_id: str, base_path: Path) -> None:
    base = Image.open(base_path).convert("RGBA")
    # Walk: 4 frames
    walk_frames = [_warp_walk_frame(base, i / 4.0) for i in range(4)]
    walk = Image.new("RGBA", (192 * 4, 256), (0, 0, 0, 0))
    for i, fr in enumerate(walk_frames):
        walk.paste(fr, (i * 192, 0), fr)
    walk_path = SHEET_OUT / f"{fig_id}_walk.png"
    walk.save(walk_path, "PNG")
    # Attack: 3 frames
    attack_frames = [_warp_attack_frame(base, p) for p in (0.15, 0.5, 0.85)]
    atk = Image.new("RGBA", (192 * 3, 256), (0, 0, 0, 0))
    for i, fr in enumerate(attack_frames):
        atk.paste(fr, (i * 192, 0), fr)
    atk_path = SHEET_OUT / f"{fig_id}_attack.png"
    atk.save(atk_path, "PNG")
    print("sheets", walk_path.name, atk_path.name)


def brighten_existing(name: str) -> None:
    path = FIG_OUT / name
    if not path.exists():
        print("MISSING brighten", path)
        return
    im = Image.open(path).convert("RGBA")
    im = add_rim(im, strength=0.4, color=(200, 230, 215))
    im = ImageEnhance.Brightness(im).enhance(1.05)
    im.save(path, "PNG")
    print("brighten", name)


def main() -> None:
    FIG_OUT.mkdir(parents=True, exist_ok=True)
    PORT_OUT.mkdir(parents=True, exist_ok=True)
    SHEET_OUT.mkdir(parents=True, exist_ok=True)

    for src_name, dst_name in FIG_SRC.items():
        src = SRC / src_name
        if not src.exists():
            print("MISSING", src)
            continue
        uid = dst_name.replace(".png", "")
        process_figure(src, FIG_OUT / dst_name, male=uid in MALE_IDS)

    for src_name, dst_name in PORT_SRC.items():
        src = SRC / src_name
        if not src.exists():
            print("MISSING port", src)
            continue
        process_portrait(src, PORT_OUT / dst_name)

    for name in BRIGHTEN_EXISTING:
        brighten_existing(name)

    for fig_id in ALL_FIGURE_IDS:
        base = FIG_OUT / f"{fig_id}.png"
        if not base.exists():
            print("MISSING sheet base", base)
            continue
        build_sheets(fig_id, base)

    print("PROCESS_V097_OK")


if __name__ == "__main__":
    main()
