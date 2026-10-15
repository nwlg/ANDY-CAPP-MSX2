"""Patch manifest: changes applied to the Spectrum game image (5FB4h-FEFFh)
for the MSX2 build.

Each entry: (address, expected original bytes, replacement, reason).
The replacement is a hex string where "{name}" stands for the address of
the runtime label name (little endian), or ('jp' | 'call', runtime label).
A shorter replacement is filled with NOPs up to the length of the expected
bytes. The build fails if the expected bytes are not found.
"""

PATCHES = [
    # ---- machine -----------------------------------------------------------
    (0xE820, 'ed 5e', 'ed 56', 'GameBoot: IM 1 (the runtime entry at 0038h runs InterruptHandler)'),
    (0xACBE, '21 05 ad', ('jp', 'rt_read_controls'), 'ReadControls: MSX keyboard matrix and joystick'),
    (0xEFEB, '06 04', 'c9', 'NpcBalanceDelay: the main loop present paces the pass by frames'),
    (0xF923, '00 00', '00 40', 'KissBufferAddr: the first RemoveKiss erases a kiss never drawn at 0000h '
     '(Spectrum ROM, ignored there; the runtime on the MSX): point it at the unused screen RAM'),

    # ---- sound: AY register writes go to the PSG ---------------------------
    (0xDFB9, '32 a3 e2', ('call', 'rt_mixer'), 'SoundFrame: R7 with bit 7 = 1, bit 6 = 0 for the MSX PSG'),
    (0xDFCB, '01 3f ff ed 51 0e fd ed 51 06 bf 7e 2b ed 79 d3 5f 15 f2 cb df',
     '7a d3 a0 7e 2b d3 a1 15 f2 cb df',
     'SoundFrame: register D := (HL), down to R0, on the PSG ports A0h/A1h (no Fuller Box)'),
    # music during play, as the C64 version: the tune is not stopped after
    # "PRESS FIRE", and the effects take channel A (the accompaniment, the
    # voice the C64 effects take) instead of C (the bass). Each frame the music
    # rewrites the channel's volume, period and noise bit, so it comes back
    # as soon as an effect ends.
    (0xFED1, 'cd 8b e0', '00 00 00', 'NewGame: no MusicStop, the tune goes on during play'),
    (0xDF49, '32 a6 e2', '32 a4 e2', 'SoundFrameSfx: effect over -> AyVolA (was AyVolC)'),
    (0xDF8D, '32 a6 e2', '32 a4 e2', 'SoundFrameSfx: effect volume (hardware envelope) -> AyVolA'),
    (0xDF90, '22 a0 e2', '22 9c e2', 'SoundFrameSfx: effect period -> AyToneA'),
    (0xDF99, '21 56 e2', '21 54 e2', 'SoundFrameSfx: effect noise bit in the mixer byte of channel A (ChanWork+0)'),

    # ---- scene: back buffer copy and drawing primitives ---------------------
    (0xAD56, 'dd 21 87 ad', ('jp', 'rt_present'), 'BlitBackBuffer: native present'),
    (0xF0CC, 'cd 56 ad', ('call', 'rt_present_main'), 'MainLoop: present paced to 5 frames, one interrupt skipped'),
    (0xF362, '21 c0 c1', ('call', 'rt_sprite'), 'DrawSprite: record frame, column, facing'),
    (0xF4BA, '21 94 69', ('call', 'rt_sprites_reset'), 'RestoreSpriteBackgrounds: the sprite list starts again'),
    (0xF5C5, 'f3', '00', 'BuildRoom: no DI. Even the 12 ms left delayed the vertical blank palette switch '
     '(top of the play area in HUD colours for a frame); the game interrupt does not touch what it builds'),
    (0xF5F4, '11 3e 6c', 'c3 4c f6', 'DrawRoomTiles: skip the 390 tiles into the back buffer (never shown): '
     'BuildRoom ran them with interrupts off for about 220 ms, which stopped the palette split'),
    (0xF64C, 'fb cd 8f c3', ('call', 'rt_room_rows'), 'DrawRoomTiles: painted background of a new room, then DrawCounterPicture'),
    (0xF68E, '21 01 58', ('call', 'rt_play_colour'), 'SetWindowColour: play-area palette entries'),
    (0xE950, '11 20 00', ('call', 'rt_win_box'), 'DrawWindowBox: record the box'),
    (0xEA22, 'e1 23 c9', ('jp', 'rt_win_char'), 'PrintWindowChar: record the glyph'),
    (0xEA2D, '2a 72 c2', ('call', 'rt_win_invert'), 'InvertMenuLine: toggle the highlight'),
    (0xEAB7, '0b', '00', 'WindowMessageWait: no 50-frame time-out, a message stays until FIRE (time to read it)'),
    (0xFEBF, 'dd 21 46 bb', 'dd 21 {rt_msg_title}', 'NewGame: the "PRESS FIRE TO START" window with the MSX2 credit line'),
    (0xBCF7, '41 3e 53 50 45 43 54 52 55 cd 41 4e 3e 49 42 cd 41 4e 3e 41 42 55 43 55 d3 00',
     '41 4e 3e 4d 53 d8 41 4e 3e 49 42 cd 41 4e 3e 41 42 41 43 55 d3 00',
     'MenuComputers (job interview): "AN MSX" instead of "A SPECTRUM", "AN ABACUS" (was "ABUCUS"); the three entries move up, the menu is chosen by number'),

    # ---- HUD --------------------------------------------------------------
    (0xC2B9, 'e5 6f 26', ('jp', 'rt_hud_digit'), 'DrawDigit: HUD font digit'),
    (0xF9EB, '0e 09 11 c0 48', ('jp', 'rt_day_name'), 'PrintDayName: HUD font letters'),
    (0xFA17, '3a 81 c2', '3a 81 c2', 'PrintDayName tail (rt_day_name jumps back here): checked only'),
    (0xFDF8, '2a 59 fe', ('call', 'rt_alco_drain'), 'AlcometerDrain: returns through rt_alco'),
    (0xFE21, '2a 59 fe', ('call', 'rt_alco_fill'), 'AlcometerFill: returns through rt_alco'),
    (0xF73C, '76 06 04', ('call', 'rt_paint_icon'), 'PaintIcon: icon ink in its palette entry'),
    (0xF757, '3e 01 32 60 c2 76 76', ('call', 'rt_icon_wait'), 'IconBar: pass of 2 vertical blanks + the one of PaintIcon, '
     'as the Spectrum (a plain HALT also ends at the HUD line interrupt: twice as fast, 20 % more at 60 Hz)'),
]
