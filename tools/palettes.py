"""The two SCREEN 5 palettes of the colour version (see doc/DESIGN.md).

PLAY: play area (rooms, characters, windows). A line interrupt switches to
HUD below the play area and the vertical blank switches back, so each part
of the screen has 16 colours. PLAY entries 0, 1 and 15 never change with the
time of day (15 is the white of the frame, border and window paper, a newsprint
cream; HUD has the same colour at 15 and black at 1, so the switch line is invisible).
Values are 3-bit R, G, B. The colours come from assets/palette_play.gpl and
assets/palette_hud.gpl (GIMP palette files) when they exist.
"""

import os

ASSETS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets')

PLAY_NAMES = ['transparent', 'black', 'white', 'skin', 'brick', 'cream', 'wood', 'dark brown',
              'grey', 'light grey', 'navy', 'light blue', 'green', 'red', 'yellow', 'white (fixed)']
PAPER = (7, 7, 6)           # newsprint: panel, border, window paper (index 15 of both palettes)
DEFAULT_PLAY = [(0, 0, 0), (0, 0, 0), (7, 7, 7), (7, 5, 4), (5, 2, 1), (7, 6, 4), (4, 2, 1), (2, 1, 0),
                (4, 4, 4), (6, 6, 6), (1, 1, 4), (4, 6, 7), (2, 5, 1), (6, 1, 1), (7, 6, 1), PAPER]
FIXED = (0, 1, 15)

HUD_NAMES = ['transparent', 'black', 'paper', 'blue', 'red', 'magenta', 'green', 'beer', 'yellow',
             'icon wallet', 'icon speak', 'icon fight', 'icon action', 'skin', 'grey', 'white (fixed)']
DEFAULT_HUD = [(0, 0, 0), (0, 0, 0), PAPER, (0, 0, 6), (6, 0, 0), (6, 0, 6), (0, 6, 0), (7, 5, 1),
               (7, 7, 0), (0, 0, 6), (0, 6, 0), (6, 0, 0), (6, 0, 6), (7, 5, 4), (4, 4, 4), PAPER]


def read_gpl(path):
    """16 colours of a GIMP palette file (Aseprite and GIMP read and write
    them), 8-bit RGB rounded to the 3 bits of the MSX2 palette."""
    cols = []
    for line in open(path):
        p = line.split()
        if len(p) >= 3 and all(v.isdigit() for v in p[:3]):
            cols.append(tuple(min(7, round(int(v) * 7 / 255)) for v in p[:3]))
    if len(cols) != 16:
        raise SystemExit('%s: %d colours, 16 expected' % (path, len(cols)))
    return cols


def write_gpl(path, name, pal, names):
    lines = ['GIMP Palette', 'Name: %s' % name, 'Columns: 8',
             '# 16 colours of the MSX2 (3 bits per component: 0, 36, 73, 109, 146, 182, 219, 255)']
    for (r, g, b), n in zip(pal, names):
        lines.append('%3d %3d %3d\t%s' % (r * 255 // 7, g * 255 // 7, b * 255 // 7, n))
    open(path, 'w').write('\n'.join(lines) + '\n')


def load(name, default):
    path = os.path.join(ASSETS, 'palette_%s.gpl' % name)
    return read_gpl(path) if os.path.exists(path) else default


PLAY = load('play', DEFAULT_PLAY)
HUD = load('hud', DEFAULT_HUD)

# indices used by the runtime
INK, WHITE, FIXED_WHITE, KISS = 1, 2, 15, 13


def variant(name):
    """PLAY palette for a time of day: 'day', 'dusk' or 'night'. Dusk and
    night come from assets/palette_play_dusk.gpl / _night.gpl when they
    exist (entries 0, 1 and 15 are always taken from the day), otherwise
    they are computed from the day colours."""
    path = os.path.join(ASSETS, 'palette_play_%s.gpl' % name)
    if name != 'day' and os.path.exists(path):
        pal = read_gpl(path)
        return [PLAY[i] if i in FIXED else c for i, c in enumerate(pal)]
    out = []
    for i, (r, g, b) in enumerate(PLAY):
        if i in FIXED or name == 'day':
            out.append((r, g, b))
        elif name == 'dusk':
            out.append((round(r * 0.85), round(g * 0.75), round(b * 0.7)))
        else:
            out.append((round(r * 0.3), round(g * 0.35), min(7, round(b * 0.45) + 2)))
    return out


def pil(pal):
    flat = []
    for r, g, b in pal:
        flat += [r * 255 // 7, g * 255 // 7, b * 255 // 7]
    return flat + [0] * (768 - len(flat))


def msx(pal):
    """32 bytes for the VDP palette port: 0RRR0BBB, 00000GGG."""
    out = bytearray()
    for r, g, b in pal:
        out += bytes([r << 4 | b, g])
    return bytes(out)
