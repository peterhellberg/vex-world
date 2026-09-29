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

# The name of the console's host import module. src/env.zig stands in for it,
# `zig build-lib --name env` turns that into libenv.so, and the tests link it
# back with -lenv -- so the module name is written down once and the three
# things that have to agree are derived from it. They used to be spelled out
# separately (shim.zig / libenv.so / -lenv) and only the middle one was
# load-bearing, which is how they drifted apart in the first place.
ENV    := env
ENVLIB := lib$(ENV).so

.PHONY: all build run web bundle deploy watch test fmt fmt-check shot \
        clean distclean help

all: build

## build: compile the cart to zig-out/bin/vex-world.wasm
build:
	@zig build
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
	LD_LIBRARY_PATH=. zig test -target x86_64-linux-gnu --dep vex \
		-Mroot=src/cart.zig -Mvex=$$SDK -L. -l$(ENV)

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

## shot: dump a raw frame to /tmp for inspection, e.g. `make shot FRAMES=1500`
shot: build
	@vex -n $(FRAMES) --dump /tmp/vex-world.raw $(WASM)
	@echo "-> /tmp/vex-world.raw ($(FRAMES) frames)"

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
