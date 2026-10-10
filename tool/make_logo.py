"""Draws the PocketTally logo (design B, "Pocket In/Out") and its variants.

Usage: python3 tool/make_logo.py assets

Writes:
  assets/icon/icon.png             1024 full-bleed launcher icon
  assets/icon/icon_foreground.png  1024 transparent, adaptive icon foreground
  assets/icon/logo.png             1024 rounded logo for README / in-app
  assets/splash/splash.png         768 transparent splash image
  assets/splash/splash_android12.png 1152 transparent Android 12 splash icon
"""
import math
import sys

from PIL import Image, ImageDraw

SS = 4  # supersampling factor
BG = (14, 59, 48, 255)        # #0E3B30
WHITE = (255, 255, 255, 255)
MINT = (123, 224, 181, 255)   # #7BE0B5  income arrow
AMBER = (242, 179, 61, 255)   # #F2B33D  expense arrow

# Artwork in a 512 x 512 design space (same as the SVG on the design page).
ART_CENTER = (256, 273)


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


def artwork(layer, cx, cy, k):
    """Draws the design-space artwork scaled by k, centred at (cx, cy)."""
    d = ImageDraw.Draw(layer)
    P = lambda x, y: (cx + (x - ART_CENTER[0]) * k, cy + (y - ART_CENTER[1]) * k)

    pocket = [P(132, 142), P(380, 142), P(362, 334), P(256, 404), P(150, 334)]
    polyline(d, pocket, 28 * k, WHITE, closed=True)

    # stitching along the top hem
    x = 170
    while x < 342:
        thick_line(d, P(x, 190), P(min(x + 14, 342), 190), 8 * k, WHITE)
        x += 32

    # income arrow (up) and expense arrow (down)
    polyline(d, [P(214, 330), P(214, 236)], 26 * k, MINT)
    polyline(d, [P(182, 266), P(214, 234), P(246, 266)], 26 * k, MINT)
    polyline(d, [P(298, 236), P(298, 330)], 26 * k, AMBER)
    polyline(d, [P(266, 300), P(298, 332), P(330, 300)], 26 * k, AMBER)


def render(size, k, background, rounded=False):
    big = size * SS
    base = Image.new("RGBA", (big, big), BG if background else (0, 0, 0, 0))
    art = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    artwork(art, big / 2, big / 2, k * size / 512 * SS)
    base = Image.alpha_composite(base, art)
    if rounded:
        mask = Image.new("L", (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, big - 1, big - 1], radius=int(big * 116 / 512), fill=255)
        out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        out.paste(base, (0, 0), mask)
        base = out
    return base.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    out = sys.argv[1]
    render(1024, 1.0, True).save(f"{out}/icon/icon.png")
    render(1024, 0.82, False).save(f"{out}/icon/icon_foreground.png")
    render(1024, 1.0, True, rounded=True).save(f"{out}/icon/logo.png")
    render(768, 0.95, False).save(f"{out}/splash/splash.png")
    render(1152, 0.8, False).save(f"{out}/splash/splash_android12.png")
    print("done")
