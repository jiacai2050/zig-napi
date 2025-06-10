const std = @import("std");
const c = @cImport({
    @cInclude("node_api.h");
});

export fn napi_register_module_v1(env: c.napi_env, exports: c.napi_value) c.napi_value {
    var function: c.napi_value = undefined;
    if (c.napi_create_function(env, null, 0, hello, null, &function) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to create function");
        return null;
    }

    if (c.napi_set_named_property(env, exports, "hello", function) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to add function to exports");
        return null;
    }

    return exports;
}

fn hello(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    _ = info;
    var result: c.napi_value = undefined;
    const msg = "Hello from Zig!";
    if (c.napi_create_string_utf8(env, msg.ptr, msg.len, &result) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to create utf string");
        return null;
    }

    return result;
}
