// Stand-in for the console's `env` import module, so the checks at the bottom of
// cart.zig can run on the host instead of inside the console. Named after the
// module it replaces: built with `--name env` it becomes libenv.so, which is
// what `make test` links with -lenv.
//
//   zig build-lib -dynamic --name env src/env.zig -lc && \
//   LD_LIBRARY_PATH=. zig test -target x86_64-linux-gnu --dep vex \
//     -Mroot=src/cart.zig -Mvex=<sdk>/vex.zig -L. -lenv
//
// Only the imports src/cart.zig actually calls need to be here; the linker
// only asks for the ones its debug info references.

export fn cls(color: i32) void {
    _ = color;
}
export fn pset(x: i32, y: i32, color: i32) void {
    _ = .{ x, y, color };
}
export fn pal(i: i32, rgb: i32) void {
    _ = .{ i, rgb };
}
export fn rect(x: i32, y: i32, w: i32, h: i32, color: i32) void {
    _ = .{ x, y, w, h, color };
}
export fn rectb(x: i32, y: i32, w: i32, h: i32, color: i32) void {
    _ = .{ x, y, w, h, color };
}
export fn blit(data: [*]const u8, x: i32, y: i32, w: i32, h: i32, key: i32) void {
    _ = .{ data, x, y, w, h, key };
}
export fn text(s: [*:0]const u8, x: i32, y: i32, color: i32) void {
    _ = .{ s, x, y, color };
}
export fn title(s: [*:0]const u8) void {
    _ = s;
}
export fn btn(b: i32) i32 {
    _ = b;
    return 0;
}
export fn btnp(b: i32) i32 {
    _ = b;
    return 0;
}
export fn mx() i32 {
    return 0;
}
export fn my() i32 {
    return 0;
}
export fn mbtn(button: i32) i32 {
    _ = button;
    return 0;
}
