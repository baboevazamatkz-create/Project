#!/usr/bin/env python3
"""Draws the two pictures Google Play asks for before it will take a listing.

    store/graphics/play-icon-512.png     512x512, the store icon
    store/graphics/feature-graphic.png   1024x500, the banner at the top

Both are built from the same pieces as the launcher icon, so the store never
drifts from the phone: the mark comes out of generate_launcher_icon.py and
the wordmark is set in the same Playfair the app sets it in.

Screenshots are not here and cannot be: Play wants pictures of the app with
real content in it, and that means a phone.

Usage:
    python3 tool/generate_store_graphics.py

Requires Pillow.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_launcher_icon as icon  # noqa: E402

ROOT = icon.ROOT
OUT = os.path.join(ROOT, 'store', 'graphics')

PLAYFAIR = os.path.join(ROOT, 'fonts', 'PlayfairDisplay-SemiBold.ttf')
ONEST_LIGHT = os.path.join(ROOT, 'fonts', 'Onest-Light.ttf')

CHAMPAGNE = (200, 168, 107, 255)
INK = (242, 239, 233, 255)

FEATURE = (1024, 500)
SS = 2  # supersample, then come back down: the hairline needs it


def write_icon():
    """The store icon: the full square, since Play rounds it itself.

    Play draws its own rounded corners and its own shadow over whatever is
    given, so a pre-rounded plate would show a second, tighter corner inside
    theirs. The margin is narrower than the launcher's for the same reason
    -- nothing here crops to a circle.
    """
    art = icon.build_icon(512, margin_ratio=0.17, radius_ratio=0)
    path = os.path.join(OUT, 'play-icon-512.png')
    art.convert('RGB').save(path)
    return path


def _tracked(draw, xy, text, font, fill, tracking):
    """Draws text letter by letter, since Pillow has no letter-spacing.

    The wordmark is set wide in the app -- 12% of its size -- and set tight
    it stops being the same wordmark.
    """
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += draw.textlength(ch, font=font) + tracking
    return x - tracking


def _tracked_width(draw, text, font, tracking):
    total = sum(draw.textlength(ch, font=font) for ch in text)
    return total + tracking * (len(text) - 1)


def write_feature():
    """The banner: obsidian, the mark, the wordmark, the line under it.

    Play crops this one on some surfaces and overlays play controls on
    others, so everything sits well inside the frame and nothing important
    goes near an edge.
    """
    w, h = FEATURE[0] * SS, FEATURE[1] * SS
    img = Image.new('RGBA', (w, h))

    # The same fall the icon's plate has, turned on its side so the banner
    # reads as lit from the left rather than from above.
    ramp = Image.new('RGBA', (64, 1))
    px = ramp.load()
    for x in range(64):
        t = x / 63
        px[x, 0] = tuple(
            int(round(a + (b - a) * t))
            for a, b in zip((28, 26, 33, 255), (12, 11, 15, 255)))
    img.paste(ramp.resize((w, h), Image.BICUBIC))

    mark = icon.build_mark()
    mark = mark.crop(mark.getbbox())
    mark_h = int(h * 0.40)
    mark_w = int(mark.width * mark_h / mark.height)
    mark = mark.resize((mark_w, mark_h), Image.LANCZOS, reducing_gap=3.0)
    mark_x = int(w * 0.105)
    img.alpha_composite(mark, (mark_x, (h - mark_h) // 2))

    draw = ImageDraw.Draw(img)
    text_x = mark_x + mark_w + int(w * 0.060)

    name_size = int(h * 0.155)
    name_font = ImageFont.truetype(PLAYFAIR, name_size)
    tracking = name_size * 0.12
    name_y = int(h * 0.30)
    end_x = _tracked(draw, (text_x, name_y), 'SOLIDUS', name_font,
                     CHAMPAGNE, tracking)

    rule_y = name_y + int(name_size * 1.42)
    draw.line([(text_x, rule_y), (end_x, rule_y)],
              fill=CHAMPAGNE[:3] + (90,), width=max(1, SS))

    tag_size = int(h * 0.066)
    tag_font = ImageFont.truetype(ONEST_LIGHT, tag_size)
    draw.text((text_x, rule_y + int(tag_size * 0.62)),
              'Единый ритм малых финансов', font=tag_font, fill=INK)

    out = img.convert('RGB').resize(FEATURE, Image.LANCZOS, reducing_gap=3.0)
    path = os.path.join(OUT, 'feature-graphic.png')
    out.save(path)
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    for path in (write_icon(), write_feature()):
        size = os.path.getsize(path) / 1024
        with Image.open(path) as im:
            print(f'{os.path.relpath(path, ROOT)}  {im.width}x{im.height}  '
                  f'{size:.0f} KB  {im.mode}')


if __name__ == '__main__':
    main()
