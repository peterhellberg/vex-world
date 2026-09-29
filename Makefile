# vex-world -- build, test and run the cart.
#
# A thin front end over build.zig, which owns the vex package dependency and the
# wasm32-freestanding target. `make help` lists the targets.

WASM   := zig-out/bin/vex-world.wasm
FRAMES ?= 300
SHOT   ?= /tmp/vex-world.raw

# `vex --dump` writes the framebuffer as raw RGBA, so the pixel size is all the
# converter needs. ZOOM is nearest-neighbour, to keep the 16x16 tile art crisp.
RAWSIZE ?= 320x180
ZOOM    ?= 200

# SEED pins the world and MAP_VIEW=1 starts in the whole-map overview. Build-time
# rather than key-driven, so these targets work with no TTY.
SEED    ?=
SEEDS  ?= 0x51ED 0x7A3F 0x2C91 0xFEED 0x1234 0xABCD

# -D flags want decimal; hex reads better for seeds.
dec = $(shell printf '%d' $(1))
SEEDOPT  = $(if $(SEED),-Dseed=$(call dec,$(SEED)),)
VIEWOPT  = $(if $(filter 1,$(MAP_VIEW)),-Dmap_view=true,)

# The console's host import module. src/env.zig stands in for it, and the tests
# link it back with -lenv.
ENV    := env
ENVLIB := lib$(ENV).so

.PHONY: all build run web bundle deploy watch test fmt fmt-check shot png \
        overview seeds clean distclean help

all: build

## build: compile the cart to zig-out/bin/vex-world.wasm
build:
	@zig build $(SEEDOPT) $(VIEWOPT)
	@echo "-> $(WASM)"

## run: build, then run in the native vex console (reloads on rebuild)
run:
	@zig build run

## web: build, then serve with vex-web
web:
	@zig build web

## bundle: build, then write a static bundle/ ready to host anywhere
bundle:
	@zig build bundle

## deploy: bundle, then scp to play.c7.se
deploy:
	@zig build deploy

## watch: rebuild on every edit. Run alongside `make run`; vex -w reloads it.
watch:
	@zig build --watch

## test: run the checks at the bottom of src/cart.zig on the host
test: $(ENVLIB)
	@# The SDK is resolved per-run, not in a variable above: make expands those
	@# once at parse time, so after a distclean it would be empty.
	@SDK=$$(ls zig-pkg/vex-*/vex.zig 2>/dev/null | head -1); \
	if [ -z "$$SDK" ]; then \
		echo "vex package not fetched -- running 'zig build' first"; \
		zig build >/dev/null; \
		SDK=$$(ls zig-pkg/vex-*/vex.zig 2>/dev/null | head -1); \
	fi; \
	LD_LIBRARY_PATH=. zig test -target x86_64-linux-gnu --dep vex --dep cfg \
		-Mroot=src/cart.zig -Mvex=$$SDK -Mcfg=src/cfg.zig \
		-L. -l$(ENV)

# The console provides the `env` imports at runtime, so the tests need a stand-in
# to link against. -lc because the stand-in itself needs libc.
$(ENVLIB): src/$(ENV).zig
	@zig build-lib -dynamic --name $(ENV) src/$(ENV).zig -lc

## fmt: format the source
fmt:
	@zig fmt src

## fmt-check: fail if the source is not formatted (for CI)
fmt-check:
	@zig fmt --check src

## shot: dump a raw frame to $(SHOT) for inspection, e.g. `make shot FRAMES=1500`
shot: build
	@vex -n $(FRAMES) --dump $(SHOT) $(WASM)
	@echo "-> $(SHOT) ($(FRAMES) frames)"

# Always re-dumps: the seed and frame count are in the command line, not the
# filename, so make cannot know an existing dump is stale.
#
# -strip drops the timestamp convert writes into every PNG, so identical renders
# hash identically. It also drops cHRM/bKGD, which is free -- a PNG without them
# still reads as sRGB, and the output is pixel-identical.
## png: dump a frame and convert it to a viewable image
png: shot
	@convert -size $(RAWSIZE) -depth 8 rgba:$(SHOT) -scale $(ZOOM)% -strip $(SHOT:.raw=.png)
	@echo "-> $(SHOT:.raw=.png)"

## overview: one PNG of the whole map, e.g. `make overview SEED=0x51ED`
overview:
	@$(MAKE) --no-print-directory png FRAMES=60 SEED=$(SEED) MAP_VIEW=1

## seeds: one overview PNG per seed in SEEDS, for checking generator variety
seeds:
	@for s in $(SEEDS); do \
		echo "== seed $$s"; \
		$(MAKE) --no-print-directory png FRAMES=60 SEED=$$s MAP_VIEW=1 \
			SHOT=/tmp/vex-world-$$s.raw; \
	done

## clean: remove build output
clean:
	@rm -f $(ENVLIB)
	@rm -rf zig-out .zig-cache

## distclean: clean, plus the fetched package (a later build re-fetches it)
distclean: clean
	@rm -rf zig-pkg

## help: list these targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  /' | sort
