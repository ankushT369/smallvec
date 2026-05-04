const std = @import("std");
const sv = @import("smallvec");

pub fn main() !void {
    const Vec = sv.SmallVec(u32, 5);

    var v = Vec.init();

    try v.push(10);
    try v.push(20);
    try v.push(30);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);
    try v.push(3073827);

    defer v.deinit();

    std.debug.print("len before = {}\n", .{v.len()});

    if (v.pop()) |val| {
        std.debug.print("val = {}\n", .{val});
    } else {
        std.debug.print("empty \n", .{});
    }

    std.debug.print("cap: {}\n", .{v.capacity()});
}
