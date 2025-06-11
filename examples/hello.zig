const std = @import("std");
const napi = @import("zig-napi");

// Every module needs to call `register_module`.
comptime {
    napi.register_module(@This());
}

fn hello(e: napi.Env) !napi.Value {
    return try e.createStringUtf8("Hello from Zig!");
}

// napi module entrypoint
pub fn init(env: napi.Env, exports: napi.Value) void {
    const function = env.createFunction("hello", hello) catch unreachable;
    env.setNamedProperty(exports, "hello", function) catch unreachable;
}
