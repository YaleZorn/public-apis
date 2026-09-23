#!/usr/bin/env python3
"""v0.9.8: limb/pose walk+attack sheets, brighter TD figures, portrait redraws."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

ART = Path("/opt/cursor/artifacts/assets")
FIG_OUT = Path("/workspace/game/assets/textures/figures")
PORT_OUT = Path("/workspace/game/assets/textures/portraits")
SHEET_OUT = Path("/workspace/game/assets/textures/figures/sheets")

PORT_SRC = {
    "portrait_zhaoyun_v098.png": "unit_zhaoyun.png",
    "portrait_linchong_v098.png": "unit_linchong.png",
}

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


def add_rim(im: Image.Image, strength: float = 0.7, color=(200, 240, 225)) -> Image.Image:
    im = im.convert("RGBA")
    alpha = im.split()[-1]
    edge = alpha.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(5))
    edge = ImageEnhance.Brightness(edge).enhance(1.55)
    rim = Image.new("RGBA", im.size, (*color, 0))
    rim.putalpha(edge.point(lambda v: min(255, int(v * strength))))
    return Image.alpha_composite(im, rim)


def lift_readability(im: Image.Image, male: bool) -> Image.Image:
    rgb = im.convert("RGBA")
    r, g, b, a = rgb.split()
    rgb_only = Image.merge("RGB", (r, g, b))
    bright = 1.18 if male else 1.12
    contrast = 1.12 if male else 1.08
    rgb_only = ImageEnhance.Brightness(rgb_only).enhance(bright)
    rgb_only = ImageEnhance.Contrast(rgb_only).enhance(contrast)
    rgb_only = ImageEnhance.Color(rgb_only).enhance(1.06)
    r2, g2, b2 = rgb_only.split()
    out = Image.merge("RGBA", (r2, g2, b2, a))
    rim_s = 0.78 if male else 0.55
    return add_rim(out, strength=rim_s, color=(205, 245, 230))


def process_portrait(src: Path, dst: Path) -> None:
    im = Image.open(src).convert("RGB")
    tw, th = 240, 288
    scale = max(tw / im.width, th / im.height)
    nw, nh = int(im.width * scale), int(im.height * scale)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = max(0, (nh - th) // 5)
    im = im.crop((left, top, left + tw, top + th))
    im = ImageEnhance.Contrast(im).enhance(1.08)
    im = ImageEnhance.Color(im).enhance(1.06)
    im = ImageEnhance.Brightness(im).enhance(1.04)
    im.save(dst, "PNG", optimize=True)
    print("portrait", dst.name, im.size)


def _sample(px, w: int, h: int, x: float, y: float):
    xi = int(round(x))
    yi = int(round(y))
    if 0 <= xi < w and 0 <= yi < h:
        return px[xi, yi]
    return (0, 0, 0, 0)


def _smoothstep(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def _side_weight(x: float, mid: float, soft: float = 18.0) -> float:
    """-1 (left) … +1 (right), soft across midline — no hard seam."""
    return math.tanh((x - mid) / soft)


def _bilinear(px, w: int, h: int, x: float, y: float):
    """Bilinear sample RGBA — prevents slice stair-steps."""
    if x < 0 or y < 0 or x >= w - 1 or y >= h - 1:
        return _sample(px, w, h, x, y)
    x0 = int(math.floor(x))
    y0 = int(math.floor(y))
    x1 = min(w - 1, x0 + 1)
    y1 = min(h - 1, y0 + 1)
    fx = x - x0
    fy = y - y0
    c00 = px[x0, y0]
    c10 = px[x1, y0]
    c01 = px[x0, y1]
    c11 = px[x1, y1]
    out = []
    for i in range(4):
        top = c00[i] * (1 - fx) + c10[i] * fx
        bot = c01[i] * (1 - fx) + c11[i] * fx
        out.append(int(top * (1 - fy) + bot * fy))
    return tuple(out)


def _limb_walk_frame(base: Image.Image, phase: float) -> Image.Image:
    """Readable walk without midline tear.

    Uses whole-body lean + Y-ramped lower shear + contact squash/bob.
    Soft L/R bias is tiny (accent only) so silhouette stays intact.
    """
    w, h = base.size
    ang = phase * math.tau
    lean = math.sin(ang) * 10.0
    shear_amp = 20.0
    bob = abs(math.sin(ang)) * 6.0
    squash = 1.0 + math.sin(ang * 2) * 0.055

    nh = max(8, int(h * squash))
    scaled = base.resize((w, nh), Image.Resampling.BILINEAR)
    staged = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    y_off = h - nh - int(bob)
    staged.paste(scaled, (0, max(0, y_off)), scaled)
    spx = staged.load()

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    mid = w * 0.5
    split = 0.40  # below this: legs get shear

    for y in range(h):
        yn = y / max(1, h - 1)
        leg_t = _smoothstep((yn - split) / (1.0 - split))
        # Classic cartoon walk: lower body shears with phase; upper counters slightly
        shear = math.sin(ang) * shear_amp * (leg_t ** 1.6)
        counter = -math.sin(ang) * 6.0 * (1.0 - leg_t)
        # Tiny soft L/R accent (not enough to tear torso)
        for x in range(w):
            side = _side_weight(float(x), mid, soft=28.0)
            dx = shear + counter + lean * (1.0 - yn) * 0.45
            dx += side * math.sin(ang) * 4.5 * leg_t  # subtle opposite-foot cue
            # Arm counter-swing cue on upper band
            if yn < 0.48:
                dx += -side * math.cos(ang) * 5.0 * (1.0 - yn / 0.48)
            dy = -abs(math.sin(ang)) * 1.5 * leg_t
            opx[x, y] = _bilinear(spx, w, h, x - dx, y - dy)
    return out


def _limb_attack_frame(base: Image.Image, phase: float) -> Image.Image:
    """Wind-up → strike → recover: lean + stretch + upper thrust, smooth."""
    w, h = base.size
    if phase < 0.35:
        lean = -0.14
        thrust = -16.0
        stretch_x, stretch_y = 0.94, 1.07
    elif phase < 0.7:
        lean = 0.22
        thrust = 24.0
        stretch_x, stretch_y = 1.16, 0.86
    else:
        lean = 0.06
        thrust = 5.0
        stretch_x, stretch_y = 1.03, 0.98

    nw = max(8, int(w * stretch_x))
    nh = max(8, int(h * stretch_y))
    scaled = base.resize((nw, nh), Image.Resampling.BILINEAR)
    staged = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x0 = (w - nw) // 2 + int(lean * 20)
    y0 = h - nh
    staged.paste(scaled, (x0, y0), scaled)
    spx = staged.load()

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    mid = w * 0.5
    for y in range(h):
        yn = y / max(1, h - 1)
        upper = 1.0 - _smoothstep((yn - 0.38) / 0.28)
        for x in range(w):
            side = _side_weight(float(x), mid, soft=24.0)
            weapon_bias = 0.9 + 0.2 * max(0.0, side)
            dx = thrust * upper * weapon_bias + lean * (1.0 - yn) * 22.0 * upper
            opx[x, y] = _bilinear(spx, w, h, x - dx, float(y))

    return out.rotate(
        -lean * 22.0,
        resample=Image.Resampling.BILINEAR,
        center=(w // 2, h - 4),
        fillcolor=(0, 0, 0, 0),
    )


def _key_black(im: Image.Image, tol: int = 28) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r <= tol and g <= tol and b <= tol:
                px[x, y] = (r, g, b, 0)
    return im


def _frame_from_rgba(im: Image.Image) -> Image.Image:
    keyed = _key_black(im) if im.mode != "RGBA" or im.getextrema()[0][0] < 40 else im.convert("RGBA")
    # Also kill near-black leftover
    keyed = _key_black(keyed, tol=22)
    keyed = trim_alpha(keyed, pad=6)
    keyed = keyed.filter(ImageFilter.SMOOTH)
    return fit_canvas(keyed, (192, 256))


def _slice_row_sheet(src: Path, n: int) -> list[Image.Image]:
    """Split a horizontal multi-figure sheet into n equal columns after trim."""
    im = _key_black(Image.open(src), tol=24)
    bbox = im.getbbox()
    if not bbox:
        return []
    im = im.crop(bbox)
    w, h = im.size
    # Prefer equal splits across content width
    frames = []
    for i in range(n):
        x0 = int(i * w / n)
        x1 = int((i + 1) * w / n)
        cell = im.crop((x0, 0, x1, h))
        frames.append(_frame_from_rgba(cell))
    return frames


def _frames_from_poses(paths: list[Path]) -> list[Image.Image]:
    out = []
    for p in paths:
        if not p.exists():
            return []
        out.append(_frame_from_rgba(Image.open(p)))
    return out


def _frames_distinct(frames: list[Image.Image], min_rgb: float = 10.0, min_alpha: float = 12.0) -> bool:
    """Reject near-copies: require both RGB and silhouette (alpha) change."""
    if len(frames) < 2:
        return False
    for i in range(len(frames) - 1):
        a = frames[i]
        b = frames[i + 1]
        ar, ag, ab, aa = a.split()
        br, bg, bb, ba = b.split()
        step = 3
        rgb_d = 0
        a_d = 0
        n = 0
        ap = Image.merge("RGB", (ar, ag, ab)).load()
        bp = Image.merge("RGB", (br, bg, bb)).load()
        aap, bap = aa.load(), ba.load()
        for y in range(0, a.height, step):
            for x in range(0, a.width, step):
                pa, pb = ap[x, y], bp[x, y]
                rgb_d += abs(pa[0] - pb[0]) + abs(pa[1] - pb[1]) + abs(pa[2] - pb[2])
                a_d += abs(aap[x, y] - bap[x, y])
                n += 1
        if rgb_d / max(1, n * 3) < min_rgb or a_d / max(1, n) < min_alpha:
            return False
    return True


# Prefer authored pose packs / AI sheets when distinct; else procedural.
AI_WALK = {
    "unit_mulan": ("poses", [ART / f"pose_mulan_walk{i}.png" for i in range(4)]),
    "unit_qinggong": ("sheet", ART / "sheet_qinggong_walk_v098.png", 4),
    "unit_feidao": ("sheet", ART / "sheet_feidao_walk_v098.png", 4),
}
AI_ATTACK = {
    "unit_mulan": ("sheet", ART / "sheet_mulan_attack_v098.png", 3),
    "unit_zhaoyun": ("sheet", ART / "sheet_zhaoyun_attack_v098.png", 3),
}


def _load_ai_frames(spec) -> list[Image.Image]:
    kind = spec[0]
    if kind == "poses":
        frames = _frames_from_poses(spec[1])
    else:
        frames = _slice_row_sheet(spec[1], spec[2])
    if frames and _frames_distinct(frames):
        return frames
    return []


def build_sheets(fig_id: str, base_path: Path) -> None:
    base = Image.open(base_path).convert("RGBA")

    walk_frames = _load_ai_frames(AI_WALK[fig_id]) if fig_id in AI_WALK else []
    if not walk_frames:
        walk_frames = [_limb_walk_frame(base, i / 4.0) for i in range(4)]
        src = "proc"
    else:
        # Boost rim on AI frames for TD fog
        walk_frames = [add_rim(f, strength=0.45, color=(200, 240, 225)) for f in walk_frames]
        src = "ai"

    walk = Image.new("RGBA", (192 * 4, 256), (0, 0, 0, 0))
    for i, fr in enumerate(walk_frames):
        walk.paste(fr, (i * 192, 0), fr)
    walk_path = SHEET_OUT / f"{fig_id}_walk.png"
    walk.save(walk_path, "PNG")

    atk_frames = _load_ai_frames(AI_ATTACK[fig_id]) if fig_id in AI_ATTACK else []
    if not atk_frames:
        atk_frames = [_limb_attack_frame(base, p) for p in (0.18, 0.52, 0.88)]
        asrc = "proc"
    else:
        atk_frames = [add_rim(f, strength=0.45, color=(200, 240, 225)) for f in atk_frames]
        asrc = "ai"

    atk = Image.new("RGBA", (192 * 3, 256), (0, 0, 0, 0))
    for i, fr in enumerate(atk_frames):
        atk.paste(fr, (i * 192, 0), fr)
    atk_path = SHEET_OUT / f"{fig_id}_attack.png"
    atk.save(atk_path, "PNG")
    print("sheets", walk_path.name, f"walk={src}", atk_path.name, f"atk={asrc}")


def brighten_figure(fig_id: str) -> None:
    path = FIG_OUT / f"{fig_id}.png"
    if not path.exists():
        print("MISSING figure", path)
        return
    im = Image.open(path).convert("RGBA")
    im = lift_readability(im, male=fig_id in MALE_IDS)
    im.save(path, "PNG")
    print("brighten", fig_id)


def main() -> None:
    FIG_OUT.mkdir(parents=True, exist_ok=True)
    PORT_OUT.mkdir(parents=True, exist_ok=True)
    SHEET_OUT.mkdir(parents=True, exist_ok=True)

    for src_name, dst_name in PORT_SRC.items():
        src = ART / src_name
        if not src.exists():
            alt = Path("/opt/cursor/artifacts") / src_name
            src = alt if alt.exists() else src
        if not src.exists():
            print("MISSING port", src_name)
            continue
        process_portrait(src, PORT_OUT / dst_name)

    for fig_id in ALL_FIGURE_IDS:
        brighten_figure(fig_id)

    for fig_id in ALL_FIGURE_IDS:
        base = FIG_OUT / f"{fig_id}.png"
        if not base.exists():
            print("MISSING sheet base", base)
            continue
        build_sheets(fig_id, base)

    print("PROCESS_V098_OK")


if __name__ == "__main__":
    main()
