#!/usr/bin/env python3
"""v0.9.9: state-VFX reveal stills (爆衣/costume-damage) + light limb gait polish."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

FIG_OUT = Path("/workspace/game/assets/textures/figures")
SHEET_OUT = Path("/workspace/game/assets/textures/figures/sheets")

# Female / high-charm figures get stronger costume-damage reveal.
REVEAL_STRONG = {"unit_qinggong", "unit_mulan"}
REVEAL_MILD = {
    "unit_feidao",
    "unit_tiebi",
    "unit_yishi",
    "unit_zhaoyun",
    "unit_linchong",
    "unit_mingwang",
}

# Easy limb win: re-bake one more walk sheet with clearer arm swing.
LIMB_WALK_IDS = ["unit_qinggong", "unit_mulan"]

FW, FH = 192, 256


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def add_rim(im: Image.Image, strength: float = 0.55, color=(210, 245, 230)) -> Image.Image:
    alpha = im.split()[-1]
    edge = alpha.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(5))
    rim = Image.new("RGBA", im.size, (*color, 0))
    rim.putalpha(edge.point(lambda v: min(255, int(v * strength))))
    return Image.alpha_composite(im, rim)


def warm_skin_mid(im: Image.Image, strength: float) -> Image.Image:
    """Lift mid-torso toward warmer skin tones (tasteful 17+ costume damage)."""
    w, h = im.size
    px = im.load()
    y0, y1 = int(h * 0.28), int(h * 0.62)
    x0, x1 = int(w * 0.28), int(w * 0.72)
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            # Prefer fabric-ish midtones (not pure white highlights / deep shadow).
            lum = (r + g + b) / 3.0
            if lum < 55 or lum > 220:
                continue
            # Reduce clothing chroma toward warm peach.
            nr = int(min(255, r * (1.0 - 0.35 * strength) + 210 * 0.35 * strength))
            ng = int(min(255, g * (1.0 - 0.35 * strength) + 155 * 0.28 * strength))
            nb = int(min(255, b * (1.0 - 0.40 * strength) + 125 * 0.22 * strength))
            px[x, y] = (nr, ng, nb, a)
    return im


def tear_alpha(im: Image.Image, strength: float) -> Image.Image:
    """Diagonal fabric tears — alpha cuts + ragged edges (not genital focus)."""
    w, h = im.size
    mask = Image.new("L", (w, h), 255)
    draw = ImageDraw.Draw(mask)
    # Upper torso / sleeve tear bands only.
    bands = [
        (0.32, 0.38, 0.55, 0.48, 2.2 + strength),
        (0.45, 0.42, 0.68, 0.52, 1.8 + strength * 0.8),
        (0.38, 0.50, 0.58, 0.58, 1.6 + strength * 0.5),
    ]
    for x0r, y0r, x1r, y1r, thick in bands:
        pts = []
        steps = 12
        for i in range(steps + 1):
            t = i / steps
            x = w * (x0r + (x1r - x0r) * t)
            y = h * (y0r + (y1r - y0r) * t)
            jag = math.sin(t * 9.0) * (2.5 + strength * 2.0)
            pts.append((x + jag, y + jag * 0.4))
        draw.line(pts, fill=int(40 + 80 * (1.0 - strength)), width=max(2, int(thick)))
    # Soften tear edges.
    mask = mask.filter(ImageFilter.GaussianBlur(0.8))
    r, g, b, a = im.split()
    a = ImageChops_multiply(a, mask)
    return Image.merge("RGBA", (r, g, b, a))


def ImageChops_multiply(a: Image.Image, b: Image.Image) -> Image.Image:
    from PIL import ImageChops

    return ImageChops.multiply(a, b)


def fabric_scraps_overlay(im: Image.Image, strength: float) -> Image.Image:
    """Ink-mist scrap petals near tear — game VFX feel baked lightly into still."""
    overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    w, h = im.size
    scraps = [
        (0.42, 0.40, 4),
        (0.55, 0.44, 3),
        (0.48, 0.52, 3),
        (0.36, 0.46, 2),
        (0.60, 0.50, 2),
    ]
    for xr, yr, rad in scraps:
        col = (210, 230, 215, int(70 + 90 * strength))
        cx, cy = int(w * xr), int(h * yr)
        draw.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), fill=col)
    return Image.alpha_composite(im, overlay)


def make_reveal(src: Path, dst: Path, strong: bool) -> None:
    im = load_rgba(src)
    strength = 0.85 if strong else 0.45
    im = warm_skin_mid(im, strength)
    im = tear_alpha(im, strength)
    # Slight brighten + warmth
    r, g, b, a = im.split()
    rgb = Image.merge("RGB", (r, g, b))
    rgb = ImageEnhance.Brightness(rgb).enhance(1.06 if strong else 1.03)
    rgb = ImageEnhance.Color(rgb).enhance(1.08 if strong else 1.04)
    r2, g2, b2 = rgb.split()
    im = Image.merge("RGBA", (r2, g2, b2, a))
    im = fabric_scraps_overlay(im, strength)
    rim_c = (255, 210, 190) if strong else (205, 235, 220)
    im = add_rim(im, strength=0.65 if strong else 0.45, color=rim_c)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)
    print("reveal", dst.name, "strong" if strong else "mild")


def fit_canvas(im: Image.Image, size=(FW, FH)) -> Image.Image:
    tw, th = size
    im = im.copy()
    im.thumbnail((tw - 8, th - 8), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (tw - im.width) // 2
    y = th - im.height - 4
    canvas.paste(im, (x, y), im)
    return canvas


def limb_walk_sheet(uid: str) -> None:
    """Clearer arm/leg swing gait for female figures (easy limb win)."""
    src = FIG_OUT / f"{uid}.png"
    if not src.exists():
        return
    base = fit_canvas(load_rgba(src))
    frames = []
    for i in range(4):
        t = i / 4.0
        # Horizontal shear stronger on limbs (upper/lower thirds), mild torso.
        frame = base.copy()
        px = frame.load()
        w, h = frame.size
        phase = math.sin(t * math.pi * 2.0)
        for y in range(h):
            yn = y / h
            if yn < 0.35:
                amp = 3.2 * phase  # arm zone
            elif yn > 0.62:
                amp = -4.0 * phase  # leg zone opposite
            else:
                amp = 0.6 * phase
            shift = int(amp)
            if shift == 0:
                continue
            row = [px[x, y] for x in range(w)]
            for x in range(w):
                sx = x - shift
                if 0 <= sx < w:
                    px[x, y] = row[sx]
                else:
                    px[x, y] = (0, 0, 0, 0)
        # Soft Y bounce
        bounced = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        dy = int(round(math.sin(t * math.pi * 2.0) * 2.0))
        bounced.paste(frame, (0, dy), frame)
        frames.append(bounced)
    sheet = Image.new("RGBA", (FW * 4, FH), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * FW, 0), fr)
    out = SHEET_OUT / f"{uid}_walk.png"
    sheet.save(out)
    print("limb_walk", out.name)


def main() -> None:
    for uid in sorted(REVEAL_STRONG | REVEAL_MILD):
        src = FIG_OUT / f"{uid}.png"
        if not src.exists():
            print("skip missing", uid)
            continue
        make_reveal(src, FIG_OUT / f"{uid}_reveal.png", uid in REVEAL_STRONG)
    for uid in LIMB_WALK_IDS:
        limb_walk_sheet(uid)
    print("process_v099 done")


if __name__ == "__main__":
    main()
