//! zig-napi - A Zig wrapper for Node.js N-API, providing a type-safe interface to create and manipulate JavaScript values.
const std = @import("std");
const c = @import("c.zig").c;
const callNodeApi = @import("c.zig").callNodeApi;
const util = @import("util.zig");
pub const Value = @import("Value.zig");

/// Env is a wrapper around the Node-API environment handle (`napi_env`).
/// It provides methods to interact with the Node-API, such as
/// - Creating JavaScript values (strings, objects, functions)
/// - Accessing global objects and primitive values (like `null`, `undefined`, and `boolean`).
/// - Managing handle scopes for memory management.
///
/// The `Env` struct is typically created by the Node.js runtime and passed to the module's initialization function.
/// It is not meant to be created directly by the user.
///
/// https://nodejs.org/api/n-api.html#napi_env
pub const Env = struct {
    c_handle: c.napi_env,

    /// Creates `Value` from a Zig type `T`.
    pub fn create(self: Env, comptime T: type, value: T) !Value {
        return try Value.createFrom(T, self, value);
    }

    /// Creates a string `Value` with given encoding and content.
    pub fn createString(
        self: Env,
        comptime encoding: Value.StringEncoding,
        str: if (encoding == .utf16) []const u16 else []const u8,
    ) !Value {
        return try Value.createString(self, encoding, str);
    }

    /// Creates an empty JavaScript object.
    pub fn createObject(
        self: Env,
    ) !Value {
        return try Value.createObject(self);
    }

    /// Creates a JavaScript function from a Zig function.
    /// The `func` argument should be a function that matches the expected signature.
    /// `fn(Env, ...args: Values) !Value` is a common signature for such functions.
    /// `void` or `!void` is also a valid return type, indicating the function does not return a value.
    /// The `name` argument is optional and can be used to set the function's name in JavaScript.
    pub fn createFunction(
        self: Env,
        func: anytype,
        comptime name: ?[]const u8,
    ) !Value {
        return try Value.createFunction(self, func, name);
    }

    /// Creates a JavaScript Error with the text provided.
    /// https://nodejs.org/api/n-api.html#napi_create_error
    pub fn createError(
        self: Env,
        code: ?Value,
        message: Value,
    ) !Value {
        var result: c.napi_value = undefined;
        try callNodeApi(
            self.c_handle,
            c.napi_create_error,
            .{ if (code) |v| v.c_handle else null, message.c_handle, &result },
        );
        return .{ .c_handle = result, .env = self };
    }

    /// Returns the `global` object.
    /// https://nodejs.org/api/n-api.html#napi_get_global
    pub fn getGlobal(env: Env) !Value {
        var result: c.napi_value = undefined;
        try callNodeApi(
            env.c_handle,
            c.napi_get_global,
            .{&result},
        );
        return .{ .c_handle = result, .env = env };
    }

    /// Returns the JavaScript singleton object that is used to represent the given boolean value.
    /// https://nodejs.org/api/n-api.html#napi_get_boolean
    pub fn getBoolean(
        env: Env,
        value: bool,
    ) !Value {
        var result: c.napi_value = undefined;
        try callNodeApi(
            env.c_handle,
            c.napi_get_boolean,
            .{ value, &result },
        );
        return .{ .c_handle = result, .env = env };
    }

    /// Returns a Node-API value corresponding to a JavaScript `null` value.
    /// https://nodejs.org/api/n-api.html#napi_get_null
    pub fn getNull(env: Env) !Value {
        var result: c.napi_value = undefined;
        try callNodeApi(
            env.c_handle,
            c.napi_get_null,
            .{&result},
        );
        return .{ .c_handle = result, .env = env };
    }

    /// Opens a new N-API handle scope. Handles created within this scope are automatically
    /// released when the scope is closed via `deinit()`. It's crucial to call `deinit()`
    /// on the returned scope, usually with `defer scope.deinit();`.
    pub fn openScope(self: Env) !scope(false) {
        return try scope(false).init(self);
    }

    /// Opens a new N-API escapable handle scope. This allows one handle created within
    /// this scope to be promoted (escaped) to the outer scope. All other handles are released
    /// when the scope is closed via `deinit()`.
    /// Note: ensure `deinit()` is called, typically with `defer`.
    pub fn openEscapeScope(self: Env) !scope(true) {
        return try scope(true).init(self);
    }

    /// Throws the JavaScript value provided.
    /// https://nodejs.org/api/n-api.html#napi_throw
    pub fn throw(
        self: Env,
        err: Value,
    ) !void {
        try callNodeApi(
            self.c_handle,
            c.napi_throw,
            .{err.c_handle},
        );
    }

    /// Throws a JavaScript Error with the text provided.
    /// https://nodejs.org/api/n-api.html#napi_throw_error
    pub fn throwError(
        self: Env,
        code: ?[:0]const u8,
        message: [:0]const u8,
    ) !void {
        try callNodeApi(
            self.c_handle,
            c.napi_throw_error,
            .{ code, message },
        );
    }
};

/// Registers a module with the Node.js runtime.
///
/// The `init_fn` will be called with the `Env` and `exports` arguments.
/// The `exports` argument is the object that will be returned from the module.
/// It can be used to create functions, objects, or other values that will be accessible from JavaScript.
/// The `init_fn` must return a `Value` or `!Value`. If it returns `!Value`, any error will be thrown as a JavaScript exception.
pub fn registerModule(init_fn: anytype) void {
    const Closure = struct {
        fn init(c_env: c.napi_env, c_exports: c.napi_value) callconv(.c) c.napi_value {
            const fn_info = switch (@typeInfo(@TypeOf(init_fn))) {
                .@"fn" => |fn_info| fn_info,
                else => @compileError("`init_fn` must be a function"),
            };
            if (!(fn_info.params.len == 2 and fn_info.params[0].type == Env and fn_info.params[1].type == Value)) @compileError("`init` function requires two arguments: (Env, Value).");

            const env = Env{ .c_handle = c_env };
            const exports = Value{ .env = env, .c_handle = c_exports };
            if (comptime util.isReturnValue(fn_info)) {
                return init_fn(env, exports).c_handle;
            } else if (comptime util.isReturnErrValue(fn_info)) {
                const ret = init_fn(env, exports) catch |e| {
                    std.log.err("Init zig-napi failed, err: {any}", .{e});
                    _ = c.napi_throw_error(c_env, null, @errorName(e));
                    return null;
                };
                return ret.c_handle;
            } else {
                @compileError("`init` function must return `Value` or `!Value` type");
            }
        }
    };

    @export(&Closure.init, .{ .name = "napi_register_module_v1" });
}

/// Scope is a context in which JavaScript values can be created and manipulated.
/// It is used to manage the lifetime of JavaScript values and ensure they are properly garbage collected.
///
/// https://nodejs.org/api/n-api.html#object-lifetime-management
fn scope(comptime escape: bool) type {
    return struct {
        env: Env,
        c_handle: if (escape) c.napi_escapable_handle_scope else c.napi_handle_scope,

        const Self = @This();

        pub fn init(env: Env) !Self {
            var self = Self{ .c_handle = undefined, .env = env };
            try callNodeApi(
                env.c_handle,
                if (escape) c.napi_open_escapable_handle_scope else c.napi_open_handle_scope,
                .{&self.c_handle},
            );

            return self;
        }

        /// This API promotes the handle to the JavaScript object so that it is valid for the lifetime of the outer scope.
        /// It can only be called once per scope. If it is called more than once an error will be returned.
        /// https://nodejs.org/api/n-api.html#napi_escape_handle
        pub fn escapeHandle(self: Self, value: Value) !Value {
            if (!escape) @compileError("Cannot escape value in a non-escapable handle scope");

            var result: c.napi_value = undefined;
            try callNodeApi(
                self.env.c_handle,
                c.napi_escape_handle,
                .{ self.c_handle, value.c_handle, &result },
            );
            return .{ .c_handle = result, .env = self.env };
        }

        pub fn deinit(self: Self) !void {
            try callNodeApi(
                self.env.c_handle,
                if (escape) c.napi_close_escapable_handle_scope else c.napi_close_handle_scope,
                .{self.c_handle},
            );
        }
    };
}
