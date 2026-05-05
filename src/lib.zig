//! lib.zig provides a SmallVec implementation
//!
//! A SmallVec stores small amount of elements (usually small) in the stack memory
//! to avoid heap allocation. If the threshold for stack elements increase
//! the it fallbacks to heap based allocation.
//!
//! This is useful for performance-critical code where most needed vectors are small.
const std = @import("std");

/// A hybrid vector that stores elements into stack up to a fixed capacity,
/// and spills to the heap when that capacity is exceeded.
///
/// The stack capacity is determined at compile time. This avoids heap
/// allocations for small workloads while still allowing growth.
///
/// Note:
/// - stack storage increases the size of the struct.
/// - Large element types or large capacities can lead to high stack usage.
pub fn SmallVec(comptime T: type, comptime cap: usize) type {
    comptime {
        if (cap > 32 and !std.math.isPowerOfTwo(cap)) {
            @compileError("capacity > 32 must be power of 2");
        }
    }

    return struct {
        const Self = @This();
        // Default it uses std.heap.smp_allocator
        const AllocatorConfig = struct { allocator: std.mem.Allocator = std.heap.smp_allocator };

        length: Packed,
        allocator: std.mem.Allocator,
        data: union(enum) {
            stack: [cap]T,
            heap: []T,
        },

        /// User API for SmallVec
        /// - init(.{})
        /// - push()
        /// - pop()
        /// - spilled()
        /// - capacity()
        /// - len()
        /// - isEmpty()
        /// - deinit()
        pub fn init(config: AllocatorConfig) Self {
            return .{
                .length = Packed.pack(0, false, isZst()),
                .allocator = config.allocator,
                .data = .{ .stack = undefined },
            };
        }

        pub fn push(self: *Self, value: T) !void {
            try self.writeMem(value);
            self.setLen(self.len() + 1);
            return;
        }

        pub fn pop(self: *Self) ?T {
            var ret: ?T = null;
            if (self.isEmpty()) return ret;

            ret = self.readMem();
            self.setLen(self.len() - 1);
            return ret;
        }

        pub inline fn spilled(self: *Self) bool {
            return self.length.onHeap(isZst());
        }

        pub inline fn capacity(self: *Self) usize {
            // Return based on the heap or stack.
            if (self.length.onHeap(isZst()))
                return self.data.heap.len
            else
                return inlineCapacity();
        }

        pub inline fn len(self: *Self) usize {
            return self.length.value(isZst());
        }

        pub inline fn isEmpty(self: *Self) bool {
            return self.len() == 0;
        }

        pub fn deinit(self: *Self) void {
            if (self.length.onHeap(isZst())) {
                const allocator = std.heap.smp_allocator;
                allocator.free(self.data.heap);
            }
        }

        fn writeMem(self: *Self, value: T) !void {
            if (inlineCapacity() == self.len())
                if (!self.length.onHeap(isZst()))
                    try self.spillToHeap();

            if (isZst()) {
                // Do nothing
                return;
            } else {
                if (self.length.onHeap(isZst())) {
                    if (self.len() == self.capacity()) {
                        // Here I have to grow the dynamic array
                        try self.growHeap();
                        self.data.heap[self.len()] = value;
                    } else {
                        self.data.heap[self.len()] = value;
                    }
                } else self.data.stack[self.len()] = value;

                return;
            }
        }

        fn readMem(self: *Self) T {
            if (isZst()) {
                // right now return undefined
                return undefined;
            } else {
                if (self.length.onHeap(isZst()))
                    return self.data.heap[self.len() - 1]
                else
                    return self.data.stack[self.len() - 1];
            }
        }

        /// Below isZst() and inlineCapacity() are complete static funtions depends on
        /// its current comp time defined capacity.
        inline fn isZst() bool {
            return cap == 0;
        }

        inline fn inlineCapacity() usize {
            return cap;
        }

        inline fn setOnHeap(self: *Self) void {
            self.length = Packed.pack(self.len(), true, isZst());
        }

        inline fn setInline(self: *Self) void {
            self.length = Packed.pack(self.len(), false, isZst());
        }

        inline fn setLen(self: *Self, new_len: usize) void {
            // std.debug.assert(new_len <= capacity());
            const on_heap: bool = self.length.onHeap(isZst());
            self.length = Packed.pack(new_len, on_heap, isZst());
        }

        fn spillToHeap(self: *Self) !void {
            const old_len = self.len();
            const new_cap = 2 * inlineCapacity();

            const heap_mem = try self.allocator.alloc(T, new_cap);
            const stack_slice = self.data.stack[0..old_len];

            std.mem.copyForwards(T, heap_mem[0..old_len], stack_slice);

            self.data = .{ .heap = heap_mem };
            self.setOnHeap();
        }

        fn growHeap(self: *Self) !void {
            const old_len = self.len();
            const old_cap = self.capacity();
            const new_cap = old_cap * 2;

            const old_heap = self.data.heap;

            const new_heap = try self.allocator.alloc(T, new_cap);

            std.mem.copyForwards(T, new_heap[0..old_len], old_heap[0..old_len]);

            self.allocator.free(old_heap);

            self.data = .{ .heap = new_heap };
            self.setOnHeap();
        }
    };
}

/// Packed is a packed form of len and on_heap, instead of wasting
/// space for len(usize 8 bytes) and is_heap(bool 1 byte) is 9 bytes with
/// padding it will form total of 16 bytes.
///
/// [usize........8 bytes][bool 1 byte][padding 7 bytes] = 16 bytes.
///
/// I packed it up by applying bitwise operator. It uses the most significant bit
/// which is also known as sign bit as is_heap (bool).
///
/// [usize..............x] = 8 bytes
///                     ^
///                     This bit represents boolean
///
const Packed = struct {
    const Self = @This();
    packed_data: usize,

    /// Returns packed (len and on_heap)
    /// Encodes `len` and `on_heap` into a single usize using bit packing.
    /// Bit 0 stores heap flag, remaining bits store length.
    /// if the datatype len is zero then we store only len orelse bit packing.
    inline fn pack(len: usize, on_heap: bool, is_zst: bool) Self {
        if (is_zst) {
            std.debug.assert(!on_heap);
            return .{ .packed_data = len };
        } else {
            std.debug.assert(len < (1 << (@bitSizeOf(usize) - 1)));
            return .{
                .packed_data = (len << 1) | @as(usize, @intFromBool(on_heap)),
            };
        }
    }

    inline fn onHeap(self: *Self, is_zst: bool) bool {
        if (is_zst)
            return false
        else
            return (self.packed_data & @as(usize, 1)) == 1;
    }

    inline fn value(self: *Self, is_zst: bool) usize {
        if (is_zst)
            return self.packed_data
        else
            return self.packed_data >> 1;
    }
};

// Test cases
test "smallvec test for unsigned 32-bit integer" {
    std.debug.print("Testing for unsigned 32-bit integer \n", .{});

    const Vec = SmallVec(u32, 5);
    var v = Vec.init();

    v.push(321);
    v.push(25346);
    v.push(843);
    v.push(903);

    try std.testing.expect(v.len() == @as(usize, 4));
    std.debug.print("✓ Passed Test 1 \n", .{});

    _ = v.pop().?;
    _ = v.pop().?;
    try std.testing.expect(v.len() == @as(usize, 2));
    std.debug.print("✓ Passed Test 2 \n", .{});

    v.push(13213);
    v.push(6478);
    try std.testing.expect(v.get(3) == @as(u32, 6478));
    std.debug.print("✓ Passed Test 3 \n", .{});

    try std.testing.expect(v.get(1) == @as(u32, 25346));
    std.debug.print("✓ Passed Test 4 \n", .{});

    try v.set(1, 436);
    try std.testing.expect(v.get(1) == @as(u32, 436));
    std.debug.print("✓ Passed Test 5 \n", .{});

    try v.set(0, 893);
    try std.testing.expect(v.get(0) == @as(u32, 893));
    std.debug.print("✓ Passed Test 6 \n", .{});
}
