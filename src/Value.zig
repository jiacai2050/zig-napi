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

/// Creates a Node-API value from a primitive Zig type.
pub fn createFrom(comptime T: type, env: Env, value: T) !Self {
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

/// Creates a Node-API value corresponding to a JavaScript `global` value.
/// This is the global object in Node.js, which is equivalent to `globalThis` in modern JavaScript.
/// https://nodejs.org/api/n-api.html#napi_get_global
pub fn getGlobal(env: Env) !Self {
    var result: c.napi_value = undefined;
    try callNodeApi(
        env.c_handle,
        c.napi_get_global,
        .{&result},
    );
    return Self{ .c_handle = result, .env = env };
}

/// Creates a Node-API value corresponding to a JavaScript `null` value.
/// https://nodejs.org/api/n-api.html#napi_get_null
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

/// Creates a Node-API value corresponding to a JavaScript string.
/// The `encoding` parameter specifies the encoding of the string.
/// Supported encodings are `utf8`, `latin1`, and `utf16`.
///
/// https://nodejs.org/api/n-api.html#napi_create_string_utf8
/// https://nodejs.org/api/n-api.html#napi_create_string_utf16
/// https://nodejs.org/api/n-api.html#napi_create_string_latin1
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

/// Creates a Node-API value corresponding to a JavaScript Array with an optional length.
/// However, the underlying buffer is not guaranteed to be pre-allocated by the VM when the array is created.
/// That behavior is left to the underlying VM implementation.
/// If the buffer must be a contiguous block of memory that can be directly read and/or written via C, consider using `createExternalArraybuffer`.
///
/// https://nodejs.org/api/n-api.html#napi_create_array
/// https://nodejs.org/api/n-api.html#napi_create_array_with_length
pub fn createArray(env: Env, len: ?usize) !Self {
    var result: c.napi_value = undefined;
    if (len) |l| {
        try callNodeApi(
            env.c_handle,
            c.napi_create_array_with_length,
            .{ l, &result },
        );
    } else {
        try callNodeApi(
            env.c_handle,
            c.napi_create_array,
            .{&result},
        );
    }
    return Self{ .c_handle = result, .env = env };
}

/// Creates a Node-API value corresponding to a JavaScript ArrayBuffer.
/// https://nodejs.org/api/n-api.html#napi_create_arraybuffer
pub fn createArrayBuffer(
    env: Env,
    len: usize,
    out_data: ?*?*anyopaque,
) !Self {
    var result: c.napi_value = undefined;
    try callNodeApi(
        env.c_handle,
        c.napi_create_arraybuffer,
        .{ len, out_data, &result },
    );
    return Self{ .c_handle = result, .env = env };
}

/// Creates a Node-API value corresponding to a JavaScript Date object.
/// The `time` parameter is a timestamp in milliseconds since the epoch (January 1, 1970).
/// https://nodejs.org/api/n-api.html#napi_create_date
pub fn createDate(
    env: Env,
    time: f64,
) !Self {
    var result: c.napi_value = undefined;
    try callNodeApi(
        env.c_handle,
        c.napi_create_date,
        .{ time, &result },
    );
    return Self{ .c_handle = result, .env = env };
}

/// Creates a Node-API function that can be called from JavaScript.
/// The `func` parameter is a Zig function that takes an `Env` as the first argument, then any number of `Value` arguments.
/// The function can return a `Value`, `!Value`, `void`, or `!void`.
/// The `name` parameter is an optional name for the function, which can be used for debugging purposes.
///
/// https://nodejs.org/api/n-api.html#napi_create_function
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
                    const res = @call(.auto, func, full_args);
                    if (comptime (fn_info.return_type == null or fn_info.return_type == void))
                        return null;
                    if (comptime util.isReturnValue(fn_info))
                        return res.c_handle;
                    if (comptime (util.isReturnErrValue(fn_info) or util.isReturnErrVoid(fn_info))) {
                        const res_without_err =
                            res catch |err| {
                                _ = c.napi_throw_error(c_env, null, @errorName(err));
                                return null;
                            };
                        return if (comptime util.isReturnErrValue(fn_info)) res_without_err.c_handle else null;
                    } else {
                        @compileError("Function must return `Value`, `!Value`, `void` or `!void` type");
                    }
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

/// Describes the type of a `c.napi_value`
/// https://nodejs.org/api/n-api.html#napi_valuetype
const NAPIValueType = enum {
    Undefined,
    Null,
    Boolean,
    Number,
    String,
    Symbol,
    Object,
    Function,
    External,
    BigInt,
};

pub fn coerceTo(
    self: Self,
    comptime value_type: NAPIValueType,
) !Self {
    var result: c.napi_value = undefined;
    try callNodeApi(
        self.env.c_handle,
        switch (value_type) {
            .Boolean => c.napi_coerce_to_bool,
            .Number => c.napi_coerce_to_number,
            .String => c.napi_coerce_to_string,
            .Object => c.napi_coerce_to_object,
            else => @compileError("Unsupported JavaScript type for coercion"),
        },
        .{ self.c_handle, &result },
    );

    return Self{ .c_handle = result, .env = self.env };
}

pub fn typeOf(self: Self) !NAPIValueType {
    var result: c.napi_valuetype = undefined;
    try callNodeApi(
        self.env.c_handle,
        c.napi_typeof,
        .{ self.c_handle, &result },
    );

    return switch (result) {
        c.napi_undefined => NAPIValueType.Undefined,
        c.napi_null => NAPIValueType.Null,
        c.napi_boolean => NAPIValueType.Boolean,
        c.napi_number => NAPIValueType.Number,
        c.napi_string => NAPIValueType.String,
        c.napi_symbol => NAPIValueType.Symbol,
        c.napi_object => NAPIValueType.Object,
        c.napi_function => NAPIValueType.Function,
        c.napi_external => NAPIValueType.External,
        c.napi_bigint => NAPIValueType.BigInt,
        else => @compileError("Unknown napi_valuetype"),
    };
}

pub fn isArray(self: Self) !bool {
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_is_array,
        .{ self.c_handle, &result },
    );
    return result;
}

pub fn isArrayBuffer(self: Self) !bool {
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_is_arraybuffer,
        .{ self.c_handle, &result },
    );
    return result;
}

pub fn isBuffer(self: Self) !bool {
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_is_buffer,
        .{ self.c_handle, &result },
    );
    return result;
}

pub fn isDate(self: Self) !bool {
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_is_date,
        .{ self.c_handle, &result },
    );
    return result;
}

pub fn isError(self: Self) !bool {
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_is_error,
        .{ self.c_handle, &result },
    );
    return result;
}

pub fn isTypedArray(self: Self) !bool {
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_is_typedarray,
        .{ self.c_handle, &result },
    );
    return result;
}

pub fn isDataView(self: Self) !bool {
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_is_dataview,
        .{ self.c_handle, &result },
    );
    return result;
}

pub fn strictEquals(self: Self, other: Self) !bool {
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_strict_equals,
        .{ self.c_handle, other.c_handle, &result },
    );
    return result;
}

// APIs below are used to get and set properties on JavaScript objects.

/// This API set a property on the Object passed in.
/// The `object` must be a JavaScript object, and `name` is the name of the property.
/// https://nodejs.org/api/n-api.html#napi_set_named_property
pub fn setNamedProperty(self: Self, name: [:0]const u8, prop: Self) !void {
    try callNodeApi(
        self.env.c_handle,
        c.napi_set_named_property,
        .{ self.c_handle, name.ptr, prop.c_handle },
    );
}

/// This API gets a property from the Object passed in.
/// The `object` must be a JavaScript object, and `name` is the name of the property.
/// https://nodejs.org/api/n-api.html#napi_get_named_property
pub fn getNamedProperty(self: Self, name: [:0]const u8) !Self {
    var result: c.napi_value = undefined;
    try callNodeApi(
        self.env.c_handle,
        c.napi_get_named_property,
        .{ self.c_handle, name.ptr, &result },
    );
    return Self{ .c_handle = result, .env = self.env };
}

/// This API checks if the Object passed in has a property with the given name.
/// The `object` must be a JavaScript object, and `name` is the name of the property.
/// https://nodejs.org/api/n-api.html#napi_has_named_property
pub fn hasNamedProperty(self: Self, name: [:0]const u8) !bool {
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_has_named_property,
        .{ self.c_handle, name.ptr, &result },
    );
    return result;
}

/// This API deletes a property from the Object passed in.
/// The `object` must be a JavaScript object, and `name` is the name of the property.
/// https://nodejs.org/api/n-api.html#napi_delete_property
pub fn deleteNamedProperty(
    self: Self,
    name: [:0]const u8,
) !bool {
    const obj_key = try Self.createString(self.env, .utf8, name);
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_delete_property,
        .{ self.c_handle, obj_key.c_handle, &result },
    );
    return result;
}

/// This API checks if the Object passed in has its own property with the given name.
pub fn hasOwnProperty(
    self: Self,
    name: [:0]const u8,
) !bool {
    const obj_key = try Self.createString(self.env, .utf8, name);
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_has_own_property,
        .{ self.c_handle, obj_key.c_handle, &result },
    );
    return result;
}

/// This API sets an element on the Object passed in.
/// The `object` must be a JavaScript object, and `index` is the numeric index of the property.
/// https://nodejs.org/api/n-api.html#napi_set_element
pub fn setElement(
    self: Self,
    index: u32,
    prop: Self,
) !void {
    try callNodeApi(
        self.env.c_handle,
        c.napi_set_element,
        .{ self.c_handle, index, prop.c_handle },
    );
}

/// This API gets an element from the Object passed in.
/// The `object` must be a JavaScript object, and `index` is the numeric index of the property.
pub fn getElement(
    self: Self,
    index: u32,
) !Self {
    var result: c.napi_value = undefined;
    try callNodeApi(
        self.env.c_handle,
        c.napi_get_element,
        .{ self.c_handle, index, &result },
    );
    return Self{ .c_handle = result, .env = self.env };
}

/// This API checks if the Object passed in has an element at the given index.
/// The `object` must be a JavaScript object, and `index` is the numeric index of the property.
/// https://nodejs.org/api/n-api.html#napi_has_element
pub fn hasElement(
    self: Self,
    index: u32,
) !bool {
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_has_element,
        .{ self.c_handle, index, &result },
    );
    return result;
}

/// This API deletes an element from the Object passed in.
/// The `object` must be a JavaScript object, and `index` is the numeric index of the property.
/// https://nodejs.org/api/n-api.html#napi_delete_element
pub fn deleteElement(
    self: Self,
    index: u32,
) !bool {
    var result: bool = false;
    try callNodeApi(
        self.env.c_handle,
        c.napi_delete_element,
        .{ self.c_handle, index, &result },
    );
    return result;
}

/// This method freezes a given object.
/// This prevents new properties from being added to it, existing properties from being removed,
/// prevents changing the enumerability, configurability, or writability of existing properties,
/// and prevents the values of existing properties from being changed.
/// It also prevents the object's prototype from being changed.
/// https://nodejs.org/api/n-api.html#napi_object_freeze
pub fn objectFreeze(self: Self) !void {
    try callNodeApi(
        self.env.c_handle,
        c.napi_object_freeze,
        .{self.c_handle},
    );
}

/// This method seals a given object.
/// This prevents new properties from being added to it, as well as marking all existing properties as non-configurable.
/// https://nodejs.org/api/n-api.html#napi_object_seal
pub fn objectSeal(self: Self) !void {
    try callNodeApi(
        self.env.c_handle,
        c.napi_object_seal,
        .{self.c_handle},
    );
}

// APIs below are used to get and set properties on JavaScript arrays.

/// This API gets an element on the Array passed in.
/// https://nodejs.org/api/n-api.html#napi_get_array_length
pub fn getArrayLength(self: Self) !u32 {
    var result: u32 = 0;
    try callNodeApi(
        self.env.c_handle,
        c.napi_get_array_length,
        .{ self.c_handle, &result },
    );
    return result;
}
