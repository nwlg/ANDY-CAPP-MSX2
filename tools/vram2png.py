#!/usr/bin/env python3
"""Renders a SCREEN 5 VRAM dump written by tools/test.tcl.

    vram2png.py NAME [NAME ...]

build/test/NAME.vram (128 KiB) + NAME.pal -> NAME.png (page 0 with the
palette that was in the VDP) and NAME_p1.png .. NAME_p3.png. When NAME.mem
(page 0 RAM, the runtime) exists, NAME_scr.png is the picture as seen on the
screen: the PLAY palette of the time of day down to the line interrupt, the
HUD palette below it.
"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def palette(raw):
    pal = []
    for i in range(16):
        rb, g = raw[2 * i], raw[2 * i + 1]
        pal.append(((rb >> 4 & 7) * 255 // 7, (g & 7) * 255 // 7, (rb & 7) * 255 // 7))
    return pal


def symbols():
    out = {}
    path = os.path.join(ROOT, 'build', 'runtime.sym')
    for line in open(path):
        p = line.split()
        if len(p) >= 3 and p[1].lower() == 'equ':
            out[p[0].rstrip(':')] = int(p[2].rstrip('hH'), 16)
    return out


def page(v, n, pal_of_line, rows=256):
    im = Image.new('RGB', (256, rows))
    px = im.load()
    for y in range(rows):
        pal = pal_of_line(y)
        for x in range(128):
            b = v[n * 0x8000 + y * 128 + x]
            px[2 * x, y] = pal[b >> 4]
            px[2 * x + 1, y] = pal[b & 15]
    return im


def render(name):
    base = os.path.join(ROOT, 'build', 'test', name)
    v = open(base + '.vram', 'rb').read()
    pal = palette(open(base + '.pal', 'rb').read())
    for n in range(4):
        page(v, n, lambda y: pal).save(base + ('.png' if n == 0 else '_p%d.png' % n))
    if os.path.exists(base + '.mem'):
        mem = open(base + '.mem', 'rb').read()
        s = symbols()
        play_ptr = mem[0x49] | mem[0x4A] << 8
        play = palette(mem[play_ptr:play_ptr + 32])
        hud = palette(mem[s['rt_pal_hud']:s['rt_pal_hud'] + 32])
        split = 10 + 104
        page(v, 0, lambda y: play if y < split else hud, 212).save(base + '_scr.png')


if __name__ == '__main__':
    for n in sys.argv[1:]:
        render(n)
