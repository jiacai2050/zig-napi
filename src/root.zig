const std = @import("std");
const c = @import("c.zig").c;
const callNodeApi = @import("c.zig").callNodeApi;
pub const Value = @import("c.zig").Value;

/// Env is a wrapper around the Node-API environment handle (`napi_env`).
/// It provides methods to interact with the Node-API, such as type conversions between Zig and JavaScript values.
pub const Env = struct {
    c_handle: c.napi_env,

    pub fn getValueDouble(self: Env, value: Value) !f64 {
        var result: f64 = undefined;
        try callNodeApi(
            self.c_handle,
            c.napi_get_value_double,
            .{ value, &result },
        );
        return result;
    }

    pub fn getValueInt64(self: Env, value: Value) !i64 {
        var result: i64 = undefined;
        try callNodeApi(
            self.c_handle,
            c.napi_get_value_int64,
            .{ value, &result },
        );
        return result;
    }

    pub fn getValueUint32(self: Env, value: Value) !u32 {
        var result: u32 = undefined;
        try callNodeApi(
            self.c_handle,
            c.napi_get_value_uint32,
            .{ value, &result },
        );
        return result;
    }

    pub fn getValueInt32(self: Env, value: Value) !i32 {
        var result: i32 = undefined;
        try callNodeApi(
            self.c_handle,
            c.napi_get_value_int32,
            .{ value, &result },
        );
        return result;
    }

    pub fn getValueStringUtf8(self: Env, value: Value, out_str: []u8) !usize {
        // Number of bytes copied into the buffer, excluding the null terminator.
        var len: usize = 0;
        try callNodeApi(
            self.c_handle,
            c.napi_get_value_string_utf8,
            .{ value, out_str.ptr, out_str.len, &len },
        );
        return len;
    }

    pub fn createDouble(self: Env, num: f64) !Value {
        var result: Value = undefined;
        try callNodeApi(
            self.c_handle,
            c.napi_create_double,
            .{ num, &result },
        );
        return result;
    }

    pub fn createInt64(self: Env, num: i64) !Value {
        var result: Value = undefined;
        try callNodeApi(
            self.c_handle,
            c.napi_create_int64,
            .{ num, &result },
        );
        return result;
    }

    pub fn createUint32(self: Env, num: u32) !Value {
        var result: Value = undefined;
        try callNodeApi(
            self.c_handle,
            c.napi_create_uint32,
            .{ num, &result },
        );
        return result;
    }

    pub fn createInt32(self: Env, num: i32) !Value {
        var result: Value = undefined;
        try callNodeApi(
            self.c_handle,
            c.napi_create_int32,
            .{ num, &result },
        );
        return result;
    }

    pub fn createStringUtf8(self: Env, str: []const u8) !Value {
        var result: Value = undefined;
        try callNodeApi(
            self.c_handle,
            c.napi_create_string_utf8,
            .{ str.ptr, str.len, &result },
        );
        return result;
    }

    pub fn createFunction(self: Env, name: []const u8, func: anytype) !Value {
        const fn_info = switch (@typeInfo(@TypeOf(func))) {
            .@"fn" => |fn_info| fn_info,
            else => @compileError("`func` must be a function"),
        };
        if (fn_info.params.len == 0) @compileError("Function requires at least one parameters.");
        if (fn_info.params[0].type != Env) @compileError("The first parameters of function must be `Env`.");
        inline for (fn_info.params[1..]) |param| {
            if (param.type != Value) @compileError("The rest parameters of function must be of type `Value`.");
        }
        const num_params = fn_info.params.len - 1;

        var function: c.napi_value = undefined;
        try callNodeApi(
            self.c_handle,
            c.napi_create_function,
            .{
                name.ptr,
                name.len,
                struct {
                    fn callback(env: c.napi_env, info: c.napi_callback_info) callconv(.C) Value {
                        var argc: usize = num_params;
                        var argv: [num_params]Value = undefined;
                        callNodeApi(
                            env,
                            c.napi_get_cb_info,
                            .{ info, &argc, &argv, null, null },
                        ) catch |err| {
                            _ = c.napi_throw_error(env, null, @errorName(err));
                            return null;
                        };
                        if (argc != num_params) {
                            _ = c.napi_throw_error(env, null, std.fmt.comptimePrint("Incorrect number of arguments, expected {d}", .{num_params}));
                            return null;
                        }
                        var full_args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;
                        full_args[0] = Env{ .c_handle = env };
                        inline for (argv, 1..) |arg, i| {
                            full_args[i] = arg;
                        }
                        return if (comptime isReturnValue(fn_info))
                            @call(.auto, func, full_args)
                        else
                            @call(.auto, func, full_args) catch |err| {
                                _ = c.napi_throw_error(env, null, @errorName(err));
                                return null;
                            };
                    }
                }.callback,
                null,
                &function,
            },
        );
        return function;
    }

    pub fn setNamedProperty(self: Env, exports: Value, name: [:0]const u8, prop: Value) !void {
        try callNodeApi(
            self.c_handle,
            c.napi_set_named_property,
            .{ exports, name.ptr, prop },
        );
    }
};

/// `init_fn` is a function that will be called when the module is initialized.
/// It should have the signature `fn(env: Env, exports: Value)`
/// It can return `Value` or `!Value`.
pub fn registerModule(init_fn: anytype) void {
    const Closure = struct {
        fn init(env: c.napi_env, exports: c.napi_value) callconv(.C) Value {
            const fn_info = switch (@typeInfo(@TypeOf(init_fn))) {
                .@"fn" => |fn_info| fn_info,
                else => @compileError("`init_fn` must be a function"),
            };
            if (!(fn_info.params.len == 2 and fn_info.params[0].type == Env and fn_info.params[1].type == Value)) @compileError("`init` function requires two arguments: (Env, Value).");

            if (comptime isReturnValue(fn_info)) {
                return init_fn(Env{ .c_handle = env }, exports);
            } else if (comptime isReturnErrValue(fn_info)) {
                return init_fn(Env{ .c_handle = env }, exports) catch |e| {
                    std.log.err("Init zig-napi failed, err: {any}", .{e});
                    _ = c.napi_throw_error(env, null, @errorName(e));
                    return null;
                };
            } else {
                @compileError("`init` function must return `Value` or `!Value` type");
            }
        }
    };

    @export(&Closure.init, .{ .name = "napi_register_module_v1" });
}

fn isReturnValue(fn_info: std.builtin.Type.Fn) bool {
    if (fn_info.return_type) |ret_type| {
        return ret_type == Value;
    }

    return false;
}

fn isReturnErrValue(fn_info: std.builtin.Type.Fn) bool {
    if (fn_info.return_type) |ret_type| {
        switch (@typeInfo(ret_type)) {
            .error_union => |err_union| return err_union.payload == Value,
            else => {},
        }
    }

    return false;
}
