#!/usr/bin/env python3
"""Regenerates the Android launcher icon: an open wallet with a question mark.

The icon is drawn geometrically rather than stored as a source image, so it
can be re-rendered at any density without hunting for the original artwork.
Everything is composed at 4x and downsampled, which keeps the curves clean at
launcher sizes.

The background stays fully transparent on purpose. An adaptive icon
(mipmap-anydpi-v26) is deliberately NOT generated: the adaptive format
requires an opaque background layer, and launchers substitute their own -- a
white square -- when that layer is transparent. Legacy PNGs keep the
transparency the design needs.

Usage:
    python3 tool/generate_launcher_icon.py            # write into the project
    python3 tool/generate_launcher_icon.py --preview out.png

Requires Pillow and a copy of Outfit-Bold (or any geometric sans) for the
question mark; override the font with --font.
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFont

S = 1024          # nominal icon size
SS = 4            # supersampling factor
N = S * SS

DEFAULT_FONT = (
    '/mnt/skills/examples/canvas-design/canvas-fonts/Outfit-Bold.ttf'
)

BRAND = (34, 197, 94, 255)     # #22C55E  the front pocket
LID = (21, 128, 61, 255)       # #15803D  the lid, standing open behind
CAVITY = (13, 92, 45, 255)     # #0D5C2D  the shadowed inside
CARD = (209, 250, 229, 255)    # #D1FAE5  a card peeking out of the opening
WHITE = (255, 255, 255, 255)

# density bucket -> pixel size
DENSITIES = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}


def _s(v):
    return int(round(v * SS))


def _layer():
    return Image.new('RGBA', (N, N), (0, 0, 0, 0))


def _rounded(img, box, radius, fill):
    ImageDraw.Draw(img).rounded_rectangle(
        [_s(box[0]), _s(box[1]), _s(box[2]), _s(box[3])],
        radius=_s(radius), fill=fill,
    )


def _tilt(img, degrees, center):
    return img.rotate(
        degrees, resample=Image.BICUBIC,
        center=(_s(center[0]), _s(center[1])),
    )


def _stack(*layers):
    out = _layer()
    for one in layers:
        out = Image.alpha_composite(out, one)
    return out


def _question_mark(canvas, font_path, cx, cy, height):
    """Draws '?' with its ink box centred on (cx, cy) and exactly `height` tall."""
    mark = _layer()
    draw = ImageDraw.Draw(mark)
    target = size = _s(height)
    for _ in range(40):
        font = ImageFont.truetype(font_path, size)
        box = draw.textbbox((0, 0), '?', font=font)
        drawn = box[3] - box[1]
        if abs(drawn - target) <= _s(1):
            break
        size = max(1, int(round(size * target / max(drawn, 1))))
    font = ImageFont.truetype(font_path, size)
    box = draw.textbbox((0, 0), '?', font=font)
    draw.text(
        (_s(cx) - (box[0] + box[2]) / 2, _s(cy) - (box[1] + box[3]) / 2),
        '?', font=font, fill=WHITE,
    )
    return Image.alpha_composite(canvas, mark)


def _centre(img, margin_ratio=0.05):
    """Centres the artwork in the square with an even margin on its long axis."""
    art = img.crop(img.getbbox())
    available = N - 2 * int(N * margin_ratio)
    scale = available / max(art.width, art.height)
    art = art.resize(
        (int(art.width * scale), int(art.height * scale)),
        Image.LANCZOS, reducing_gap=3.0,
    )
    out = _layer()
    out.paste(art, ((N - art.width) // 2, (N - art.height) // 2))
    return out


def build(font_path=DEFAULT_FONT):
    lid = _layer()
    _rounded(lid, (180, 214, 844, 528), 68, LID)
    lid = _tilt(lid, 8.0, (512, 528))

    card = _layer()
    _rounded(card, (244, 318, 780, 508), 42, CARD)
    card = _tilt(card, -3.5, (512, 508))

    cavity = _layer()
    _rounded(cavity, (156, 380, 868, 508), 48, CAVITY)

    front = _layer()
    _rounded(front, (128, 436, 896, 926), 98, BRAND)

    art = _question_mark(
        _stack(lid, cavity, card, front), font_path, 512, 686, 336,
    )
    return _centre(art).resize((S, S), Image.LANCZOS, reducing_gap=3.0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', default=DEFAULT_FONT,
                        help='TTF used for the question mark')
    parser.add_argument('--preview', metavar='PATH',
                        help='write a single 1024px PNG here instead of '
                             'updating the project icons')
    args = parser.parse_args()

    icon = build(args.font)

    if args.preview:
        icon.save(args.preview)
        print('wrote', args.preview)
        return

    root = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        'android', 'app', 'src', 'main', 'res',
    )
    for bucket, px in DENSITIES.items():
        path = os.path.join(root, f'mipmap-{bucket}', 'ic_launcher.png')
        icon.resize((px, px), Image.LANCZOS, reducing_gap=3.0).save(
            path, optimize=True)
        # Guard the one thing that has regressed before: an opaque corner
        # means the transparent background was lost somewhere.
        written = Image.open(path).convert('RGBA')
        corners = [written.getpixel(p)[3] for p in
                   [(0, 0), (px - 1, 0), (0, px - 1), (px - 1, px - 1)]]
        assert max(corners) == 0, f'{path} is not transparent: {corners}'
        print(f'{bucket:8} {px:3}px  {path}')


if __name__ == '__main__':
    main()
