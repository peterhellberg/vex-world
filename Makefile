# vex-world -- build, test and run the cart.
#
# The real build lives in build.zig (it owns the vex package dependency and the
# wasm32-freestanding target). This is a thin front end over it, so there is one
# place that knows how the cart is compiled.
#
# Note the other vex carts build with a bare `zig build-exe` and a curl'd
# vex.zig. This one does not: it depends on the published vex package, so
# `zig build` is the only thing that can produce the wasm.
#
# `make help` lists the targets.

WASM   := zig-out/bin/vex-world.wasm
FRAMES ?= 300
SHOT   ?= /tmp/vex-world.raw

# `vex --dump` writes the framebuffer as raw RGBA, so the pixel size is all the
# converter needs. ZOOM is nearest-neighbour, to keep the 16x16 tile art crisp.
RAWSIZE ?= 320x180
ZOOM    ?= 200

# SEED pins the world (zig build -Dseed=N). MAP_VIEW=1 pins the cart to the
# whole-map overview instead of the scrolling view, which is what you want when
# checking terrain rather than art. Both are compile-time debug hooks: pinning
# them at build time keeps the render reproducible from the command line, with
# no TTY and no key simulation.
SEED    ?=
SEEDS  ?= 0x51ED 0x7A3F 0x2C91 0xFEED 0x1234 0xABCD

# Zig's -D flags want decimal, but hex reads better for seeds, so the seeds are
# written in hex here and converted on the way in. The two functions use
# opposite bases, hence the round trip.
dec = $(shell printf '%d' $(1))
SEEDOPT  = $(if $(SEED),-Dseed=$(call dec,$(SEED)),)
VIEWOPT  = $(if $(filter 1,$(MAP_VIEW)),-Dmap_view=true,)

# The name of the console's host import module. src/env.zig stands in for it,
# `zig build-lib --name env` turns that into libenv.so, and the tests link it
# back with -lenv -- so the module name is written down once and the three
# things that have to agree are derived from it. They used to be spelled out
# separately (shim.zig / libenv.so / -lenv) and only the middle one was
# load-bearing, which is how they drifted apart in the first place.
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
	@# The SDK is resolved here rather than in the variable above: make expands
	@# that once at parse time, so after a distclean it would be empty and the
	@# test would fail with a confusing error instead of fetching the package.
	@SDK=$$(ls zig-pkg/vex-*/vex.zig 2>/dev/null | head -1); \
	if [ -z "$$SDK" ]; then \
		echo "vex package not fetched -- running 'zig build' first"; \
		zig build >/dev/null; \
		SDK=$$(ls zig-pkg/vex-*/vex.zig 2>/dev/null | head -1); \
	fi; \
	LD_LIBRARY_PATH=. zig test -target x86_64-linux-gnu --dep vex --dep build_options \
		-Mroot=src/cart.zig -Mvex=$$SDK -Mbuild_options=src/build_options.zig \
		-L. -l$(ENV)

# The cart's `env` imports are provided by the console at runtime, so the tests
# need a stand-in to link against. -lc because the stand-in itself needs libc.
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

# The overview is the fastest way to judge terrain: it is the whole map at one
# pixel per tile, so coastlines and biome edges are all visible at once. It is
# pinned at build time (MAP_VIEW=1) rather than toggled with X, because these
# targets render from the command line with no TTY and cannot press a key.
# Re-dumps every time rather than converting a stale file: the seed and the
# frame count are in the command line, not in the filename, so make has no way
# to know the existing dump is out of date.
## png: dump a frame and convert it to a viewable image
png: shot
	@convert -size $(RAWSIZE) -depth 8 rgba:$(SHOT) -scale $(ZOOM)% $(SHOT:.raw=.png)
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
