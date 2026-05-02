//! lib.zig provides a SmallVec implementation
//!
//! A SmallVec stores small amount of elements (usually small) inline
//! to avoid heap allocation. If the threshold for inline elements increase
//! the it fallbacks to heap based allocation.
//!
//! This is useful for performance-critical code where most needed vectors are small.
const std = @import("std");

/// A hybrid vector that stores elements inline up to a fixed capacity,
/// and spills to the heap when that capacity is exceeded.
///
/// The inline capacity is determined at compile time. This avoids heap
/// allocations for small workloads while still allowing growth.
///
/// Note:
/// - Inline storage increases the size of the struct.
/// - Large element types or large capacities can lead to high stack usage.
pub inline fn SmallVec(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        capacity: usize,
        metadata: Packed,
        data: [capacity]T,

        pub fn init() Self {
            return Self{
                .data = undefined,
                .capacity = capacity,
                .metadata = Packed.init(),
            };
        }

        pub fn push(self: *Self, value: T) void {
            if (self.checkIfLenEqualOrExceedsCapacity()) {
                // later handle this for heap allocation
                return ;
            }

            self.data[self.metadata.unpackLen()] = value;
            self.metadata.growLength();

            return;
        }

        pub fn pop(self: *Self) ?T {
            var ret: ?T = null;

            if (self.isEmpty()) return ret;

            if (self.metadata.unpackIsHeap()) {
                // If data is on heap we have to deallocate it for now its now implemented
                return ret;
            }

            ret = self.data[self.metadata.unpackLen() - 1];
            self.metadata.shrinkLength();

            return ret;
        }

        pub fn get(self: *Self, index: usize) T {
            if (index >= self.len()) @panic("index out of bounds");

            return self.data[index];
        }

        pub fn set(self: *Self, index: usize, value: T) !void {
            self.data[index] = value;
        }

        pub inline fn isEmpty(self: *Self) bool {
            return self.metadata.unpackLen() == 0;
        }

        pub fn len(self: *Self) usize {
            return self.metadata.unpackLen();
        }

        pub fn spilled(self: *Self) bool {
            return self.metadata.unpackIsHeap();
        }

        fn checkIfLenEqualOrExceedsCapacity(self: *Self) bool {
            return self.capacity <= self.metadata.unpackLen();
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

    fn init() Self {
        return Self{ .packed_data = pack(0, false) };
    }

    /// Returns packed (len and on_heap)
    /// Encodes `len` and `on_heap` into a single usize using bit packing.
    /// Bit 0 stores heap flag, remaining bits store length.
    inline fn pack(len: usize, on_heap: bool) usize {
        return (len << 1) | @intFromBool(on_heap);
    }

    inline fn store(self: *Self, packed_data: usize) void {
        self.packed_data = packed_data;
    }

    /// unpack*() are read-only functions used to read len or on_heap status
    inline fn unpackLen(self: *Self) usize {
        return self.packed_data >> 1;
    }

    inline fn unpackIsHeap(self: *Self) bool {
        return (self.packed_data & 1) == 1;
    }

    /// Mutates the packed state:
    /// - increase/decrease modify length 
    /// - setHeap/unsetHeap modify heap flag
    inline fn growLength(self: *Self) void {
        var len: usize = self.unpackLen();
        len += 1;
        self.store(pack(len, self.unpackIsHeap()));
    }

    inline fn shrinkLength(self: *Self) void {
        var len: usize = self.unpackLen();
        len -= 1;
        self.store(pack(len, self.unpackIsHeap()));
    }

    inline fn setHeap(self: *Self) void {
        var on_heap: bool = self.unpackIsHeap();
        on_heap = true;
        self.store(pack(self.unpackLen(), on_heap));
    }

    inline fn unsetHeap(self: *Self) void {
        var on_heap: bool = self.unpackIsHeap();
        on_heap = false; 
        self.store(pack(self.unpackLen(), on_heap));
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
