#!/usr/bin/env python3
"""Resize a source icon image to Google Play's 512x512 format."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def resize_icon(source_path: Path, output_path: Path, size: int = 512) -> None:
    """Resize icon to a square size and save it as PNG."""
    with Image.open(source_path) as src:
        icon = src.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        icon.save(output_path, format="PNG")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a Google Play icon (default: 512x512 PNG)."
    )
    parser.add_argument(
        "--input",
        default="assets/icon/app_icon.png",
        help="Path to the source icon image.",
    )
    parser.add_argument(
        "--output",
        default="assets/icon/app_icon_512.png",
        help="Path for the resized PNG icon.",
    )
    parser.add_argument(
        "--size",
        type=int,
        default=512,
        help="Target width/height in pixels (default: 512).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    resize_icon(input_path, output_path, args.size)
    print(f"Saved resized icon: {output_path} ({args.size}x{args.size})")


if __name__ == "__main__":
    main()
