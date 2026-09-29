//! Fallback for the `cfg` module.
//!
//! `zig build` generates this module and points src/cart.zig at it, which is
//! how `-Dseed=N` reaches the cart. This file is what the host test build links
//! instead, where there is no build system to generate one -- the tests pick
//! their own seeds anyway. Kept so `zig test` needs no extra flags.
pub const seed: ?u32 = null;
pub const map_view: bool = false;
