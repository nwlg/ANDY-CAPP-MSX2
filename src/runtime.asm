; Andy Capp MSX2 - runtime, copied to page 0 RAM (0000h) by the boot code.
; Assemble with sjasm 0.42c. See doc/DESIGN.md.
;
; Everything the Spectrum code needs from the machine: interrupt entry, ROM
; access at boot, input reader and the SCREEN 5 renderer. Nothing is drawn by
; converting the Spectrum back buffer: hooks next to the original drawing
; primitives describe the scene, which is composed with VDP commands from the
; graphics sheets in VRAM (see the table in doc/DESIGN.md, section 3).

        include "layout.inc"
        include "../build/zx_syms.inc"

        org RT_BASE
        di
        jp rt_boot

        ds 0x0038-$,0
        jp rt_irq               ; IM 1 interrupt entry

        ds RT_VARS+16-$,0       ; RT_VARS: see layout.inc

; ---- interrupt -----------------------------------------------------------------
; Two sources. The line interrupt at HUD_LINE loads the HUD palette. The
; vertical blank loads the PLAY palette of the time of day and runs the
; game's own handler (which ends with EI / RETI) at the Spectrum's 50 Hz: on
; a 60 Hz machine one interrupt in six is dropped first. Of those 50 Hz
; ticks, the one after every main loop present is skipped too (the Spectrum
; loses that interrupt while its blit runs with interrupts off), so the game
; clock keeps its 75-frame minute; only the sound driver runs on that tick.
rt_irq:
        push af
        push hl
        ld a,1
        out (VDP_CTRL),a
        ld a,0x8F               ; R#15 = 1
        out (VDP_CTRL),a
        in a,(VDP_CTRL)         ; S#1: bit 0 = line interrupt (cleared by the read)
        ld h,a
        xor a
        out (VDP_CTRL),a
        ld a,0x8F               ; R#15 = 0 again
        out (VDP_CTRL),a
        bit 0,h
        jr z,rt_irq_vblank
        ld hl,rt_pal_hud
        call rt_irq_palette
        pop hl
        pop af
        ei
        ret
rt_irq_vblank:
        in a,(VDP_CTRL)         ; S#0: acknowledge the vertical blank
        ld hl,(rt_pal_play)
        call rt_irq_palette
        ld a,(rt_show)          ; first picture of the game ready: the display goes
        dec a                   ; on here, after the PLAY palette, so the very first
        jr nz,rt_irq_shown      ; frame shown has both palettes
        ld a,2
        ld (rt_show),a
        ld a,0x62               ; R#1: display on
        out (VDP_CTRL),a
        ld a,0x81
        out (VDP_CTRL),a
rt_irq_shown:
        ld hl,rt_frames
        inc (hl)
        ld a,(rt_60hz)
        or a
        jr z,rt_irq_tick
        ld hl,rt_div6
        dec (hl)
        jr nz,rt_irq_tick
        ld (hl),6
        jr rt_irq_drop          ; not a 50 Hz tick (a pending skip waits)
rt_irq_tick:
        ld hl,rt_skip
        ld a,(hl)
        or a
        jr z,rt_irq_game
rt_irq_skip:
        ld (hl),0
        push bc                 ; the tune plays during the game: the skipped
        push de                 ; tick still runs the sound driver, so the
        call ZX_SoundFrame      ; music keeps its 50 Hz (preserves IX)
        pop de
        pop bc
rt_irq_drop:
        pop hl
        pop af
        ei
        ret
rt_irq_game:
        pop hl
        pop af
        jp ZX_InterruptHandler

; rt_irq_palette: load the 16 entries at HL. Interrupts are off. Clobbers A, HL.
rt_irq_palette:
        push bc
        xor a
        out (VDP_CTRL),a
        ld a,0x90               ; R#16 = 0
        out (VDP_CTRL),a
        ld bc,32*256+VDP_PAL
        otir
        pop bc
        ret

; ---- boot ------------------------------------------------------------------------
; Entered from the ROM boot code with page 1 = cartridge, the rest RAM,
; interrupts off. Copies the game image, loads the graphics into VRAM and
; starts the game at GameEntry.
rt_boot:
        ld sp,RT_STACK
        call rt_logo
        call rt_opening
        ld hl,rt_pal_hud_rom    ; the HUD palette can change (icon flash): RAM copy
        ld de,rt_pal_hud
        ld bc,32
        ldir
        ld hl,rt_pal_day
        ld (rt_pal_play),hl
        call rt_set_palette
        ld a,15                 ; border: the fixed white of both palettes, as the
        ld c,7                  ; Spectrum's white border
        call rt_wreg
        ld a,HUD_LINE
        ld c,19
        call rt_wreg
        ld a,0x16               ; R#0: SCREEN 5 with the line interrupt
        ld c,0
        call rt_wreg
        ld hl,rt_cmd_clear_all
        call rt_cmd_block
        ld hl,rt_game_chunks
        call rt_copy_chunks
        ld hl,rt_vram_blobs
        call rt_load_blobs
        ld a,(rt_slot_ram)
        out (PPI_SLOT),a
        ld hl,ZX_HudAttrTable   ; the Spectrum attributes as StartFromMenu leaves
        ld de,0x5800            ; them: the icon bar reads them back (IconSavedAttr)
        ld bc,768
        ldir
        xor a
        ld (rt_show),a
        ld (rt_frames),a
        ld (rt_skip),a
        ld (rt_last),a
        ld (rt_spr_n),a
        ld (rt_spr_old_n),a
        ld (rt_ops_n),a
        ld a,6
        ld (rt_div6),a
        ld a,(rt_60hz)
        or a
        ld a,5
        jr z,rt_boot_pass
        inc a
rt_boot_pass:
        ld (rt_pass),a
        ld a,0xFF
        ld (rt_clock_min),a
        ld (rt_kiss_col),a
        ld (rt_play_attr),a
        ld (rt_bg_room),a
        call rt_dirty_clear
        im 1
        jp ZX_GameEntry

; rt_logo: the DiHalt Studio logo, SCREEN 5 page 0, about 4 seconds; it
; cannot be skipped. Interrupts are off.
rt_logo:
        ld a,0x22               ; display off
        ld c,1
        call rt_wreg
        ld hl,rt_logo_palette
        call rt_set_palette
        ld a,LOGO_BORDER
        ld c,7
        call rt_wreg
        ld hl,rt_logo_blobs
        call rt_load_blobs
        ld a,0x62               ; display on
        ld c,1
        call rt_wreg
        ld b,200                ; 4 seconds of frames
        ld a,(rt_60hz)
        or a
        jr z,rt_logo_wait
        ld b,240
rt_logo_wait:
        call rt_wait_frame
        djnz rt_logo_wait
        ret

; rt_opening: the cover, 512 x 424 in 16 colours: SCREEN 7 with interlace,
; the even lines in page 0 and the odd lines in page 1, which the VDP shows
; in alternate fields. It stays until a key or a joystick (either port, any
; direction or button) is pressed and released. Interrupts are off.
rt_opening:
        ld a,0x22               ; display off
        ld c,1
        call rt_wreg
        ld a,0x0A               ; R#0: SCREEN 7 (G6)
        ld c,0
        call rt_wreg
        ld hl,rt_opening_palette
        call rt_set_palette
        xor a                   ; border: colour 0, black
        ld c,7
        call rt_wreg
        ld hl,rt_opening_blobs
        call rt_load_blobs
        ld a,(rt_r9)            ; interlace, alternate pages
        or 0x0C
        ld c,9
        call rt_wreg
        ld a,0x3F               ; R#2: page 1 (page 0 in the even fields)
        ld c,2
        call rt_wreg
        ld a,0x62               ; display on
        ld c,1
        call rt_wreg
rt_op_release:
        call rt_anykey
        jr nz,rt_op_release
rt_op_press:
        call rt_anykey
        jr z,rt_op_press
rt_op_release2:                 ; the game must not see this press
        call rt_anykey
        jr nz,rt_op_release2
        ld a,0x22               ; display off, back to SCREEN 5 page 0
        ld c,1
        call rt_wreg
        ld a,(rt_r9)
        ld c,9
        call rt_wreg
        ld a,0x06
        ld c,0
        call rt_wreg
        ld a,0x1F
        ld c,2
        call rt_wreg
        ret                     ; the display stays off until the game screen is
                                ; complete (rt_show, set by rt_day_name)

; rt_wait_frame: wait for the next vertical blank (S#0 bit 7), interrupts
; off. Clobbers AF.
rt_wait_frame:
        in a,(VDP_CTRL)
        rlca
        jr nc,rt_wait_frame
        ret

; rt_anykey: NZ while any key of the 11 keyboard rows, or any direction or
; button of a joystick in either port, is down. Interrupts off. Clobbers AF, BC.
rt_anykey:
        in a,(PPI_ROW)
        and 0xF0
        ld c,a
        ld b,11
rt_ak_row:
        dec b
        ld a,c
        or b
        out (PPI_ROW),a
        in a,(PPI_KEYS)
        inc a
        ret nz                  ; not FFh: a key
        inc b
        djnz rt_ak_row
        ld b,0x00               ; joystick port 1, then port 2
rt_ak_port:
        ld a,15
        out (PSG_ADDR),a
        in a,(PSG_READ)
        and 0xBF
        or b
        out (PSG_WRITE),a
        ld a,14
        out (PSG_ADDR),a
        in a,(PSG_READ)
        or 0xC0
        inc a
        ret nz                  ; a line low: pressed
        ld a,b
        xor 0x40
        ld b,a
        jr nz,rt_ak_port
        xor a                   ; Z: nothing
        ret

; rt_copy_chunks: copy the game image from ROM. HL -> entries of segment,
; offset in the segment, destination, length; segment FFh ends. A piece
; never crosses a segment or a 16 KiB page of the destination.
rt_copy_chunks:
        ld a,(hl)
        cp 0xFF
        ret z
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = offset in the segment
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = destination
        inc hl
        push hl                 ; -> length
        ld h,a                  ; H = segment
        ld a,(rt_slot_rom1)     ; the mapper registers answer in page 1
        out (PPI_SLOT),a
        ld a,h
        bit 7,d
        jr nz,.high
        ld (ASCII16_PAGE2),a    ; destination in page 1: read through page 2
        ld a,b
        add a,0x80
        ld b,a
        ld a,(rt_slot_rom2)
        jr .go
.high:
        ld (ASCII16_PAGE1),a    ; destination in pages 2-3: read through page 1
        ld a,b
        add a,0x40
        ld b,a
        ld a,(rt_slot_rom1)
.go:
        out (PPI_SLOT),a
        pop hl
        push bc                 ; source
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = length
        inc hl
        ex (sp),hl              ; HL = source, stack -> next entry
        ldir
        ld a,(rt_slot_rom1)
        out (PPI_SLOT),a
        pop hl
        jr rt_copy_chunks

; rt_load_blobs: copy graphics from ROM to VRAM. HL -> entries of segment,
; offset, VRAM address (17 bits: low word, then bit 16), length; segment FFh ends.
rt_load_blobs:
        ld a,(rt_slot_rom1)
        out (PPI_SLOT),a
rt_lb_entry:
        ld a,(hl)
        cp 0xFF
        ret z
        inc hl
        ld (ASCII16_PAGE1),a    ; page 1 is the cartridge while blobs load
        ld c,(hl)
        inc hl
        ld a,(hl)
        add a,0x40
        ld b,a                  ; BC = source in the page 1 window
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = VRAM address bits 0-15
        inc hl
        ld a,(hl)               ; bit 16
        inc hl
        push bc
        call rt_vram_waddr
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = length
        inc hl
        ex (sp),hl              ; HL = source, stack = table pointer
rt_lb_byte:
        ld a,(hl)
        out (VDP_DATA),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,rt_lb_byte
        pop hl
        jr rt_lb_entry

; rt_vram_waddr: set the VRAM write address A:DE (A = bit 16). Interrupts
; must be off. Clobbers AF.
rt_vram_waddr:
        rlca
        rlca
        push bc
        ld b,a
        ld a,d
        rlca
        rlca
        and 3
        or b                    ; R#14 = address bits 16-14
        ld c,14
        call rt_wreg
        pop bc
        ld a,e
        out (VDP_CTRL),a
        ld a,d
        and 0x3F
        or 0x40
        out (VDP_CTRL),a
        ret

; ---- VDP access --------------------------------------------------------------------
; Every sequence of writes to the VDP control port runs with interrupts off:
; the interrupt entry reads the status port, which resets the latch.

; rt_iff: are interrupts enabled? Out: PE if they are, PO if not (callers push
; AF, DI, and later "pop af / ret po / ei"). LD A,I alone is not enough: an
; interrupt accepted during it makes the flag read "disabled"; then the
; interrupt has overwritten the zero byte left below the stack pointer.
rt_iff:
        xor a
        push af
        pop af                  ; (SP-1) = 0
        ld a,i
        jp pe,rt_iff_on
        dec sp
        dec sp
        pop af                  ; A = (SP-1)
        or a
        jr nz,rt_iff_on
        inc a
        or a                    ; PO
        ret
rt_iff_on:
        xor a                   ; PE
        ret

; rt_wreg: VDP register C := A. Interrupts off. Clobbers AF.
rt_wreg:
        out (VDP_CTRL),a
        ld a,c
        or 0x80
        out (VDP_CTRL),a
        ret

; rt_set_palette: the 16 entries at HL (2 bytes each). Clobbers AF, BC, HL.
rt_set_palette:
        call rt_iff
        push af
        di
        xor a
        ld c,16
        call rt_wreg
        ld bc,32*256+VDP_PAL
        otir
        pop af
        ret po
        ei
        ret

; rt_pal_entry: palette entry A := D (0RRR0BBB), E (00000GGG). Preserves BC.
rt_pal_entry:
        push bc
        ld b,a
        call rt_iff
        push af                 ; parity: interrupts on or off
        di
        ld a,b
        ld c,16
        call rt_wreg
        ld a,d
        out (VDP_PAL),a
        ld a,e
        out (VDP_PAL),a
        pop af
        pop bc
        ret po
        ei
        ret

; rt_zx_rgb: Spectrum colour A (bits 0-2, bit 6 bright) -> D, E palette values.
; Clobbers AF, B.
rt_zx_rgb:
        ld b,6
        bit 6,a
        jr z,rt_zr_dim
        ld b,7
rt_zr_dim:
        ld de,0
        bit 1,a                 ; red
        jr z,rt_zr_nored
        ld d,b
        rlc d
        rlc d
        rlc d
        rlc d
rt_zr_nored:
        bit 0,a                 ; blue
        jr z,rt_zr_noblue
        push af
        ld a,d
        or b
        ld d,a
        pop af
rt_zr_noblue:
        bit 2,a                 ; green
        ret z
        ld e,b
        ret

; rt_cmd_go: run the command in rt_cmd with A = command code. Waits for the
; previous command to end first. Clobbers AF, BC, HL.
rt_cmd_go:
        ld (rt_cmd+14),a
        ld hl,rt_cmd
; rt_cmd_block: run the 15-byte command block at HL (R#32-R#46), after the
; previous command has ended.
rt_cmd_block:
        call rt_iff
        push af
        di
        ld a,2
        out (VDP_CTRL),a
        ld a,0x8F               ; R#15 = 2: status register 2
        out (VDP_CTRL),a
        in a,(VDP_CTRL)
        ld b,a
        xor a
        out (VDP_CTRL),a
        ld a,0x8F               ; R#15 = 0 again for the interrupt entry
        out (VDP_CTRL),a
        bit 0,b                 ; CE: a command is still running
        jr z,rt_cg_go
        pop af                  ; wait with the interrupts as they were, so that
        jp po,rt_cmd_block      ; the line interrupt is not late
        ei
        jr rt_cmd_block
rt_cg_go:
        ld a,32
        out (VDP_CTRL),a
        ld a,0x91               ; R#17 = 32, auto increment
        out (VDP_CTRL),a
        ld bc,15*256+VDP_REGS
        otir
        pop af
        ret po
        ei
        ret

; rt_copy8: HMMM 8x8 from (L, DE) to (H, BC... see below). In: L = source x,
; DE = source y, H = destination x, BC = destination y. Clobbers AF, BC, HL.
rt_copy8:
        ld a,l
        ld (rt_cmd+0),a
        xor a
        ld (rt_cmd+1),a
        ld (rt_cmd+5),a
        ld (rt_cmd+9),a
        ld (rt_cmd+11),a
        ld (rt_cmd+13),a
        ld a,h
        ld (rt_cmd+4),a
        ld (rt_cmd+2),de
        ld (rt_cmd+6),bc
        ld a,8
        ld (rt_cmd+8),a
        ld (rt_cmd+10),a
        ld a,CMD_HMMM
        jp rt_cmd_go

; rt_rect: command A on the rectangle in rt_cmd destination fields, after
; clearing the source and argument bytes. In: B = x (0-255), DE = y, C = width
; (0 = 256), L = height, H = colour byte. Clobbers AF, BC, HL.
rt_rect:
        push af
        ld a,b
        ld (rt_cmd+4),a
        xor a
        ld (rt_cmd+5),a
        ld (rt_cmd+9),a
        ld (rt_cmd+11),a
        ld (rt_cmd+13),a
        ld (rt_cmd+6),de
        ld a,c
        ld (rt_cmd+8),a
        or a
        jr nz,rt_rect_w
        inc a
        ld (rt_cmd+9),a         ; width 256
rt_rect_w:
        ld a,l
        ld (rt_cmd+10),a
        ld a,h
        ld (rt_cmd+12),a
        pop af
        jp rt_cmd_go

; ---- input -------------------------------------------------------------------------
; rt_read_controls: replaces ReadControls. Out: C = 000LRUDF (1 = pressed),
; B = 0. Cursor keys and SPACE; a joystick in either port (both buttons fire).
; Clobbers AF, DE, HL.
rt_read_controls:
        call rt_clock_hud
        call rt_iff
        push af
        di
        in a,(PPI_ROW)
        and 0xF0
        or 8                    ; row 8: SPACE . . . LEFT UP DOWN RIGHT
        out (PPI_ROW),a
        in a,(PPI_KEYS)
        cpl
        ld e,a                  ; E: 7 right, 6 down, 5 up, 4 left, 0 space
        ld d,0x00               ; joystick port 1, then port 2
rt_rc_port:
        ld a,15
        out (PSG_ADDR),a
        in a,(PSG_READ)
        and 0xBF
        or d
        out (PSG_WRITE),a
        ld a,14
        out (PSG_ADDR),a
        in a,(PSG_READ)
        cpl                     ; bits 0 up, 1 down, 2 left, 3 right, 4-5 buttons
        ld l,a
        bit 0,l
        jr z,rt_rc_j1
        set 5,e
rt_rc_j1:
        bit 1,l
        jr z,rt_rc_j2
        set 6,e
rt_rc_j2:
        bit 2,l
        jr z,rt_rc_j3
        set 4,e
rt_rc_j3:
        bit 3,l
        jr z,rt_rc_j4
        set 7,e
rt_rc_j4:
        ld a,l
        and 0x30
        jr z,rt_rc_j5
        set 0,e
rt_rc_j5:
        ld a,d
        xor 0x40
        ld d,a
        jr nz,rt_rc_port
        ld c,0                  ; E bits 7 R, 6 D, 5 U, 4 L, 0 F -> C 000LRUDF
        bit 0,e
        jr z,rt_rc_f
        set 0,c
rt_rc_f:
        bit 4,e
        jr z,rt_rc_l
        set 4,c
rt_rc_l:
        bit 7,e
        jr z,rt_rc_r
        set 3,c
rt_rc_r:
        bit 5,e
        jr z,rt_rc_u
        set 2,c
rt_rc_u:
        bit 6,e
        jr z,rt_rc_d
        set 1,c
rt_rc_d:
        ld b,0
        pop af
        ret po
        ei
        ret

; rt_clock_hud: prints the game time on the HUD when its minute has changed
; since the last print. The main loop prints it on every pass, but messages,
; menus, the icon bar and "PRESS FIRE" wait in loops of their own while the
; interrupt keeps the clock running; all of them read the controls, so the
; time is kept up to date from here. Clobbers AF, BC, DE, HL.
rt_clock_hud:
        ld a,(ZX_ClockMinute)
        ld hl,rt_clock_min
        cp (hl)
        ret z
        ld (hl),a
        ld l,a
        ld h,0
        ld bc,ZX_ScrMinutesDigits
        call ZX_PrintNumber2
        ld hl,(ZX_ClockHour)
        ld h,0
        ld bc,ZX_ScrHoursDigits
        jp ZX_PrintNumber2

; ---- sound ---------------------------------------------------------------------------
; rt_mixer: store the mixer value of the driver for the MSX PSG: bit 7 = 1
; (port B output), bit 6 = 0 (port A input, the joysticks).
rt_mixer:
        and 0x3F
        or 0x80
        ld (ZX_AyMixer),a
        ret

; ---- scene: dirty rectangle -------------------------------------------------------------
; The rectangle of the play area that changed since the last present, in
; back buffer bytes (columns 0-32) and lines (0-104). Empty when c0 >= c1.

rt_dirty_clear:
        ld a,32
        ld (rt_dc0),a
        xor a
        ld (rt_dc1),a
        ld a,104
        ld (rt_dl0),a
        xor a
        ld (rt_dl1),a
        ret

rt_dirty_full:
        xor a
        ld (rt_dc0),a
        ld (rt_dl0),a
        ld a,32
        ld (rt_dc1),a
        ld a,104
        ld (rt_dl1),a
        ret

; rt_mark: add columns B to C-1, lines D to E-1. Clobbers AF.
rt_mark:
        ld a,(rt_dc0)
        cp b
        jr c,rt_mk1
        ld a,b
        ld (rt_dc0),a
rt_mk1:
        ld a,(rt_dc1)
        cp c
        jr nc,rt_mk2
        ld a,c
        ld (rt_dc1),a
rt_mk2:
        ld a,(rt_dl0)
        cp d
        jr c,rt_mk3
        ld a,d
        ld (rt_dl0),a
rt_mk3:
        ld a,(rt_dl1)
        cp e
        ret nc
        ld a,e
        ld (rt_dl1),a
        ret

; rt_mark_actor: mark the 32-pixel wide column band of an actor at game
; column A (pixel x = 8 * (A - 2)) on lines D to E-1. Clobbers AF, BC.
rt_mark_actor:
        ld c,a
        sub 2
        jr nc,rt_ma1
        xor a
rt_ma1:
        ld b,a
        ld a,c
        add a,2
        cp 33
        jr c,rt_ma2
        ld a,32
rt_ma2:
        ld c,a
        jr rt_mark

; ---- scene: sprites -----------------------------------------------------------------------
; rt_sprite: DrawSprite hook (replaces "ld hl,SpriteSaveCount"). Records the
; sprite of this call: frame, column and facing.
rt_sprite:
        push af
        push bc
        push de
        ld a,(rt_spr_n)
        cp 8
        jr nc,rt_spr_full
        ld c,a
        inc a
        ld (rt_spr_n),a
        ld b,0
        ld hl,rt_spr
        add hl,bc
        add hl,bc
        add hl,bc
        ld a,(ZX_SpriteFrame)
        ld (hl),a
        inc hl
        ld a,(ZX_SpriteColumn)
        ld (hl),a
        inc hl
        ld a,(ZX_SpriteFacing)
        cp 0xFF                 ; FFh = as stored, like 0
        jr nz,rt_spr_face
        xor a
rt_spr_face:
        and 1
        ld (hl),a
        ld a,(ZX_SpriteColumn)
        ld de,44*256+100
        call rt_mark_actor
rt_spr_full:
        pop de
        pop bc
        pop af
        ld hl,ZX_SpriteSaveCount
        ret

; rt_sprites_reset: RestoreSpriteBackgrounds hook (replaces "ld hl,
; SpriteSaveAreas"). The sprites shown leave: mark them, start a new list.
rt_sprites_reset:
        push af
        push bc
        push de
        ld a,(rt_spr_n)
        or a
        jr z,rt_sr_done
        ld b,a
        ld hl,rt_spr+1
rt_sr_next:
        push bc
        ld a,(hl)
        ld de,44*256+100
        call rt_mark_actor
        inc hl
        inc hl
        inc hl
        pop bc
        djnz rt_sr_next
        xor a
        ld (rt_spr_n),a
rt_sr_done:
        pop de
        pop bc
        pop af
        ld hl,ZX_SpriteSaveAreas
        ret

; ---- scene: room ----------------------------------------------------------------------------
; rt_room_rows: DrawRoomTiles hook (replaces "ei / call DrawCounterPicture").
; A full redraw of a new room uploads its painted background (RLE in ROM) to
; the clean room page; any redraw drops the window operations in the rows
; drawn and asks for a full present. Then the original DrawCounterPicture.
rt_room_rows:
        push bc
        push de
        push hl
        ei
        ld a,(ZX_DrawRoomTiles_rowCount+1)
        cp 13
        jr nz,rt_rr_same
        ld a,(ZX_AndyRoom)
        ld hl,rt_bg_room
        cp (hl)
        jr z,rt_rr_same
        ld (hl),a
        call rt_room_upload
rt_rr_same:
        ld a,(ZX_DrawRoomTiles_rowCount+1)
        add a,a
        add a,a
        add a,a                 ; lines redrawn
        call rt_ops_drop_above
        call rt_dirty_full
        pop hl
        pop de
        pop bc
        jp ZX_DrawCounterPicture

; rt_room_upload: background of room A from ROM to VRAM (0, BG_Y). The ROM
; stream is RLE: 00h-7Fh = so many plus one literal bytes, 80h-FFh = the next
; byte so many minus 7Dh times. Page 1 shows the cartridge meanwhile (the
; game interrupt only uses pages 0 and 3). Clobbers AF, BC, DE, HL.
rt_room_upload:
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de               ; 3 bytes per room
        ld de,rt_rooms
        add hl,de
        ld b,(hl)               ; segment
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        add a,0x40
        ld d,a                  ; DE = stream in the page 1 window
        push de
        call rt_iff
        push af
        di
        xor a
        ld de,BG_Y*128          ; VRAM 08000h
        call rt_vram_waddr
        ld a,(rt_slot_rom1)
        out (PPI_SLOT),a
        ld a,b
        ld (ASCII16_PAGE1),a
        pop af
        jp po,rt_ru_di
        ei
rt_ru_di:
        pop hl
        ld de,BG_BYTES
rt_ru_next:
        ld a,(hl)
        inc hl
        cp 0x80
        jr nc,rt_ru_run
        inc a
        ld b,a
        call rt_ru_count
rt_ru_lit:
        ld a,(hl)
        out (VDP_DATA),a
        inc hl
        djnz rt_ru_lit
        jr rt_ru_more
rt_ru_run:
        sub 0x7D
        ld b,a
        call rt_ru_count
        ld a,(hl)
        inc hl
rt_ru_rep:
        out (VDP_DATA),a
        nop
        djnz rt_ru_rep
rt_ru_more:
        ld a,d
        or e
        jr nz,rt_ru_next
        ld a,(rt_slot_ram)
        out (PPI_SLOT),a
        ret
; DE -= B
rt_ru_count:
        ld a,e
        sub b
        ld e,a
        ret nc
        dec d
        ret

; rt_buf_pos: back buffer address HL -> B = byte column, C = line. Clobbers
; AF, DE, HL.
rt_buf_pos:
        ld de,ZX_BackBuffer
        or a
        sbc hl,de
        ld a,l
        and 0x1F
        ld b,a
        add hl,hl
        add hl,hl
        add hl,hl               ; H = offset / 32
        ld c,h
        ret

; rt_play_colour: SetWindowColour hook (replaces "ld hl,ZX_ATTRS+1"). A = the
; Spectrum attribute of the play area (41h night, 38h dawn and dusk, 78h day
; and indoors) selects the PLAY palette that the vertical blank loads.
rt_play_colour:
        push af
        ld hl,rt_pal_day
        cp 0x41
        jr nz,rt_pc1
        ld hl,rt_pal_night
rt_pc1:
        cp 0x38
        jr nz,rt_pc2
        ld hl,rt_pal_dusk
rt_pc2:
        ld (rt_pal_play),hl
        pop af
        ld hl,0x5801            ; ZX_ATTRS+1
        ret

; ---- scene: text windows --------------------------------------------------------------------
; Window operations, 5 bytes each: type (0 deleted, 1 box, 2 glyph, 3
; highlight), then
;   box:       column, top line, width (bytes), height (lines)
;   glyph:     tile, column, line, -
;   highlight: column, line, width (bytes), -
; They are drawn over the sprites at every present, until the rows under
; them are redrawn.

RT_OPS_MAX      equ 240

; rt_win_box: DrawWindowBox hook (replaces "ld de,0020h").
rt_win_box:
        push af
        push bc
        push hl
        ld a,(ZX_WindowBoxColumn)
        ld b,a
        ld a,(ZX_WindowBoxTop)
        ld c,a
        ld a,(ZX_WindowBoxWidth)
        ld d,a
        ld a,(ZX_WindowBoxHeight)
        ld e,a
        call rt_ops_drop_inside
        ld a,1
        call rt_op_add
        ld a,b                  ; mark the box
        add a,d
        ld d,c
        ld c,a
        ld a,d
        add a,e
        ld e,a
        call rt_mark
        pop hl
        pop bc
        pop af
        ld de,0x0020
        ret

; rt_win_char: end of PrintWindowChar (replaces "pop hl / inc hl / ret",
; entered with a jump). DE = glyph + 8, (SP) = cell address.
rt_win_char:
        pop hl
        push af
        push bc
        push de
        push hl
        ex de,hl
        ld de,ZX_TileSet+8
        or a
        sbc hl,de               ; (tile * 8)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; H = tile
        ld a,h
        pop hl
        push hl
        push af
        call rt_buf_pos         ; B = column, C = line
        pop af
        push bc
        ld d,b                  ; op: tile, column, line
        ld b,a
        ld e,c
        ld c,d
        ld d,e
        ld a,2
        call rt_op_add
        pop bc
        ld a,b
        inc a
        ld d,c
        ld e,c
        ld c,a
        ld a,e
        add a,8
        ld e,a
        call rt_mark
        pop hl
        pop de
        pop bc
        pop af
        inc hl
        ret

; rt_win_invert: InvertMenuLine hook (replaces "ld hl,(MenuHighlightPtr)").
; The highlight of a line is a toggle: the same operation twice cancels.
rt_win_invert:
        push af
        push bc
        push de
        push ix
        ld hl,(ZX_MenuHighlightPtr)
        call rt_buf_pos         ; B = column, C = line
        ld a,(ZX_WindowTextWidth)
        ld d,a
        ld e,0
        ; look for the same highlight
        ld a,(rt_ops_n)
        or a
        jr z,rt_wi_add
        push bc
        ld b,a
        ld hl,rt_ops
rt_wi_find:
        ld a,(hl)
        cp 3
        jr nz,rt_wi_next
        inc hl
        ld a,(hl)
        dec hl
        pop ix                  ; (C = line, B = column of the new one)
        push ix
        cp ixh
        jr nz,rt_wi_next
        inc hl
        inc hl
        ld a,(hl)
        dec hl
        dec hl
        cp ixl
        jr nz,rt_wi_next
        ld (hl),0               ; found: the highlight goes away
        pop bc
        jr rt_wi_mark
rt_wi_next:
        inc hl
        inc hl
        inc hl
        inc hl
        inc hl
        djnz rt_wi_find
        pop bc
rt_wi_add:
        ld a,3
        call rt_op_add
rt_wi_mark:
        ld a,b
        add a,d
        ld d,c
        ld c,a
        ld a,d
        add a,8
        ld e,a
        call rt_mark
        pop ix
        pop de
        pop bc
        pop af
        ld hl,(ZX_MenuHighlightPtr)
        ret

; rt_op_add: append operation A with bytes B, C, D, E. Clobbers AF, HL.
rt_op_add:
        push af
        ld a,(rt_ops_n)
        cp RT_OPS_MAX
        call nc,rt_ops_compact
        ld a,(rt_ops_n)
        cp RT_OPS_MAX
        jr nc,rt_oa_full
        ld l,a
        inc a
        ld (rt_ops_n),a
        ld h,0
        push de
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        ld de,rt_ops
        add hl,de
        pop de
        pop af
        ld (hl),a
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),d
        inc hl
        ld (hl),e
        ret
rt_oa_full:
        pop af
        ret

; rt_ops_compact: remove deleted operations. Clobbers AF, HL.
rt_ops_compact:
        push bc
        push de
        ld a,(rt_ops_n)
        or a
        jr z,rt_ocp_done
        ld b,a
        ld c,0                  ; operations kept
        ld hl,rt_ops
        ld de,rt_ops
rt_ocp_next:
        ld a,(hl)
        or a
        jr z,rt_ocp_skip
        push bc
        ld bc,5
        ldir
        pop bc
        inc c
        jr rt_ocp_cont
rt_ocp_skip:
        inc hl
        inc hl
        inc hl
        inc hl
        inc hl
rt_ocp_cont:
        djnz rt_ocp_next
        ld a,c
        ld (rt_ops_n),a
rt_ocp_done:
        pop de
        pop bc
        ret

; rt_ops_drop_above: delete the operations that start above line A (the rows
; just redrawn). Preserves A. Clobbers HL.
rt_ops_drop_above:
        push af
        push bc
        ld c,a
        ld a,(rt_ops_n)
        or a
        jr z,rt_oda_done
        ld b,a
        ld hl,rt_ops
rt_oda_next:
        ld a,(hl)
        or a
        jr z,rt_oda_skip
        push hl
        inc hl
        inc hl
        cp 2
        jr nz,rt_oda_line
        inc hl                  ; glyph: the line is the third byte
rt_oda_line:
        ld a,(hl)
        pop hl
        cp c
        jr nc,rt_oda_skip
        ld (hl),0
rt_oda_skip:
        inc hl
        inc hl
        inc hl
        inc hl
        inc hl
        djnz rt_oda_next
        call rt_ops_compact
rt_oda_done:
        pop bc
        pop af
        ret

; rt_ops_drop_inside: delete the operations inside the box B = column,
; C = top, D = width, E = height (a new box covers them). Clobbers AF, HL.
rt_ops_drop_inside:
        ld a,(rt_ops_n)
        or a
        ret z
        push bc
        push de
        push ix
        ld ixh,a
        ld a,b
        add a,d
        ld d,a                  ; D = right column (exclusive)
        ld a,c
        add a,e
        ld e,a                  ; E = bottom line (exclusive)
        ld hl,rt_ops
rt_odi_next:
        push hl
        ld a,(hl)
        or a
        jr z,rt_odi_skip
        cp 2
        jr nz,rt_odi_pos
        inc hl                  ; glyph: column and line one byte later
rt_odi_pos:
        inc hl
        ld a,(hl)               ; column
        cp b
        jr c,rt_odi_skip
        cp d
        jr nc,rt_odi_skip
        inc hl
        ld a,(hl)               ; line
        cp c
        jr c,rt_odi_skip
        cp e
        jr nc,rt_odi_skip
        pop hl
        ld (hl),0
        push hl
rt_odi_skip:
        pop hl
        inc hl
        inc hl
        inc hl
        inc hl
        inc hl
        dec ixh
        jr nz,rt_odi_next
        pop ix
        pop de
        pop bc
        ret

; ---- present ----------------------------------------------------------------------------------
; rt_present: BlitBackBuffer (entered with a jump). Waits for a frame like
; the original HALT, then composes the dirty rectangle.
rt_present:
        call rt_iff
        jp po,rt_pr_nohalt
        halt
rt_pr_nohalt:
        jp rt_compose

; rt_present_main: the main loop's blit. A pass lasts rt_pass frames, and
; the next interrupt is not given to the game (the Spectrum loses it).
rt_present_main:
        ld a,(rt_frames)
        ld hl,rt_last
        sub (hl)
        ld hl,rt_pass
        cp (hl)
        jr nc,rt_pm_go
        halt
        jr rt_present_main
rt_pm_go:
        ld a,(rt_frames)
        ld (rt_last),a
        ld a,1
        ld (rt_skip),a
        jp rt_compose

; rt_compose: build the dirty rectangle in the scratch area (clean room,
; kiss, sprites, windows) and copy it to the display. Clobbers all.
rt_compose:
        push ix
        push iy
        call rt_kiss_mark
        ld a,(rt_dc0)           ; clip to the window columns 1-30
        or a
        jr nz,rt_co_c0
        inc a
rt_co_c0:
        ld (rt_dc0),a
        ld a,(rt_dc1)
        cp 32
        jr c,rt_co_c1
        ld a,31
rt_co_c1:
        ld (rt_dc1),a
        ld hl,rt_dc0
        cp (hl)
        jp c,rt_co_none
        jp z,rt_co_none
        ld a,(rt_dl0)
        ld b,a
        ld a,(rt_dl1)
        cp 105
        jr c,rt_co_l1
        ld a,104
rt_co_l1:
        ld (rt_dl1),a
        cp b
        jp c,rt_co_none
        jp z,rt_co_none
        ; 1. clean room -> scratch
        ld a,(rt_dc0)
        add a,a
        add a,a
        add a,a
        ld (rt_cmd+0),a
        ld (rt_cmd+4),a
        xor a
        ld (rt_cmd+1),a
        ld (rt_cmd+5),a
        ld (rt_cmd+9),a
        ld (rt_cmd+11),a
        ld (rt_cmd+13),a
        ld a,(rt_dl0)
        ld l,a
        ld h,0
        ld de,BG_Y
        add hl,de
        ld (rt_cmd+2),hl
        ld de,SCR_Y-BG_Y
        add hl,de
        ld (rt_cmd+6),hl
        ld a,(rt_dc0)
        ld b,a
        ld a,(rt_dc1)
        sub b
        add a,a
        add a,a
        add a,a
        ld (rt_cmd+8),a
        ld a,(rt_dl0)
        ld b,a
        ld a,(rt_dl1)
        sub b
        ld (rt_cmd+10),a
        ld a,CMD_HMMM
        call rt_cmd_go
        ; 2. kiss
        call rt_kiss_draw
        ; 3. sprites, in drawing order
        ld a,(rt_spr_n)
        or a
        jr z,rt_co_ops
        ld b,a
        ld ix,rt_spr
rt_co_spr:
        push bc
        call rt_sprite_draw
        inc ix
        inc ix
        inc ix
        pop bc
        djnz rt_co_spr
rt_co_ops:
        ; 4. windows
        call rt_ops_draw
        ; 5. scratch -> display
        ld a,(rt_dc0)
        add a,a
        add a,a
        add a,a
        ld (rt_cmd+0),a
        ld (rt_cmd+4),a
        xor a
        ld (rt_cmd+1),a
        ld (rt_cmd+5),a
        ld (rt_cmd+9),a
        ld (rt_cmd+11),a
        ld (rt_cmd+13),a
        ld a,(rt_dl0)
        ld l,a
        ld h,0
        ld de,SCR_Y
        add hl,de
        ld (rt_cmd+2),hl
        ld de,PLAY_Y-SCR_Y
        add hl,de
        ld (rt_cmd+6),hl
        ld a,(rt_dc0)
        ld b,a
        ld a,(rt_dc1)
        sub b
        add a,a
        add a,a
        add a,a
        ld (rt_cmd+8),a
        ld a,(rt_dl0)
        ld b,a
        ld a,(rt_dl1)
        sub b
        ld (rt_cmd+10),a
        ld a,CMD_HMMM
        call rt_cmd_go
rt_co_none:
        call rt_dirty_clear
        pop iy
        pop ix
        ret

; rt_sprite_draw: draw sprite entry IX (frame, column, facing) into the
; scratch area: top half at line 44, bottom half at line 76.
rt_sprite_draw:
        ld a,(ix+0)
        add a,a
        add a,(ix+2)            ; entry = frame * 2 + facing
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        add hl,hl               ; * 6
        ld de,rt_frame_src
        add hl,de
        push hl
        pop iy                  ; IY -> top x, top y (word), bottom x, bottom y (word)
        ld a,(ix+1)
        sub 2
        ld l,a
        sbc a,a
        ld h,a                  ; HL = column - 2, signed
        add hl,hl
        add hl,hl
        add hl,hl
        ld (rt_px),hl
        ld a,(iy+0)
        ld e,(iy+1)
        ld d,(iy+2)
        ld bc,SCR_Y+44
        ld l,32
        call rt_part_draw
        ld a,(iy+3)
        ld e,(iy+4)
        ld d,(iy+5)
        ld bc,SCR_Y+76
        ld l,24
        ; fall through

; rt_part_draw: transparent copy of a 32-pixel wide part. A = source x,
; DE = source y, BC = destination y, L = height, (rt_px) = destination x
; (signed, clipped to 0-255).
rt_part_draw:
        ld (rt_cmd+2),de
        ld (rt_cmd+6),bc
        ld h,a                  ; H = source x
        ld a,l
        ld (rt_cmd+10),a
        xor a
        ld (rt_cmd+1),a
        ld (rt_cmd+5),a
        ld (rt_cmd+9),a
        ld (rt_cmd+11),a
        ld (rt_cmd+13),a
        ld de,(rt_px)
        ld c,32                 ; width
        bit 7,d
        jr z,rt_pd_right
        ld a,e                  ; x < 0: cut the left part
        add a,32
        ret m
        ret z
        ld c,a
        ld a,h
        sub e
        ld h,a
        ld e,0
        jr rt_pd_go
rt_pd_right:
        ld a,d
        or a
        ret nz                  ; x >= 256
        ld a,e
        cp 225
        jr c,rt_pd_go
        neg                     ; 256 - x
        ld c,a
rt_pd_go:
        ld a,h
        ld (rt_cmd+0),a
        ld a,e
        ld (rt_cmd+4),a
        ld a,c
        ld (rt_cmd+8),a
        ld a,CMD_LMMM_TIMP
        jp rt_cmd_go

; rt_kiss_mark: mark the kiss drawn at the last present and the one to draw now.
rt_kiss_mark:
        ld a,(rt_kiss_col)
        cp 0xFF
        jr z,rt_km_new
        ld de,56*256+64
        call rt_mark_kiss
rt_km_new:
        ld a,(ZX_KissState)
        cp 1
        ld a,0xFF
        jr nz,rt_km_store
        ld a,(ZX_KissColumn)
        push af
        ld de,56*256+64
        call rt_mark_kiss
        pop af
rt_km_store:
        ld (rt_kiss_col),a
        ret

; rt_mark_kiss: mark the 8x8 kiss at game column A (byte column A - 2).
rt_mark_kiss:
        sub 2
        ret c
        cp 32
        ret nc
        ld b,a
        inc a
        ld c,a
        jp rt_mark

; rt_kiss_draw: transparent copy of the kiss frame to the scratch area.
rt_kiss_draw:
        ld a,(rt_kiss_col)
        cp 0xFF
        ret z
        sub 2
        ret c
        cp 32
        ret nc
        add a,a
        add a,a
        add a,a
        ld h,a                  ; destination x
        ld a,(ZX_KissFrame)
        and 3
        add a,a
        add a,a
        add a,a
        add a,KISS_X
        ld (rt_cmd+0),a
        ld a,h
        ld (rt_cmd+4),a
        xor a
        ld (rt_cmd+1),a
        ld (rt_cmd+5),a
        ld (rt_cmd+9),a
        ld (rt_cmd+11),a
        ld (rt_cmd+13),a
        ld hl,PIC_Y
        ld (rt_cmd+2),hl
        ld hl,SCR_Y+56
        ld (rt_cmd+6),hl
        ld a,8
        ld (rt_cmd+8),a
        ld (rt_cmd+10),a
        ld a,CMD_LMMM_TIMP
        jp rt_cmd_go

; rt_ops_draw: replay the window operations into the scratch area.
rt_ops_draw:
        ld a,(rt_ops_n)
        or a
        ret z
        ld b,a
        ld ix,rt_ops
rt_od_next:
        push bc
        ld a,(ix+0)
        cp 1
        call z,rt_od_box
        ld a,(ix+0)
        cp 2
        call z,rt_od_glyph
        ld a,(ix+0)
        cp 3
        call z,rt_od_invert
        ld bc,5
        add ix,bc
        pop bc
        djnz rt_od_next
        ret

rt_od_box:
        ld l,(ix+4)             ; paper fill
        ld a,(ix+3)
        add a,a
        add a,a
        add a,a
        ld c,a
        call rt_od_xy
        ld h,COL_PAPER*17
        ld a,CMD_HMMV
        call rt_rect
        ld l,1                  ; top line
        call rt_od_xy
        ld a,(ix+3)
        add a,a
        add a,a
        add a,a
        ld c,a
        ld h,COL_INK
        ld a,CMD_LMMV
        call rt_rect
        call rt_od_xy           ; bottom line
        ld a,(ix+4)
        dec a
        add a,e
        ld e,a
        jr nc,rt_odb1
        inc d
rt_odb1:
        ld a,(ix+3)
        add a,a
        add a,a
        add a,a
        ld c,a
        ld l,1
        ld h,COL_INK
        ld a,CMD_LMMV
        call rt_rect
        call rt_od_xy           ; left edge
        ld c,1
        ld l,(ix+4)
        ld h,COL_INK
        ld a,CMD_LMMV
        call rt_rect
        call rt_od_xy           ; right edge
        ld a,(ix+3)
        add a,a
        add a,a
        add a,a
        dec a
        add a,b
        ld b,a
        ld c,1
        ld l,(ix+4)
        ld h,COL_INK
        ld a,CMD_LMMV
        jp rt_rect

; rt_od_xy: B = 8 * column (ix+1), DE = SCR_Y + line (ix+2) of a box or highlight.
rt_od_xy:
        ld a,(ix+1)
        add a,a
        add a,a
        add a,a
        ld b,a
        push hl
        ld l,(ix+2)
        ld h,0
        ld de,SCR_Y
        add hl,de
        ex de,hl
        pop hl
        ret

rt_od_glyph:
        ld a,(ix+1)             ; tile
        ld c,a
        and 0x1F
        add a,a
        add a,a
        add a,a
        ld l,a                  ; source x
        ld a,c
        rlca
        rlca
        rlca
        and 7
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,TILE_Y
        add hl,de
        ex de,hl                ; DE = source y
        pop hl
        ld a,(ix+2)
        add a,a
        add a,a
        add a,a
        ld h,a                  ; destination x
        push hl
        ld l,(ix+3)
        ld h,0
        ld bc,SCR_Y
        add hl,bc
        ld b,h
        ld c,l                  ; BC = destination y
        pop hl
        jp rt_copy8

rt_od_invert:
        call rt_od_xy
        ld a,(ix+3)
        add a,a
        add a,a
        add a,a
        ld c,a
        ld l,8
        ld h,14 ; ink and paper swap
        ld a,CMD_LMMV_XOR
        jp rt_rect

; ---- HUD ----------------------------------------------------------------------------------------
; rt_hud_char: draw HUD font character A at character cell column E, row D
; of the Spectrum screen. Clobbers AF, BC, DE, HL.
rt_hud_char:
        sub 0x20
        ld c,a
        and 0x1F
        add a,a
        add a,a
        add a,a
        ld l,a                  ; source x
        ld a,c
        rlca
        rlca
        rlca
        and 3
        add a,a
        add a,a
        add a,a
        push de
        ld e,a
        ld d,0
        push hl
        ld hl,FONT_Y
        add hl,de
        ex (sp),hl
        pop bc                  ; BC = source y
        pop de
        ld a,e
        add a,a
        add a,a
        add a,a
        ld h,a                  ; destination x
        push hl
        ld a,d
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,PLAY_Y
        add hl,de
        ex de,hl                ; DE = destination y
        pop hl
        push de
        ld d,b
        ld e,c                  ; DE = source y
        pop bc                  ; BC = destination y
        jp rt_copy8

; rt_hud_digit: DrawDigit (entered with a jump). A = digit, BC = Spectrum
; screen address of the cell. Preserves BC, HL.
rt_hud_digit:
        push bc
        push hl
        add a,0x30
        push af
        ld a,c
        and 0x1F
        ld e,a                  ; column
        ld a,c
        rlca
        rlca
        rlca
        and 7
        ld d,a
        ld a,b
        and 0x18
        add a,d
        ld d,a                  ; row
        pop af
        call rt_hud_char
        pop hl
        pop bc
        ret

; rt_day_name: PrintDayName (replaces "ld c,09h / ld de,ScrCharRow14",
; entered with a jump). IX -> 9 characters, printed at row 14, columns 1-9;
; then the original goes on with the day counter.
rt_day_name:
        ld b,9
        ld e,1
rt_dn_next:
        push bc
        push de
        ld a,(ix+0)
        inc ix
        ld d,14
        call rt_hud_char
        pop de
        inc e
        pop bc
        djnz rt_dn_next
        ld hl,rt_show           ; first day name of the game (NewGame, after the
        ld a,(hl)               ; first room is drawn): the screen is complete and
        or a                    ; the next vertical blank turns the display on
        jr nz,rt_dn_done
        inc (hl)
rt_dn_done:
        jp ZX_PrintDayName+0x3F ; (the tail loads A and HL itself)

; rt_alco_drain, rt_alco_fill: AlcometerDrain / AlcometerFill hooks
; (replace their first instruction "ld hl,(AlcometerPtr)", called). The
; routine then returns through rt_alco, which redraws the bar.
rt_alco_drain:
        pop hl
        ld hl,rt_alco
        push hl
        ld hl,(ZX_AlcometerPtr)
        jp ZX_AlcometerDrain+3
rt_alco_fill:
        pop hl
        ld hl,rt_alco
        push hl
        ld hl,(ZX_AlcometerPtr)
        jp ZX_AlcometerFill+3

; rt_alco: the bar shows 8 * (AlcometerPtr - 5328h) + AlcometerBits pixels
; of the 128. Preserves all registers.
rt_alco:
        push af
        push bc
        push de
        push hl
        ld hl,(ZX_AlcometerPtr)
        ld de,0x5328
        or a
        sbc hl,de
        jr nc,rt_al1
        ld hl,0
rt_al1:
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(ZX_AlcometerBits)
        ld e,a
        ld d,0
        add hl,de
        ld de,128
        or a
        sbc hl,de
        add hl,de
        jr c,rt_al2
        ld hl,128
rt_al2:
        ld a,l
        ld (rt_tmp),a
        or a
        jr z,rt_al_empty
        ld c,a
        ld b,ALCO_X
        ld de,ALCO_Y
        ld l,3
        ld h,COL_BEER
        ld a,CMD_LMMV
        call rt_rect
rt_al_empty:
        ld a,(rt_tmp)
        cp 128
        jr nc,rt_al_done
        ld b,a
        neg
        add a,128
        ld c,a
        ld a,b
        add a,ALCO_X
        ld b,a
        ld de,ALCO_Y
        ld l,3
        ld h,COL_PANEL
        ld a,CMD_LMMV
        call rt_rect
rt_al_done:
        pop hl
        pop de
        pop bc
        pop af
        ret

; rt_wait_vbl: a HALT that returns only at the next vertical blank. A plain HALT
; also ends at the HUD line interrupt, so on the MSX two HALTs last one frame (the
; Spectrum's last two): code paced by HALTs ran about twice as fast, and 20 % faster
; again at 60 Hz. Interrupts on. Preserves AF and HL.
rt_wait_vbl:
        push af
        push hl
        ld a,(rt_frames)
rt_wv_wait:
        halt
        ld hl,rt_frames
        cp (hl)
        jr z,rt_wv_wait
        pop hl
        pop af
        ret

; rt_icon_wait: the icon bar loop's "ld a,1 / ld (WindowMode),a / halt / halt".
; Clobbers A.
rt_icon_wait:
        ld a,1
        ld (ZX_WindowMode),a
        call rt_wait_vbl
        jp rt_wait_vbl

; rt_paint_icon: PaintIcon hook (replaces "halt / ld b,04h"). A = attribute,
; HL = attribute address of the icon: the icon's HUD palette entry (9-12)
; takes the ink; the line interrupt loads it.
rt_paint_icon:
        call rt_wait_vbl
        push af
        push de
        push hl
        push af
        ld de,0x5A86
        or a
        sbc hl,de
        ld a,l
        ld b,COL_ICON0-1
rt_pi_div:
        inc b
        sub 5
        jr nc,rt_pi_div
        pop af
        push bc
        and 0x47
        call rt_zx_rgb
        pop bc
        ld l,b
        ld h,0
        add hl,hl
        push de
        ld de,rt_pal_hud
        add hl,de
        pop de
        ld (hl),d
        inc hl
        ld (hl),e
        pop hl
        pop de
        pop af
        ld b,4
        ret

; ---- data ---------------------------------------------------------------------------------------
; rt_msg_title: the new game window (MsgTitlePressFire, BB46h, has no room for
; more lines). TEXT format: 3Eh = space, bit 7 = last character of a line.
; The digits are tiles D3h-DCh of assets/tiles.png (room graphics on the Spectrum).
rt_msg_title:
        db 3Eh,3Eh,3Eh,3Eh,41h,4Eh,44h,59h,3Eh,43h,41h,50h,0D0h                 ; "    ANDY CAPP"
        db 50h,52h,45h,53h,53h,3Eh,46h,49h,52h,45h,3Eh,54h,4Fh,3Eh,53h,54h,41h,52h,0D4h ; "PRESS FIRE TO START"
        db 0BEh                                                                 ; ""
        db 4Dh,53h,58h,32h,3Eh,42h,59h,3Eh,44h,49h,48h,41h,4Ch,54h,3Eh,32h,30h,32h,0B6h ; "MSX2 BY DIHALT 2026"
        db 00h

rt_cmd_clear_all:              ; HMMV the four pages: display white, the rest paper
        dw 0, 0, 0, 0, 256, 212
        db 15*17, 0, CMD_HMMV

        include "../build/tables.inc"

rt_cmd:         ds 15
rt_tmp:         ds 2
rt_px:          ds 2
rt_dest_y:      ds 2
rt_rows:        ds 1
rt_dc0:         ds 1
rt_dc1:         ds 1
rt_dl0:         ds 1
rt_dl1:         ds 1
rt_kiss_col:    ds 1
rt_play_attr:   ds 1
rt_spr_n:       ds 1
rt_spr_old_n:   ds 1
rt_spr:         ds 8*3
rt_pal_hud:     ds 32
rt_ops_n:       ds 1
rt_ops:         ds RT_OPS_MAX*5
rt_end:
        assert rt_end < RT_STACK-0x200
