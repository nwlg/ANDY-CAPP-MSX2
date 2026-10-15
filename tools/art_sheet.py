#!/usr/bin/env python3
"""Contact sheets of the coloured art for review: build/art/<what>_N.png.

    art_sheet.py rooms|sprites [palette: day|dusk|night]
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import palettes  # noqa: E402


def recolour(im, pal):
    im = im.copy()
    im.putpalette(palettes.pil(pal))
    return im.convert('RGB')


def main():
    what = sys.argv[1]
    pal = palettes.variant(sys.argv[2] if len(sys.argv) > 2 else 'day')
    out = os.path.join(ROOT, 'build', 'art')
    os.makedirs(out, exist_ok=True)
    if what == 'rooms':
        fs = sorted(glob.glob(os.path.join(ROOT, 'assets', 'rooms', 'room_*.png')))
        for k in range(0, len(fs), 8):
            W = Image.new('RGB', (2 * 490, 4 * 228), (40, 40, 40))
            d = ImageDraw.Draw(W)
            for i, f in enumerate(fs[k:k + 8]):
                im = recolour(Image.open(f), pal).resize((480, 208), Image.NEAREST)
                x0, y0 = (i % 2) * 490, (i // 2) * 228
                W.paste(im, (x0, y0 + 18))
                d.text((x0 + 2, y0 + 2), os.path.basename(f)[:-4], fill=(255, 255, 0))
            W.save(os.path.join(out, 'colour_rooms_%d.png' % (k // 8)))
    else:
        for name in ('sprites_top', 'sprites_bot'):
            im = Image.open(os.path.join(ROOT, 'assets', name + '.png'))
            bg = Image.new('RGB', im.size, (120, 160, 120))
            rgb = recolour(im, pal)
            mask = Image.new('L', im.size)
            mask.putdata([0 if v == 0 else 255 for v in im.getdata()])
            bg.paste(rgb, (0, 0), mask)
            bg = bg.resize((im.width * 3, im.height * 3), Image.NEAREST)
            d = ImageDraw.Draw(bg)
            h = 32 if 'top' in name else 24
            for i in range((im.width // 32) * (im.height // h)):
                d.text(((i % 8) * 96 + 2, (i // 8) * h * 3 + 1), str(i), fill=(255, 0, 0))
            bg.save(os.path.join(out, 'colour_%s.png' % name))


if __name__ == '__main__':
    main()
