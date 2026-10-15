# Editable art

Every picture of the game is an indexed PNG in this directory. The build
(`make`) takes them as they are. Paint them with any program that keeps
indexed colour, for example Aseprite or GIMP in indexed mode. Do not convert
them to RGB.

## Palettes

The screen has two palettes of 16 colours. A line interrupt switches between
them below the play area.

| File | Used by |
|---|---|
| `palette_play.gpl` | rooms, characters, window font, kiss (the day colours) |
| `palette_hud.gpl` | `screen.png` (frame and status panel) |
| `palette_play_dusk.gpl`, `palette_play_night.gpl` (optional) | the play area at dawn/dusk and at night; without them both are computed from the day colours |

These are GIMP palette files; Aseprite and GIMP load and save them. The MSX2
has 3 bits per component, so every value is rounded to 0, 36, 73, 109, 146,
182, 219 or 255. After changing a `.gpl` file, run `make palette`: it writes
the new colours into every PNG so that the paint program shows them. The
build always reads the colours from the `.gpl` files.

To work the other way round, change the palette of one picture in the
paint program and run `make syncpal FROM=rooms/room_21.png` (any picture,
path from `assets/`). Its 16 colours, rounded to 3 bits, replace the `.gpl`
file of its palette (`palette_hud.gpl` for `screen.png`, `palette_play.gpl`
for the rest) and go into every other picture of that palette. It warns
when entries 1 or 15 no longer match the other palette.
`opening_screen.png` has a palette of its own; neither command touches it.

Fixed entries, both palettes:
- **0:** transparent in the character and kiss pictures (black elsewhere).
- **1:** black.
- **15:** the newsprint white of the border, the window paper and the line
  where the palettes switch. Keep 1 and 15 equal in both palettes, or the
  switch line becomes visible. Entries 0, 1 and 15 do not change at night.

Play palette entries 2-14 are free colours: their names are in the `.gpl`
file, and changing a colour changes it everywhere.

`screen.png` has the HUD palette, but its rows 0-103 (the frame beside the
play area) are shown with the play palette: paint them only with 1 and 15,
the entries both palettes share. From row 104 down it is the HUD palette.

HUD palette entries that the code uses:
- **2:** the panel; the digits and day name are printed black on it.
- **7:** the alcometer liquid.
- **9-12:** the inks of the four icons. The selected icon flashes by changing
  its entry, so keep each icon's outline in its own entry.

## Pictures

| File | Size | Content |
|---|---|---|
| `rooms/room_NN.png` | 240x104 | background of a room; `rooms/rooms.txt` says which of the 80 rooms show it (the counter people are part of the picture) |
| `sprites_top.png` | 256x128 | upper halves (32x32) of the characters, 8 per row |
| `sprites_bot.png` | 256x144 | lower halves (32x24), 8 per row: one character per row |
| `screen.png` | 256x192 | frame and status panel; the play area inside the frame (y 0-103) is drawn by the game |
| `tiles.png` | 256x64 | the font of the text windows: character `c` is tile `c + A3h` (letters A-Z, `?` and `!` in the last row, digits 0-9 at tiles D3h-DCh); the other tiles are unused Spectrum room graphics |
| `kiss.png` | 32x8 | the 4 frames of a blown kiss |
| `dihalt_logo.png` | any size, RGB | the logo shown at power on; the build scales it to 256x212 |
| `opening.png` | any size, RGB | the box art of the cover screen; also the cover of the manual |
| `opening_screen.png` | 512x424 | the cover screen as the cartridge shows it (SCREEN 7, interlaced), 16 colours of its own; made from `opening.png` by `tools/make_opening.py --force` (without `--force` it keeps the existing one, so it can be retouched by hand) |

The upper and lower halves are combined into frames as the Spectrum game
did. Halves are shared between frames: one walking upper half serves
several steps, for example. The characters are drawn facing left; the
mirrored copies are made by the build, so paint only the left-facing
version.

| Upper halves | Lower halves | Character |
|---|---|---|
| 0-3 | 0-7 | Andy |
| 4-7 | 8-15 | Flo |
| 8-11 | 16-23 | the woman with the ponytail |
| 12-15 | 24-31 | the rent man |
| 16-19 | 32-39 | the policemen |
| 20-25 | 40-45 | the fight cloud |

Do not change the sizes or the positions of the cells: the build checks the
size, the indexed mode and that only colours 0-15 are used.

## Seeing the result

`make preview` writes `build/preview/`:
- **`characters.png`:** every frame assembled, facing left and right.
- **`characters_night.png`:** the same with the night palette.
- **`rooms_day.png`, `rooms_dusk.png`, `rooms_night.png`:** every room picture.
- **`hud.png`:** the status panel.

`make run` builds the ROM and starts it in openMSX.

## The first colouring

The pictures were coloured from the black and white Spectrum graphics by
`tools/colour_art.py`, following `rooms/colours.txt`,
`sprites_colours.txt` and `hud_colours.txt`. That tool never replaces an
existing picture unless it is given `--force`, and never replaces one named
in `HAND_MADE.txt`. Add every picture you paint to `HAND_MADE.txt` (one
name per line, e.g. `rooms/room_21.png` or `sprites_top.png`).
