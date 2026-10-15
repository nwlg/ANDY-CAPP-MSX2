#!/usr/bin/env python3
"""Derives the opening screen from the photo assets/opening.png.

    make_opening.py [--force]

Writes assets/opening_screen.png: 512 x 424, 16 colours with its own palette
(the colours of the V9938: 3 bits per channel; colour 0 is black, used by
the border and the bars at the sides). The cartridge shows it in SCREEN 7
with interlace: the even lines are one field, the odd lines the other. That
PNG is the editable asset the build uses; an existing one is kept unless
--force is given.

The cover in the photo (what is neither transparent nor white) is fitted to the full screen
height; PIXEL is the width / height of a pixel of the 512 x 424 screen.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'assets', 'opening.png')
TARGET = os.path.join(ROOT, 'assets', 'opening_screen.png')
WIDTH, HEIGHT = 512, 424
PIXEL = 1.1


def main():
    if os.path.exists(TARGET) and '--force' not in sys.argv:
        print('kept assets/opening_screen.png (exists; --force replaces it)')
        return
    src = Image.open(SOURCE).convert('RGBA')
    # the cover: what is neither transparent nor the white page around it
    mask = Image.new('L', src.size)
    mask.putdata([255 if a > 128 and min(r, g, b) < 245 else 0 for r, g, b, a in src.getdata()])
    bbox = mask.getbbox() or (0, 0, src.width, src.height)
    pic = src.crop(bbox).convert('RGB')
    width = min(WIDTH, round(HEIGHT * pic.width / pic.height * PIXEL) & ~1)
    lines = HEIGHT if width < WIDTH else round(WIDTH / (pic.width / pic.height) / PIXEL) & ~1
    pic = pic.resize((width, lines), Image.LANCZOS)
    canvas = Image.new('RGB', (WIDTH, HEIGHT), (0, 0, 0))
    left, top = ((WIDTH - width) // 2) & ~1, ((HEIGHT - lines) // 2) & ~1
    canvas.paste(pic, (left, top))
    # 15 colours chosen from the picture plus black, in the levels of the
    # VDP: a k-means palette rounded to those levels; entries that rounding
    # made equal are replaced by frequent colours far from the chosen ones
    q = pic.quantize(15, method=Image.Quantize.MEDIANCUT, kmeans=8, dither=Image.Dither.NONE)
    p = q.getpalette()[:45]
    levels = [(0, 0, 0)]
    for i in range(0, 45, 3):
        c = tuple((v * 7 + 127) // 255 for v in p[i:i + 3])
        if c not in levels:
            levels.append(c)
    count = {}
    for c in pic.getdata():
        k = tuple((v * 7 + 127) // 255 for v in c)
        count[k] = count.get(k, 0) + 1
    while len(levels) < 16:
        def far(k):
            return min(sum((a - b) ** 2 for a, b in zip(k, l)) for l in levels)
        levels.append(max(count, key=lambda k: count[k] ** 0.5 * far(k)))
    flat = [v * 255 // 7 for c in levels for v in c]
    pal = Image.new('P', (1, 1))
    pal.putpalette(flat + [0] * (768 - len(flat)))
    out = canvas.quantize(palette=pal, dither=Image.Dither.FLOYDSTEINBERG)
    px = out.load()
    for y in range(HEIGHT):              # the bars stay pure black
        for x in range(WIDTH):
            if not (left <= x < left + width and top <= y < top + lines):
                px[x, y] = 0
    out.save(TARGET)
    print('assets/opening_screen.png: picture %dx%d at (%d,%d)' % (width, lines, left, top))


if __name__ == '__main__':
    main()
