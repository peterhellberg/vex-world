//! Fallback for the `cfg` module.
//!
//! `zig build` generates this module and points src/cart.zig at it, which is
//! how `-Dseed=N` reaches the cart. This file is what the host test build links
//! instead, where there is no build system to generate one -- the tests pick
//! their own seeds anyway. Kept so `zig test` needs no extra flags.
pub const seed: ?u32 = null;
/// Optional, not a plain bool, so "unset" is distinguishable from "false".
/// The cart opens on the map, so the fallback for unset is the overview; a
/// plain `false` here would silently override that to the scrolling view in
/// every host test build.
pub const map_view: ?bool = null;
