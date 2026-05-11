#!/usr/bin/env python3
"""
Expand pre-masked / rounded app icon to a full square for iOS (no white frame).

Flood-fills the outer light border, then fills using radial samples from the
interior night sky (avoids anti-aliased grey and the central star glow).
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageFilter, ImageOps


def light_enough(r: int, g: int, b: int, threshold: int) -> bool:
    return r + g + b >= threshold


def is_night_sky(r: int, g: int, b: int, sky_max_sum: int = 270) -> bool:
    """Picks inner navy / starfield; skips anti-aliased grey fringes and the bright star."""
    s = r + g + b
    if s > sky_max_sum:
        return False
    # Anti-aliased grey between white frame and sky (channels rise together).
    if (
        max(r, g, b) - min(r, g, b) < 22
        and r > 55
        and g > 55
        and b > 55
    ):
        return False
    # Star core / bright flare
    if r > 120 and g > 100:
        return False
    return True


def flood_frame_mask(
    im: Image.Image, threshold: int = 690
) -> list[list[bool]]:
    w, h = im.size
    px = im.load()
    seen = [[False] * w for _ in range(h)]
    stack: list[tuple[int, int]] = []
    for x in range(w):
        for y in (0, h - 1):
            r, g, b, _a = px[x, y]
            if light_enough(r, g, b, threshold):
                stack.append((x, y))
    for y in range(1, h - 1):
        for x in (0, w - 1):
            r, g, b, _a = px[x, y]
            if light_enough(r, g, b, threshold):
                stack.append((x, y))

    while stack:
        x, y = stack.pop()
        if seen[y][x]:
            continue
        r, g, b, _a = px[x, y]
        if not light_enough(r, g, b, threshold):
            continue
        seen[y][x] = True
        if x > 0:
            stack.append((x - 1, y))
        if x < w - 1:
            stack.append((x + 1, y))
        if y > 0:
            stack.append((x, y - 1))
        if y < h - 1:
            stack.append((x, y + 1))
    return seen


def fill_frame(
    im: Image.Image, mask: list[list[bool]], cx: float, cy: float
) -> Image.Image:
    """Fill outer white frame using colours from the *interior* night sky.

    Radial shrink works better than ray-casting toward the centre: a ray from a
    bottom corner can pass through the star glow before it hits true sky.
    """
    w, h = im.size
    px = im.load()
    out = im.copy()
    opx = out.load()
    max_steps = int((w * w + h * h) ** 0.5) + 2
    ks = (0.30, 0.34, 0.38, 0.42, 0.46)

    for y in range(h):
        for x in range(w):
            if not mask[y][x]:
                continue
            filled = False
            vx, vy = x - cx, y - cy
            for k in ks:
                ix = int(round(cx + vx * k))
                iy = int(round(cy + vy * k))
                if ix < 0 or iy < 0 or ix >= w or iy >= h:
                    continue
                r, g, b, _a = px[ix, iy]
                if mask[iy][ix]:
                    continue
                if not is_night_sky(r, g, b):
                    continue
                opx[x, y] = (r, g, b, 255)
                filled = True
                break
            if filled:
                continue
            dx, dy = cx - x, cy - y
            length = (dx * dx + dy * dy) ** 0.5
            if length < 1e-6:
                opx[x, y] = (8, 14, 35, 255)
                continue
            dx /= length
            dy /= length
            sx, sy = float(x), float(y)
            for _ in range(max_steps):
                sx += dx
                sy += dy
                ix = int(round(sx))
                iy = int(round(sy))
                if ix < 0 or iy < 0 or ix >= w or iy >= h:
                    break
                r, g, b, _a = px[ix, iy]
                if not mask[iy][ix] and is_night_sky(r, g, b):
                    opx[x, y] = (r, g, b, 255)
                    filled = True
                    break
            if not filled:
                opx[x, y] = (8, 14, 35, 255)
    return out


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("input", type=Path)
    p.add_argument("-o", "--output", type=Path, required=True)
    p.add_argument("--size", type=int, default=1024, help="square output size")
    p.add_argument("--blur", type=float, default=0.4, help="gaussian sigma for edge soften")
    args = p.parse_args()

    base = Image.open(args.input).convert("RGBA")
    mask = flood_frame_mask(base)
    filled = fill_frame(base, mask, (base.size[0] - 1) / 2, (base.size[1] - 1) / 2)

    # Very mild blur only on former-frame pixels to hide blockiness after ray fill
    if args.blur > 0:
        soft = filled.filter(ImageFilter.GaussianBlur(radius=args.blur))
        fpixels = filled.load()
        spixels = soft.load()
        m_px = mask
        for y in range(base.size[1]):
            for x in range(base.size[0]):
                if m_px[y][x]:
                    fpixels[x, y] = spixels[x, y]
        filled = filled

    if args.size and args.size != filled.size[0]:
        filled = filled.resize((args.size, args.size), Image.Resampling.LANCZOS)

    # iOS: no alpha holes; flatten to opaque
    rgb = Image.new("RGB", filled.size, (0, 11, 30))
    rgb.paste(filled, mask=filled.split()[3])
    rgb = ImageOps.exif_transpose(rgb)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    rgb.save(args.output, format="PNG", optimize=True)
    print("wrote", args.output, rgb.size)


if __name__ == "__main__":
    main()
