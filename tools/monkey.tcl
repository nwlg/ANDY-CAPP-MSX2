# openMSX script: random play (seed AC_SEED) for AC_SECS seconds after the
# title (first walking left out of the house); logs game writes into page 0 (the runtime) and any stop of the main
# loop, then dumps VRAM like tools/test.tcl. Output: AC_OUT.monkey; with
# AC_EVERY=seconds also AC_OUT_NNN.vram/.pal (page 0) every so often.
set throttle off
set ::hits [dict create]
expr {srand($::env(AC_SEED))}
set secs $::env(AC_SECS)
proc mk_key {} {
    set keys {{8 128} {8 16} {8 32} {8 64} {8 1} {8 128} {8 16}}
    set k [lindex $keys [expr {int(rand()*[llength $keys])}]]
    set hold [expr {0.1 + rand()*1.5}]
    keymatrixdown [lindex $k 0] [lindex $k 1]
    after time $hold "keymatrixup [lindex $k 0] [lindex $k 1]"
    after time [expr {$hold + 0.05 + rand()*0.6}] mk_key
}
after time 17 {keymatrixdown 8 1; after time 0.3 {keymatrixup 8 1}}
after time 19 {
    debug set_watchpoint write_mem {0x0000 0x3FFF} {[reg pc] >= 0x4000} {
        set k [format %04X [reg pc]]
        dict incr ::hits $k
    }
    keymatrixdown 8 16
    after time 6 {keymatrixup 8 16; mk_key}
    if {[info exists ::env(AC_EVERY)]} { mk_shot }
}
set ::shot 0
proc mk_shot {} {
    set vf [open [format "%s_%03d.vram" $::env(AC_OUT) $::shot] w]
    fconfigure $vf -translation binary
    puts -nonewline $vf [debug read_block VRAM 0 0x8000]
    close $vf
    set pf [open [format "%s_%03d.pal" $::env(AC_OUT) $::shot] w]
    fconfigure $pf -translation binary
    puts -nonewline $pf [debug read_block {VDP palette} 0 32]
    close $pf
    incr ::shot
    after time $::env(AC_EVERY) mk_shot
}
proc mk_end {} {
    set f [open $::env(AC_OUT).monkey w]
    puts $f "room=[peek 0xE6F8] hour=[peek 0xC1F3] min=[peek 0xC1F5] day=[peek 0xC281] money=[peek16 0xC257] alco=[format %04X [peek16 0xFE59]] kisses=[peek 0xC203]"
    dict for {k v} $::hits { puts $f "write from pc=$k x$v" }
    close $f
    set vf [open "$::env(AC_OUT).vram" w]
    fconfigure $vf -translation binary
    puts -nonewline $vf [debug read_block VRAM 0 0x20000]
    close $vf
    set pf [open "$::env(AC_OUT).pal" w]
    fconfigure $pf -translation binary
    puts -nonewline $pf [debug read_block {VDP palette} 0 32]
    close $pf
    exit
}
after time [expr {19 + $secs}] mk_end
