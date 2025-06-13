const std = @import("std");
const napi = @import("napi");

// Every napi module needs to call `registerModule` to register it with the N-API runtime.
comptime {
    napi.registerModule(init);
}

fn hello(e: napi.Env) !napi.Value {
    return try e.createStringUtf8("Hello from Zig!");
}

fn greeting(e: napi.Env, who: napi.Value) !napi.Value {
    var buf: [64]u8 = undefined;
    const len = try e.getValueStringUtf8(who, &buf);
    std.debug.print("Hello, {s}!\n", .{buf[0..len]});
    return null;
}

fn add(e: napi.Env, n1: napi.Value, n2: napi.Value) !napi.Value {
    const d1 = try e.getValueDouble(n1);
    const d2 = try e.getValueDouble(n2);
    return try e.createDouble(d1 + d2);
}

pub fn init(env: napi.Env, exports: napi.Value) !napi.Value {
    try env.setNamedProperty(
        exports,
        "hello",
        try env.createFunction("hello", hello),
    );

    try env.setNamedProperty(
        exports,
        "greeting",
        try env.createFunction("greeting", greeting),
    );

    try env.setNamedProperty(
        exports,
        "add",
        try env.createFunction("add", add),
    );

    return exports;
}
