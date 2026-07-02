#!/usr/bin/env python3
"""Generate X (Twitter) profile icons from the MindGalaxy app icon design."""

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


def render_icon(size: int, *, content_scale: float = 1.0) -> Image.Image:
    """Render the MindGalaxy star icon at [size]x[size].

    content_scale < 1.0 shrinks the star and glow so they sit comfortably
    inside X's circular profile crop (inscribed circle in a square).
    """
    img = Image.new("RGB", (size, size), (7, 13, 32))
    px = img.load()
    cx = cy = size / 2
    max_r = math.hypot(cx, cy)

    core = (9, 19, 44)
    edge = (4, 9, 24)
    for y in range(size):
        ny = y / (size - 1)
        for x in range(size):
            r = math.hypot(x - cx, y - cy) / max_r
            t = min(1.0, r * 1.2)
            base = blend(core, edge, t)
            shade = int(10 * ny)
            px[x, y] = (max(0, base[0] - shade), max(0, base[1] - shade), max(0, base[2] - shade))

    rng = random.Random(42)
    draw = ImageDraw.Draw(img, "RGBA")
    star_count = int(800 * (size / 1024) ** 2)
    for _ in range(star_count):
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

    s = content_scale
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow, "RGBA")
    blur = max(8, int(20 * size / 1024))
    for r, a in [(220 * s, 22), (170 * s, 34), (130 * s, 42), (95 * s, 52), (68 * s, 58)]:
        gdraw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 238, 170, a))
    glow = glow.filter(ImageFilter.GaussianBlur(blur))
    img = Image.alpha_composite(img.convert("RGBA"), glow)

    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(fg, "RGBA")
    pts = star_points(cx, cy, outer_r=155 * s, inner_r=66 * s)
    fdraw.polygon(pts, fill=(253, 247, 218, 255))
    if size >= 256:
        fg = fg.filter(ImageFilter.GaussianBlur(1))
    img = Image.alpha_composite(img, fg).convert("RGB")
    return img


def circle_preview(icon: Image.Image) -> Image.Image:
    """Show how the icon looks when X crops it to a circle."""
    size = icon.size[0]
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    bg = Image.new("RGB", (size, size), (21, 32, 43))  # X dark UI tone
    out = Image.composite(icon, bg, mask)
    return out


def main() -> None:
    out_dir = Path("assets/icon/x")
    out_dir.mkdir(parents=True, exist_ok=True)

    # Slightly smaller star/glow keeps the halo inside X's circular crop.
    master = render_icon(1024, content_scale=0.93)

    exports: dict[str, int] = {
        "profile_400.png": 400,
        "profile_800.png": 800,
        "profile_1024.png": 1024,
    }
    for name, px in exports.items():
        out = master if px == 1024 else master.resize((px, px), Image.Resampling.LANCZOS)
        path = out_dir / name
        out.save(path, format="PNG", optimize=True)
        print(f"wrote {path} ({px}x{px})")

    preview = circle_preview(master.resize((800, 800), Image.Resampling.LANCZOS))
    preview_path = out_dir / "profile_800_circle_preview.png"
    preview.save(preview_path, format="PNG", optimize=True)
    print(f"wrote {preview_path} (circle crop preview)")


if __name__ == "__main__":
    main()
