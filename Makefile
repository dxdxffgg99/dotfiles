SHELL := /bin/sh
INSTALL := ./install.sh

# make install COPY=1     -> copy files instead of symlinking
# make install DRY_RUN=1  -> print what would happen, change nothing
# make install NO_BACKUP=1-> replace existing files without backing them up
FLAGS := $(if $(COPY),--copy) $(if $(DRY_RUN),--dry-run) $(if $(NO_BACKUP),--no-backup)

GROUPS := zsh starship wallpaper chrome kitty waybar rofi hypr nvim btop mako fastfetch

.PHONY: help install copy uninstall status deps check dry-run $(GROUPS)

help:
	@echo "make install      symlink every config into \$$HOME (backs up what is there)"
	@echo "make copy         same, but copy the files instead of symlinking"
	@echo "make dry-run      show what install would do, change nothing"
	@echo "make uninstall    remove the symlinks that point into this repo"
	@echo "make status       show which files are linked / copied / differ / missing"
	@echo "make deps         check for the programs these configs need"
	@echo ""
	@echo "make <group>      install one group: $(GROUPS)"
	@echo ""
	@echo "flags:            COPY=1  DRY_RUN=1  NO_BACKUP=1"

install:
	@$(INSTALL) $(FLAGS)

copy:
	@$(INSTALL) --copy $(if $(DRY_RUN),--dry-run) $(if $(NO_BACKUP),--no-backup)

dry-run:
	@$(INSTALL) --dry-run $(if $(COPY),--copy)

uninstall:
	@$(INSTALL) --uninstall $(if $(DRY_RUN),--dry-run)

status:
	@$(INSTALL) --status

deps check:
	@$(INSTALL) --deps

$(GROUPS):
	@$(INSTALL) $(FLAGS) $@
