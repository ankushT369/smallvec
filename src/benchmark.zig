//! Benchmark smallvec

const std = @import("std");
const sv = @import("smallvec");

fn benchmark(comptime stack_size: usize, N: usize) !void {
    const Vec = sv.SmallVec(u32, stack_size);

    // Initialize IO (required for Timestamp.now)
    var threaded_io: std.Io.Threaded = .init_single_threaded;
    const io = threaded_io.io();

    var v = Vec.init(.{ .allocator = std.heap.smp_allocator });
    // by default it uses std.heap.smp_allocator
    // var v = Vec.init(.{});
    defer v.deinit();

    std.debug.print("Benchmarking {} elements of stack size {}\n", .{N, stack_size});

    // Benchmark PUSH
    const push_start = std.Io.Timestamp.now(io, .real);

    for (0..N) |i| {
        try v.push(@intCast(i));
    }

    const push_end = std.Io.Timestamp.now(io, .real);
    const push_time = std.Io.Timestamp.durationTo(push_start, push_end);

    // Benchmark POP
    const pop_start = std.Io.Timestamp.now(io, .real);

    for (0..N) |_| {
        _ = v.pop();
    }

    const pop_end = std.Io.Timestamp.now(io, .real);
    const pop_time = std.Io.Timestamp.durationTo(pop_start, pop_end);

    // Print results
    std.debug.print("Push time: {} ns\n", .{push_time});
    std.debug.print("Pop time:  {} ns\n", .{pop_time});

    const push_ns = push_time.toNanoseconds();
    const pop_ns = pop_time.toNanoseconds();

    const avg_push = @divTrunc(push_ns, @as(i96, @intCast(N)));
    const avg_pop = @divTrunc(pop_ns, @as(i96, @intCast(N)));

    std.debug.print("Avg time per push: {} ns\n", .{avg_push});
    std.debug.print("Avg time per pop: {} ns\n", .{avg_pop});

    std.debug.print("\n", .{});
}

pub fn main() !void {
    // Benchmark total element size N = 1_000_00 and stack_size = 32
    try benchmark(32, 1_000_00);

    // Benchmark total element size N = 1_000_00 and stack_size = 64
    try benchmark(64, 1_000_00);

    // Benchmark total element size N = 1_000_00 and stack_size = 128
    try benchmark(128, 1_000_00);

    // Benchmark total element size N = 1_000_00 and stack_size = 256
    try benchmark(256, 1_000_00);

    // Benchmark total element size N = 1_000_00 and stack_size = 512
    try benchmark(512, 1_000_00);

    // Benchmark total element size N = 1_000_00 and stack_size = 1024
    try benchmark(1024, 1_000_00);

    // Benchmark total element size N = 1_000_00 and stack_size = 2048
    try benchmark(2048, 1_000_00);
}
