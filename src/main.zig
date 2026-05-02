const std = @import("std");
const sv = @import("smallvec");

pub fn main() !void {
    const Vec = sv.SmallVec(u32, 5);

    var v = Vec.init();

    v.push(10);
    v.push(20);
    v.push(30);
    v.push(30);

    std.debug.print("len before = {}\n", .{v.len()});

    if (v.pop()) |val| {
        std.debug.print("val = {}\n", .{val});
    } else {
        std.debug.print("empty \n", .{});
    }
}
