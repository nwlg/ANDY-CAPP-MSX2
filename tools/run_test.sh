#!/bin/sh
# Boots build/andycapp.rom in a private openMSX instance on the virtual
# display and writes build/test/<name>.vram/.pal/.txt (render with
# tools/vram2png.py <name>) and <name>_scr.png, the real picture (both
# palettes of the split screen).
#   tools/run_test.sh NAME [SECONDS] [MACHINE] [KEYS]
# KEYS: "seconds key ..." pairs, key = space left right up down o p q a or
# row:mask of the keyboard matrix; key/hold to hold it longer than 0.3 s.
# AC_SHOTS="t1 t2 ...": extra VRAM dumps NAME_t1 ... at those seconds.
cd "$(dirname "$0")/.."
mkdir -p build/test
if [ -n "$4" ]; then export AC_KEYS="$4"; fi
export AC_OUT="$PWD/build/test/${1:-boot}" AC_SECS="${2:-20}"
export DISPLAY=:99 SDL_AUDIODRIVER=dummy OPENMSX_USER_DATA="$HOME/.cache/openmsx-tests/share"
exec openmsx -machine "${3:-Philips_NMS_8250}" -carta build/andycapp.rom -romtype ASCII16 \
    -script tools/test.tcl
