# smallvec
smallvec is a hybrid vector written in [zig](https://ziglang.org/) (inspired by ```SmallVec``` in ```Rust```) it stores small amount of elements (usually small) in the stack memory
to avoid heap allocation. If the threshold for stack elements increase
the it fallbacks to heap based allocation.

This is useful for performance-critical code where most needed vectors are small.

## Usage
```zig
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
```
