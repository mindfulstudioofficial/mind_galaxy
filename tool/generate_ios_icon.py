#!/usr/bin/env python3
"""Generate a clean iOS app icon inspired by the Android icon."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def blend(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(lerp(c1[i], c2[i], t)) for i in range(3))


def star_points(cx: float, cy: float, outer_r: float, inner_r: float) -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = []
    start = -math.pi / 2
    for i in range(10):
        r = outer_r if i % 2 == 0 else inner_r
        a = start + i * math.pi / 5
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def main() -> None:
    size = 1024
    out_path = Path("assets/icon/app_icon_ios_1024.png")

    img = Image.new("RGB", (size, size), (7, 13, 32))
    px = img.load()
    cx = cy = size / 2
    max_r = math.hypot(cx, cy)

    core = (9, 19, 44)
    edge = (4, 9, 24)
    # Radial + subtle vertical gradient for depth.
    for y in range(size):
        ny = y / (size - 1)
        for x in range(size):
            r = math.hypot(x - cx, y - cy) / max_r
            t = min(1.0, r * 1.2)
            base = blend(core, edge, t)
            # Slightly darker toward bottom; keeps Android-like atmosphere.
            shade = int(10 * ny)
            px[x, y] = (max(0, base[0] - shade), max(0, base[1] - shade), max(0, base[2] - shade))

    rng = random.Random(42)
    draw = ImageDraw.Draw(img, "RGBA")
    # Starfield layer
    for _ in range(800):
        x = rng.randrange(size)
        y = rng.randrange(size)
        radius = rng.choice([1, 1, 1, 2])
        c = rng.choice(
            [
                (185, 215, 255, 45),
                (205, 235, 255, 35),
                (170, 220, 170, 28),
                (255, 245, 200, 28),
            ]
        )
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=c)

    # Central glow (stacked soft circles)
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow, "RGBA")
    for r, a in [(220, 22), (170, 34), (130, 42), (95, 52), (68, 58)]:
        gdraw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 238, 170, a))
    glow = glow.filter(ImageFilter.GaussianBlur(20))
    img = Image.alpha_composite(img.convert("RGBA"), glow)

    # Foreground five-point star
    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(fg, "RGBA")
    pts = star_points(cx, cy, outer_r=155, inner_r=66)
    fdraw.polygon(pts, fill=(253, 247, 218, 255))
    fg = fg.filter(ImageFilter.GaussianBlur(1))
    img = Image.alpha_composite(img, fg).convert("RGB")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, format="PNG", optimize=True)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
