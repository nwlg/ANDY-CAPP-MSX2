#!/usr/bin/env python3
"""Creates the editable SCREEN 5 assets from the Spectrum graphics.

    import_zx_gfx.py [--force]

Reads ../ZX/orig (the tape bytes) and writes indexed PNGs (16 colours, the
palette of doc/DESIGN.md) to assets/:

  tiles.png         256 tiles of 8x8 (32 per row): only the window font is used
                    (black on the fixed white)
  rooms/room_NN.png the play-area background of every different room (240x104),
                    named after the first room that shows it; rooms/rooms.txt
                    gives the picture of each of the 80 rooms
  sprites_top.png   the 26 top part pairs (mask + graphic) of 32x32, 8 per row
  sprites_bot.png   the 46 bottom part pairs of 32x24, 8 per row
  sprite_parts.txt  which Spectrum part pair each cell of the two sheets holds
  screen.png        256x192 frame and status panel (tape block ANDY3 in its colours;
                    the play area inside the frame is drawn by the game)
  kiss.png          the 4 frames (8x8) of a blown kiss, transparent background

Existing files are kept unless --force is given, so hand-coloured art is
never overwritten by accident.

Rooms, sprites, kiss and tiles use the PLAY palette, screen.png the HUD
palette (tools/palettes.py). The importer writes the Spectrum pictures as
black on white (PLAY indices 1 and 2); the colours are added on top.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'tools'))
import palettes  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIG = os.path.join(ROOT, '..', 'ZX', 'orig')
ASSETS = os.path.join(ROOT, 'assets')
BASE = 0x5FB4

TILES = 0x6C3E
PART_TABLE = 0xAEC7
TOP_TABLE = 0xB033
BOTTOM_TABLE = 0xAFD5
NUM_FRAMES = 47
HUD_ATTRS = 0x6144

TRANSPARENT, INK, PAPER = 0, palettes.INK, palettes.WHITE
FIXED_WHITE = palettes.FIXED_WHITE
# icon cells (column, row, width, height) and their palette index
ICONS = [((6, 20, 5, 4), 9), ((11, 20, 5, 4), 10), ((16, 20, 5, 4), 11), ((22, 20, 5, 4), 12)]
KISS_TABLE = 0xF925         # 4 words: glyph of each kiss frame
# Spectrum colour (0-7) -> palette index in the panel
ZX_TO_HUD = [1, 3, 4, 5, 6, 7, 8, 2]


def new_image(w, h, fill=0, pal=None):
    img = Image.new('P', (w, h), fill)
    img.putpalette(palettes.pil(pal or palettes.PLAY))
    return img


def load_memory():
    mem = bytearray(65536)
    data = open(os.path.join(ORIG, 'game_5FB4_FEFF.bin'), 'rb').read()
    mem[BASE:BASE + len(data)] = data
    return mem


def word(mem, a):
    return mem[a] | mem[a + 1] << 8


def part_rows(mem, part, rows):
    a = word(mem, PART_TABLE + 2 * part)
    return [int.from_bytes(mem[a + 4 * r:a + 4 * r + 4], 'big') for r in range(rows)]


def part_pairs(mem):
    """Unique (mask part, graphic part) pairs of the 47 frames, tops and bottoms."""
    tops, bots = [], []
    for f in range(NUM_FRAMES):
        t, b = word(mem, TOP_TABLE + 2 * f), word(mem, BOTTOM_TABLE + 2 * f)
        if (t & 255, t >> 8) not in tops:
            tops.append((t & 255, t >> 8))
        if (b & 255, b >> 8) not in bots:
            bots.append((b & 255, b >> 8))
    return tops, bots


def pair_image(mem, pair, rows):
    mask, gfx = part_rows(mem, pair[0], rows), part_rows(mem, pair[1], rows)
    img = new_image(32, rows)
    px = img.load()
    for y in range(rows):
        for x in range(32):
            bit = 0x80000000 >> x
            if gfx[y] & bit:
                px[x, y] = INK
            elif not mask[y] & bit:
                px[x, y] = PAPER
    return img


def sheet(images, w, h, per_row=8):
    rows = (len(images) + per_row - 1) // per_row
    out = new_image(per_row * w, rows * h)
    for i, im in enumerate(images):
        out.paste(im, ((i % per_row) * w, (i // per_row) * h))
    return out


def tiles_image(mem):
    img = new_image(256, 64)
    px = img.load()
    for t in range(256):
        for y in range(8):
            b = mem[TILES + 8 * t + y]
            for x in range(8):
                px[(t % 32) * 8 + x, (t // 32) * 8 + y] = INK if b & (0x80 >> x) else FIXED_WHITE
    return img


def screen_image():
    scr = open(os.path.join(ORIG, 'andy3_hud.scr'), 'rb').read()
    attrs = load_memory()[HUD_ATTRS:HUD_ATTRS + 768]
    img = new_image(256, 192, pal=palettes.HUD)
    px = img.load()
    for y in range(192):
        row = ((y & 0xC0) << 5) | ((y & 7) << 8) | ((y & 0x38) << 2)
        for cx in range(32):
            bits, a = scr[row + cx], attrs[(y >> 3) * 32 + cx]
            ink, paper = ZX_TO_HUD[a & 7], ZX_TO_HUD[(a >> 3) & 7]
            if y < 104 and 1 <= cx <= 30:
                ink, paper = 0, 0               # play area: drawn by the game
            elif y < 112:
                ink, paper = 1, FIXED_WHITE     # frame and the line where the palette switches
            for (x0, y0, w, h), idx in ICONS:
                if x0 <= cx < x0 + w and y0 <= y >> 3 < y0 + h and ink != 1:
                    ink = idx
            for b in range(8):
                px[cx * 8 + b, y] = ink if bits & (0x80 >> b) else paper
    return img


def kiss_image(mem):
    img = new_image(32, 8)
    px = img.load()
    for f in range(4):
        g = word(mem, KISS_TABLE + 2 * f)
        for y in range(8):
            b = mem[g + y]
            for x in range(8):
                if b & (0x80 >> x):
                    px[8 * f + x, y] = palettes.KISS
    return img


def room_images(mem):
    """The background of every room as the game builds it (the decoder of
    ../tools/extract_rooms.py): {first room: image}, [picture name per room]."""
    import extract_rooms
    seen, images, names = {}, {}, []
    for room in range(80):
        buf = extract_rooms.build_buffer(mem, room)
        if buf not in seen:
            seen[buf] = 'room_%02d' % room
            img = new_image(240, 104)
            px = img.load()
            for y in range(104):
                for c in range(30):
                    b = buf[y * 32 + 1 + c]
                    for i in range(8):
                        px[c * 8 + i, y] = INK if b & (0x80 >> i) else PAPER
            images[seen[buf]] = img
        names.append(seen[buf])
    return images, names


def save(img, name, force):
    path = os.path.join(ASSETS, name)
    if os.path.exists(path) and not force:
        print('kept', name)
        return
    img.save(path)
    print('wrote', name)


def main():
    force = '--force' in sys.argv
    os.makedirs(ASSETS, exist_ok=True)
    mem = load_memory()
    tops, bots = part_pairs(mem)
    save(tiles_image(mem), 'tiles.png', force)
    save(sheet([pair_image(mem, p, 32) for p in tops], 32, 32), 'sprites_top.png', force)
    save(sheet([pair_image(mem, p, 24) for p in bots], 32, 24), 'sprites_bot.png', force)
    save(screen_image(), 'screen.png', force)
    os.makedirs(os.path.join(ASSETS, 'rooms'), exist_ok=True)
    images, names = room_images(mem)
    for name, img in images.items():
        save(img, os.path.join('rooms', name + '.png'), force)
    open(os.path.join(ASSETS, 'rooms', 'rooms.txt'), 'w').write(
        '# room: background picture (generated by tools/import_zx_gfx.py)\n' +
        ''.join('%d: %s\n' % (r, n) for r, n in enumerate(names)))
    save(kiss_image(mem), 'kiss.png', force)
    lines = ['# cell: Spectrum mask part, graphic part (generated by tools/import_zx_gfx.py)']
    lines += ['top %d: %d %d' % (i, m, g) for i, (m, g) in enumerate(tops)]
    lines += ['bot %d: %d %d' % (i, m, g) for i, (m, g) in enumerate(bots)]
    path = os.path.join(ASSETS, 'sprite_parts.txt')
    if force or not os.path.exists(path):
        open(path, 'w').write('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
