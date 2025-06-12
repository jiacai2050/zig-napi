const std = @import("std");
const napi = @import("zig-napi");

// Every module needs to call `register_module`.
comptime {
    napi.registerModule(@This());
}

fn hello(e: napi.Env) !napi.Value {
    return try e.createStringUtf8("Hello from Zig!");
}

// napi module entrypoint
pub fn init(env: napi.Env, exports: napi.Value) !napi.Value {
    const function = try env.createFunction("hello", hello);
    try env.setNamedProperty(exports, "hello", function);

    return exports;
}
