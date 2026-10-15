; Andy Capp MSX2 - fixed addresses shared by the boot code (ROM) and the
; runtime (page 0 RAM). See doc/DESIGN.md.

RT_BASE         equ 0x0000      ; the runtime is copied here
RT_STACK        equ 0x4000      ; boot stack (the game sets its own at FFFFh)
ROM_RUNTIME     equ 0x4800      ; runtime image inside ROM segment 0 (page 1 window)

; runtime variables right after the interrupt entry (a jump at 0038h)
RT_VARS         equ 0x0040
rt_slot_rom1    equ RT_VARS+0   ; slot register: page 1 = cartridge, the rest RAM
rt_slot_rom2    equ RT_VARS+1   ; slot register: page 2 = cartridge, the rest RAM
rt_slot_ram     equ RT_VARS+2   ; slot register: RAM in all four pages
rt_60hz         equ RT_VARS+3   ; not 0 on a 60 Hz machine
rt_frames       equ RT_VARS+4   ; interrupts counted by the entry
rt_skip         equ RT_VARS+5   ; not 0: the next interrupt does not run the game handler
rt_div6         equ RT_VARS+6   ; 60 Hz: counts interrupts, every 6th is not given to the game
rt_last         equ RT_VARS+7   ; rt_frames at the last main loop present
rt_pass         equ RT_VARS+8   ; frames per main loop pass: 5 (50 Hz) or 6 (60 Hz)
rt_pal_play     equ RT_VARS+9   ; PLAY palette of the time of day (2), loaded at every vertical blank
rt_bg_room      equ RT_VARS+11  ; room whose background is in the clean room page (FFh none)
rt_r9           equ RT_VARS+12  ; VDP R#9 of the game screen (212 lines, 50/60 Hz as the BIOS set it)
rt_show         equ RT_VARS+13  ; display: 0 off while the game screen is built, 1 ready (first day name), 2 on
rt_clock_min    equ RT_VARS+14  ; minute last printed on the HUD by rt_read_controls (FFh: none)

; screen geometry
PLAY_Y          equ 10          ; display line of back buffer line 0
BG_Y            equ 256         ; clean room (page 1)
SCR_Y           equ 360         ; scratch composition area (page 1)
FONT_Y          equ 468         ; HUD font, ASCII 20h-7Fh, 32 per row (VRAM 0EA00h-0F5FFh: the
                                ; interleaved SCREEN 7 opening does not touch it)
PIC_Y           equ 496         ; kiss frames at (KISS_X + 8 * frame, PIC_Y)
KISS_X          equ 144
HUD_LINE        equ PLAY_Y+103  ; line interrupt: the HUD palette from the next line on
BG_BYTES        equ 104*128     ; a room background: 104 full lines of VRAM
TILE_Y          equ 512         ; room tiles, 32 per row
ALCO_X          equ 64          ; alcometer bar: 128 x 3 pixels
ALCO_Y          equ PLAY_Y+139

; colours: PLAY palette (play area) and HUD palette, see tools/palettes.py
COL_BLACK       equ 1
COL_PANEL       equ 2           ; HUD
COL_BEER        equ 7           ; HUD: the alcometer liquid
COL_ICON0       equ 9           ; HUD 9-12: inks of the four icons
COL_INK         equ 1           ; window ink (PLAY)
COL_PAPER       equ 15          ; window paper: the white that never changes

; VDP commands
CMD_HMMM        equ 0xD0
CMD_HMMV        equ 0xC0
CMD_LMMM_TIMP   equ 0x98
CMD_LMMV        equ 0x80
CMD_LMMV_XOR    equ 0x83

; MSX hardware
VDP_DATA        equ 0x98
VDP_CTRL        equ 0x99
VDP_PAL         equ 0x9A
VDP_REGS        equ 0x9B
PPI_SLOT        equ 0xA8
PPI_KEYS        equ 0xA9
PPI_ROW         equ 0xAA
PSG_ADDR        equ 0xA0
PSG_WRITE       equ 0xA1
PSG_READ        equ 0xA2
ASCII16_PAGE1   equ 0x6000      ; mapper register: segment at 4000h-7FFFh
ASCII16_PAGE2   equ 0x7000      ; mapper register: segment at 8000h-BFFFh
