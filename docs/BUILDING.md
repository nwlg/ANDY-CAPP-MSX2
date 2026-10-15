# Building and running

## Requirements

| Tool | Notes |
|---|---|
| GNU make | |
| **sjasm** 0.42c | the classic SjAsm by Sjoerd Mastijn, **not** SjAsmPlus (different syntax) |
| Python 3 | with [Pillow](https://python-pillow.org/) 10 or newer |
| openMSX | to run and test; machines used: Philips NMS 8250 (MSX2), Panasonic FS-A1WSX (MSX2+), Panasonic FS-A1GT (turbo R) |
| pdflatex | only for `make manual` (TeX Live with the `babel`, `booktabs` and `tabularx` packages) |

The game needs an MSX2 with 64 KB of RAM and 128 KB of VRAM.

## The Spectrum original

**The original game is needed to build.** The port patches the original program (`src/patches.py` lists every change:
address, expected bytes, replacement) and reads its symbols, so the Spectrum game must be in a folder named `ZX` next to
this repository (`../ZX`). It is not distributed here; the game belongs to its rights holders. Without it,
`make run` still plays `release/andycapp-msx2.rom` once you have downloaded it.

The build reads three files from it:

| File | What it is |
|---|---|
| `../ZX/build/game.bin` | the game image, 5FB4h-FEFFh of the Spectrum 48K tape (*Andy Capp*, the Alternative Software re-release), reassembled with sjasm from a labelled disassembly |
| `../ZX/build/game.sym` | the labels of that disassembly (`name: equ 0xADDR`); the runtime refers to them as `ZX_<name>`, for example `ZX_SoundFrame`, `ZX_ClockMinute`, `ZX_PrintNumber2` |
| `../ZX/orig/game_5FB4_FEFF.bin` | the same bytes straight from the tape; the build stops if the reassembly differs from them |

`tools/import_zx_gfx.py` and `tools/colour_art.py`, which made the first version of the art from the Spectrum graphics,
also read `../ZX/orig`. They are not needed to build: the art is in `assets/`.

## Quick start

```sh
git clone https://github.com/nwlg/ANDY-CAPP-MSX2.git
cd ANDY-CAPP-MSX2
make          # builds build/andycapp.rom (needs ../ZX)
make run      # starts it in openMSX
make release  # copies the ROM and the manuals to release/, plus a zip
```

**`build/andycapp.rom` is the game**: a 512 KB ASCII16 MegaROM that holds the boot code and the runtime, the Spectrum game
image with its patches, the pictures and the cover. Load it with the ASCII16 mapper forced (`-romtype ASCII16`); the
`make run` targets do it.

## All targets

`make help` prints the list.

| Target | Does |
|---|---|
| `make` | builds `build/andycapp.rom` |
| `make run`, `run60`, `run-turbor` | plays it in openMSX on an MSX2 (50 Hz), an MSX2+ (60 Hz) or a turbo R (60 Hz); override the machine with `MACHINE=`, `MACHINE60=`, `MACHINETR=` and pass options with `OPENMSX_EXTRA=` |
| `make release` | the ROM and the manuals in `release/`, plus `andycapp-msx2-$(VERSION).zip` |
| `make dist` | `dist/`, the files for a MegaFlashROM SCC+ SD card |
| `make manual` | rebuilds the pictures and the two PDFs in `docs/manual/` |
| `make test` | boots the ROM headless in openMSX and writes `build/test/boot.png` (needs Xvfb) |
| `make preview` | pictures of the editable art as the game shows it, in `build/preview/` |
| `make palette`, `make syncpal FROM=...` | palette tools, see [../assets/README.md](../assets/README.md) |
| `make clean` | removes `build/` and `dist/` |

## SD card folder (MegaFlashROM SCC+ SD)

`make dist` copies the ROM and the system files into `dist/` and writes an `AUTOEXEC.BAT` (and `ANDYCAPP.BAT`, the same)
that starts the loader: `OPFXSD ANDYCAPP.ROM /A16 /X` (ASCII16 mapper, run the game after writing it to the flash). The
system files are third-party and are not in the repository; put them in `third_party/` (not tracked) or point to them
with environment variables:

| File | Folder (default) | Variable |
|---|---|---|
| `OPFXSD.COM` (Manuel Pazos, from the MegaFlashROM SCC+ SD tools) | `third_party/opfxsd.com` | `OPFXSD` |
| `NEXTOR.SYS` (Nextor, with 128 KB of RAM or more) | `third_party/nextor/` | `NEXTOR_DIR` |
| `MSXDOS2.SYS`, `COMMAND2.COM` | `third_party/dos2/` | `DOS2_DIR` |
| `MSXDOS.SYS`, `COMMAND.COM` (MSX-DOS 1, 64 KB machines) | `third_party/dos1/` | `DOS1_DIR` |

Copy the contents of `dist/` to the root of the card. The computer starts MSX-DOS, `AUTOEXEC.BAT` writes the game to the
cartridge and starts it. From then on the cartridge starts Andy Capp every time it is switched on; hold ESC while
switching on to boot the card instead; `OPFXSD /C` erases the game.

## What happens during a build

1. `tools/build_rom.py` reads `../ZX/build/game.bin` and `game.sym` and writes `build/zx_syms.inc` (the labels as
   `ZX_*`).
2. It applies `src/patches.py` to the game image; the build fails if an expected byte does not match.
3. It converts the PNGs of `assets/` (room pictures with RLE, VRAM blobs, window font, status panel, kiss, cover, logo)
   and the palettes (`assets/palette_*.gpl`) into binary tables.
4. sjasm assembles `src/runtime.asm` (the page 0 runtime) and `src/rom.asm` (the boot code and the segment layout).
5. The ROM is laid out in 16 KB segments: boot and runtime, three segments of game image, the VRAM blobs, the rooms, the
   logo and the cover.

[DESIGN.md](DESIGN.md) has the details, including the memory model and the rendering.
