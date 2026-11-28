#!/usr/bin/env python3
"""Draws the store art (experience icon and thumbnails) with Pillow: our own cube pets, a trophy,
stacked desk-book platforms and a title. Run: python tools/gen_store_art.py  (needs Pillow).

Writes assets/store/icon.png (512x512) and assets/store/thumb_1..3.png (1920x1080). The art is drawn
from scratch; only the general cute-cube-pet genre style is shared with other games.
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "store")
FONT = "C:/Windows/Fonts/impact.ttf"

random.seed(7)


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def gradient(size, stops, angle=35):
    """Diagonal multi-stop gradient."""
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    span = abs(w * ca) + abs(h * sa)
    for y in range(h):
        for x in range(w):
            t = ((x * ca + y * sa) / span) % 1.0 if False else (x * ca + y * sa) / span
            t = min(1, max(0, t))
            seg = t * (len(stops) - 1)
            i = min(int(seg), len(stops) - 2)
            f = seg - i
            c0, c1 = stops[i], stops[i + 1]
            px[x, y] = tuple(int(c0[k] + (c1[k] - c0[k]) * f) for k in range(3))
    return img


def star(d, cx, cy, r, color):
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy - rr * math.sin(a)))
    d.polygon(pts, fill=color)


def rr(d, box, **kw):
    x0, y0, x1, y1 = box
    d.rounded_rectangle([min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)], **kw)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def pet(img, cx, cy, s, color, kind, tilt=0):
    """A rounded cube pet centred at (cx, cy), side s, drawn onto img."""
    layer = Image.new("RGBA", (int(s * 2.4), int(s * 2.4)), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ox, oy = layer.width / 2, layer.height / 2
    r = s * 0.24
    dark = shade(color, 0.62)
    light = shade(color, 1.22)
    outline = shade(color, 0.45)
    # shadow
    d.ellipse([ox - s * 0.55, oy + s * 0.5, ox + s * 0.55, oy + s * 0.68], fill=(0, 0, 0, 60))
    # ears / species parts behind the body
    if kind == "bunny":
        for sx in (-1, 1):
            rr(d, [ox + sx * s * 0.22 - s * 0.11, oy - s * 1.08, ox + sx * s * 0.22 + s * 0.11, oy - s * 0.3], radius=s * 0.1, fill=color, outline=outline, width=4)
            rr(d, [ox + sx * s * 0.22 - s * 0.05, oy - s * 0.98, ox + sx * s * 0.22 + s * 0.05, oy - s * 0.4], radius=s * 0.05, fill=(255, 190, 205))
    elif kind in ("cat", "pup"):
        for sx in (-1, 1):
            if kind == "cat":
                d.polygon([(ox + sx * s * 0.42, oy - s * 0.42), (ox + sx * s * 0.2, oy - s * 0.78), (ox + sx * s * 0.05, oy - s * 0.42)], fill=color, outline=outline)
            else:
                rr(d, [ox + sx * s * 0.45, oy - s * 0.4, ox + sx * s * 0.68, oy + s * 0.1], radius=s * 0.1, fill=dark, outline=outline, width=4)
    elif kind == "dino":
        for i in range(3):
            xx = ox + (i - 1) * s * 0.28
            d.polygon([(xx - s * 0.11, oy - s * 0.46), (xx, oy - s * 0.72), (xx + s * 0.11, oy - s * 0.46)], fill=dark, outline=outline)
    elif kind == "dragon":
        for sx in (-1, 1):
            d.polygon([(ox + sx * s * 0.48, oy - s * 0.1), (ox + sx * s * 0.98, oy - s * 0.46), (ox + sx * s * 0.95, oy + s * 0.12)], fill=dark, outline=outline)
            d.polygon([(ox + sx * s * 0.3, oy - s * 0.46), (ox + sx * s * 0.22, oy - s * 0.8), (ox + sx * s * 0.42, oy - s * 0.46)], fill=(255, 225, 130), outline=outline)
    # feet
    for sx in (-1, 1):
        d.ellipse([ox + sx * s * 0.3 - s * 0.15, oy + s * 0.38, ox + sx * s * 0.3 + s * 0.15, oy + s * 0.62], fill=dark, outline=outline, width=3)
    # body: rounded cube with a soft highlight
    d.rounded_rectangle([ox - s / 2, oy - s / 2, ox + s / 2, oy + s / 2], radius=r, fill=color, outline=outline, width=5)
    d.rounded_rectangle([ox - s / 2 + 9, oy - s / 2 + 9, ox + s / 2 - 9, oy - s / 2 + s * 0.32], radius=r * 0.6, fill=light)
    d.rounded_rectangle([ox - s * 0.34, oy + s * 0.08, ox + s * 0.34, oy + s * 0.42], radius=r * 0.6, fill=light)
    # face: big dark eyes with highlights, cheeks, nose, smile
    for sx in (-1, 1):
        ex, ey = ox + sx * s * 0.24, oy - s * 0.02
        d.ellipse([ex - s * 0.15, ey - s * 0.17, ex + s * 0.15, ey + s * 0.17], fill=(28, 24, 48))
        d.ellipse([ex - s * 0.1 - s * 0.03, ey - s * 0.12, ex - s * 0.03 + s * 0.02, ey - s * 0.03], fill=(255, 255, 255))
        d.ellipse([ex + s * 0.03, ey + s * 0.03, ex + s * 0.08, ey + s * 0.08], fill=(255, 255, 255))
        d.ellipse([ox + sx * s * 0.4 - s * 0.08, oy + s * 0.12, ox + sx * s * 0.4 + s * 0.08, oy + s * 0.22], fill=(255, 140, 165))
    d.ellipse([ox - s * 0.04, oy + s * 0.12, ox + s * 0.04, oy + s * 0.19], fill=(40, 30, 45))
    d.arc([ox - s * 0.12, oy + s * 0.12, ox, oy + s * 0.26], 20, 160, fill=(40, 30, 45), width=4)
    d.arc([ox, oy + s * 0.12, ox + s * 0.12, oy + s * 0.26], 20, 160, fill=(40, 30, 45), width=4)
    if kind == "cat":
        for sx in (-1, 1):
            for k in (-1, 0, 1):
                d.line([(ox + sx * s * 0.5, oy + s * 0.18 + k * s * 0.04), (ox + sx * s * 0.78, oy + s * 0.14 + k * s * 0.09)], fill=(240, 240, 245), width=3)
    if kind == "pup":
        d.rounded_rectangle([ox - s * 0.04, oy + s * 0.22, ox + s * 0.05, oy + s * 0.32], radius=6, fill=(255, 120, 150))
    layer = layer.rotate(tilt, resample=Image.BICUBIC)
    img.paste(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)), layer)


def trophy(img, cx, cy, h):
    d = ImageDraw.Draw(img)
    gold, dark, light = (255, 200, 60), (200, 140, 30), (255, 235, 140)
    w = h * 0.62
    # plinth
    d.rounded_rectangle([cx - w * 0.55, cy + h * 0.38, cx + w * 0.55, cy + h * 0.5], radius=8, fill=(40, 46, 100), outline=(18, 20, 50), width=4)
    d.rectangle([cx - w * 0.5, cy + h * 0.36, cx + w * 0.5, cy + h * 0.4], fill=gold)
    d.rounded_rectangle([cx - w * 0.36, cy + h * 0.3, cx + w * 0.36, cy + h * 0.38], radius=6, fill=dark, outline=(120, 80, 10), width=3)
    # stem
    d.rectangle([cx - w * 0.07, cy + h * 0.02, cx + w * 0.07, cy + h * 0.32], fill=gold, outline=dark, width=3)
    # handles
    for sx in (-1, 1):
        d.arc([cx + sx * w * 0.42 - w * 0.2, cy - h * 0.3, cx + sx * w * 0.42 + w * 0.2, cy + h * 0.02], 270 if sx > 0 else 90, 90 if sx > 0 else 270, fill=gold, width=int(h * 0.05))
    # cup
    d.pieslice([cx - w * 0.5, cy - h * 0.5, cx + w * 0.5, cy + h * 0.26], 0, 180, fill=gold, outline=dark, width=4)
    d.rectangle([cx - w * 0.5, cy - h * 0.5, cx + w * 0.5, cy - h * 0.12], fill=gold, outline=dark, width=4)
    d.ellipse([cx - w * 0.5, cy - h * 0.56, cx + w * 0.5, cy - h * 0.44], fill=light, outline=dark, width=4)
    d.rounded_rectangle([cx - w * 0.38, cy - h * 0.46, cx - w * 0.28, cy - h * 0.1], radius=6, fill=light)
    star(d, cx, cy - h * 0.2, h * 0.14, (255, 250, 210))


def platforms(img, x, y, count, w, h, gap, rise, colors):
    d = ImageDraw.Draw(img)
    for i in range(count):
        px, py = x + i * (w + gap), y - i * rise
        c = colors[i % len(colors)]
        d.rounded_rectangle([px, py + 10, px + w, py + h + 10], radius=14, fill=shade(c, 0.45))
        d.rounded_rectangle([px, py, px + w, py + h], radius=14, fill=c, outline=shade(c, 0.5), width=4)
        d.rounded_rectangle([px + 10, py + 6, px + w - 10, py + h * 0.4], radius=8, fill=shade(c, 1.2))


def laser(img, x, y0, y1):
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.line([(x, y0), (x, y1)], fill=(255, 40, 60, 255), width=26)
    glow = glow.filter(ImageFilter.GaussianBlur(14))
    img.paste(glow, (0, 0), glow)
    d = ImageDraw.Draw(img)
    d.line([(x, y0), (x, y1)], fill=(255, 90, 100), width=10)
    d.line([(x, y0), (x, y1)], fill=(255, 235, 235), width=3)
    for yy in (y0, y1):
        d.rounded_rectangle([x - 16, yy - 14, x + 16, yy + 14], radius=6, fill=(30, 34, 70))


def text_outline(img, xy, text, size, fill, stroke=10, anchor="mm", outline=(18, 20, 50)):
    d = ImageDraw.Draw(img)
    f = font(size)
    d.text(xy, text, font=f, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=outline)


def background(size, stars=40):
    img = gradient(size, [(255, 160, 40), (235, 70, 130), (90, 70, 200)], angle=35).convert("RGBA")
    d = ImageDraw.Draw(img)
    for _ in range(stars):
        star(d, random.randint(0, size[0]), random.randint(0, size[1]), random.randint(8, 30) * size[0] / 1920 + 4, (255, 240, 170, 110))
    return img


def make_icon():
    size = (512, 512)
    img = background(size, 18)
    trophy(img, 256, 196, 250)
    pet(img, 150, 360, 150, (255, 205, 70), "cat", -6)
    pet(img, 362, 366, 140, (255, 140, 170), "bunny", 7)
    pet(img, 256, 410, 96, (230, 70, 80), "dino", 0)
    img.convert("RGB").save(os.path.join(OUT, "icon.png"))


def make_thumb(index):
    size = (1920, 1080)
    img = background(size, 60)
    d = ImageDraw.Draw(img)
    if index == 1:
        # hero: title, trophy and the pet crew
        text_outline(img, (960, 150), "MINI CHAMPIONS", 190, (255, 235, 120), 14)
        text_outline(img, (960, 285), "TINY HEROES. GIANT ADVENTURES!", 70, (255, 255, 255), 8)
        trophy(img, 960, 640, 520)
        pet(img, 470, 780, 300, (255, 205, 70), "cat", -5)
        pet(img, 1450, 790, 290, (255, 140, 170), "bunny", 5)
        pet(img, 250, 600, 190, (230, 70, 80), "dino", -8)
        pet(img, 1690, 590, 190, (150, 110, 240), "dragon", 8)
        pet(img, 700, 900, 150, (255, 160, 70), "pup", 0)
        pet(img, 1230, 905, 150, (190, 205, 225), "bunny", 0)
    elif index == 2:
        # the course: stepping platforms, lasers and a runner pet
        text_outline(img, (960, 120), "JUMP. DODGE. CLIMB!", 150, (255, 235, 120), 12)
        platforms(img, 140, 880, 7, 220, 70, 40, 85, [(120, 90, 210), (60, 160, 230), (70, 190, 120), (240, 90, 90)])
        laser(img, 560, 560, 760)
        laser(img, 1040, 420, 640)
        pet(img, 400, 720, 150, (255, 205, 70), "cat", -8)
        trophy(img, 1680, 450, 330)
        text_outline(img, (960, 1000), "TWO HUGE TRACKS - LASERS - SPINNERS - A SKY TOWER", 56, (255, 255, 255), 7)
    else:
        # collect: the pet lineup
        text_outline(img, (960, 130), "COLLECT CUTE PETS!", 160, (255, 235, 120), 12)
        kinds = [("bug", (190, 200, 215)), ("bunny", (255, 150, 170)), ("pup", (255, 190, 80)), ("cat", (255, 225, 100)), ("dino", (230, 70, 80)), ("dragon", (140, 100, 230))]
        for i, (k, c) in enumerate(kinds):
            x = 230 + i * 292
            y = 640 + (i % 2) * 70
            pet(img, x, y, 220, c, k if k != "bug" else "bunny", (-1) ** i * 5)
        text_outline(img, (960, 960), "EARN STARS - BUILD YOUR CLUB - EQUIP YOUR FAVORITE", 60, (255, 255, 255), 7)
    img.convert("RGB").save(os.path.join(OUT, f"thumb_{index}.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    make_icon()
    for i in (1, 2, 3):
        make_thumb(i)
    print("written to", OUT, sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
