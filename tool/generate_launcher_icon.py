#!/usr/bin/env python3
"""Regenerates the app icon: the wallet-with-a-question-mark, in champagne.

The icon is drawn geometrically rather than stored as a source image, so it
can be re-rendered at any density without hunting for the original artwork.
Everything is composed at 4x and downsampled, which keeps the curves clean at
launcher sizes.

The design is the "metal" reading of the mark: an open wallet with a card
peeking out, its front pocket filled with a champagne-to-gold gradient and a
light bevel along the rim, and the question mark knocked out of the pocket so
the plate shows through it. The plate is obsidian on every surface -- Android
and iOS do not swap icons with the system theme, so the mark commits to one
background, and gold reads better on dark among other apps' bright icons.

Unlike the previous green icon, the plate is part of the artwork. That makes
an adaptive icon possible (it needs an opaque background layer), so this
writes one: a solid obsidian background resource plus a foreground layer
drawn inside the 66% safe zone launchers may crop to.

Usage:
    python3 tool/generate_launcher_icon.py            # Android icons
    python3 tool/generate_launcher_icon.py --web      # ... and the PWA set
    python3 tool/generate_launcher_icon.py --preview out.png

Requires Pillow. The question mark is set in the app's own bundled Onest, so
no external font is needed.
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

S = 1024          # nominal icon size
SS = 4            # supersampling factor
N = S * SS

FONT = os.path.join(ROOT, 'fonts', 'Onest-SemiBold.ttf')

# The app's palette. Names match lib/theme.dart where they overlap.
OBSIDIAN = (20, 19, 24, 255)      # #141318  the plate
CHAMPAGNE = (224, 196, 137, 255)  # #E0C489  the lit corner of the pocket
GOLD = (154, 123, 68, 255)        # #9A7B44  its shadowed corner, and the lid
CAVITY = (107, 84, 48, 255)       # #6B5430  the shadowed inside
CARD = (246, 242, 234, 255)       # #F6F2EA  the card peeking out

PLATE_RADIUS = 0.24               # of the icon's width, matching iOS/Android
SPLASH_MARK_DP = 96               # how big the mark sits on the launch window
DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}

# Geometry in a 0..100 square, the same coordinates the design was drawn in.
LID = (15, 16, 85, 48, 7)         # x0, y0, x1, y1, radius
CARD_BOX = (19, 22, 81, 47, 4)
CAVITY_BOX = (8, 30, 92, 47, 5)
FRONT = (6, 40, 94, 92, 11)
LID_TILT, CARD_TILT = 5.0, -3.0
MARK_CENTRE, MARK_HEIGHT = (50.0, 65.4), 27.0


def _s(v):
    return v * N / 100.0


def _layer():
    return Image.new('RGBA', (N, N), (0, 0, 0, 0))


def _rounded(img, box, fill):
    x0, y0, x1, y1, r = box
    ImageDraw.Draw(img).rounded_rectangle(
        [_s(x0), _s(y0), _s(x1), _s(y1)], radius=_s(r), fill=fill)


def _tilt(img, degrees, centre=(50.0, 47.5)):
    return img.rotate(-degrees, resample=Image.BICUBIC,
                      center=(_s(centre[0]), _s(centre[1])))


def _stack(*layers):
    out = _layer()
    for one in layers:
        out = Image.alpha_composite(out, one)
    return out


def _gradient(start, end):
    """A diagonal ramp from `start` at the top-left to `end` at the bottom-right."""
    # Built small and scaled up: the ramp is linear, so interpolation is exact
    # and this avoids allocating a million-pixel gradient per channel.
    small = Image.new('RGBA', (64, 64))
    px = small.load()
    for y in range(64):
        for x in range(64):
            t = (x + y) / 126.0
            px[x, y] = tuple(
                int(round(a + (b - a) * t)) for a, b in zip(start, end))
    return small.resize((N, N), Image.BICUBIC)


def _mark_font(draw, height):
    """Onest sized so the '?' ink box is exactly `height` (in 0..100 units) tall."""
    target = _s(height)
    size = int(target)
    for _ in range(40):
        font = ImageFont.truetype(FONT, size)
        box = draw.textbbox((0, 0), '?', font=font)
        drawn = box[3] - box[1]
        if abs(drawn - target) <= _s(0.1):
            break
        size = max(1, int(round(size * target / max(drawn, 1))))
    return ImageFont.truetype(FONT, size)


def _question_mark(fill):
    """The '?' alone, ink-centred on MARK_CENTRE."""
    mark = _layer()
    draw = ImageDraw.Draw(mark)
    font = _mark_font(draw, MARK_HEIGHT)
    box = draw.textbbox((0, 0), '?', font=font)
    draw.text((_s(MARK_CENTRE[0]) - (box[0] + box[2]) / 2,
               _s(MARK_CENTRE[1]) - (box[1] + box[3]) / 2),
              '?', font=font, fill=fill)
    return mark


def build_mark():
    """The wallet on a transparent square, at N x N."""
    lid = _layer()
    _rounded(lid, LID, GOLD)
    lid = _tilt(lid, LID_TILT)

    cavity = _layer()
    _rounded(cavity, CAVITY_BOX, CAVITY)

    card = _layer()
    _rounded(card, CARD_BOX, CARD)
    card = _tilt(card, CARD_TILT)

    # The pocket is the gradient seen through a mask: the pocket's silhouette
    # minus the question mark, so the mark is a hole rather than white ink.
    shape = Image.new('L', (N, N), 0)
    _rounded(shape, FRONT, 255)
    hole = _question_mark((255, 255, 255, 255)).getchannel('A')
    shape.paste(0, mask=hole)
    pocket = _layer()
    pocket.paste(_gradient(CHAMPAGNE, GOLD), mask=shape)

    # A light bevel just inside the rim, the way a milled edge catches light.
    bevel = _layer()
    x0, y0, x1, y1, r = FRONT
    ImageDraw.Draw(bevel).rounded_rectangle(
        [_s(x0 + 0.9), _s(y0 + 0.9), _s(x1 - 0.9), _s(y1 - 0.9)],
        radius=_s(r - 0.9), outline=CHAMPAGNE[:3] + (140,), width=int(_s(0.8)))
    bevel.paste((0, 0, 0, 0), mask=hole)

    return _stack(lid, cavity, card, pocket, bevel)


def build_icon(size, radius_ratio=PLATE_RADIUS, plate=OBSIDIAN, inset=0.0):
    """The finished icon: the mark on an obsidian plate, downsampled to `size`.

    `inset` shrinks the artwork inside the plate, for the maskable and iOS
    variants whose plates get cropped or rounded by the platform.
    """
    canvas = _layer()
    if radius_ratio <= 0:
        ImageDraw.Draw(canvas).rectangle([0, 0, N, N], fill=plate)
    else:
        ImageDraw.Draw(canvas).rounded_rectangle(
            [0, 0, N - 1, N - 1], radius=int(N * radius_ratio), fill=plate)

    art = build_mark()
    if inset > 0:
        inner = int(N * (1 - 2 * inset))
        art = art.resize((inner, inner), Image.LANCZOS, reducing_gap=3.0)
        placed = _layer()
        placed.paste(art, ((N - inner) // 2, (N - inner) // 2))
        art = placed

    return _stack(canvas, art).resize((size, size), Image.LANCZOS,
                                      reducing_gap=3.0)


def build_adaptive_foreground(size):
    """The mark alone, inside the 66% an adaptive icon guarantees is visible.

    Launchers crop an adaptive layer to any shape inside the middle 72 of its
    108 units, so the artwork is scaled to that safe circle and the rest of
    the layer stays transparent.
    """
    inner = int(N * 72 / 108)
    art = build_mark().resize((inner, inner), Image.LANCZOS, reducing_gap=3.0)
    out = _layer()
    out.paste(art, ((N - inner) // 2, (N - inner) // 2))
    return out.resize((size, size), Image.LANCZOS, reducing_gap=3.0)


ADAPTIVE_XML = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_launcher_icon.py -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'''

BACKGROUND_XML = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_launcher_icon.py -->
<resources>
    <color name="ic_launcher_background">#141318</color>
</resources>
'''


def write_android(root):
    res = os.path.join(root, 'android', 'app', 'src', 'main', 'res')
    written = []

    for bucket, px in DENSITIES.items():
        folder = os.path.join(res, f'mipmap-{bucket}')
        os.makedirs(folder, exist_ok=True)

        legacy = os.path.join(folder, 'ic_launcher.png')
        build_icon(px).save(legacy, optimize=True)
        written.append((bucket, px, legacy))

        # The adaptive foreground is authored at 108/72 of the nominal size,
        # which is what the launcher expects to crop from.
        fg = os.path.join(folder, 'ic_launcher_foreground.png')
        build_adaptive_foreground(int(round(px * 108 / 48))).save(
            fg, optimize=True)
        written.append((bucket, int(round(px * 108 / 48)), fg))

    anydpi = os.path.join(res, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    for name, body in (('ic_launcher.xml', ADAPTIVE_XML),
                       ('ic_launcher_round.xml', ADAPTIVE_XML)):
        path = os.path.join(anydpi, name)
        with open(path, 'w') as handle:
            handle.write(body)
        written.append(('anydpi', 0, path))

    path = os.path.join(res, 'values', 'ic_launcher_background.xml')
    with open(path, 'w') as handle:
        handle.write(BACKGROUND_XML)
    written.append(('values', 0, path))

    # The mark alone, for the window Android paints before Flutter starts.
    # Written per density so the bitmap lands at SPLASH_MARK_DP on every
    # screen; a single drawable would draw at its own pixel size instead.
    mark = build_mark()
    for bucket, px in DENSITIES.items():
        folder = os.path.join(res, f'drawable-{bucket}')
        os.makedirs(folder, exist_ok=True)
        side = int(round(SPLASH_MARK_DP * px / 48))
        path = os.path.join(folder, 'brand_mark.png')
        mark.resize((side, side), Image.LANCZOS, reducing_gap=3.0).save(
            path, optimize=True)
        written.append((bucket, side, path))

    return written


def write_flutter_asset(root):
    """The mark as a Flutter asset, for the gate screen's own loading state."""
    folder = os.path.join(root, 'assets')
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, 'brand_mark.png')
    build_mark().resize((512, 512), Image.LANCZOS, reducing_gap=3.0).save(
        path, optimize=True)
    return path


def write_web(root):
    web = os.path.join(root, 'web')
    icons = os.path.join(web, 'icons')
    os.makedirs(icons, exist_ok=True)
    written = []

    def save(img, path):
        img.save(path, optimize=True)
        written.append(path)

    save(build_icon(32), os.path.join(web, 'favicon.png'))
    for size in (192, 512):
        save(build_icon(size), os.path.join(icons, f'Icon-{size}.png'))

    # Maskable: a full-bleed square, artwork well inside the circle launchers
    # may crop to. iOS rounds the corners itself, so its icon is square too.
    for size in (192, 512):
        save(build_icon(size, radius_ratio=0, inset=0.14),
             os.path.join(icons, f'Icon-maskable-{size}.png'))
    save(build_icon(180, radius_ratio=0, inset=0.06),
         os.path.join(icons, 'apple-touch-icon-180.png'))

    return written


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview', metavar='PATH',
                        help='write a single 1024px PNG here instead of '
                             'updating the project icons')
    parser.add_argument('--web', action='store_true',
                        help='also refresh the PWA icons under web/')
    args = parser.parse_args()

    if args.preview:
        build_icon(1024).save(args.preview)
        print('wrote', args.preview)
        return

    for bucket, px, path in write_android(ROOT):
        print(f'{bucket:8} {px:4}px  {os.path.relpath(path, ROOT)}')
    asset = write_flutter_asset(ROOT)
    print(f'flutter   512px  {os.path.relpath(asset, ROOT)}')
    if args.web:
        for path in write_web(ROOT):
            size = Image.open(path).size[0]
            print(f'web      {size:4}px  {os.path.relpath(path, ROOT)}')


if __name__ == '__main__':
    main()
