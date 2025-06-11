const std = @import("std");
const c = @cImport({
    @cInclude("node_api.h");
});

pub const Env = struct {
    core: c.napi_env,

    pub fn createStringUtf8(self: *Env, str: []const u8) c.napi_value {
        var result: c.napi_value = undefined;
        self.ffi(c.napi_create_string_utf8, .{ str.ptr, str.len, &result });
        return result;
    }

    pub fn createFunction(self: *Env, name: []const u8, func: anytype) !c.napi_value {
        const fn_info = switch (@typeInfo(@TypeOf(func))) {
            .@"fn" => |fn_info| fn_info,
            else => @compileError("`func` must be a function"),
        };
        if (fn_info.params.len == 0) @compileError("Function must have at least one parameter (the napi.Env)");
        if (fn_info.params[0].type != Env) @compileError("First parameter must be of type `Env`");
        if (fn_info.return_type) |ret_type| {
            if (ret_type != Value) @compileError("Function must return `Value` type");
        } else @compileError("Function must return `Value` type");

        var function: c.napi_value = undefined;
        self.ffi(c.napi_create_function, .{
            name.ptr,
            name.len,
            struct {
                fn callback(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
                    _ = info;
                    const self_env = Env{ .core = env };
                    return func(self_env);
                }
            }.callback,
            null,
            &function,
        });
        return function;
    }

    /// `ffi` is a convenience function to call C functions from Zig.
    /// It will automatically pass the `napi_env` as the first argument to the C function, and it will handle the error checking for you.
    pub fn ffi(self: *Env, c_func: anytype, args: anytype) void {
        var ffi_args: std.meta.ArgsTuple(@TypeOf(c_func)) = undefined;
        ffi_args[0] = self.core;
        inline for (args, 1..) |arg, i| {
            ffi_args[i] = arg;
        }

        if (@call(.auto, c_func, ffi_args) == c.napi_ok) {
            return;
        }

        var err_info: ?*c.napi_extended_error_info = null;
        c.napi_get_last_error_info(self.core, &err_info);

        var is_pending: bool = undefined;
        c.napi_is_exception_pending(self.core, &is_pending);
        // If an exception is already pending, don't rethrow it
        if (is_pending) {
            return;
        }

        if (err_info) |info| {
            c.napi_throw_error(self.core, null, info.*.error_message);
        }

        c.napi_throw_error(self.core, null, 'Unknown error occurred');
    }
};

fn FFIReturnType(Func: type) type {
    const info = @typeInfo(Func);
    const fn_info = switch (info) {
        .@"fn" => |fn_info| fn_info,
        else => @compileError("expecting a function"),
    };

    return fn_info.return_type.?;
}
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

pub fn register_module(comptime Module: type) void {
    const Closure = struct {
        fn init(env: c.napi_env, exports: c.napi_value) callconv(.C) c.npai_value {
            if (!@hasDecl(Module, "init")) @compileError("zig-napi module must provider function `init`");
            const env = Env{
                .core = env,
            };
            Module.init(env, exports);

            return exports;
        }
    };

    @export(&Closure.init, .{ .name = "napi_register_module_v1" });
}

pub const Value = c.napi_value;
