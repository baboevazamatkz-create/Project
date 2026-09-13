#!/usr/bin/env python3
"""Regenerates the app icon: the wallet-with-a-question-mark, in champagne.

The icon is drawn geometrically rather than stored as a source image, so it
can be re-rendered at any density without hunting for the original artwork.
Everything is composed at 4x and downsampled, which keeps the curves clean at
launcher sizes.

The design is the "stack": three rounded bars, each shorter than the one
above it, reading at once as the bars of a chart and as a stack of notes.
Each bar is a step down the champagne ramp rather than the same gold at
falling opacity -- opacity would let a light wallpaper wash the lower two
out, and this icon has no plate of its own to sit on.

The mark sits on an obsidian plate -- the same #141318 the app's dark room
is painted in, with a slight fall from top to bottom so it reads as a
surface rather than a flat swatch. Transparent looked unfinished against a
busy wallpaper, and the plate is what lets the three bars keep the same
contrast wherever the icon lands.

Because the plate is opaque, the adaptive icon Android wants is possible
and is generated: a solid obsidian background layer plus a foreground drawn
inside the 66% safe zone launchers may crop to. Without one, a launcher
shrinks the legacy PNG into a white shim of its own, which is the look the
plate exists to avoid.

Usage:
    python3 tool/generate_launcher_icon.py            # Android icons
    python3 tool/generate_launcher_icon.py --web      # ... and the PWA set
    python3 tool/generate_launcher_icon.py --preview out.png

Requires Pillow, and nothing else -- the mark is pure geometry.
"""
import argparse
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

S = 1024          # nominal icon size
SS = 4            # supersampling factor
N = S * SS

# The app's palette. Names match lib/theme.dart where they overlap.
OBSIDIAN = (20, 19, 24, 255)      # #141318  the one opaque backdrop
CHAMPAGNE = (224, 196, 137, 255)  # #E0C489  the top bar
GOLD = (154, 123, 68, 255)        # #9A7B44  the bottom one

PLATE_TOP = (26, 25, 31, 255)     # a touch lifted, so the plate has a top
PLATE_BOTTOM = (12, 11, 15, 255)  # and a bottom
PLATE_RADIUS = 0.235              # of the icon's width, matching iOS/Android
MARK_MARGIN = 0.20                # the stack's breathing room inside the plate

SPLASH_MARK_DP = 112              # how big the icon sits on the launch window
DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}

# Geometry in a 0..100 square, the same coordinates the design was drawn in.
# Three bars, left-aligned, each a step shorter and a step darker.
BAR_HEIGHT = 15.0
BAR_GAP = 7.5
BAR_LEFT = 10.0
BAR_RADIUS = 7.5
BAR_WIDTHS = (80.0, 58.0, 36.0)
BAR_TOP = 50 - (3 * BAR_HEIGHT + 2 * BAR_GAP) / 2

def _s(v):
    return v * N / 100.0


def _layer():
    return Image.new('RGBA', (N, N), (0, 0, 0, 0))


def build_mark():
    """The stack on a transparent square, at N x N."""
    mark = _layer()
    draw = ImageDraw.Draw(mark)
    for index, width in enumerate(BAR_WIDTHS):
        top = BAR_TOP + index * (BAR_HEIGHT + BAR_GAP)
        draw.rounded_rectangle(
            [_s(BAR_LEFT), _s(top), _s(BAR_LEFT + width), _s(top + BAR_HEIGHT)],
            radius=_s(BAR_RADIUS),
            fill=_step(index, len(BAR_WIDTHS)),
        )
    return mark


def _step(index, count):
    """Bar `index` of `count`, stepped down the champagne-to-gold ramp."""
    t = index / max(count - 1, 1)
    return tuple(
        int(round(a + (b - a) * t)) for a, b in zip(CHAMPAGNE, GOLD))


def _centre(img, margin_ratio=0.05):
    """Centres the artwork in the square with an even margin on its long axis.

    With no plate to sit on, the mark has to provide its own margins, so it
    is cropped to its ink and rescaled rather than left wherever the geometry
    happened to put it.
    """
    art = img.crop(img.getbbox())
    available = N - 2 * int(N * margin_ratio)
    scale = available / max(art.width, art.height)
    art = art.resize((int(art.width * scale), int(art.height * scale)),
                     Image.LANCZOS, reducing_gap=3.0)
    out = _layer()
    out.paste(art, ((N - art.width) // 2, (N - art.height) // 2))
    return out


def _plate(radius_ratio=PLATE_RADIUS):
    """The obsidian ground, with a slight fall from top to bottom.

    Built as a one-pixel-wide ramp and scaled up: the gradient is linear,
    so interpolation reproduces it exactly and nothing large is allocated.
    """
    ramp = Image.new('RGBA', (1, 64))
    px = ramp.load()
    for y in range(64):
        t = y / 63
        px[0, y] = tuple(
            int(round(a + (b - a) * t)) for a, b in zip(PLATE_TOP, PLATE_BOTTOM))
    ramp = ramp.resize((N, N), Image.BICUBIC)

    out = _layer()
    if radius_ratio <= 0:
        out.paste(ramp)
        return out
    mask = Image.new('L', (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, N - 1, N - 1], radius=int(N * radius_ratio), fill=255)
    out.paste(ramp, mask=mask)
    return out


def build_icon(size, margin_ratio=MARK_MARGIN, radius_ratio=PLATE_RADIUS):
    """The finished icon: the stack on its plate."""
    art = Image.alpha_composite(
        _plate(radius_ratio), _centre(build_mark(), margin_ratio))
    return art.resize((size, size), Image.LANCZOS, reducing_gap=3.0)


def build_full_bleed(size, margin_ratio):
    """A square plate with no rounded corners, for the two places that crop.

    A maskable icon needs a wide inset: launchers may crop up to 20% off
    every edge, so the artwork has to sit inside the middle circle. iOS
    rounds the corners itself, so its icon is square too.
    """
    return build_icon(size, margin_ratio=margin_ratio, radius_ratio=0)


def build_adaptive_foreground(size):
    """The mark alone, inside the 66% an adaptive icon guarantees is visible.

    Launchers crop an adaptive layer to any shape inside the middle 72 of
    its 108 units, so the artwork is scaled to that safe circle and the rest
    of the layer stays transparent -- the obsidian comes from the background
    layer, which is a colour resource rather than a second PNG.
    """
    inner = int(N * 72 / 108)
    art = _centre(build_mark(), 0.0).resize(
        (inner, inner), Image.LANCZOS, reducing_gap=3.0)
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
        adaptive = int(round(px * 108 / 48))
        path = os.path.join(folder, 'ic_launcher_foreground.png')
        build_adaptive_foreground(adaptive).save(path, optimize=True)
        written.append((bucket, adaptive, path))

    anydpi = os.path.join(res, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    for name in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        path = os.path.join(anydpi, name)
        with open(path, 'w') as handle:
            handle.write(ADAPTIVE_XML)
        written.append(('anydpi', 0, path))

    path = os.path.join(res, 'values', 'ic_launcher_background.xml')
    with open(path, 'w') as handle:
        handle.write(BACKGROUND_XML)
    written.append(('values', 0, path))

    # The icon itself, for the window Android paints before Flutter starts.
    # Written per density so the bitmap lands at SPLASH_MARK_DP on every
    # screen; a single drawable would draw at its own pixel size instead.
    icon = build_icon(N // SS)
    for bucket, px in DENSITIES.items():
        folder = os.path.join(res, f'drawable-{bucket}')
        os.makedirs(folder, exist_ok=True)
        side = int(round(SPLASH_MARK_DP * px / 48))
        path = os.path.join(folder, 'brand_mark.png')
        icon.resize((side, side), Image.LANCZOS, reducing_gap=3.0).save(
            path, optimize=True)
        written.append((bucket, side, path))

    return written


def write_flutter_asset(root):
    """The icon as a Flutter asset, for the gate screen's loading state."""
    folder = os.path.join(root, 'assets')
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, 'brand_mark.png')
    build_icon(512).save(path, optimize=True)
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
        save(build_full_bleed(size, margin_ratio=0.30),
             os.path.join(icons, f'Icon-maskable-{size}.png'))
    save(build_full_bleed(180, margin_ratio=0.22),
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
