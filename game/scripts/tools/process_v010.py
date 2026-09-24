#!/usr/bin/env python3
"""v0.10.0 quality rebuild: authored reveal figures + soft aura/slash VFX atlases."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ART = Path("/opt/cursor/artifacts/assets")
FIG_OUT = Path("/workspace/game/assets/textures/figures")
SHEET_OUT = Path("/workspace/game/assets/textures/figures/sheets")
VFX_OUT = Path("/workspace/game/assets/textures/vfx")

FW, FH = 192, 256

REVEAL_SRC = {
    "unit_qinggong": "reveal_qinggong_v010.png",
    "unit_mulan": "reveal_mulan_v010.png",
    "unit_feidao": "reveal_feidao_v010.png",
    "unit_tiebi": "reveal_tiebi_v010.png",
    "unit_yishi": "reveal_yishi_v010.png",
    "unit_zhaoyun": "reveal_zhaoyun_v010.png",
    "unit_linchong": "reveal_linchong_v010.png",
    "unit_mingwang": "reveal_mingwang_v010.png",
}

# Stronger rim for female / high-charm reveals.
STRONG_RIM = {"unit_qinggong", "unit_mulan"}
LIMB_WALK_IDS = ["unit_qinggong", "unit_mulan", "unit_feidao", "unit_zhaoyun"]


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def chroma_dark(im: Image.Image, tol: int = 28, soft: int = 36) -> Image.Image:
    """Knock out near-black studio backgrounds."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            lum = (r + g + b) / 3.0
            chroma = max(abs(r - g), abs(g - b), abs(r - b))
            if lum <= tol and chroma < 18:
                px[x, y] = (r, g, b, 0)
            elif lum < tol + soft and chroma < 28:
                fade = int(255 * (lum - tol) / soft)
                px[x, y] = (r, g, b, min(a, fade))
    return im


def chroma_light(im: Image.Image, tol: int = 240, soft: int = 20) -> Image.Image:
    """Knock out near-white studio backgrounds."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if min(r, g, b) >= tol:
                px[x, y] = (r, g, b, 0)
            elif min(r, g, b) > tol - soft:
                t = (min(r, g, b) - (tol - soft)) / soft
                px[x, y] = (r, g, b, min(a, int(255 * (1.0 - t))))
    return im


def auto_key(im: Image.Image) -> Image.Image:
    """Pick dark vs light key from corner samples."""
    im = im.convert("RGBA")
    w, h = im.size
    corners = [
        im.getpixel((2, 2))[:3],
        im.getpixel((w - 3, 2))[:3],
        im.getpixel((2, h - 3))[:3],
        im.getpixel((w - 3, h - 3))[:3],
    ]
    avg = sum(sum(c) for c in corners) / (3 * 4)
    if avg > 200:
        return chroma_light(im)
    return chroma_dark(im)


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


def fit_canvas(im: Image.Image, size=(FW, FH)) -> Image.Image:
    tw, th = size
    im = im.copy()
    im.thumbnail((tw - 10, th - 10), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (tw - im.width) // 2
    y = th - im.height - 4
    canvas.paste(im, (x, y), im)
    return canvas


def add_rim(im: Image.Image, strength: float = 0.7, color=(210, 245, 230)) -> Image.Image:
    alpha = im.split()[-1]
    edge = alpha.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(5))
    edge = ImageEnhance.Brightness(edge).enhance(1.4)
    rim = Image.new("RGBA", im.size, (*color, 0))
    rim.putalpha(edge.point(lambda v: min(255, int(v * strength))))
    return Image.alpha_composite(im, rim)


def tear_scraps_overlay(im: Image.Image, strong: bool) -> Image.Image:
    """Light ink-mist scrap accents near torso — readable as costume-change beat."""
    overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    w, h = im.size
    strength = 0.9 if strong else 0.55
    scraps = [
        (0.38, 0.36, 5, (230, 210, 190)),
        (0.58, 0.40, 4, (200, 230, 215)),
        (0.46, 0.48, 4, (235, 200, 180)),
        (0.34, 0.52, 3, (190, 220, 210)),
        (0.62, 0.54, 3, (220, 190, 170)),
        (0.50, 0.34, 3, (210, 235, 220)),
    ]
    for xr, yr, rad, col in scraps:
        cx, cy = int(w * xr), int(h * yr)
        a = int(90 + 80 * strength)
        draw.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), fill=(*col, a))
        # Tiny petal shard
        draw.polygon(
            [
                (cx + rad + 2, cy - 2),
                (cx + rad + 8, cy + 1),
                (cx + rad + 3, cy + 5),
            ],
            fill=(*col, int(a * 0.7)),
        )
    overlay = overlay.filter(ImageFilter.GaussianBlur(0.6))
    return Image.alpha_composite(im, overlay)


def process_reveal(uid: str, src_name: str) -> None:
    src = ART / src_name
    if not src.exists():
        print("MISSING", src)
        return
    im = auto_key(load_rgba(src))
    im = trim_alpha(im, pad=8)
    im = fit_canvas(im)
    strong = uid in STRONG_RIM
    # Mild brightness lift so reveal reads vs base under mist modulate.
    r, g, b, a = im.split()
    rgb = Image.merge("RGB", (r, g, b))
    rgb = ImageEnhance.Brightness(rgb).enhance(1.05 if strong else 1.03)
    rgb = ImageEnhance.Color(rgb).enhance(1.08 if strong else 1.04)
    r2, g2, b2 = rgb.split()
    im = Image.merge("RGBA", (r2, g2, b2, a))
    im = tear_scraps_overlay(im, strong)
    rim_c = (255, 215, 195) if strong else (205, 235, 220)
    im = add_rim(im, strength=0.72 if strong else 0.5, color=rim_c)
    out = FIG_OUT / f"{uid}_reveal.png"
    im.save(out)
    print("reveal", out.name, "strong" if strong else "mild", im.size)


def bake_aura_ring() -> None:
    """Soft layered ring — intentional ink-mist, not a flat ColorRect."""
    size = 256
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx = cy = size // 2
    # Outer soft wash
    for i, (rad, a, col) in enumerate(
        [
            (118, 28, (90, 154, 144)),
            (104, 48, (106, 168, 154)),
            (92, 70, (230, 193, 90)),
            (80, 55, (90, 154, 144)),
            (68, 35, (200, 230, 215)),
        ]
    ):
        bbox = (cx - rad, cy - rad, cx + rad, cy + rad)
        ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        rd = ImageDraw.Draw(ring)
        # Donut via outer fill then punch hole
        rd.ellipse(bbox, outline=(*col, a), width=max(3, 10 - i))
        ring = ring.filter(ImageFilter.GaussianBlur(3.5 if i < 2 else 2.0))
        im = Image.alpha_composite(im, ring)
    # Speckle particles on ring
    import random

    rng = random.Random(42)
    speck = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(speck)
    for _ in range(48):
        ang = rng.random() * math.tau
        rad = 78 + rng.random() * 30
        x = int(cx + math.cos(ang) * rad)
        y = int(cy + math.sin(ang) * rad)
        r = 1 + rng.randint(0, 2)
        col = (210, 235, 220, 110) if rng.random() < 0.6 else (230, 193, 90, 130)
        sd.ellipse((x - r, y - r, x + r, y + r), fill=col)
    speck = speck.filter(ImageFilter.GaussianBlur(0.6))
    im = Image.alpha_composite(im, speck)
    VFX_OUT.mkdir(parents=True, exist_ok=True)
    im.save(VFX_OUT / "aura_ring_soft.png")
    print("vfx aura_ring_soft.png")


def bake_aura_mist() -> None:
    """Soft oval mist disc under feet / around torso."""
    size = 128
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    for rad, a in [(58, 55), (42, 70), (28, 40)]:
        draw.ellipse(
            (64 - rad, 64 - int(rad * 0.55), 64 + rad, 64 + int(rad * 0.55)),
            fill=(90, 154, 144, a),
        )
    im = im.filter(ImageFilter.GaussianBlur(6))
    im.save(VFX_OUT / "aura_mist_disc.png")
    print("vfx aura_mist_disc.png")


def bake_particle_petal() -> None:
    size = 48
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    draw.polygon(
        [(24, 4), (40, 18), (26, 44), (8, 18)],
        fill=(200, 230, 215, 200),
    )
    draw.ellipse((18, 10, 30, 22), fill=(230, 193, 90, 160))
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    im.save(VFX_OUT / "mist_petal.png")
    print("vfx mist_petal.png")


def bake_slash_trail() -> None:
    """Process AI slash or bake procedural crescent."""
    src = ART / "vfx_slash_trail.png"
    size = (256, 128)
    if src.exists():
        im = auto_key(load_rgba(src))
        # Prefer bright energy pixels — boost alpha on luminous teal/gold.
        px = im.load()
        w, h = im.size
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                lum = (r + g + b) / 3.0
                if lum < 35:
                    px[x, y] = (r, g, b, 0)
                elif a > 0:
                    # Keep energetic greens/golds
                    boost = min(255, int(a * (0.7 + lum / 255.0)))
                    px[x, y] = (r, g, b, boost)
        im = trim_alpha(im, pad=4)
        im.thumbnail(size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        canvas.paste(im, ((size[0] - im.width) // 2, (size[1] - im.height) // 2), im)
        canvas = canvas.filter(ImageFilter.GaussianBlur(0.4))
        canvas.save(VFX_OUT / "slash_trail.png")
    else:
        im = Image.new("RGBA", size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(im)
        # Crescent slash
        for i, a in enumerate([40, 90, 160, 90, 40]):
            y0 = 20 + i * 14
            draw.arc((10, y0 - 40, 246, y0 + 40), 200, 340, fill=(106, 200, 180, a), width=6 - i // 2)
        im = im.filter(ImageFilter.GaussianBlur(1.2))
        im.save(VFX_OUT / "slash_trail.png")
    print("vfx slash_trail.png")


def bake_burst_flash() -> None:
    size = 128
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx = cy = 64
    for rad, col in [
        (58, (230, 193, 90, 50)),
        (42, (200, 230, 215, 90)),
        (28, (255, 240, 200, 140)),
        (14, (255, 255, 240, 200)),
    ]:
        draw.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), fill=col)
    # Radial spikes
    for i in range(8):
        ang = i * math.tau / 8
        x1 = cx + math.cos(ang) * 18
        y1 = cy + math.sin(ang) * 18
        x2 = cx + math.cos(ang) * 60
        y2 = cy + math.sin(ang) * 60
        draw.line([(x1, y1), (x2, y2)], fill=(230, 210, 160, 120), width=3)
    im = im.filter(ImageFilter.GaussianBlur(2.0))
    im.save(VFX_OUT / "burst_flash.png")
    print("vfx burst_flash.png")


def limb_walk_sheet(uid: str) -> None:
    """Clearer arm/leg swing — reduce morph-soup feel."""
    src = FIG_OUT / f"{uid}.png"
    if not src.exists():
        return
    base = fit_canvas(load_rgba(src))
    frames = []
    for i in range(4):
        t = i / 4.0
        frame = base.copy()
        px = frame.load()
        w, h = frame.size
        phase = math.sin(t * math.pi * 2.0)
        for y in range(h):
            yn = y / h
            if yn < 0.32:
                amp = 2.8 * phase
            elif yn > 0.64:
                amp = -3.6 * phase
            else:
                amp = 0.45 * phase
            shift = int(round(amp))
            if shift == 0:
                continue
            row = [px[x, y] for x in range(w)]
            for x in range(w):
                sx = x - shift
                px[x, y] = row[sx] if 0 <= sx < w else (0, 0, 0, 0)
        bounced = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        dy = int(round(math.sin(t * math.pi * 2.0) * 1.8))
        bounced.paste(frame, (0, dy), frame)
        frames.append(bounced)
    sheet = Image.new("RGBA", (FW * 4, FH), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * FW, 0), fr)
    out = SHEET_OUT / f"{uid}_walk.png"
    sheet.save(out)
    print("limb_walk", out.name)


def write_import_stub(png: Path, uid_suffix: str) -> None:
    """Minimal .import so headless Godot picks up new textures cleanly."""
    rel = str(png).replace("/workspace/game/", "res://")
    dest = png.with_suffix(png.suffix + ".import")
    # Stable-ish fake uid from path hash
    h = abs(hash(rel)) % (16**10)
    uid = f"uid://v010{h:010x}"[:20]
    text = f"""[remap]

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
    dest.write_text(text)


def main() -> None:
    VFX_OUT.mkdir(parents=True, exist_ok=True)
    for uid, src in REVEAL_SRC.items():
        process_reveal(uid, src)
    bake_aura_ring()
    bake_aura_mist()
    bake_particle_petal()
    bake_slash_trail()
    bake_burst_flash()
    for uid in LIMB_WALK_IDS:
        limb_walk_sheet(uid)
    # Import stubs for new VFX + overwritten reveals
    for p in sorted(VFX_OUT.glob("*.png")):
        write_import_stub(p, p.stem)
    for uid in REVEAL_SRC:
        write_import_stub(FIG_OUT / f"{uid}_reveal.png", uid)
    for uid in LIMB_WALK_IDS:
        write_import_stub(SHEET_OUT / f"{uid}_walk.png", uid)
    print("process_v010 done")


if __name__ == "__main__":
    main()
