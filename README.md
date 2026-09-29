# vex-world

A procedural overworld for the [VEX](https://github.com/peterhellberg/vex) console, assembled by
wave function collapse and written in Zig. The whole thing is one file, `src/cart.zig`, compiling to
a ~450 KB wasm cart. `make overview SEED=0x51ED` renders the map to a PNG if you would rather look
than read.

## Quick start

```sh
make run     # build and run in the native vex console
make test    # run the checks on the host
make help    # list every target
```

`make` needs [Zig](https://ziglang.org) (0.17-dev) and, for `run`/`web`, the `vex` and `vex-web`
binaries on your `PATH`. The SDK itself is fetched as a build dependency; a cart build pulls
nothing heavy.

## Controls

| | |
|---|---|
| arrows / hold LMB | scroll. Dragging near a screen edge accelerates; the minimap suppresses it |
| X / RMB | toggle the full-map overview and the scrolling view |
| Z | new world |
| click | on the minimap or the overview, move the camera to that spot |

The cart opens zoomed in on the scrolling view, with an 80x40 minimap in the top-right corner
showing the whole map and a frame marking the visible part. Press X for the full-screen overview.

## How it works

**Generation.** Every one of the 51,200 cells starts as "any tile". The cell with the fewest
options left is collapsed to a weighted pick, and the choice is propagated to its neighbours,
removing anything no longer legal. Cells are bucketed by option count, so picking the next cell is
O(1) rather than a scan. The solve runs `CELLS/32` collapses per frame — about half a second of
watching it appear, whatever the map size.

**Terrain.** Elevation is four octaves of value noise under a low-frequency land mask, warped
before it is sampled, with ridged noise on the upper octaves. Height picks an elevation class, and
classes blend: two adjacent cells may differ by at most one, so the coast and every contour are
gradual rather than stepped. Band edges are quantiles fitted to the actual height distribution,
which is what keeps all seven land tiers visible instead of a handful swallowing the rest.

| | | |
|---|---|---|
| water | DEEP SEA, SHALLOWS, BEACH | |
| rising | PLAINS, FOREST, DEEP FOREST, HIGHLANDS, BARRENS, PEAKS, SNOWCAP | |
| landmarks | RUINS | rare, inland, never on a beach |

**Tiles** are opaque 16x16 palette bitmaps, 8 variants each, so the same terrain never stamps one
texture twice running. A frame is one blit per *visible* tile — about 200 — not one per map cell.

**Seams.** Where two terrains meet, the earlier tile in row-major order owns the seam and dithers
an 8px band of the neighbour's art into its own edge, so terrain boundaries are feathered rather
than cut. Ruins are the exception: a ruin lends its *ground* to a seam, never its building, so no
roof can leak onto the grass next door.

**Palette** is the cart's own 16 colours, named by role in `src/cart.zig` rather than by index.
The roles encode relationships — deep water is exactly one step darker than shallows, a wave crest
is the next depth's body tone — which is why swapping the table is a single edit that cannot
silently turn grass into steel blue.

## Layout

```
src/cart.zig    the cart: palette, tiles, generator, renderer, HUD, and the tests
src/cfg.zig     fallback for the generated `cfg` module, so `zig test` needs no extra flags
src/env.zig     stand-in for the console's host imports, which the host tests link against
build.zig       wasm32-freestanding build, -Dseed / -Dmap_view, run/web/bundle/deploy
Makefile        build, test and render targets over build.zig
```

## Rendering headlessly

The VEX console dumps the framebuffer as raw RGBA, so the Makefile turns a run into a PNG with
ImageMagick. `-strip` drops the timestamp `convert` writes into every PNG, so identical renders
hash identically and a diff means an actual change.

```sh
make png SEED=0x51ED FRAMES=1200   # the scrolling view, as the cart opens
make overview SEED=0x51ED           # the whole map, one pixel per tile
make seeds                          # one overview per seed, for checking variety
```

`SEED` and `MAP_VIEW` are passed through to `zig build -Dseed=N -Dmap_view=true`. Unset seed means
the cart's own default, `0xC0FFEE`.

## Tests

`make test` runs 30 checks on the host against `src/env.zig` — the generator obeys its own
adjacency table, the same seed always collapses to the same world, seams are blended once and only
toward the neighbour, every elevation tier gets a visible share of the land, ruins stay off the
beach, and no tile's map colour is one its art never paints.

## Notes

- The cart solves `GENERATE_PER_FRAME` cells at a time so the map can be watched appearing, while a
  test calls `solve(CELLS)` and gets it in one go. These produce identical worlds, checked across
  ten seeds: the budget only decides how many iterations a call makes before returning. An earlier
  version of this file claimed otherwise, on the strength of a probe that called `solve(CELLS)`
  without resetting first and so inherited the previous test's half-collapsed world. There is now a
  test for it.
- `VARIANTS` is the size knob: 11,264 bytes each in the wasm, art and bands together, so the eight
  of them are 90 KB of a 458 KB cart. Four is 45 KB smaller and still reads.
- The overview's viewport rectangle needs no treatment beyond the 1px outline it already has. At
  full-map scale it is 20x10 and has an 18x8 interior to be hollow; the minimap's is 5x2, which has
  no interior at all and is why that one is grown a pixel.
