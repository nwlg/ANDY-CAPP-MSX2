; Andy Capp MSX2 - ROM segment 0: cartridge header and boot.
; Assemble with sjasm 0.42c. See doc/DESIGN.md.
;
; The BIOS calls rom_init with page 1 = this cartridge. The boot sets
; SCREEN 5 with the BIOS, copies the MSX font of the machine into VRAM as the
; HUD font (the Spectrum printed its digits and day names with its ROM
; font), finds the RAM slot, selects RAM in pages 0, 2 and 3 (page 1 stays on
; the cartridge), copies the runtime to 0000h and jumps to it. The BIOS is
; never used again.

        include "layout.inc"

CHGMOD          equ 0x005F
CGTABL          equ 0x0004      ; address of the BIOS font
RG8SAV          equ 0xFFE7
RG9SAV          equ 0xFFE8
FORCLR          equ 0xF3E9      ; then BAKCLR, BDRCLR

        org 0x4000
        db "AB"
        dw rom_init
        dw 0, 0, 0
        ds 6,0

rom_init:
        ld hl,0x0101            ; black screen while the boot runs
        ld (FORCLR),hl          ; FORCLR, BAKCLR
        ld a,1
        ld (FORCLR+2),a         ; BDRCLR
        ld a,5
        call CHGMOD             ; SCREEN 5
        di
        ld a,(RG8SAV)
        or 0x22                 ; TP: colour 0 from the palette; SPD: no sprites
        out (VDP_CTRL),a
        ld a,0x88
        out (VDP_CTRL),a
        ld a,(RG9SAV)
        or 0x80                 ; 212 lines
        ld (0xC000),a           ; kept for the runtime (page 3 RAM, read back below)
        out (VDP_CTRL),a
        ld a,0x89
        out (VDP_CTRL),a
        xor a                   ; R#15 = 0
        out (VDP_CTRL),a
        ld a,0x8F
        out (VDP_CTRL),a

; ---- HUD font: ASCII 20h-7Fh of the BIOS font, ink 1 on paper 2, to VRAM
; (0, FONT_Y), 32 characters per row of 8 lines: 3 x 8 lines x 128 bytes.
; (VRAM 0EA00h-0F5FFh: the logo and the opening that the runtime shows
; first do not use it; in SCREEN 7 the VRAM is interleaved, and the odd field
; of the opening fills 08000h-0E9FFh.)
        ld a,(FONT_Y*128)/16384 ; R#14 = VRAM address bits 16-14
        out (VDP_CTRL),a
        ld a,0x8E
        out (VDP_CTRL),a
        ld a,(FONT_Y*128)&255
        out (VDP_CTRL),a
        ld a,(((FONT_Y*128)/256)&0x3F)|0x40
        out (VDP_CTRL),a
        ld c,0x20               ; first character of the row
font_row:
        ld b,0                  ; pixel line 0-7
font_line:
        push bc
        ld e,32                 ; characters in the row
font_char:
        push bc
        push de
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; character * 8
        ld e,b
        ld d,0
        add hl,de
        ld de,(CGTABL)
        add hl,de
        ld d,(hl)               ; D = glyph line
        ld b,4
font_pair:
        ld a,0x22               ; two pixels of paper
        rl d
        jr nc,font_p1
        ld a,0x12
font_p1:
        rl d
        jr nc,font_p2
        and 0xF0
        or 0x01
font_p2:
        out (VDP_DATA),a
        djnz font_pair
        pop de
        pop bc
        inc c
        dec e
        jr nz,font_char
        pop bc                  ; C = first character of the row again
        inc b
        ld a,b
        cp 8
        jr nz,font_line
        ld a,c
        add a,32
        ld c,a
        cp 0x80
        jr nz,font_row

; ---- find the RAM slot: write test in page 2 over the primary slots
        in a,(PPI_SLOT)
        ld e,a                  ; E = slot register as the BIOS left it
        ld b,0
find_ram:
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,e
        and 0xCF
        or c
        out (PPI_SLOT),a        ; page 2 = candidate slot
        ld a,(0x8000)
        cpl
        ld l,a
        ld (0x8000),a
        ld a,(0x8000)
        cp l
        jr z,ram_found
        inc b
        ld a,b
        cp 4
        jr nz,find_ram
; no primary slot answers: the RAM is in an expanded slot, the one of page 3
        ld a,e
        rlca
        rlca
        and 3
        ld b,a
ram_found:
        ld a,b                  ; A = RAM primary slot
        add a,a
        add a,a
        or b
        ld c,a
        rlca
        rlca
        rlca
        rlca
        or c
        ld c,a                  ; C = RAM slot in all four pages
        ld a,e
        and 0x0C                ; cartridge slot bits of page 1
        ld d,a
        ld a,c
        and 0xF3
        or d
        ld b,a                  ; B = RAM everywhere, page 1 = cartridge
        ld a,d
        add a,a
        add a,a                 ; cartridge slot in the page 2 bits
        ld d,a
        ld a,c
        and 0xCF
        or d
        ld d,a                  ; D = RAM everywhere, page 2 = cartridge
        ld a,b
        out (PPI_SLOT),a
; Expanded RAM slot: FFFFh is its secondary slot register and reads back
; complemented. Give pages 0-2 the sub-slot that page 3 already has.
        ld a,(0xFFFF)
        cpl
        ld h,a
        ld (0xFFFF),a
        ld a,(0xFFFF)
        cpl
        cp h
        jr nz,not_expanded      ; plain RAM at FFFFh: not a secondary slot register
        ld a,h
        rlca
        rlca
        and 3                   ; sub-slot of page 3
        ld l,a
        add a,a
        add a,a
        or l
        ld l,a
        rlca
        rlca
        rlca
        rlca
        or l
        ld (0xFFFF),a           ; same sub-slot in the four pages
not_expanded:
        push bc
        push de
        ld hl,ROM_RUNTIME
        ld de,RT_BASE
        ld bc,runtime_size
        ldir
        pop de
        pop bc
        ld a,b
        ld (rt_slot_rom1),a
        ld a,c
        ld (rt_slot_ram),a
        ld a,d
        ld (rt_slot_rom2),a
        ld a,(0xC000)
        ld (rt_r9),a
        ld a,(RG9SAV)           ; RAM is in page 3 on every path above
        cpl
        and 2                   ; R#9 bit 1: 1 = 50 Hz
        ld (rt_60hz),a
        jp RT_BASE

        assert $ <= ROM_RUNTIME
        ds ROM_RUNTIME-$,0xFF
runtime_image:
        incbin "../build/runtime.bin"
runtime_size    equ $-runtime_image
        assert $ <= 0x8000
