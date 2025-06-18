//! `Value` is a wrapper around the Node-API environment handle (`napi_value`).
//! It provides methods to interact with the Node-API, such as type conversions between Zig and JavaScript values.

const std = @import("std");
const c = @import("c.zig").c;
const callNodeApi = @import("c.zig").callNodeApi;
const Env = @import("root.zig").Env;
const util = @import("util.zig");

c_handle: c.napi_value,
env: Env,

const Self = @This();

/// default represents  `undefined` object in JavaScript.
pub const default = Self{
    .c_handle = null,
    .env = Env{ .c_handle = null },
};

pub fn try_from(comptime T: type, env: Env, value: T) !Self {
    var result: c.napi_value = undefined;
    switch (T) {
        f64, i64, u64, u32, i32 => try callNodeApi(
            env.c_handle,
            switch (T) {
                f64 => c.napi_create_double,
                i64 => c.napi_create_int64,
                u64 => c.napi_create_uint64,
                u32 => c.napi_create_uint32,
                i32 => c.napi_create_int32,
                else => @compileError("Unsupported numeric type for conversion to napi_value"),
            },
            .{ value, &result },
        ),
        void => return try getNull(env),
        []const u8 => return try createString(env, value, .utf8),
        []const u16 => return try createString(env, value, .utf16),
        c.napi_value => return Self{ .c_handle = value, .env = env },
        else => @compileError("Unsupported type for conversion to napi_value"),
    }

    return Self{ .c_handle = result, .env = env };
}

pub fn getGlobal(env: Env) !Self {
    var result: c.napi_value = undefined;
    try callNodeApi(
        env.c_handle,
        c.napi_get_global,
        .{&result},
    );
    return Self{ .c_handle = result, .env = env };
}

pub fn getNull(env: Env) !Self {
    var result: c.napi_value = undefined;
    try callNodeApi(
        env.c_handle,
        c.napi_get_null,
        .{&result},
    );
    return Self{ .c_handle = result, .env = env };
}

pub const StringEncoding = enum {
    utf8,
    latin1,
    utf16,
};

pub fn createString(
    env: Env,
    comptime encoding: StringEncoding,
    str: if (encoding == .utf16) []const u16 else []const u8,
) !Self {
    var result: c.napi_value = undefined;
    try callNodeApi(
        env.c_handle,
        switch (encoding) {
            .utf8 => c.napi_create_string_utf8,
            .latin1 => c.napi_create_string_latin1,
            .utf16 => c.napi_create_string_utf16,
        },
        .{ str.ptr, str.len, &result },
    );
    return Self{ .c_handle = result, .env = env };
}

pub fn createObject(env: Env) !Self {
    var result: c.napi_value = undefined;
    try callNodeApi(
        env.c_handle,
        c.napi_create_object,
        .{&result},
    );
    return Self{ .c_handle = result, .env = env };
}

pub fn createFunction(env: Env, func: anytype, comptime name: ?[]const u8) !Self {
    const fn_info = switch (@typeInfo(@TypeOf(func))) {
        .@"fn" => |fn_info| fn_info,
        else => @compileError("`func` must be a function"),
    };
    if (fn_info.params.len == 0) @compileError("Function requires at least one parameter.");
    if (fn_info.params[0].type != Env) @compileError("The first parameter of function must be `Env`.");
    inline for (fn_info.params[1..]) |param| {
        if (param.type != Self) @compileError("The rest parameters of function must be of type `Value`.");
    }
    const num_params = fn_info.params.len - 1;

    var function: c.napi_value = undefined;
    try callNodeApi(
        env.c_handle,
        c.napi_create_function,
        .{
            if (name) |n| n.ptr else null,
            if (name) |n| n.len else 0,
            struct {
                fn callback(c_env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
                    var argc: usize = num_params;
                    var argv: [num_params]c.napi_value = undefined;
                    callNodeApi(
                        c_env,
                        c.napi_get_cb_info,
                        .{ info, &argc, &argv, null, null },
                    ) catch |err| {
                        _ = c.napi_throw_error(c_env, null, @errorName(err));
                        return null;
                    };
                    if (argc != num_params) {
                        _ = c.napi_throw_error(c_env, null, std.fmt.comptimePrint("Incorrect number of arguments, expected {d}", .{num_params}));
                        return null;
                    }
                    var full_args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;
                    full_args[0] = Env{ .c_handle = c_env };
                    inline for (argv, 1..) |arg, i| {
                        full_args[i] = Self{ .env = full_args[0], .c_handle = arg };
                    }
                    if (comptime util.isReturnValue(fn_info))
                        return @call(.auto, func, full_args).c_handle;
                    const ret =
                        @call(.auto, func, full_args) catch |err| {
                            _ = c.napi_throw_error(c_env, null, @errorName(err));
                            return null;
                        };
                    return ret.c_handle;
                }
            }.callback,
            null,
            &function,
        },
    );
    return Self{ .c_handle = function, .env = env };
}

/// Convert Value to primitive Zig types.
pub fn getValue(self: Self, comptime T: type) !T {
    if (self.c_handle == null) {
        // Trying to get a concrete Zig type from JavaScript 'undefined'.
        // This should be an error, as 'undefined' cannot be converted to a concrete type.
        return error.getValueOnUndefinedValue;
    }
    var result: T = undefined;
    switch (T) {
        f64, i64, u32, i32, bool => try callNodeApi(
            self.env.c_handle,
            switch (T) {
                f64 => c.napi_get_value_double,
                i64 => c.napi_get_value_int64,
                u32 => c.napi_get_value_uint32,
                i32 => c.napi_get_value_int32,
                bool => c.napi_get_value_bool,
                else => @compileError("Unsupported numeric type for conversion to napi_value"),
            },
            .{ self.c_handle, &result },
        ),
        else => @compileError("Unsupported type for conversion to zig value"),
    }

    return result;
}

pub fn getValueString(
    self: Self,
    comptime encoding: StringEncoding,
    out_str: if (encoding == .utf16) []u16 else []u8,
) !usize {
    // Number of bytes copied into the buffer, excluding the null terminator.
    var len: usize = 0;
    try callNodeApi(
        self.env.c_handle,
        switch (encoding) {
            .utf8 => c.napi_get_value_string_utf8,
            .latin1 => c.napi_get_value_string_latin1,
            .utf16 => c.napi_get_value_string_utf16,
        },
        .{ self.c_handle, out_str.ptr, out_str.len, &len },
    );
    return len;
}
