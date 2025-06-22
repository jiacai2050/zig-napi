const napi = @import("napi");
const std = @import("std");

pub fn hello(env: napi.Env) !napi.Value {
    return try env.createString(.utf8, "Hello from Zig!");
}

pub fn greeting(env: napi.Env, who: napi.Value) !napi.Value {
    var buf: [64]u8 = undefined;
    const len = try who.getValueString(.utf8, &buf);
    const allocator = std.heap.page_allocator;
    const message = try std.fmt.allocPrint(allocator, "Hello {s}", .{buf[0..len]});
    defer allocator.free(message);

    return try env.createString(.utf8, message);
}

pub fn add(env: napi.Env, n1: napi.Value, n2: napi.Value) !napi.Value {
    const d1 = try n1.getValue(f64);
    const d2 = try n2.getValue(f64);
    return try env.create(f64, d1 + d2);
}
