const std = @import("std");
const c = @cImport({
    @cInclude("node_api.h");
});

pub const Value = c.napi_value;

pub const Env = struct {
    c_handle: c.napi_env,

    pub fn createStringUtf8(self: Env, str: []const u8) !Value {
        var result: c.napi_value = undefined;
        try self.ffi(c.napi_create_string_utf8, .{ str.ptr, str.len, &result });
        return result;
    }

    pub fn createFunction(self: Env, name: []const u8, func: anytype) !Value {
        const fn_info = switch (@typeInfo(@TypeOf(func))) {
            .@"fn" => |fn_info| fn_info,
            else => @compileError("`func` must be a function"),
        };
        if (fn_info.params.len == 0 || fn_info.params[0].type != Env) @compileError("The function requires an `Env`-type parameter as its first parameter
.");
        if (fn_info.return_type) |ret_type| {
            if (ret_type != Value)
                switch (@typeInfo(ret_type)) {
                    .error_union => |err_union| if (err_union.payload != Value) @compileError("Expected a !Value type"),
                    else => @compileError("Function must return `Value` or `!Value` type"),
                }
            else
                @compileError("Function must return `Value` or `!Value` type");
        } else @compileError("Function must return `Value` or `!Value` type");

        var function: c.napi_value = undefined;
        try self.ffi(c.napi_create_function, .{
            name.ptr,
            name.len,
            struct {
                fn callback(env: c.napi_env, info: c.napi_callback_info) callconv(.C) Value {
                    // TODO: support extra parameters from info
                    _ = info;
                    const self_env = Env{ .c_handle = env };
                    return if (fn_info.return_type.? == Value)
                        @call(.auto, func, .{self_env})
                    else
                        @call(.auto, func, .{self_env}) catch |err| {
                            _ = c.napi_throw_error(env, null, @errorName(err));
                            return null;
                        };
                }
            }.callback,
            null,
            &function,
        });
        return function;
    }

    pub fn setNamedProperty(self: Env, exports: Value, name: [:0]const u8, prop: Value) !void {
        try self.ffi(c.napi_set_named_property, .{ exports, name.ptr, prop });
    }
    /// `ffi` is a convenience function to call C functions from Zig.
    /// It will automatically pass the `napi_env` as the first argument to the C function, and it will handle the error checking for you.
    pub fn ffi(self: Env, c_func: anytype, args: anytype) !void {
        var ffi_args: std.meta.ArgsTuple(@TypeOf(c_func)) = undefined;
        ffi_args[0] = self.c_handle;
        inline for (args, 1..) |arg, i| {
            ffi_args[i] = arg;
        }

        if (@call(.auto, c_func, ffi_args) == c.napi_ok) {
            return;
        }

        var err_info: [*c]const c.napi_extended_error_info = null;
        if (c.napi_get_last_error_info(self.c_handle, &err_info) != c.napi_ok) {
            return error.GetLastError;
        }

        var is_pending: bool = undefined;
        if (c.napi_is_exception_pending(self.c_handle, &is_pending) != c.napi_ok) {
            return error.IsExceptionPending;
        }
        // If an exception is already pending, don't rethrow it
        if (is_pending) {
            return;
        }

        const msg = if (err_info) |info|
            std.mem.span(info.*.error_message)
        else
            "Unknown error";

        if (c.napi_throw_error(self.c_handle, null, msg) != c.napi_ok) {
            return error.ThrowError;
        }
    }
};

pub fn register_module(comptime Module: type) void {
    const Closure = struct {
        fn init(env: c.napi_env, exports: c.napi_value) callconv(.C) Value {
            if (!@hasDecl(Module, "init")) @compileError("zig-napi module must provider function `init`");
            Module.init(Env{ .c_handle = env }, exports);

            return exports;
        }
    };

    @export(&Closure.init, .{ .name = "napi_register_module_v1" });
}
