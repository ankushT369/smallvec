const std = @import("std");
const sv = @import("smallvec");

pub fn main() !void {
    const Vec = sv.SmallVec(u32, 64);
    const N: usize = 75;
    var iter: usize = 50;

    // by default it uses std.heap.smp_allocator
    var v = Vec.init(.{});
    defer v.deinit();

    std.debug.print("before capacity: {}\n", .{v.capacity()});
    std.debug.print("before len: {}\n", .{v.len()});

    for (0..N) |i| {
        try v.push(@intCast(i));
    }

    std.debug.print("after capacity: {}\n", .{v.capacity()});
    std.debug.print("after len: {}\n", .{v.len()});

    while (!v.isEmpty() and iter > 0) {
        if (v.pop()) |value| {
            std.debug.print("{}", .{value});
        }

        iter -= 1;
    }

    v.shrinkToFit();

    std.debug.print("after shrink capacity: {}\n", .{v.capacity()});
    std.debug.print("after shrink len: {}\n", .{v.len()});
}
