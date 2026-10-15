#!/usr/bin/env python3
"""Writes the palettes of assets/palette_play.gpl and palette_hud.gpl into
every indexed PNG of assets/, so that a paint program shows the colours of
the game. Only the palette of the files changes, never their pixels.

    apply_palette.py              after editing a .gpl file
    apply_palette.py PICTURE      after editing the palette of one picture

With PICTURE (e.g. rooms/room_21.png, path from assets/ or from here), its
16 colours, rounded to the 3 bits of the MSX2, first replace the .gpl file
of its palette (palette_hud.gpl for screen.png, palette_play.gpl for the
rest; the colour names are kept), and then go into every other picture of
that palette.

The build itself always takes the colours from the .gpl files, not from the
PNGs. opening_screen.png has its own palette and is never touched.
"""
import glob
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'assets')
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import palettes  # noqa: E402

OWN_PALETTE = ('opening_screen.png',)


def group(path):
    return 'hud' if os.path.basename(path) == 'screen.png' else 'play'


def from_picture(arg):
    """Reads the palette of one picture into its .gpl file; returns (group, palette)."""
    path = next((p for p in (arg, os.path.join(ASSETS, arg)) if os.path.isfile(p)), None)
    if path is None:
        sys.exit('%s: no such picture (give the path from assets/, e.g. rooms/room_21.png)' % arg)
    name = os.path.basename(path)
    if name in OWN_PALETTE:
        sys.exit('%s has its own palette, shared with no other picture' % name)
    im = Image.open(path)
    if im.mode != 'P':
        sys.exit('%s: not an indexed PNG' % arg)
    p = (im.getpalette() + [0] * 48)[:48]
    pal = [tuple(min(7, round(v * 7 / 255)) for v in p[3 * i:3 * i + 3]) for i in range(16)]
    g = group(path)
    if pal == (palettes.HUD if g == 'hud' else palettes.PLAY):
        print('%s: its palette is already that of palette_%s.gpl, nothing to sync. If you changed a colour,'
              ' the paint program saved repainted pixels instead of a new palette entry.'
              % (os.path.relpath(path, ROOT), g))
    names, title = (palettes.HUD_NAMES, 'status panel') if g == 'hud' else (palettes.PLAY_NAMES, 'play area (day)')
    palettes.write_gpl(os.path.join(ASSETS, 'palette_%s.gpl' % g), 'Andy Capp MSX2 ' + title, pal, names)
    print('assets/palette_%s.gpl <- %s' % (g, os.path.relpath(path, ROOT)))
    other = palettes.PLAY if g == 'hud' else palettes.HUD
    for i in (1, 15):
        if pal[i] != other[i]:
            print('warning: entry %d differs from the %s palette, the switch line will show'
                  % (i, 'play' if g == 'hud' else 'hud'))
    return g, pal


def main():
    pals = {'play': palettes.PLAY, 'hud': palettes.HUD}
    only = None
    if len(sys.argv) > 1:
        only, pal = from_picture(sys.argv[1])
        pals[only] = pal
    files = glob.glob(os.path.join(ASSETS, '*.png')) + glob.glob(os.path.join(ASSETS, 'rooms', '*.png'))
    count = 0
    for f in sorted(files):
        if os.path.basename(f) in OWN_PALETTE or (only and group(f) != only):
            continue
        im = Image.open(f)
        if im.mode != 'P':
            print('not indexed, left alone:', os.path.relpath(f, ROOT))
            continue
        pal = palettes.pil(pals[group(f)])
        if im.getpalette()[:48] != pal[:48]:
            im.putpalette(pal)
            im.save(f)
            count += 1
    print('%d pictures changed' % count)


if __name__ == '__main__':
    main()
