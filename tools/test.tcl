# openMSX script for tools/run_test.sh: runs the ROM, presses keys, dumps
# VRAM, palette and a state report, then exits. Environment: AC_OUT (output
# prefix), AC_SECS (emulated seconds), AC_KEYS, AC_SHOTS.
set out $::env(AC_OUT)
set secs 20
if {[info exists ::env(AC_SECS)]} { set secs $::env(AC_SECS) }
set throttle off
set minframeskip 0
set maxframeskip 0
proc ac_dump {name} {
    set mf [open "${name}.mem" w]
    fconfigure $mf -translation binary
    puts -nonewline $mf [debug read_block memory 0 0x4000]
    close $mf
    set vf [open "${name}.vram" w]
    fconfigure $vf -translation binary
    puts -nonewline $vf [debug read_block VRAM 0 0x20000]
    close $vf
    set pf [open "${name}.pal" w]
    fconfigure $pf -translation binary
    puts -nonewline $pf [debug read_block {VDP palette} 0 32]
    close $pf
}
proc ac_report {} {
    global out
    if {[catch ac_report_body err]} { puts stderr "report: $err" }
    ac_dump $out
    exit
}
proc ac_report_body {} {
    global out
    set f [open "${out}.txt" w]
    puts $f "pc=[format %04X [reg pc]] sp=[format %04X [reg sp]] im=[reg im] iff=[reg iff]"
    puts $f "slots=[format %02X [debug read ioports 0xA8]]"
    puts $f "frames=[peek 0x44] skip=[peek 0x45] 60hz=[peek 0x43]"
    puts $f "room=[peek 0xE6F8] andyx=[peek 0xE6E9] hour=[peek 0xC1F3] min=[peek 0xC1F5]"
    set st ""
    for {set i 0} {$i < 16} {incr i} {
        set a [expr {([reg sp] + 2*$i) & 0xFFFF}]
        append st [format "%02X%02X " [peek [expr {($a + 1) & 0xFFFF}]] [peek $a]]
    }
    puts $f "stack: $st"
    set v ""
    for {set i 0} {$i < 14} {incr i} { append v [format "%02X " [debug read {PSG regs} $i]] }
    puts $f "psg regs: $v"
    set v ""
    for {set i 0} {$i < 24} {incr i} { append v [format "%02X " [debug read {VDP regs} $i]] }
    puts $f "vdp regs: $v"
    close $f
}
proc ac_key {row mask hold} {
    keymatrixdown $row $mask
    after time $hold "keymatrixup $row $mask"
}
if {[info exists ::env(AC_KEYS)]} {
    array set names {space {8 1} left {8 16} up {8 32} down {8 64} right {8 128} o {4 16} p {4 32} q {4 64} a {2 64}}
    foreach {t k} $::env(AC_KEYS) {
        set hold 0.3
        if {[regexp {^(.*)/(.*)$} $k -> k hold]} {}
        if {[info exists names($k)]} { set rm $names($k) } else { set rm [split $k :] }
        after time $t "ac_key [lindex $rm 0] [lindex $rm 1] $hold"
    }
}
if {[info exists ::env(AC_SHOTS)]} {
    foreach t $::env(AC_SHOTS) { after time $t "ac_dump ${out}_$t" }
}
after time $secs ac_report
