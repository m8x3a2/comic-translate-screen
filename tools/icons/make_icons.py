# /// script
# dependencies = ["pillow>=10", "numpy"]
# ///
"""Builds the program icons for Windows, Android and Linux.

    uv run tools/icons/make_icons.py            # write all icons
    uv run tools/icons/make_icons.py --sheet F  # also a check sheet (16-256 on light/dark)

The default icon ("translator", green) is drawn here: a grey card with あ behind a green speech bubble
with A. It is the exe's main icon and the Android/Linux icon. Needs Windows (the あ comes from Yu Gothic).

Two spare icons, chosen in Settings → General, come from the owner's pictures (tools/icons/src,
made in a picture generator, 1254x1254 on white):
  main_blue.png      cat in a frame + speech bubble on a blue rounded square
  main_navy.png      the same on dark navy
  (no_background.png and silhouette.png: the cat's Android layers, no longer used)

Sizes 16-24 px use simplified pictures (translator: no あ; cats: only the cat in its frame):
at that size the full picture turns into noise.
"""

from __future__ import annotations

import argparse
import io
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "src"
APP = ROOT / "apps" / "comic_translate"

MASTER = 1024  # side of the cleaned masters

# Simplified picture for 16-24 px: this part of main_*.png (the cat), in 1254-px source coordinates,
# put into a white window on the same rounded square.
SMALL_CROP = (345, 240, 905, 800)
SMALL_INSET = 0.09  # window edge from the square's edge, share of the side
SMALL_BORDER = 0.04  # white window border
OUTLINE = (4, 10, 40)  # dark line of the drawing

ICO_SIZES = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
SMALL_MAX = 24  # sizes up to this one use the simplified picture

# Android: legacy launcher icon (48 dp) and adaptive layers (108 dp) per density.
ANDROID_DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
ADAPTIVE_CONTENT = 0.56  # drawing side / layer side (safe zone is a 66/108 circle)


# ---------------------------------------------------------------- cleaning the sources


def _outside(img: Image.Image, thresh: int) -> np.ndarray:
    """True where a pixel is the white page around the drawing (flood fill from the four corners)."""
    work = img.convert("RGB").copy()
    w, h = work.size
    for xy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if work.getpixel(xy) != (255, 0, 255):
            ImageDraw.floodfill(work, xy, (255, 0, 255), thresh=thresh)
    a = np.asarray(work)
    return (a[..., 0] == 255) & (a[..., 1] == 0) & (a[..., 2] == 255)


def _cut_from_white(img: Image.Image, edge_rgb: tuple[int, int, int], band: int = 5, thresh: int = 70) -> Image.Image:
    """Makes the white page around the drawing transparent; the anti-aliased edge gets a smooth alpha.

    Edge pixels are a mix of white and `edge_rgb` (the colour the drawing has at its border), so
    alpha = how far the pixel moved from white towards that colour."""
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    out = _outside(img, thresh)
    out_img = Image.fromarray((out * 255).astype(np.uint8))
    near = np.asarray(out_img.filter(ImageFilter.MaxFilter(2 * band + 1))) > 0
    edge = np.array(edge_rgb, np.float32)
    white = np.array([255, 255, 255], np.float32)
    full = np.linalg.norm(edge - white)
    mix = np.clip(np.linalg.norm(rgb - white, axis=2) / full, 0, 1)
    alpha = np.where(out, 0.0, np.where(near, mix, 1.0))
    color = np.where((near & ~out)[..., None], edge, rgb)
    rgba = np.dstack([color, alpha * 255]).round().clip(0, 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def _square(img: Image.Image, side: int, content: float = 1.0) -> Image.Image:
    """Crops to the drawing, centres it on a transparent square `side` px, drawing side = content * side."""
    bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    img = img.crop(bbox)
    scale = content * side / max(img.size)
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(img, ((side - img.width) // 2, (side - img.height) // 2))
    return canvas


def _bg_color(path: Path) -> tuple[int, int, int]:
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    h, w, _ = a.shape
    samples = np.array([a[h // 2, int(w * 0.06)], a[int(h * 0.05), w // 2], a[int(h * 0.94), w // 2]])
    return tuple(int(v) for v in np.median(samples, axis=0))


def main_icon(name: str) -> Image.Image:
    path = SRC / name
    return _square(_cut_from_white(Image.open(path), _bg_color(path)), MASTER)


def small_icon(name: str) -> Image.Image:
    """The cat in a white window on the same rounded square: no corner marks, no bubble, bigger cat."""
    path = SRC / name
    src = Image.open(path).convert("RGBA")
    bg = _bg_color(path)
    shape = _cut_from_white(src, bg)  # the rounded square with its alpha edge
    side = shape.width
    base = Image.new("RGBA", shape.size, bg + (255,))
    # the window: dark outline + white border, drawn 4x larger for smooth corners
    k = 4
    win = Image.new("RGBA", (side * k, side * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(win)
    a, b = round(side * k * SMALL_INSET), side * k - round(side * k * SMALL_INSET)
    o = round(side * k * 0.018)
    d.rounded_rectangle((a - o, a - o, b + o, b + o), radius=round(side * k * 0.04), fill=OUTLINE + (255,))
    d.rectangle((a, a, b, b), fill=(255, 255, 255, 255))
    base.alpha_composite(win.resize(shape.size, Image.LANCZOS))
    # the cat picture inside, with a thin dark line around it
    a1 = round(side * SMALL_INSET) + round(side * SMALL_BORDER)
    n = side - 2 * a1
    line = round(side * 0.012)
    base.alpha_composite(Image.new("RGBA", (n + 2 * line, n + 2 * line), OUTLINE + (255,)), (a1 - line, a1 - line))
    base.alpha_composite(src.crop(SMALL_CROP).resize((n, n), Image.LANCZOS), (a1, a1))
    base.putalpha(shape.getchannel("A"))
    return _square(base, MASTER)


# ---------------------------------------------------------------- the translator icon (default)

GREEN = (22, 163, 104)
GREEN_DARK = (12, 118, 74)  # the fold of the bubble's tail
CARD = (226, 229, 234)
CARD_TEXT = (95, 99, 104)
LATIN_FONT = APP / "assets" / "fonts" / "PTSans-Bold.ttf"  # OFL, bundled with the app
JP_FONT = Path("C:/Windows/Fonts/YuGothB.ttc")  # Windows font, only drawn into the picture


def translator_icon(small: bool = False, mono: bool = False) -> Image.Image:
    """Grey card with あ (the original) behind a green speech bubble with A (the translation).

    `small`: for 16-24 px — no あ (it turns into a grey smudge there).
    `mono`: one white silhouette with the letters cut out (Android themed icon)."""
    from PIL import ImageFont

    k = 2048
    im = Image.new("RGBA", (k, k), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    clear = (0, 0, 0, 0)
    white = (255, 255, 255, 255)
    card = white if mono else CARD + (255,)
    main = white if mono else GREEN + (255,)
    fold = white if mono else GREEN_DARK + (255,)
    d.rounded_rectangle((k * 0.40, k * 0.22, k * 0.92, k * 0.80), radius=k * 0.07, fill=card)
    if not small:
        jp = ImageFont.truetype(str(JP_FONT), int(k * 0.26))
        d.text((k * 0.735, k * 0.53), "あ", font=jp, fill=clear if mono else CARD_TEXT + (255,), anchor="mm")
    x0, y0, x1, y1 = k * 0.08, k * 0.14, k * 0.60, k * 0.68
    if mono:  # a gap between the bubble and the card, else they merge into one blob
        g = k * 0.025
        d.rounded_rectangle((x0 - g, y0 - g, x1 + g, y1 + g), radius=k * 0.07 + g, fill=clear)
        d.polygon([(k * 0.28, y1), (k * 0.55, y1), (k * 0.575, k * 0.89)], fill=clear)
    d.polygon([(k * 0.36, y1 - 2), (k * 0.52, y1 - 2), (k * 0.56, k * 0.86)], fill=fold)
    d.polygon([(k * 0.30, y1 - 2), (k * 0.48, y1 - 2), (k * 0.56, k * 0.86)], fill=main)
    d.rounded_rectangle((x0, y0, x1, y1), radius=k * 0.07, fill=main)
    latin = ImageFont.truetype(str(LATIN_FONT), int(k * (0.44 if small else 0.40)))
    d.text(((x0 + x1) / 2, (y0 + y1) / 2 + k * 0.005), "A", font=latin, fill=clear if mono else white, anchor="mm")
    return _square(im.resize((MASTER, MASTER), Image.LANCZOS), MASTER)


def foreground() -> Image.Image:
    path = SRC / "no_background.png"
    return _cut_from_white(Image.open(path), (8, 16, 48))


def monochrome() -> Image.Image:
    g = np.asarray(Image.open(SRC / "silhouette.png").convert("L")).astype(np.float32)
    alpha = np.clip((235 - g) / (235 - 20), 0, 1) * 255
    rgba = np.dstack([np.full_like(g, 255)] * 3 + [alpha]).round().astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


# ---------------------------------------------------------------- outputs


def scaled(master: Image.Image, side: int) -> Image.Image:
    img = master.resize((side, side), Image.LANCZOS)
    if side <= 48:  # a touch of sharpening keeps the outlines crisp at small sizes
        img = img.filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=2))
    return img


def ico_frames(big: Image.Image, small: Image.Image) -> list[Image.Image]:
    return [scaled(small if s <= SMALL_MAX else big, s) for s in ICO_SIZES]


def _dib(img: Image.Image) -> bytes:
    """32-bit BGRA bitmap as stored inside .ico (bottom-up, doubled height, 1-bit AND mask)."""
    w, h = img.size
    a = np.asarray(img.convert("RGBA"))[::-1]
    bgra = a[..., [2, 1, 0, 3]].tobytes()
    row = ((w + 31) // 32) * 4
    mask = bytearray(row * h)
    for y in range(h):
        for x in range(w):
            if a[y, x, 3] == 0:
                mask[y * row + x // 8] |= 0x80 >> (x % 8)
    head = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0, len(bgra) + len(mask), 0, 0, 0, 0)
    return head + bgra + bytes(mask)


def write_ico(frames: list[Image.Image], path: Path) -> None:
    """ICO: 256 px as PNG, smaller sizes as classic 32-bit bitmaps (what every Windows reader expects)."""
    blobs = []
    for f in frames:
        if f.width >= 256:
            b = io.BytesIO()
            f.save(b, "PNG", optimize=True)
            blobs.append(b.getvalue())
        else:
            blobs.append(_dib(f))
    head = struct.pack("<HHH", 0, 1, len(frames))
    offset = 6 + 16 * len(frames)
    entries = b""
    for f, blob in zip(frames, blobs):
        w = f.width if f.width < 256 else 0
        entries += struct.pack("<BBBBHHII", w, w, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    path.write_bytes(head + entries + b"".join(blobs))


def write_android(big: Image.Image, fg: Image.Image, mono: Image.Image, bg: tuple[int, int, int]) -> None:
    res = APP / "android" / "app" / "src" / "main" / "res"
    fg_sq = _square(fg, MASTER, ADAPTIVE_CONTENT)
    mono_sq = _square(mono, MASTER, ADAPTIVE_CONTENT)
    for name, k in ANDROID_DENSITIES.items():
        d = res / f"mipmap-{name}"
        d.mkdir(parents=True, exist_ok=True)
        scaled(big, round(48 * k)).save(d / "ic_launcher.png", optimize=True)
        scaled(fg_sq, round(108 * k)).save(d / "ic_launcher_foreground.png", optimize=True)
        scaled(mono_sq, round(108 * k)).save(d / "ic_launcher_monochrome.png", optimize=True)
    any_dpi = res / "mipmap-anydpi-v26"
    any_dpi.mkdir(parents=True, exist_ok=True)
    (any_dpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
        newline="\n",
    )
    (res / "values" / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="ic_launcher_background">#{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}</color>\n'
        "</resources>\n",
        encoding="utf-8",
        newline="\n",
    )


def sheet(variants: list[tuple[str, list[Image.Image]]], extra: list[tuple[str, Image.Image]], path: Path) -> None:
    """Every ico size at 1:1 and x4 (pixels visible) on a light and a dark background."""
    pad = 12
    rows = []
    for title, frames in variants:
        for bg in [(243, 243, 243), (32, 32, 32)]:
            w = sum(max(f.width, 48) + pad for f in frames) + pad
            w += sum(f.width * 4 + pad for f in frames if f.width <= 32)
            row = Image.new("RGBA", (w, 256 + 2 * pad), bg + (255,))
            x = pad
            for f in frames:
                row.alpha_composite(f, (x, pad + 256 - f.height))
                x += max(f.width, 48) + pad
            for f in frames:
                if f.width <= 32:
                    big = f.resize((f.width * 4, f.height * 4), Image.NEAREST)
                    row.alpha_composite(big, (x, pad + 256 - big.height))
                    x += big.width + pad
            rows.append(row)
    for title, img in extra:
        rows.append(img)
    out = Image.new("RGBA", (max(r.width for r in rows), sum(r.height for r in rows)), (200, 200, 200, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height
    out.save(path)


def android_preview(big, fg, mono, bg) -> Image.Image:
    """Adaptive icon as launchers show it: circle and rounded square masks, plus the themed variant."""
    side = 192
    fg_l = scaled(_square(fg, MASTER, ADAPTIVE_CONTENT), side)
    mono_l = scaled(_square(mono, MASTER, ADAPTIVE_CONTENT), side)
    tiles = []
    for shape in ["circle", "squircle"]:
        for layer, color in [(fg_l, bg), (mono_l, (40, 60, 90))]:
            tile = Image.new("RGBA", (side, side), color + (255,))
            tile.alpha_composite(layer)
            mask = Image.new("L", (side * 4, side * 4), 0)
            d = ImageDraw.Draw(mask)
            # launchers show the middle 72 of 108 dp
            m = round(side * 4 * 18 / 108)
            box = (m, m, side * 4 - m, side * 4 - m)
            if shape == "circle":
                d.ellipse(box, fill=255)
            else:
                d.rounded_rectangle(box, radius=side * 4 // 6, fill=255)
            tile.putalpha(mask.resize((side, side), Image.LANCZOS))
            tiles.append(tile)
    tiles.append(scaled(big, side))
    out = Image.new("RGBA", (len(tiles) * (side + 12) + 12, side + 24), (243, 243, 243, 255))
    for i, t in enumerate(tiles):
        out.alpha_composite(t, (12 + i * (side + 12), 12))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", type=Path, help="write a check sheet to this png")
    args = ap.parse_args()

    green, green_s = translator_icon(), translator_icon(small=True)
    blue, navy = main_icon("main_blue.png"), main_icon("main_navy.png")
    blue_s, navy_s = small_icon("main_blue.png"), small_icon("main_navy.png")
    fg, mono = _square(green, MASTER), translator_icon(mono=True)
    bg = (255, 255, 255)

    res = APP / "windows" / "runner" / "resources"
    green_frames = ico_frames(green, green_s)
    # the exe's main icon (IDI_APP_ICON); the cats are spare ones, switched in Settings → General
    write_ico(green_frames, res / "app_icon.ico")
    blue_frames = ico_frames(blue, blue_s)
    write_ico(blue_frames, res / "app_icon_blue.ico")  # IDI_BLUE_ICON
    navy_frames = ico_frames(navy, navy_s)
    write_ico(navy_frames, res / "app_icon_navy.ico")  # IDI_NAVY_ICON
    icons = APP / "assets" / "icon"
    icons.mkdir(parents=True, exist_ok=True)
    for name, img in [("green", green), ("blue", blue), ("navy", navy)]:
        scaled(img, 512).save(icons / f"app_icon_{name}_512.png", optimize=True)  # Linux
        # small pictures for the icon choice in the settings (bundled with the app)
        scaled(img, 96).save(icons / f"preview_{name}.png", optimize=True)
    write_android(_on_white(green), fg, mono, bg)

    if args.sheet:
        sheet(
            [("green", green_frames), ("blue", blue_frames), ("navy", navy_frames)],
            [("android", android_preview(_on_white(green), fg, mono, bg))],
            args.sheet,
        )
    print("ok")


def _on_white(img: Image.Image) -> Image.Image:
    """Android's legacy launcher icon: the drawing on a white rounded square."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(out).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius=img.width * 0.2, fill="white")
    out.alpha_composite(_square(img, img.width, 0.8))
    return out


if __name__ == "__main__":
    main()
