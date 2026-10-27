#!/usr/bin/env python3
"""Draw the Herakili crest (a heater shield with an 'H', Classic gold on dark) as WoW textures.

Usage: python3 tools/make_logo.py [preview.png]
Writes Textures/HERAKILI.tga (256x256, front page and minimap) and, with an argument, a PNG preview.
Everything is drawn from geometry (no fonts or third-party art), so the crest is ours to license with the addon.
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 1024                      # drawing size; downsampled to 256 for smooth edges
OUT = 256

GOLD_HI = (250, 214, 110)
GOLD = (214, 160, 52)
GOLD_LO = (138, 92, 24)
FIELD_TOP = (40, 46, 62)
FIELD_BOTTOM = (16, 18, 26)


def shield(cx, top, w, h):
    """Heater shield outline: flat top with slightly rounded shoulders, sides curving to a point."""
    pts = []
    left, right = cx - w / 2, cx + w / 2
    shoulder = h * 0.42
    pts += [(left + w * 0.06, top), (right - w * 0.06, top)]
    for i in range(0, 11):                                  # top-right shoulder
        t = i / 10
        pts.append((right - w * 0.06 * (1 - t) ** 2, top + h * 0.06 * t))
    for i in range(0, 41):                                  # right side down to the point
        t = i / 40
        y = top + h * 0.06 + (shoulder - h * 0.06) * min(1, t * 2.2) + (h - shoulder) * max(0, (t - 0.45) / 0.55)
        x = right - (w / 2) * (max(0, (t - 0.35) / 0.65) ** 1.6)
        pts.append((x, y))
    pts.append((cx, top + h))
    mirrored = [(2 * cx - x, y) for (x, y) in reversed(pts[2:-1])]
    return pts + mirrored


def vertical_gradient(size, top, bottom):
    g = Image.new("RGBA", size)
    d = ImageDraw.Draw(g)
    for y in range(size[1]):
        t = y / (size[1] - 1)
        d.line([(0, y), (size[0], y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    return g


def masked(fill, mask):
    out = Image.new("RGBA", fill.size, (0, 0, 0, 0))
    out.paste(fill, (0, 0), mask)
    return out


def letter_h(cx, cy, size):
    """A serif capital H as polygons: two stems with slab serifs and a crossbar."""
    stem_w, gap, height = size * 0.17, size * 0.36, size
    serif_w, serif_h = size * 0.30, size * 0.075
    bar_h = size * 0.12
    top, bottom = cy - height / 2, cy + height / 2
    rects = []
    for sx in (cx - gap / 2 - stem_w, cx + gap / 2):
        rects.append((sx, top, sx + stem_w, bottom))
        scx = sx + stem_w / 2
        rects.append((scx - serif_w / 2, top, scx + serif_w / 2, top + serif_h))
        rects.append((scx - serif_w / 2, bottom - serif_h, scx + serif_w / 2, bottom))
    rects.append((cx - gap / 2 - 1, cy - bar_h / 2, cx + gap / 2 + 1, cy + bar_h / 2))
    return rects


def draw():
    cx, top, w, h = S / 2, S * 0.07, S * 0.80, S * 0.88
    outer = shield(cx, top, w, h)
    inner = shield(cx, top + S * 0.045, w - S * 0.09, h - S * 0.085)

    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Soft drop shadow so the crest reads on any background.
    shadow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shadow).polygon([(x, y + S * 0.015) for x, y in outer], fill=160)
    shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.02))
    img.paste(Image.new("RGBA", (S, S), (0, 0, 0, 255)), (0, 0), shadow)

    # Gold rim (gradient), then the dark field inside it.
    rim_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(rim_mask).polygon(outer, fill=255)
    img.alpha_composite(masked(vertical_gradient((S, S), GOLD_HI, GOLD_LO), rim_mask))

    field_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(field_mask).polygon(inner, fill=255)
    img.alpha_composite(masked(vertical_gradient((S, S), FIELD_TOP, FIELD_BOTTOM), field_mask))

    # Thin inner gold line.
    ImageDraw.Draw(img).line(inner + [inner[0]], fill=GOLD_LO + (255,), width=int(S * 0.008), joint="curve")

    # The H, with a darker bevel offset beneath it.
    hx, hy, hs = cx, top + h * 0.45, S * 0.46
    bevel = Image.new("L", (S, S), 0)
    bd = ImageDraw.Draw(bevel)
    for r in letter_h(hx + S * 0.008, hy + S * 0.012, hs):
        bd.rectangle(r, fill=255)
    img.alpha_composite(masked(Image.new("RGBA", (S, S), GOLD_LO + (255,)), bevel))

    face = Image.new("L", (S, S), 0)
    fd = ImageDraw.Draw(face)
    for r in letter_h(hx, hy, hs):
        fd.rectangle(r, fill=255)
    img.alpha_composite(masked(vertical_gradient((S, S), GOLD_HI, GOLD), face))

    return img.resize((OUT, OUT), Image.LANCZOS)


if __name__ == "__main__":
    logo = draw()
    logo.save("Textures/HERAKILI.tga")
    if len(sys.argv) > 1:
        bg = Image.new("RGBA", (OUT * 2 + 48, OUT + 32), (0, 0, 0, 0))
        dark = Image.new("RGBA", (OUT + 16, OUT + 32), (30, 30, 30, 255))
        light = Image.new("RGBA", (OUT + 16, OUT + 32), (225, 225, 225, 255))
        bg.paste(dark, (0, 0)); bg.paste(light, (OUT + 32, 0))
        bg.alpha_composite(logo, (8, 16)); bg.alpha_composite(logo, (OUT + 40, 16))
        small = logo.resize((32, 32), Image.LANCZOS)
        bg.alpha_composite(small, (OUT - 32, OUT - 24))           # minimap-size check
        bg.save(sys.argv[1])
    print("wrote Textures/HERAKILI.tga")
