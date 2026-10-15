#!/bin/sh
# Takes the screens of the manual: build/manual/<name>_scr.png (rendered with
# both palettes by tools/vram2png.py). Needs build/andycapp.rom.
cd "$(dirname "$0")/.."
mkdir -p build/manual build/test
export AC_OUT="$PWD/build/test/man" DISPLAY=:99 SDL_AUDIODRIVER=dummy OPENMSX_USER_DATA="$HOME/.cache/openmsx-tests/share"
openmsx -machine Philips_NMS_8250 -carta build/andycapp.rom -romtype ASCII16 -script tools/manual_shots.tcl >/dev/null 2>&1
for n in title home pub pub2 street kiss night night2 menu message; do
    python3 tools/vram2png.py man_$n && cp build/test/man_${n}_scr.png build/manual/$n.png
done
