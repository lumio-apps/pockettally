import sys
from PIL import Image, ImageDraw

OUT = sys.argv[1]
SS = 4  # supersampling

TEAL = (31, 122, 99, 255)
TEAL_TOP = (42, 157, 127)
TEAL_BOTTOM = (22, 100, 80)
WHITE = (255, 255, 255, 255)
AMBER = (242, 179, 61, 255)
STITCH = (31, 122, 99, 150)


def gradient(size):
    img = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(a + (b - a) * t) for a, b in zip(TEAL_TOP, TEAL_BOTTOM))
        d.line([(0, y), (size, y)], fill=c + (255,))
    return img


import math


def cap_line(d, p1, p2, w, fill):
    """Thick line with round caps, drawn as a polygon so edges stay clean."""
    (x1, y1), (x2, y2) = p1, p2
    r = w / 2
    L = math.hypot(x2 - x1, y2 - y1) or 1
    nx, ny = -(y2 - y1) / L * r, (x2 - x1) / L * r
    d.polygon([(x1 + nx, y1 + ny), (x2 + nx, y2 + ny), (x2 - nx, y2 - ny), (x1 - nx, y1 - ny)], fill=fill)
    for (x, y) in (p1, p2):
        d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def rounded_poly(d, pts, r, fill):
    """Polygon with smooth filleted corners (quadratic curve at each vertex)."""
    out = []
    n = len(pts)
    for i in range(n):
        a, v, b = pts[i - 1], pts[i], pts[(i + 1) % n]
        def toward(p):
            L = math.hypot(p[0] - v[0], p[1] - v[1])
            k = min(r, L / 2) / L
            return (v[0] + (p[0] - v[0]) * k, v[1] + (p[1] - v[1]) * k)
        t1, t2 = toward(a), toward(b)
        for j in range(17):
            t = j / 16
            x = (1 - t) ** 2 * t1[0] + 2 * (1 - t) * t * v[0] + t * t * t2[0]
            y = (1 - t) ** 2 * t1[1] + 2 * (1 - t) * t * v[1] + t * t * t2[1]
            out.append((x, y))
    d.polygon(out, fill=fill)


def artwork(layer, cx, cy, box):
    """Draw the pocket + tally mark artwork into layer, centred, in a box of size `box`."""
    d = ImageDraw.Draw(layer)
    ox, oy = cx - box / 2, cy - box / 2
    P = lambda x, y: (ox + x * box, oy + y * box)
    r = 0.07 * box
    pocket = [P(0.12, 0.08), P(0.88, 0.08), P(0.85, 0.70), P(0.50, 0.93), P(0.15, 0.70)]
    rounded_poly(d, pocket, r, WHITE)

    # stitching along the top hem
    y = 0.22
    x = 0.20
    while x < 0.79:
        cap_line(d, P(x, y), P(min(x + 0.045, 0.80), y), 0.018 * box, STITCH)
        x += 0.075

    # four tally marks
    w = 0.062 * box
    for tx in (0.32, 0.43, 0.54, 0.65):
        cap_line(d, P(tx, 0.34), P(tx, 0.66), w, TEAL)
    # the fifth mark, a diagonal strike in amber
    cap_line(d, P(0.25, 0.62), P(0.73, 0.38), w, AMBER)


def render(size, box_frac, background, rounded=False):
    big = size * SS
    if background:
        base = gradient(big)
    else:
        base = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    art = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    artwork(art, big / 2, big / 2 + big * 0.01, big * box_frac)
    base = Image.alpha_composite(base, art)
    if rounded:
        mask = Image.new("L", (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * 0.22), fill=255)
        out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        out.paste(base, (0, 0), mask)
        base = out
    return base.resize((size, size), Image.LANCZOS)


render(1024, 0.62, True).save(f"{OUT}/icon/icon.png")
render(1024, 0.52, False).save(f"{OUT}/icon/icon_foreground.png")
render(1024, 0.62, True, rounded=True).save(f"{OUT}/icon/logo.png")
render(768, 0.80, False).save(f"{OUT}/splash/splash.png")
render(1152, 0.50, False).save(f"{OUT}/splash/splash_android12.png")
print("done")
