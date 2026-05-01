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
pub fn SmallVec(comptime T: type, comptime capacity: usize) type {
    return struct{
        const Self = @This();

        data: [capacity]T,
        capacity: usize,
        length: PackedLen,


        pub fn init() Self {
            return Self{
                .data = undefined,
                .capacity = capacity,
                .length = PackedLen.init(0),
            };
        }

        pub fn push(self: *Self, value: T) !void {
            if (self.checkIfLenExceedsCapacity()) {
                // later handle this for heap allocation
                return error.Full;
            }

            self.data[self.length.unPackLen()] = value;
            self.length.increaseLen();

            return;
        }

        pub fn pop(self: *Self) !void {
            if (self.isEmpty()) {
                return error.Full;
            }

            if (self.checkIfLenExceedsCapacity()) {
                // If data is on heap we have to deallocate it for now its now implemented
                return error.Full;
            }

            self.data[self.length.unPackLen()] = 0;
            self.length.decreaseLen();

            return;
        }

        pub fn get(self: *Self, index: usize) T {
            return self.data[index];
        }

        pub fn set(self: *Self, index: usize, value: T) !void {
            self.data[index] = value;
        }

        pub fn isEmpty(self: *Self) bool {
            return self.length.unPackLen() == 0; 
        }

        pub fn len(self: *Self) usize {
            return self.length.unPackLen();
        }

        pub fn spilled(self: *Self) bool {
            return self.length.unPackIsHeap();
        }

        fn checkIfLenExceedsCapacity(self: *Self) bool {
            return self.capacity <= self.length.unPackLen();
        }
    };

}

/// PackedLen is a packed form of length and on_heap, instead of wasting
/// space for len(usize 8 bytes) and is_heap(bool 1 byte) is 9 bytes with 
/// padding it will form total of 16 bytes.
///
/// [usize........8 bytes][bool 1 byte][padding 7 bytes] = 16 bytes.
///
/// I packed it up by applying bitwise operator. It uses the most significant bit
/// which is also known as sign bit as is_heap (bool).
const PackedLen = struct {
    const Self = @This();
    packed_len_and_heap: usize,

    fn init(len: usize) Self {
        return Self{
            .packed_len_and_heap = pack(len, false)
        };
    }
    fn pack(len: usize, on_heap: bool) usize {
        return (len << 1) | @intFromBool(on_heap);
    }

    fn unPackLen(self: *Self) usize {
        return self.packed_len_and_heap >> 1;
    }

    fn unPackIsHeap(self: *Self) bool {
        return (self.packed_len_and_heap & 1) == 1;
    }

    fn increaseLen(self: *Self) void {
        self.packed_len_and_heap += 2; 
    }

    fn decreaseLen(self: *Self) void {
        self.packed_len_and_heap -= 2; 
    }

    fn setHeap(self: *Self) void {
        self.packed_len_and_heap |= 1;
    }

    fn unsetHeap(self: *Self) void {
        self.packed_len_and_heap &= ~@as(usize, 1);
    }
};

// Test cases
test "smallvec push pop test for unsigned 32-bit" {
    const Vec = SmallVec(u32, 5);

    var v = Vec.init();

    try v.push(10);
    try v.push(20);
    try v.push(30);
    try v.push(30);

    try std.testing.expect(v.len() == @as(usize, 4));

    try v.pop();
    try v.pop();

    try std.testing.expect(v.len() == @as(usize, 2));
}

test "smallvec get set test unsigned 32-bit" {
    const Vec = SmallVec(u32, 5);

    var v = Vec.init();

    try v.push(10);
    try v.push(20);
    try v.push(30);
    try v.push(30);

    try std.testing.expect(v.get(3) == @as(u32, 30));
    try std.testing.expect(v.get(1) == @as(u32, 20));

    try v.set(1, 436);
    try std.testing.expect(v.get(1) == @as(u32, 436));

    try v.set(0, 893);
    try std.testing.expect(v.get(0) == @as(u32, 893));
}
