const std = @import("std");
const napi = @import("napi");

// Every napi module needs to call `registerModule` to register it with the N-API runtime.
comptime {
    napi.registerModule(init);
}

fn hello(e: napi.Env) !napi.Value {
    return try e.createStringUtf8("Hello from Zig!");
}

pub fn init(env: napi.Env, exports: napi.Value) !napi.Value {
    const function = try env.createFunction("hello", hello);
    try env.setNamedProperty(exports, "hello", function);

    return exports;
}
