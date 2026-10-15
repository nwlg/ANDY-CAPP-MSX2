# openMSX script: screens for the manual (tools/manual_shots.sh). Dumps VRAM,
# palette and page 0 RAM like tools/test.tcl at fixed moments of a scripted
# game; rooms are reached by placing Andy at an edge (pokes) and walking.
# Times count from the moment the script is sourced (power on or reset).
set throttle off
set out $::env(AC_OUT)
proc dump {name} {
    global out
    foreach {ext what size} {vram VRAM 0x20000 pal {VDP palette} 32 mem memory 0x4000} {
        set f [open "${out}_${name}.${ext}" w]
        fconfigure $f -translation binary
        puts -nonewline $f [debug read_block $what 0 $size]
        close $f
    }
}
proc tap {row mask {hold 0.08}} { keymatrixdown $row $mask; after time $hold "keymatrixup $row $mask" }
proc hold {row mask secs} { keymatrixdown $row $mask; after time $secs "keymatrixup $row $mask" }
proc place {room x} { poke 0xE6F8 $room; poke 0xE6E9 $x }
after time 16 {tap 8 1 0.3}
after time 21 {dump title}
after time 26 {tap 8 1}
after time 29 {dump home}
after time 30 {place 34 30; hold 8 128 1.5}
after time 33 {dump pub}
after time 34 {place 53 30; hold 8 128 1.5}
after time 37 {dump pub2}
after time 38 {place 8 30; hold 8 128 2.5}
after time 42 {hold 8 128 0.6}
after time 43 {dump street}
after time 44 {tap 8 64 0.1}
after time 44.6 {dump kiss}
after time 46 {poke 0xC1F3 23}
after time 47 {hold 8 16 1.2}
after time 49 {dump night}
after time 50 {place 4 30; hold 8 128 2}
after time 54 {dump night2}
after time 55 {poke 0xC1F3 12; place 53 30; hold 8 128 1.5}
after time 58 {tap 8 1 0.3}
after time 60 {tap 8 1 0.3}
after time 61.5 {dump menu}
after time 62 {tap 8 1 0.3}
after time 62.8 {dump message}
after time 64 {if {![info exists ::env(AC_KEEP)]} exit}   ;# AC_KEEP: leave openMSX running (mcp-openmsx)
