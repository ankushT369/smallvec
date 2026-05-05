const std = @import("std");
const sv = @import("smallvec");

pub fn main() !void {
    const Vec = sv.SmallVec(u32, 64);
    const N: usize = 1_000;

    // by default it uses std.heap.smp_allocator
    var v = Vec.init(.{});
    defer v.deinit();

    for (0..N) |i| {
        try v.push(@intCast(i));
    }

    while (!v.isEmpty()) {
        if (v.pop()) |value| {
            std.debug.print("{}\n", .{value});
        }
    }
}
