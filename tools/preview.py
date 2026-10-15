#!/usr/bin/env python3
"""Preview of the editable pictures, as the game will show them.

    preview.py

Writes build/preview/:
  characters.png        every frame of every character, assembled from the
                        part sheets, facing left and right (day colours)
  characters_night.png  the same with the night palette
  rooms_day.png, rooms_dusk.png, rooms_night.png
                        every room picture with the rooms that show it
  hud.png               the status panel
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'assets')
OUT = os.path.join(ROOT, 'build', 'preview')
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import import_zx_gfx as gfx  # noqa: E402
import palettes  # noqa: E402

CHARACTERS = [('Andy', 0, 9), ('Flo', 9, 8), ('woman with ponytail', 17, 8), ('rent man', 25, 8),
              ('policeman', 33, 8), ('fight cloud (pairs)', 41, 6)]
BACK = (150, 190, 150)


def rgb(im, pal):
    im = im.copy()
    im.putpalette(palettes.pil(pal))
    return im.convert('RGB')


def frames_image(pal):
    mem = gfx.load_memory()
    tops, bots = gfx.part_pairs(mem)
    flags = mem[0xAD9F:0xAD9F + 135]
    top_sheet = Image.open(os.path.join(ASSETS, 'sprites_top.png'))
    bot_sheet = Image.open(os.path.join(ASSETS, 'sprites_bot.png'))

    def cell(sheet, i, h):
        return sheet.crop(((i % 8) * 32, (i // 8) * h, (i % 8) * 32 + 32, (i // 8) * h + h))

    scale, gap = 3, 6
    fw, fh = 32 * scale, 56 * scale
    width = 9 * (fw + gap) + gap
    height = len(CHARACTERS) * 2 * (fh + 20) + 10
    sheet = Image.new('RGB', (width, height), BACK)
    d = ImageDraw.Draw(sheet)
    y = 4
    for name, first, count in CHARACTERS:
        for facing in (0, 1):
            d.text((gap, y), '%s, facing %s (frames %d-%d)' % (name, 'right' if facing else 'left',
                                                             first, first + count - 1), fill=(0, 0, 0))
            for k in range(count):
                f = first + k
                t, b = gfx.word(mem, gfx.TOP_TABLE + 2 * f), gfx.word(mem, gfx.BOTTOM_TABLE + 2 * f)
                ti, bi = tops.index((t & 255, t >> 8)), bots.index((b & 255, b >> 8))
                frame = Image.new('P', (32, 56), 0)
                top, bot = cell(top_sheet, ti, 32), cell(bot_sheet, bi, 24)
                if facing and flags[t >> 8] != 0xFF:
                    top = top.transpose(Image.FLIP_LEFT_RIGHT)
                if facing and flags[b >> 8] != 0xFF:
                    bot = bot.transpose(Image.FLIP_LEFT_RIGHT)
                frame.paste(top, (0, 0))
                frame.paste(bot, (0, 32))
                mask = Image.new('L', frame.size)
                mask.putdata([0 if v == 0 else 255 for v in frame.getdata()])
                big = rgb(frame, pal).resize((fw, fh), Image.NEAREST)
                x = gap + k * (fw + gap)
                sheet.paste(big, (x, y + 14), mask.resize((fw, fh), Image.NEAREST))
                d.text((x, y + 14 + fh - 10), 'F%d' % f, fill=(120, 0, 0))
            y += fh + 20
    return sheet


def rooms_image(pal):
    names = {}
    for line in open(os.path.join(ASSETS, 'rooms', 'rooms.txt')):
        if ':' in line and not line.startswith('#'):
            r, n = line.split(':')
            names.setdefault(n.strip(), []).append(int(r))
    pics = sorted(names)
    cols = 4
    w, h = 240 * 2, 104 * 2
    sheet = Image.new('RGB', (cols * (w + 8) + 8, ((len(pics) + cols - 1) // cols) * (h + 22) + 8), (40, 40, 40))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(pics):
        x, y = 8 + (i % cols) * (w + 8), 8 + (i // cols) * (h + 22)
        im = rgb(Image.open(os.path.join(ASSETS, 'rooms', n + '.png')), pal).resize((w, h), Image.NEAREST)
        sheet.paste(im, (x, y + 14))
        d.text((x, y), '%s.png  rooms %s' % (n, ' '.join(str(r) for r in names[n])), fill=(255, 255, 0))
    return sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    frames_image(palettes.variant('day')).save(os.path.join(OUT, 'characters.png'))
    frames_image(palettes.variant('night')).save(os.path.join(OUT, 'characters_night.png'))
    for t in ('day', 'dusk', 'night'):
        rooms_image(palettes.variant(t)).save(os.path.join(OUT, 'rooms_%s.png' % t))
    hud = rgb(Image.open(os.path.join(ASSETS, 'screen.png')), palettes.HUD).crop((0, 104, 256, 192))
    hud.resize((768, 264), Image.NEAREST).save(os.path.join(OUT, 'hud.png'))
    print('build/preview: characters, characters_night, rooms_day/dusk/night, hud')


if __name__ == '__main__':
    main()
