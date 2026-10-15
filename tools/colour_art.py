#!/usr/bin/env python3
"""Colours the Spectrum pictures for the colour version.

    colour_art.py [rooms|sprites|hud|all] [--only NAME] [--force]

Starts from the black and white pictures of the game (rebuilt from
../ZX/orig, never from assets/, so the result can always be remade) and
applies the operations of assets/rooms/colours.txt or
assets/sprites_colours.txt or assets/hud_colours.txt (HUD palette names).
Writes assets/rooms/room_NN.png,
assets/sprites_top.png / sprites_bot.png and assets/screen.png. A picture
that already exists is only replaced with --force, and the pictures named in
assets/HAND_MADE.txt never (painted by hand). The PNGs in assets/ are the
source of the build: once they are painted by hand, this tool is not needed.

Spec language, one operation per line ("#" starts a comment):
  NAME                     the picture the next lines apply to (room_09, top_3, bot_12)
  macro NAME ... end       define a list of operations; "use NAME" inserts it
  fill X Y C               flood fill (4 neighbours) the area of the colour at X,Y with C
  keep X Y                 the area at X,Y stays white (protected from rest/rect)
  rect X0 Y0 X1 Y1 C [F]   every pixel of colour F (default 2, white) in the box becomes C
  rest X0 Y0 X1 Y1 C       = rect with F = 2: whatever is still white in the box
  ink X0 Y0 X1 Y1 C        the black pixels (1) in the box become C
  swap X0 Y0 X1 Y1 A B     colour A becomes B in the box
  small X0 Y0 X1 Y1 MAX C  every white area inside the box with at most MAX pixels
                           becomes C (the squares of a check pattern)
  face Y0 Y1 MIN C         every white area lying between lines Y0 and Y1 with at
                           least MIN pixels becomes C (faces of the characters)
Colours are PLAY palette indices or names (tools/palettes.py: black, white,
skin, brick, cream, wood, darkbrown, grey, lightgrey, navy, lightblue,
green, red, yellow, fixedwhite).
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'assets')
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import import_zx_gfx as gfx  # noqa: E402
import palettes  # noqa: E402

NAMES = {n.replace(' ', '').replace('(fixed)', '').lower(): i for i, n in enumerate(palettes.PLAY_NAMES)}
NAMES['fixedwhite'] = 15
NAMES['white'] = 2
HUD_NAMES = {n.replace(' ', '').replace('(fixed)', '').lower(): i for i, n in enumerate(palettes.HUD_NAMES)}
HUD_NAMES['fixedwhite'] = 15
KEEP = 16
names = NAMES


def colour(tok):
    return int(tok) if tok.isdigit() else names[tok.lower()]


def parse(path):
    """{picture: [ops]} with the macros expanded."""
    macros, specs = {}, {}
    cur, mac = None, None
    for raw in open(path):
        line = raw.split('#')[0].strip()
        if not line:
            continue
        t = line.split()
        if t[0] == 'macro':
            mac = macros.setdefault(t[1], [])
        elif t[0] == 'end':
            mac = None
        elif mac is not None:
            mac.append(t)
        elif len(t) == 1:
            cur = specs.setdefault(t[0], [])
        elif t[0] == 'use':
            cur.extend(macros[t[1]])
        else:
            cur.append(t)
    return specs


def apply(img, ops):
    w, h = img.size
    px = [[img.getpixel((x, y)) for x in range(w)] for y in range(h)]

    def flood(x, y, c):
        old = px[y][x]
        if old == c:
            return
        todo = [(x, y)]
        while todo:
            x, y = todo.pop()
            if 0 <= x < w and 0 <= y < h and px[y][x] == old:
                px[y][x] = c
                todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]

    def box(t):
        x0, y0, x1, y1 = (int(v) for v in t[1:5])
        return range(max(0, y0), min(h - 1, y1) + 1), range(max(0, x0), min(w - 1, x1) + 1)

    for t in ops:
        op = t[0]
        if op == 'fill':
            flood(int(t[1]), int(t[2]), colour(t[3]))
        elif op == 'keep':
            flood(int(t[1]), int(t[2]), KEEP)
        elif op in ('rect', 'rest', 'ink', 'swap'):
            ys, xs = box(t)
            if op == 'swap':
                a, b = colour(t[5]), colour(t[6])
            elif op == 'ink':
                a, b = 1, colour(t[5])
            else:
                a = colour(t[6]) if op == 'rect' and len(t) > 6 else 2
                b = colour(t[5])
            for y in ys:
                for x in xs:
                    if px[y][x] == a:
                        px[y][x] = b
        elif op == 'small':
            x0, y0, x1, y1, mx, c = (int(v) for v in t[1:6]) + (colour(t[6]),) if False else (
                int(t[1]), int(t[2]), int(t[3]), int(t[4]), int(t[5]), colour(t[6]))
            seen = set()
            for y in range(max(0, y0), min(h - 1, y1) + 1):
                for x in range(max(0, x0), min(w - 1, x1) + 1):
                    if px[y][x] != 2 or (x, y) in seen:
                        continue
                    todo, pts = [(x, y)], []
                    seen.add((x, y))
                    while todo and len(pts) <= mx:
                        a, b = todo.pop()
                        pts.append((a, b))
                        for e, f in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                            if 0 <= e < w and 0 <= f < h and (e, f) not in seen and px[f][e] == 2:
                                seen.add((e, f))
                                todo.append((e, f))
                    if len(pts) <= mx and not todo and all(x0 <= a <= x1 and y0 <= b <= y1 for a, b in pts):
                        for a, b in pts:
                            px[b][a] = c
        elif op == 'face':
            y0, y1, mina, c = int(t[1]), int(t[2]), int(t[3]), colour(t[4])
            seen = set()
            for y in range(h):
                for x in range(w):
                    if px[y][x] != 2 or (x, y) in seen:
                        continue
                    todo, pts = [(x, y)], []
                    seen.add((x, y))
                    while todo:
                        a, b = todo.pop()
                        pts.append((a, b))
                        for e, f in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                            if 0 <= e < w and 0 <= f < h and (e, f) not in seen and px[f][e] == 2:
                                seen.add((e, f))
                                todo.append((e, f))
                    ys = [q[1] for q in pts]
                    if len(pts) >= mina and min(ys) >= y0 and max(ys) <= y1:
                        for a, b in pts:
                            px[b][a] = c
        else:
            sys.exit('unknown operation: ' + ' '.join(t))
    out = gfx.new_image(w, h, pal=palettes.HUD if names is HUD_NAMES else None)
    out.putdata([2 if v == KEEP else v for row in px for v in row])
    return out


FORCE = '--force' in sys.argv


def writable(rel):
    """May assets/REL be (re)written?"""
    if rel in hand_made():
        return False
    if os.path.exists(os.path.join(ASSETS, rel)) and not FORCE:
        print('kept %s (exists; --force replaces it)' % rel)
        return False
    return True


def hand_made():
    path = os.path.join(ASSETS, 'HAND_MADE.txt')
    if not os.path.exists(path):
        return set()
    return {l.split('#')[0].strip() for l in open(path)} - {''}


def rooms(only=None):
    mem = gfx.load_memory()
    images, _ = gfx.room_images(mem)
    specs = parse(os.path.join(ASSETS, 'rooms', 'colours.txt'))
    for name, img in images.items():
        if (only and name != only) or not writable('rooms/%s.png' % name):
            continue
        apply(img, specs.get(name, [])).save(os.path.join(ASSETS, 'rooms', name + '.png'))


def sprites(only=None):
    mem = gfx.load_memory()
    tops, bots = gfx.part_pairs(mem)
    specs = parse(os.path.join(ASSETS, 'sprites_colours.txt'))
    for sheet, pairs, rows, prefix in (('sprites_top.png', tops, 32, 'top'), ('sprites_bot.png', bots, 24, 'bot')):
        if not writable(sheet):
            continue
        cells = [apply(gfx.pair_image(mem, p, rows), specs.get('%s_%d' % (prefix, i), []))
                 for i, p in enumerate(pairs)]
        gfx.sheet(cells, 32, rows).save(os.path.join(ASSETS, sheet))


def hud():
    """assets/screen.png: the frame and status panel, HUD palette."""
    global names
    if not writable('screen.png'):
        return
    names = HUD_NAMES
    specs = parse(os.path.join(ASSETS, 'hud_colours.txt'))
    apply(gfx.screen_image(), specs.get('screen', [])).save(os.path.join(ASSETS, 'screen.png'))
    names = NAMES


if __name__ == '__main__':
    what = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('-') else 'all'
    only = sys.argv[sys.argv.index('--only') + 1] if '--only' in sys.argv else None
    if what in ('rooms', 'all'):
        rooms(only)
    if what in ('sprites', 'all'):
        sprites(only)
    if what in ('hud', 'all'):
        hud()
