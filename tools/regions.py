#!/usr/bin/env python3
"""Lists the white areas of a black and white picture (help for writing
colour specs): regions.py rooms ROOM_NN [min area] | hud [min area] | sprites top|bot N"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import import_zx_gfx as gfx  # noqa: E402


def regions(img, minarea):
    w, h = img.size
    px = img.load()
    seen = set()
    out = []
    for y in range(h):
        for x in range(w):
            if px[x, y] != 2 or (x, y) in seen:
                continue
            todo, pts = [(x, y)], []
            seen.add((x, y))
            while todo:
                a, b = todo.pop()
                pts.append((a, b))
                for c, d in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                    if 0 <= c < w and 0 <= d < h and (c, d) not in seen and px[c, d] == 2:
                        seen.add((c, d))
                        todo.append((c, d))
            if len(pts) >= minarea:
                xs, ys = [p[0] for p in pts], [p[1] for p in pts]
                out.append((len(pts), pts[0], (min(xs), min(ys), max(xs), max(ys))))
    return sorted(out, reverse=True)


def main():
    mem = gfx.load_memory()
    if sys.argv[1] == 'hud':
        img = gfx.screen_image()
        minarea = int(sys.argv[2]) if len(sys.argv) > 2 else 15
    elif sys.argv[1] == 'rooms':
        img = gfx.room_images(mem)[0][sys.argv[2]]
        minarea = int(sys.argv[3]) if len(sys.argv) > 3 else 15
    else:
        tops, bots = gfx.part_pairs(mem)
        top = sys.argv[2] == 'top'
        img = gfx.pair_image(mem, (tops if top else bots)[int(sys.argv[3])], 32 if top else 24)
        minarea = 1
    for area, seed, bbox in regions(img, minarea):
        print('area %5d  seed %3d %3d  box %s' % (area, seed[0], seed[1], bbox))


if __name__ == '__main__':
    main()
