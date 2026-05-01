const std = @import("std");
const sv = @import("smallvec");

pub fn main() !void {
    const Vec = sv.SmallVec(u32, 5);

    var v = Vec.init();

    try v.push(10);
    try v.push(20);
    try v.push(30);
    try v.push(30);

    std.debug.print("len before = {}\n", .{v.len()});
    try v.pop();
    std.debug.print("len after = {}\n", .{v.len()});
}
