"""Draws the PocketTally logo ("Pocket In/Out" in the app's blue) and its variants.

Usage: python3 tool/make_logo.py assets

Writes:
  assets/icon/icon.png               1024 full-bleed launcher icon (blue)
  assets/icon/icon_background.png    1024 adaptive icon background (blue gradient)
  assets/icon/icon_foreground.png    1024 transparent adaptive icon foreground
  assets/icon/icon_monochrome.png    1024 one-colour glyph for Android 13+ themed icons
  assets/icon/logo.png               1024 rounded blue logo (Windows, Linux, README)
  assets/icon/logo_light.png         512 rounded logo for the app in light mode
  assets/icon/logo_dark.png          512 rounded logo for the app in dark mode
  assets/splash/splash.png           768 transparent splash image
  assets/splash/splash_android12.png 1152 transparent Android 12+ splash icon
"""
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

SS = 4  # supersampling factor

WHITE = (255, 255, 255)
MINT = (123, 224, 181)    # #7BE0B5  income arrow
AMBER = (255, 194, 75)    # #FFC24B  expense arrow

# Backgrounds: (start colour, end colour, direction)
BLUE_BG = ((0x4A, 0x8B, 0xFF), (0x0F, 0x4F, 0xE0), "diagonal")
LIGHT_BG = ((0xFF, 0xFF, 0xFF), (0xE6, 0xEE, 0xFF), "vertical")
DARK_BG = ((0x16, 0x21, 0x3A), (0x0A, 0x10, 0x1D), "vertical")
# The filled pocket, top to bottom.
POCKET_FILL = ((0x4A, 0x8B, 0xFF), (0x12, 0x57, 0xF0))

# Artwork in a 512 x 512 design space.
ART_CENTER = (256, 273)
POCKET = [(132, 142), (380, 142), (362, 334), (256, 404), (150, 334)]


def gradient(size, start, end, direction="vertical", y0=0.0, y1=1.0):
    """An RGBA image filled with a linear gradient.

    For "vertical", y0 and y1 (0..1 of the height) are where the gradient
    starts and ends; outside them the end colours are kept.
    """
    # Worked out on a small grid and scaled up: a gradient has no detail,
    # and the full supersampled size would need a lot of memory.
    w, h = min(size[0], 512), min(size[1], 512)
    ys = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    xs = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    if direction == "diagonal":
        t = (xs + ys) / 2
    else:
        t = np.clip((ys - y0) / max(y1 - y0, 1e-6), 0, 1) + 0 * xs
    a = np.array(start, dtype=np.float32)
    b = np.array(end, dtype=np.float32)
    rgb = a + (b - a) * t[..., None]
    alpha = np.full((h, w, 1), 255, dtype=np.float32)
    small = Image.fromarray(
        np.concatenate([rgb, alpha], axis=2).round().astype(np.uint8), "RGBA")
    return small.resize(size, Image.BICUBIC)


def thick_line(d, p1, p2, w, fill):
    (x1, y1), (x2, y2) = p1, p2
    r = w / 2
    length = math.hypot(x2 - x1, y2 - y1) or 1
    nx, ny = -(y2 - y1) / length * r, (x2 - x1) / length * r
    d.polygon([(x1 + nx, y1 + ny), (x2 + nx, y2 + ny),
               (x2 - nx, y2 - ny), (x1 - nx, y1 - ny)], fill=fill)
    for x, y in (p1, p2):
        d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def polyline(d, pts, w, fill, closed=False):
    n = len(pts)
    for i in range(n if closed else n - 1):
        thick_line(d, pts[i], pts[(i + 1) % n], w, fill)


def colour_layer(size, mask, colour):
    """`colour` (RGB tuple or RGBA image) shown where `mask` (L image) is set."""
    if isinstance(colour, Image.Image):
        src = colour
    else:
        src = Image.new("RGBA", size, colour + (255,))
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(src, (0, 0), mask)
    return out


def artwork(size, cx, cy, k, style, mono=False):
    """The pocket artwork as an RGBA layer.

    style "outline": white pocket outline (on the blue icon).
    style "filled":  blue gradient pocket (light/dark logos, splash).
    mono: everything in white, for the themed icon.
    """
    P = lambda x, y: (cx + (x - ART_CENTER[0]) * k, cy + (y - ART_CENTER[1]) * k)
    pts = [P(x, y) for x, y in POCKET]
    layer = Image.new("RGBA", size, (0, 0, 0, 0))

    if style == "filled" and not mono:
        mask = Image.new("L", size, 0)
        md = ImageDraw.Draw(mask)
        md.polygon(pts, fill=255)
        polyline(md, pts, 24 * k, 255, closed=True)  # rounds the corners
        top, bottom = P(0, 142 - 12)[1], P(0, 404 + 12)[1]
        fill = gradient(size, *POCKET_FILL, "vertical",
                        top / size[1], bottom / size[1])
        layer = Image.alpha_composite(layer, colour_layer(size, mask, fill))
        dash_colour, dash_alpha = WHITE, 190
    else:
        if not mono:
            tint = Image.new("L", size, 0)
            ImageDraw.Draw(tint).polygon(pts, fill=26)  # 10% white inside
            layer = Image.alpha_composite(layer, colour_layer(size, tint, WHITE))
        mask = Image.new("L", size, 0)
        polyline(ImageDraw.Draw(mask), pts, 28 * k, 255, closed=True)
        layer = Image.alpha_composite(layer, colour_layer(size, mask, WHITE))
        dash_colour, dash_alpha = WHITE, 255 if mono else 220

    # stitching along the top hem
    mask = Image.new("L", size, 0)
    md = ImageDraw.Draw(mask)
    x = 170
    while x < 342:
        thick_line(md, P(x, 190), P(min(x + 14, 342), 190), 8 * k, dash_alpha)
        x += 32
    layer = Image.alpha_composite(layer, colour_layer(size, mask, dash_colour))

    # income arrow (up) and expense arrow (down)
    for colour, lines in (
        (MINT, [[P(214, 330), P(214, 236)], [P(182, 266), P(214, 234), P(246, 266)]]),
        (AMBER, [[P(298, 236), P(298, 330)], [P(266, 300), P(298, 332), P(330, 300)]]),
    ):
        mask = Image.new("L", size, 0)
        md = ImageDraw.Draw(mask)
        for line in lines:
            polyline(md, line, 26 * k, 255)
        layer = Image.alpha_composite(
            layer, colour_layer(size, mask, WHITE if mono else colour))
    return layer


def render(size, k, background=None, style="outline", rounded=False, mono=False):
    big = (size * SS, size * SS)
    if background:
        base = gradient(big, *background)
    else:
        base = Image.new("RGBA", big, (0, 0, 0, 0))
    art = artwork(big, big[0] / 2, big[1] / 2, k * size / 512 * SS, style, mono)
    base = Image.alpha_composite(base, art)
    if rounded:
        mask = Image.new("L", big, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, big[0] - 1, big[1] - 1], radius=int(big[0] * 116 / 512), fill=255)
        out = Image.new("RGBA", big, (0, 0, 0, 0))
        out.paste(base, (0, 0), mask)
        base = out
    return base.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    out = sys.argv[1]
    # Phone launcher (blue, the same in light and dark mode).
    render(1024, 1.0, BLUE_BG).save(f"{out}/icon/icon.png")
    gradient((1024, 1024), *BLUE_BG).save(f"{out}/icon/icon_background.png")
    render(1024, 0.7).save(f"{out}/icon/icon_foreground.png")
    # Android 13+ "Themed icons": the phone colours this glyph itself.
    render(1024, 0.66, mono=True).save(f"{out}/icon/icon_monochrome.png")
    # Rounded logos.
    render(1024, 1.0, BLUE_BG, rounded=True).save(f"{out}/icon/logo.png")
    render(512, 1.0, LIGHT_BG, "filled", rounded=True).save(f"{out}/icon/logo_light.png")
    render(512, 1.0, DARK_BG, "filled", rounded=True).save(f"{out}/icon/logo_dark.png")
    # Splash screen (its background colour is set in pubspec.yaml).
    render(768, 0.95, style="filled").save(f"{out}/splash/splash.png")
    render(1152, 0.72, style="filled").save(f"{out}/splash/splash_android12.png")
    print("done")
