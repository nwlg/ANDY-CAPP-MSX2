#!/usr/bin/env python3
"""Builds dist/: everything for a MegaFlashROM SCC+ SD card, ready to copy.

    make_dist.py

dist/ holds the ROM, the cartridge's loader OPFXSD.COM, the boot files of
Nextor / MSX-DOS 2 and MSX-DOS 1 and AUTOEXEC.BAT, which writes the ROM to
the cartridge's flash with the ASCII16 mapper and starts it. ANDYCAPP.BAT
does the same when the folder is not the root of the card.

The system files are third-party binaries and are not kept in the
repository: put them in third_party/ (not tracked) or point to them with the
environment:

  DOS1_DIR    MSXDOS.SYS, COMMAND.COM          (MSX-DOS 1, 64 KB machines)   default third_party/dos1
  DOS2_DIR    MSXDOS2.SYS, COMMAND2.COM        (MSX-DOS 2)                   default third_party/dos2
  NEXTOR_DIR  NEXTOR.SYS                       (Nextor, the cartridge's kernel) default third_party/nextor
  OPFXSD      OPFXSD.COM                       (Manuel Pazos's loader)       default third_party/opfxsd.com
"""
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, 'dist')
TP = os.path.join(ROOT, 'third_party')

SOURCES = [
    ('ANDYCAPP.ROM', os.path.join(ROOT, 'build', 'andycapp.rom')),
    ('OPFXSD.COM', os.environ.get('OPFXSD', os.path.join(TP, 'opfxsd.com'))),
    ('NEXTOR.SYS', os.path.join(os.environ.get('NEXTOR_DIR', os.path.join(TP, 'nextor')), 'NEXTOR.SYS')),
    ('MSXDOS2.SYS', os.path.join(os.environ.get('DOS2_DIR', os.path.join(TP, 'dos2')), 'MSXDOS2.SYS')),
    ('COMMAND2.COM', os.path.join(os.environ.get('DOS2_DIR', os.path.join(TP, 'dos2')), 'COMMAND2.COM')),
    ('MSXDOS.SYS', os.path.join(os.environ.get('DOS1_DIR', os.path.join(TP, 'dos1')), 'msxdos.sys')),
    ('COMMAND.COM', os.path.join(os.environ.get('DOS1_DIR', os.path.join(TP, 'dos1')), 'command.com')),
]

# /A16: ASCII16 mapper (the automatic detection is not reliable for this ROM)
# /X: start the game once it is in the flash
START = [
    'MODE 80',
    'ECHO ',
    'ECHO',
    'ECHO                      ANDY CAPP for MSX2',
    'ECHO                              by DiHalt Studio 2026',
    'ECHO ',
    'OPFXSD ANDYCAPP.ROM /A16 /X',
]

README = """ANDY CAPP for MSX2 - DiHalt Studio 2026
MegaFlashROM SCC+ SD

Copy the contents of this folder to the root of the SD card.
The computer starts MSX-DOS, AUTOEXEC.BAT writes the game to the
cartridge (it takes a few seconds) and the game starts.

In a folder of its own instead of the root: go to the folder and
type ANDYCAPP (or choose ANDYCAPP.BAT in your file manager).

From then on the cartridge starts Andy Capp every time the computer
is switched on. Hold ESC while switching on to boot the SD card
instead. OPFXSD /C erases the game from the cartridge.

Needs an MSX2 (or better) with 64 KB of RAM. With 128 KB or more the
cartridge boots Nextor (NEXTOR.SYS, COMMAND2.COM); with 64 KB it boots
MSX-DOS 1 (MSXDOS.SYS, COMMAND.COM), which reads only FAT12 partitions
of up to 16 MB.

OPFXSD.COM: MegaFlashROM SCC+ SD loader by Manuel Pazos and Ramones.
NEXTOR.SYS: Konamiman. MSX-DOS: ASCII Corporation / Microsoft.
"""


def dos_text(lines):
    return ('\r\n'.join(lines) + '\r\n').encode('ascii')


def main():
    missing = [src for _name, src in SOURCES if not os.path.isfile(src)]
    if missing:
        sys.exit('missing: ' + ', '.join(missing) + '\n(make builds the ROM; set DOS1_DIR, DOS2_DIR, NEXTOR_DIR, OPFXSD)')
    if os.path.isdir(DIST):
        shutil.rmtree(DIST)
    os.makedirs(DIST)
    for name, src in SOURCES:
        shutil.copyfile(src, os.path.join(DIST, name))
    open(os.path.join(DIST, 'AUTOEXEC.BAT'), 'wb').write(dos_text(START))
    open(os.path.join(DIST, 'ANDYCAPP.BAT'), 'wb').write(dos_text(START))
    open(os.path.join(DIST, 'README.TXT'), 'wb').write(dos_text(README.rstrip('\n').split('\n')))
    for name in sorted(os.listdir(DIST)):
        print('%-13s %7d' % (name, os.path.getsize(os.path.join(DIST, name))))


if __name__ == '__main__':
    main()
