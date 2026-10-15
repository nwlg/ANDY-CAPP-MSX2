# Andy Capp MSX2 - design

Target: MSX2 with 64 KiB of RAM, SCREEN 5, ASCII16 MegaROM, PSG. Base: the
ZX Spectrum 48K code (Alternative Software re-release), disassembled
byte-identical in `../ZX/` (the reassembly of the tape bytes, not distributed
with this repository; see `BUILDING.md`). Same architecture as the DiHalt
HeroQuest MSX2 port.

## 1. Memory model

The Spectrum code uses absolute addresses and self-modifying code, so it runs
from RAM at its original addresses. The ROM only stores images that are
copied at boot.

| Z80 page | Spectrum | MSX2 |
|---|---|---|
| 0000h-3FFFh | 48K ROM (font at 3D00h used for HUD digits and day names) | RAM: MSX runtime (`src/runtime.asm`): interrupt entry 0038h, VDP renderer, input |
| 4000h-5AFFh | display file and attributes | RAM, written by the untouched parts of the game (attribute writes, alcometer bytes); never shown |
| 5B00h-5C8Fh | room link tables (copied by GameBoot) | RAM, same use |
| 5C94h-6C3Dh | back buffer, sprite save areas | RAM, same use (the original still draws into the back buffer; it is never shown) |
| 5FB4h-FEFFh | game image (ANDY1 + ANDY2) | RAM, same bytes plus the patches of `src/patches.py` |
| FF00h-FFFEh | stack (SP = FFFFh) | RAM; FFFFh itself is never written (secondary slot register on some machines) |

The BIOS is switched out after boot: RAM in all four pages, the runtime owns
the interrupt and reads the keyboard matrix and joystick itself.

## 2. Replacing the Spectrum hardware

| Spectrum | Where | MSX2 |
|---|---|---|
| control menu stub | 6446h-66C5h | not used: the runtime jumps to `GameEntry`; keyboard (cursor keys, O/P/Q/A, SPACE) and joystick port 1 are always read |
| IM 2, vector table E700h, JP at FEFEh | `GameBoot` E820h | IM 1; 0038h acknowledges the VDP and jumps to `InterruptHandler` |
| keyboard half-rows / Kempston | `ReadControls` ACBEh | `rt_read_controls`, same result C = 000LRUDF |
| AY ports FFFDh/BFFDh, Fuller Box 3Fh/5Fh | `SoundFrame` register loop DFCBh | PSG ports A0h/A1h; R7 written as (R7 AND 3Fh) OR 80h; period table rescaled for the 1.7898 MHz PSG clock |
| display file, ROM font | blit, HUD printers | native SCREEN 5 drawing with VDP commands (section 3) |
| one interrupt lost per main loop pass (the blit runs with DI longer than a frame) | `BlitBackBuffer` | the main loop present asks the interrupt entry to skip one game interrupt, so the clock keeps the 75-frame game minute; at 60 Hz one interrupt in six is skipped as well |
| `NpcBalanceDelay` busy loop | EFEBh | not needed: the main loop present waits until 5 (50 Hz) or 6 (60 Hz) frames have passed since the previous one |

## 3. Rendering

Rule: the screen is only drawn with VDP commands from graphics sheets in
VRAM; the CPU never converts the Spectrum back buffer. The original keeps
drawing into its back buffer (harmless, never shown); hooks next to the
drawing primitives describe the same scene to the runtime:

| Hook | Spectrum primitive | Native work |
|---|---|---|
| `rt_room_rows` | `DrawRoomTiles` (13 or 4 rows) | room tiles from `RoomMap` copied to the clean room page; window operations in those rows dropped; full redraw requested |
| `rt_picture` | `DrawCounterPicture` | 24x24 picture copied to the clean room page |
| `rt_play_colour` | `SetWindowColour` | palette entries 14/15 (night, dawn/dusk, day) |
| `rt_sprite` | `DrawSprite` | frame, column and facing appended to the sprite list of this pass |
| `rt_sprites_reset` | `RestoreSpriteBackgrounds` | a new sprite list starts |
| (state) | kiss | `KissState`, `KissColumn`, `KissFrame` read at present time |
| `rt_win_box`, `rt_win_char`, `rt_win_invert` | `DrawWindowBox`, `PrintWindowChar`, `InvertMenuLine` | window operations recorded (box, glyph, highlight toggle) |
| `rt_present`, `rt_present_main` | `BlitBackBuffer` | the changed rectangle is composed in a scratch area (clean room, kiss, sprites, windows) and copied to the visible page |
| `rt_hud_digit`, `rt_day_name` | `DrawDigit`, `PrintDayName` | glyphs of the HUD font (taken from the MSX BIOS font at boot) |
| `rt_alco` | alcometer drain/fill | bar redrawn from `AlcometerPtr`/`AlcometerBits` |
| `rt_paint_icon` | `PaintIcon` | the icon's own palette entry (9-12) takes the flash colour |

### Colour version: two palettes per frame

The play area and the HUD have 16 colours each. The line interrupt (R#19 =
HUD_LINE, IE1) loads the HUD palette just below the play area; the vertical
blank loads the PLAY palette of the time of day (day, dusk, night: computed
by `tools/palettes.py` from the day colours; entries 0, 1 and 15 never
change). Both palettes have black at 1 and the same white at 15, and the
lines around the switch use only those, so the switch is invisible even if
the interrupt is a little late. Palette changes of the game (time of day,
icon flash) only change the tables in RAM; the interrupt applies them.
Every VDP wait of the runtime keeps interrupts as the caller had them, so
the line interrupt is not delayed by the renderer.

Room backgrounds are pictures, not tiles: each of the 41 different rooms is
an indexed PNG (`assets/rooms/room_NN.png`, `rooms.txt` maps the 80 rooms),
stored RLE-compressed in ROM and uploaded to the clean room page when a new
room is built (about 8 frames, inside the pause the original already has).
Redraws of the same room (closing a window) upload nothing: the clean room
page never holds windows or sprites.

### VRAM (SCREEN 5, 4 pages of 256 lines)

| Lines | Use |
|---|---|
| page 0, 0-211 | display: play area at x 8-247, y 10-113; HUD at y 114-201 |
| page 0, 212-235 | sprite bottom halves, row 11 |
| page 1, 256-359 | clean room (the room picture; buffer line n = y 256+n) |
| page 1, 360-463 | scratch composition area, same geometry |
| page 1, 468-491 | HUD font (ASCII 20h-7Fh of the machine's BIOS font) |
| page 1, 496-503 | kiss frames at x 144 |
| page 2, 512-575 | window font (the Spectrum tile set, black on the fixed white) |
| page 2, 576-767 | sprite top halves (32x32), left and mirrored copies |
| page 3, 768-1007 | sprite bottom halves (32x24), rows 1-10 |

### Art

`tools/palettes.py` defines both palettes. `tools/import_zx_gfx.py` makes
the black and white pictures from the Spectrum data (and the HUD screen in
its own palette); `tools/colour_art.py` colours rooms and characters from
the Spectrum pictures with the operations of `assets/rooms/colours.txt` and
`assets/sprites_colours.txt` (flood fills, boxes, faces). A PNG listed in
`assets/HAND_MADE.txt` is never rewritten: that is how pictures painted by
hand are protected. `tools/regions.py` lists the white areas of a picture
(seed points for the specs) and `tools/art_sheet.py` makes review sheets.

## 4. ROM layout (ASCII16)

| Segment | Content |
|---|---|
| 0 | header, boot (BIOS still active: SCREEN 5, RAM search, font capture), runtime image |
| 1-3 | game image 5FB4h-FEFFh with the patches |
| 4- | VRAM blobs (window font, sprite sheets, HUD screen, kiss), then the RLE room pictures |

## 5. Build and test

`make` builds `build/andycapp.rom` from `../ZX/build/game.bin` (the
Spectrum reassembly, see `BUILDING.md`), `src/patches.py`, `src/*.asm` and `assets/`.
`make run` starts it in openMSX (Philips NMS 8250, 50 Hz), `make run60` on a
Panasonic FS-A1WSX (60 Hz); `tools/run_test.sh` runs it headless and
`tools/vram2png.py` renders the VRAM dump.

`make manual` builds the user manual (`manual/manual-es.pdf`,
`manual-en.pdf`) from the LaTeX sources and the pictures in `manual/art/`:
the screens come from `tools/manual_shots.tcl` (a scripted game that dumps
the VRAM, rendered by `vram2png.py`), the cover `art/cover.png` is a copy of `assets/opening.png` and
`art/cover-shot.png` is `assets/opening_screen.png` scaled to 640x480.

`make dist` writes `dist/` for a MegaFlashROM SCC+ SD card
(`tools/make_dist.py`): the ROM, Manuel Pazos's loader `OPFXSD.COM`, the
Nextor / MSX-DOS 2 and MSX-DOS 1 boot files (copied from this computer, not
kept in the repository) and `AUTOEXEC.BAT` / `ANDYCAPP.BAT` with
`OPFXSD ANDYCAPP.ROM /A16 /X` (ASCII16 mapper, start after writing).

## 6. Status

2026-10-11: first playable build. Verified in headless openMSX runs
(Philips NMS 8250 at 50 Hz, Panasonic FS-A1 at 60 Hz):

- **Boot:** the boot code and runtime start the game; the title appears
  with "PRESS FIRE TO START".
- **Native rendering:** rooms, counter pictures, Andy and the NPCs (with
  transparency and mirrored copies), the kiss, text windows and menus with
  their highlight, and the HUD (digits, day name, alcometer bar, icon flash
  through the palette).
- **Colours and sound:** play-area colours follow the time of day (night
  outdoors is blue on black); the PSG is written by the original driver.
- **Clock:** the game interrupt runs at 40 ticks per second on both
  machines, as on the Spectrum (75-frame game minute).
- **Random play:** no game writes into page 0 RAM.

Found on the way: the first `RemoveKiss` erases a kiss that was never drawn
at 0000h (Spectrum ROM there, the runtime here); `KissBufferAddr` now starts
at the unused screen RAM. The Spectrum attributes (`HudAttrTable`) are
copied to 5800h at boot because the icon bar reads them back.

Not verified yet: fights (dust cloud), court and jail scenes, the full
solution, sound by ear, joystick.

2026-10-11 (colour version): split palette by line interrupt, painted room
pictures, coloured characters (first pass made with `tools/colour_art.py`),
window text black on white at any time of day, night as a dark blue-violet
version of the day colours. Checked in headless runs with
`tools/vram2png.py`, which renders the split screen from the VRAM and the
palettes in the runtime RAM (`NAME_scr.png`); real screenshots from a hidden
virtual display are stale, so the raster timing of the split still has to be
seen on a real screen.

2026-10-11 (HUD and room change):
- **Room change:** wrong colours for about half a second, reported by the user and measured in the user's replay. `BuildRoom` drew the 390 tiles into the (never shown) back buffer with interrupts off for about 220 ms, so neither the line interrupt nor the vertical blank could switch the palettes. The tile loop is now skipped (patch at F5F4h). Interrupts stay off for about 12 ms, and the whole room change takes about 0.18 s.
- **HUD palette:** a newsprint cream panel, which index 15 of both palettes shares, so the panel runs up to the play area without a seam (it is also the border and the window paper). Red labels, black numbers, a grey alcometer tube with beer-coloured liquid, and a white speech bubble and yellow warning sign on the icons.
- **Faces:** Andy's cap is a grey check; Flo has a skin-coloured face and a red checked blouse.
- **Source:** `assets/hud_colours.txt` (HUD palette names), made by `tools/colour_art.py hud`.
- 2026-10-11, follow-up from a second user replay: a tenth of a second of wrong colours was still visible. The 12 ms that `BuildRoom` still spent with interrupts off could straddle the vertical blank, so the play palette arrived half a frame late. The DI at F5C5h is now a NOP. Measured over 8 room changes: vertical blank and line interrupt always 20.0-20.1 ms apart; the game interrupt handler takes at most 1.7 ms.

2026-10-11 (boot and controls):
- **Boot sequence:**
  1. DiHalt Studio logo (`assets/dihalt_logo.png`, SCREEN 5, its own 16 colours), about 4 seconds, cannot be skipped.
  2. Opening: the box cover (`assets/opening_screen.png`, 512x424 in 16 colours, made from the photo `assets/opening.png` by `tools/make_opening.py`). It is shown in SCREEN 7 with interlace, the even lines in page 0 and the odd lines in page 1, as in MSX2Civ. It waits until a key or a joystick (either port, any direction or button) is pressed and released.
  3. The game.
- **SCREEN 7 VRAM:** in SCREEN 7 the VRAM is interleaved, and the odd field fills physical 08000h-0E9FFh. For that reason the HUD font now starts at line 468 (0EA00h) and the kiss frames are at line 496.
- **Controls:** the cursor keys and SPACE, plus a joystick in either port (both buttons fire). O, P, Q and A were dropped.

2026-10-11 (music during play, credit line):
- **Music during play:** the Spectrum 128 AY tune, which the original plays only on the title screen, now goes on during the game, as the C64 version does (the C64 in-game tune is the same composition). `NewGame` no longer calls `MusicStop` (patch at FED1h). The sound effects take channel A (the accompaniment, the voice the C64 effects take) instead of C (the bass): patches at DF49h, DF8Dh, DF90h, DF99h. Each frame the music rewrites the channel's period, volume and noise bit, so it comes back as soon as an effect ends.
- **50 Hz music:** the 50 Hz tick that the runtime skips after every main loop present (40 game ticks per second, see "Clock") still runs `SoundFrame`, so the tune keeps its tempo. Measured in openMSX during play: one `SoundFrame` per vertical blank. The driver costs up to 8200 T-states (2.3 ms) in that interrupt.
- **Credit line:** the "PRESS FIRE TO START" window adds an empty line and "MSX2 BY DIHALT 2026" (`rt_msg_title` in the runtime, patch at FEBFh). The window font got the digits 0-9 at tiles D3h-DCh of `assets/tiles.png` (character c is tile c + A3h; those tiles were Spectrum room graphics, unused on the MSX2).
- **Start of the game without wrong colours:** reported by the user from a replay. When the opening ended, the display came back on while the boot loaded the game screen with interrupts off, so for a moment the HUD showed with the play palette and the play area was empty. Now the display stays off (R#1 = 22h) from the end of the opening until the game screen is complete: the first room drawn (`BlitBackBuffer` at E826h) and the day name printed by `NewGame` (the HUD picture has a sample "WEDNESDAY" in that place). `rt_day_name` then sets `rt_show` = 1, and the next vertical blank interrupt turns the display on (R#1 = 62h) right after it loads the PLAY palette. Checked in openMSX (headless, frame by frame): display off for 2.0 s after the opening, then the first frame shown has the whole room, MONDAY, the HUD and both palettes; the alcometer fill follows as on the Spectrum.
- **Messages wait for FIRE:** a message window (inventory items, examine, "THAT WAS GOOD"...) closed by itself after 50 frames (1-2 s) on the Spectrum. Now it stays until FIRE is pressed (and released): the countdown in `WindowMessageWait` is gone (patch at EAB7h). Menus already waited for FIRE; the "PRESS FIRE TO START" window does not use this wait. The game interrupt keeps running meanwhile (game clock, music).
- **HUD time while waiting:** the main loop prints the time on every pass, but messages, menus, the icon bar and "PRESS FIRE" wait in loops of their own while the interrupt keeps the clock running, so the HUD time froze. All those loops read the controls: `rt_read_controls` now starts with `rt_clock_hud`, which prints the time through the game's `PrintNumber2` when the minute differs from `rt_clock_min` (the menu loop reads the controls without pause; the VDP is not touched otherwise). Checked in openMSX with a message open: 05:45 -> 05:49 in 4 s. The day name, the alcometer and the night colours still change only in the main loop.

2026-10-12 (interview text, cover):
- **"AN MSX":** in the factory job interview ("WHAT HAVE YOU USED") the first answer "A SPECTRUM" reads "AN MSX" and the misspelt "AN ABUCUS" reads "AN ABACUS" (patch at BCF7h). The three entries of `MenuComputers` move up four bytes (the code passes only the start of the list and reads the choice as a number), and the four bytes left over at the end become 00h.
- **Manual:** screens taken again, cover and cover screen from the new picture, and a paragraph on the MegaFlashROM SCC+ SD (`make dist`) in "Setting up".
- **Cover:** `assets/opening_screen.png` made again with `tools/make_opening.py --force` from the new `assets/opening.png` (no white page around it any more: the picture fills the full height, 332 x 424 at x = 90).

2026-10-15 (icon bar speed, `make run-turbor`):
- **`make run-turbor`:** runs the ROM on a Panasonic FS-A1GT (MSX turbo R, 60 Hz); the machine is `MACHINETR`.
- **Icon bar pace:** a pass of the icon bar loop (`IconBar` at F754h) is "flash the selected icon (one HALT in `PaintIcon`) + two HALTs", 3 interrupts = 60 ms on the Spectrum, and one icon moves per pass while LEFT/RIGHT is held. On the MSX a HALT also ends at the HUD line interrupt, so the pass lasted 1.5 frames: measured in openMSX on the FS-A1GT (60 Hz) 40 passes per second (25 ms), against 17 on the Spectrum and 33 at 50 Hz. Now the three waits end only at a vertical blank (`rt_wait_vbl`, patch at F757h for the loop's two and `rt_paint_icon` for the third): 3 frames, 20 passes per second at 60 Hz (50 ms), 16.7 at 50 Hz (60 ms, as the Spectrum). Checked on the FS-A1GT: the selection moves one icon per pass in both directions. Other HALTs paced by input are unchanged: the menu highlight (EA5Fh, EA85h, and the present's HALT) and the window opening and closing (FC47h, FC5Dh) still last as many interrupts as before, which on the MSX is about twice as fast as on the Spectrum.
