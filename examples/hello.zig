const std = @import("std");
const napi = @import("zig-napi");

// Every module needs to call `module_init` in order to register with Emacs.
comptime {
    napi.register_module(@This());
}

fn hello(e: napi.Env) napi.Value {
    return e.createStringUtf8("Hello from Zig!");
}

// zig-napi module entrypoint
pub fn init(env: napi.Env, exports: napi.Value) void {
    var function: napi.value = undefined;
    if (c.napi_create_function(env, null, 0, hello, null, &function) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to create function");
        return null;
    }

    if (c.napi_set_named_property(env, exports, "hello", function) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to add function to exports");
        return null;
    }
}
