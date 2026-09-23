#!/usr/bin/env python3
"""v0.10.1 VFX polish: ink-wash aura, longer slash energy, soft-edge reveal wipe frames."""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

FIG = Path("/workspace/game/assets/textures/figures")
VFX = Path("/workspace/game/assets/textures/vfx")
FW, FH = 192, 256

REVEAL_IDS = [
    "unit_qinggong",
    "unit_mulan",
    "unit_feidao",
    "unit_tiebi",
    "unit_yishi",
    "unit_zhaoyun",
    "unit_linchong",
    "unit_mingwang",
]
STRONG = {"unit_qinggong", "unit_mulan", "unit_feidao"}


def write_import_stub(png: Path) -> None:
    rel = str(png).replace("/workspace/game/", "res://")
    dest = png.with_suffix(png.suffix + ".import")
    h = abs(hash(rel)) % (16**10)
    uid = f"uid://v101{h:010x}"[:20]
    dest.write_text(
        f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="res://.godot/imported/{png.name}-{h:032x}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{rel}"
dest_files=["res://.godot/imported/{png.name}-{h:032x}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
    )


def soft_edge_reveal(uid: str) -> None:
    """Strip thick sticker rim; keep a hairline ink edge + soft halo."""
    path = FIG / f"{uid}_reveal.png"
    if not path.exists():
        print("MISSING reveal", uid)
        return
    im = Image.open(path).convert("RGBA")
    # Rebuild from alpha: drop previous bright rim by eroding bright edge noise lightly.
    r, g, b, a = im.split()
    # Detect near-white / neon rim pixels hugging the silhouette and mute them.
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            rr, gg, bb, aa = px[x, y]
            if aa < 8:
                continue
            lum = (rr + gg + bb) / 3.0
            # Thick sticker rims from v0.10 were warm peach / cyan highlights on edge.
            if lum > 200 and min(rr, gg, bb) > 170:
                # Pull toward local body tone by dimming highlight
                px[x, y] = (
                    int(rr * 0.82 + 40),
                    int(gg * 0.82 + 35),
                    int(bb * 0.82 + 30),
                    aa,
                )
    alpha = im.split()[-1]
    # Soft hairline: thin edge, low strength (not MaxFilter sticker).
    edge = alpha.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(0.6))
    edge = ImageEnhance.Brightness(edge).enhance(0.55)
    rim_col = (255, 220, 200) if uid in STRONG else (190, 220, 210)
    rim = Image.new("RGBA", im.size, (*rim_col, 0))
    rim.putalpha(edge.point(lambda v: min(110, int(v * 0.35))))
    # Soft outer haze (illustrated, not outline)
    haze = alpha.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(2.2))
    haze_layer = Image.new("RGBA", im.size, (90, 154, 144, 0))
    haze_layer.putalpha(haze.point(lambda v: min(55, int(v * 0.18))))
    out = Image.alpha_composite(Image.alpha_composite(im, haze_layer), rim)
    # Mild contrast for figure readability on mist grounds
    rr, gg, bb, aa = out.split()
    rgb = ImageEnhance.Contrast(Image.merge("RGB", (rr, gg, bb))).enhance(1.06)
    rgb = ImageEnhance.Color(rgb).enhance(1.04)
    r2, g2, b2 = rgb.split()
    out = Image.merge("RGBA", (r2, g2, b2, aa))
    out.save(path)
    print("soft_reveal", uid)

    # Mid wipe frame: 55% reveal over base — used for multi-frame transition.
    base_path = FIG / f"{uid}.png"
    if base_path.exists():
        base = Image.open(base_path).convert("RGBA").resize((FW, FH), Image.Resampling.LANCZOS)
        rev = out.copy()
        # Vertical wipe mask (torn cloth feel)
        mask = Image.new("L", (FW, FH), 0)
        md = ImageDraw.Draw(mask)
        for y in range(FH):
            # Irregular tear front around mid torso
            wave = int(8 * math.sin(y * 0.11) + 5 * math.sin(y * 0.27 + 1.2))
            cut = int(FH * 0.28 + (y / FH) * FH * 0.55) + wave
            # Actually horizontal progress by y bands
            progress = 0.35 + 0.45 * (y / FH)
            for x in range(FW):
                jagged = int(6 * math.sin(x * 0.19 + y * 0.07))
                thresh = int(FW * progress) + jagged
                if x < thresh:
                    mask.putpixel((x, y), 210)
        mask = mask.filter(ImageFilter.GaussianBlur(1.4))
        mid = Image.composite(rev, base, mask)
        mid_path = FIG / f"{uid}_reveal_mid.png"
        mid.save(mid_path)
        write_import_stub(mid_path)
        print("reveal_mid", mid_path.name)


def bake_ink_wisp() -> None:
    """Brush-like ink wisp — not a geometric ring."""
    size = 256
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rng = random.Random(101)
    for _ in range(7):
        layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        # S-curve stroke as polyline with varying width
        points = []
        cx0 = 40 + rng.randint(0, 40)
        cy0 = 30 + rng.randint(0, 50)
        for t in range(18):
            tt = t / 17.0
            x = cx0 + tt * 160 + 18 * math.sin(tt * 4.2 + rng.random())
            y = cy0 + tt * 170 + 22 * math.sin(tt * 3.1 + 0.8)
            points.append((x, y))
        col = (90, 154, 144, 40 + rng.randint(0, 50)) if rng.random() < 0.7 else (230, 193, 90, 35 + rng.randint(0, 40))
        for i in range(len(points) - 1):
            w = max(2, int(14 * (1.0 - abs(i / 17.0 - 0.45)) + rng.randint(0, 3)))
            d.line([points[i], points[i + 1]], fill=col, width=w)
        layer = layer.filter(ImageFilter.GaussianBlur(2.8 + rng.random() * 1.5))
        im = Image.alpha_composite(im, layer)
    # Soft particle dust
    dust = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dust)
    for _ in range(60):
        x, y = rng.randint(20, 236), rng.randint(20, 236)
        r = rng.randint(1, 3)
        dd.ellipse((x - r, y - r, x + r, y + r), fill=(200, 230, 215, rng.randint(40, 120)))
    dust = dust.filter(ImageFilter.GaussianBlur(0.7))
    im = Image.alpha_composite(im, dust)
    out = VFX / "aura_ink_wisp.png"
    im.save(out)
    write_import_stub(out)
    print("vfx", out.name)


def bake_ink_wash() -> None:
    """Asymmetric ink wash puddle for underfoot / torso — replaces concentric rings."""
    size = 256
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Irregular blotches, not a circle
    blobs = [
        (128, 140, 110, 55, (90, 154, 144, 70)),
        (100, 150, 70, 40, (106, 168, 154, 55)),
        (160, 145, 75, 38, (230, 193, 90, 40)),
        (120, 120, 50, 30, (200, 230, 215, 50)),
        (148, 165, 60, 28, (90, 140, 130, 45)),
    ]
    for cx, cy, rx, ry, col in blobs:
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=col)
    im = im.filter(ImageFilter.GaussianBlur(8))
    # Calligraphy speckles
    rng = random.Random(7)
    speck = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(speck)
    for _ in range(35):
        x = rng.randint(40, 220)
        y = rng.randint(80, 200)
        r = rng.randint(1, 4)
        sd.ellipse((x - r, y - r, x + r, y + r), fill=(210, 235, 220, rng.randint(50, 140)))
    speck = speck.filter(ImageFilter.GaussianBlur(0.8))
    im = Image.alpha_composite(im, speck)
    out = VFX / "aura_ink_wash.png"
    im.save(out)
    write_import_stub(out)
    print("vfx", out.name)


def bake_slash_long() -> None:
    """Longer, softer energy trail with afterglow core."""
    size = (320, 96)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Main crescent ribbon
    for i, a in enumerate([30, 70, 130, 200, 150, 80, 35]):
        y0 = 18 + i * 8
        d.arc((8, y0 - 48, 312, y0 + 48), 195, 345, fill=(106, 200, 180, a), width=7 - i // 2)
    # Hot core streak
    for i, a in enumerate([0, 90, 180, 90, 0]):
        if a == 0:
            continue
        y0 = 36 + i * 6
        d.arc((40, y0 - 30, 280, y0 + 30), 205, 335, fill=(255, 240, 200, a), width=3)
    # Trailing spark dust
    rng = random.Random(19)
    for _ in range(40):
        t = rng.random()
        x = int(40 + t * 250)
        y = int(48 + 18 * math.sin(t * 3.2) + rng.uniform(-8, 8))
        r = rng.randint(1, 3)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(230, 220, 170, rng.randint(60, 160)))
    im = im.filter(ImageFilter.GaussianBlur(1.1))
    out = VFX / "slash_trail_long.png"
    im.save(out)
    write_import_stub(out)
    print("vfx", out.name)


def bake_cloth_scrap() -> None:
    """Soft fabric scrap for burst — no hard diamond geometry."""
    size = 48
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(8, 10), (36, 6), (42, 28), (22, 44), (4, 30)], fill=(230, 205, 185, 200))
    d.polygon([(14, 14), (30, 12), (28, 26), (12, 28)], fill=(255, 235, 220, 120))
    im = im.filter(ImageFilter.GaussianBlur(0.9))
    out = VFX / "cloth_scrap.png"
    im.save(out)
    write_import_stub(out)
    print("vfx", out.name)


def refresh_soft_ring() -> None:
    """Keep a faint broken ring as secondary layer — break continuity so it reads less geometric."""
    size = 256
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = cy = 128
    rng = random.Random(33)
    for seg in range(16):
        if rng.random() < 0.28:
            continue  # gaps → ink broken arc, not full circle
        a0 = seg * 22.5 + rng.uniform(-4, 4)
        a1 = a0 + 16 + rng.uniform(0, 6)
        rad = 92 + rng.randint(-6, 6)
        col = (106, 168, 154, 55 + rng.randint(0, 30))
        d.arc((cx - rad, cy - rad, cx + rad, cy + rad), a0, a1, fill=col, width=rng.randint(3, 6))
    im = im.filter(ImageFilter.GaussianBlur(2.4))
    out = VFX / "aura_ring_soft.png"
    im.save(out)
    write_import_stub(out)
    print("vfx refreshed", out.name)


def main() -> None:
    VFX.mkdir(parents=True, exist_ok=True)
    for uid in REVEAL_IDS:
        soft_edge_reveal(uid)
        write_import_stub(FIG / f"{uid}_reveal.png")
    bake_ink_wisp()
    bake_ink_wash()
    bake_slash_long()
    bake_cloth_scrap()
    refresh_soft_ring()
    print("process_v0101 done")


if __name__ == "__main__":
    main()
