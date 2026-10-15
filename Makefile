# Andy Capp for MSX2 (SCREEN 5, 512 KB ASCII16 MegaROM, sjasm 0.42c)
#   make              build the playable ROM: build/andycapp.rom
#   make run          play it in openMSX (Philips NMS 8250, MSX2, 50 Hz): release/andycapp-msx2.rom
#                     if it is there, else the one built from source
#   make run60        the same on a Panasonic FS-A1WSX (MSX2+, 60 Hz)
#   make run-turbor   the same on a Panasonic FS-A1GT (MSX turbo R, 60 Hz)
#   make release      build it and copy it to release/ with the manuals, plus a zip (the files of a release)
#   make dist         dist/: ROM, OPFXSD, Nextor/MSX-DOS boot files and AUTOEXEC.BAT for a
#                     MegaFlashROM SCC+ SD card (copy the folder's contents to the card)
#   make manual       the user manual, Spanish and English (docs/manual/manual-es.pdf, manual-en.pdf)
#   make test         boot it in a private openMSX instance, write build/test/boot.png
#   make preview      pictures of the editable art as the game shows it (build/preview/)
#   make palette      write assets/palette_*.gpl into every PNG of assets/ (after editing a .gpl)
#   make syncpal FROM=rooms/room_21.png
#                     take the palette of one picture into its .gpl and every other PNG of that palette
#   make help         this list
#
# Building needs the Spectrum original in ../ZX (its reassembly and tape bytes; not distributed
# here, see README.md, "Building from source"). Requirements: sjasm 0.42c (classic SjAsm, not
# SjAsmPlus), python3 with Pillow, openMSX; pdflatex for the manual.

OPENMSX       ?= openmsx
MACHINE       ?= Philips_NMS_8250
MACHINE60     ?= Panasonic_FS-A1WSX
MACHINETR     ?= Panasonic_FS-A1GT
OPENMSX_EXTRA ?=
ROM           := build/andycapp.rom
VERSION       ?= 1.0
RELEASE_ROM   := release/andycapp-msx2.rom
RELEASE_ZIP   := release/andycapp-msx2-$(VERSION).zip
MANUAL_LANGS  ?= es en
ZX            := ../ZX

# `make run` plays the release ROM when there is one, so the game can be tried without building it.
PLAY_ROM  = $(firstword $(wildcard $(RELEASE_ROM)) $(ROM))
PLAY_DEPS = $(if $(wildcard $(RELEASE_ROM)),,all)

ifeq ($(wildcard $(ZX)/build/game.bin),)
ifneq ($(filter-out run run60 run-turbor help manual clean,$(or $(MAKECMDGOALS),all)),)
ifeq ($(wildcard $(RELEASE_ROM)),$(RELEASE_ROM))
$(info Note: $(RELEASE_ROM) is ready to play with `make run`.)
endif
$(error Building needs the Spectrum original in $(ZX)/ (not distributed here, see README.md))
endif
endif

.PHONY: all run run60 run-turbor release test preview palette syncpal manual dist clean help

all:
	python3 tools/build_rom.py

help:
	@sed -n '2,/^$$/p' Makefile | sed 's/^# \{0,1\}//'

run: $(PLAY_DEPS)
	$(OPENMSX) -machine $(MACHINE) -carta $(PLAY_ROM) -romtype ASCII16 $(OPENMSX_EXTRA)

run60: $(PLAY_DEPS)
	$(OPENMSX) -machine $(MACHINE60) -carta $(PLAY_ROM) -romtype ASCII16 $(OPENMSX_EXTRA)

run-turbor: $(PLAY_DEPS)
	$(OPENMSX) -machine $(MACHINETR) -carta $(PLAY_ROM) -romtype ASCII16 $(OPENMSX_EXTRA)

# The files of a GitHub release: the ROM, the two manuals and a zip with them.
release: all manual
	mkdir -p release
	cp $(ROM) $(RELEASE_ROM)
	cp docs/manual/manual-en.pdf release/andycapp-msx2-manual-en.pdf
	cp docs/manual/manual-es.pdf release/andycapp-msx2-manual-es.pdf
	rm -f $(RELEASE_ZIP)
	cd release && zip -q $(notdir $(RELEASE_ZIP)) andycapp-msx2.rom andycapp-msx2-manual-en.pdf andycapp-msx2-manual-es.pdf
	@ls -l release

test: all
	tools/run_test.sh boot 20
	python3 tools/vram2png.py boot

preview:
	python3 tools/preview.py

manual:
	python3 tools/manual_images.py docs/manual .
	cd docs/manual && for l in $(MANUAL_LANGS); do \
	  for i in 1 2; do pdflatex -interaction=nonstopmode -jobname=manual-$$l "\def\manlang{$$l}\input{manual}" >/dev/null || exit 1; done; done

palette:
	python3 tools/apply_palette.py

syncpal:
	@test -n "$(FROM)" || { echo 'usage: make syncpal FROM=rooms/room_21.png (path from assets/)'; exit 1; }
	python3 tools/apply_palette.py $(FROM)

dist: all
	python3 tools/make_dist.py

clean:
	rm -rf build dist
