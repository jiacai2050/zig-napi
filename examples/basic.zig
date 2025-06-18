const std = @import("std");
const napi = @import("napi");

// Every napi module needs to call `registerModule` to register it with the N-API runtime.
comptime {
    napi.registerModule(init);
}

fn hello(e: napi.Env) !napi.Value {
    return try e.createString(.utf8, "Hello from Zig!");
}

fn greeting(e: napi.Env, who: napi.Value) !napi.Value {
    var buf: [64]u8 = undefined;
    const len = try who.getValueString(.utf8, &buf);
    const allocator = std.heap.page_allocator;
    const message = try std.fmt.allocPrint(allocator, "Hello {s}", .{buf[0..len]});
    defer allocator.free(message);

    return try e.createString(.utf8, message);
}

fn add(e: napi.Env, n1: napi.Value, n2: napi.Value) !napi.Value {
    const d1 = try n1.getValue(f64);
    const d2 = try n2.getValue(f64);
    return try e.create(f64, d1 + d2);
}

fn scope_demo(e: napi.Env) !napi.Value {
    for (0..100000) |i| {
        const scope = try e.openScope();
        defer scope.deinit() catch unreachable;
        const value = try e.create(f64, @floatFromInt(i));
        // Do something with value, and it will get freed when scope is deinited.
        _ = value;
    }
    return .default;
}

pub fn init(env: napi.Env, exports: napi.Value) !napi.Value {
    try env.setNamedProperty(
        exports,
        "hello",
        try env.createFunction(hello, null),
    );

    try env.setNamedProperty(
        exports,
        "greeting",
        try env.createFunction(greeting, null),
    );

    try env.setNamedProperty(
        exports,
        "add",
        try env.createFunction(add, null),
    );

    try env.setNamedProperty(
        exports,
        "scope_demo",
        try env.createFunction(scope_demo, null),
    );
    return exports;
}
