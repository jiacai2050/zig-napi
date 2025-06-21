const std = @import("std");
const c = @import("c.zig").c;
const callNodeApi = @import("c.zig").callNodeApi;
pub const Value = @import("Value.zig");
const util = @import("util.zig");

/// Env is a wrapper around the Node-API environment handle (`napi_env`).
/// It provides methods to interact with the Node-API, such as type conversions between Zig and JavaScript values.
/// It is used to create and manage JavaScript values, objects, and functions.
/// The `Env` struct is typically created by the Node.js runtime and passed to the module's initialization function.
/// It is not meant to be created directly by the user.
///
/// https://nodejs.org/api/n-api.html#napi_env
pub const Env = struct {
    c_handle: c.napi_env,

    pub fn create(self: Env, comptime T: type, value: T) !Value {
        return try Value.createFrom(T, self, value);
    }

    pub fn createString(
        self: Env,
        comptime encoding: Value.StringEncoding,
        str: if (encoding == .utf16) []const u16 else []const u8,
    ) !Value {
        return try Value.createString(self, encoding, str);
    }

    pub fn createObject(
        self: Env,
    ) !Value {
        return try Value.createObject(self);
    }

    pub fn createFunction(
        self: Env,
        func: anytype,
        comptime name: ?[]const u8,
    ) !Value {
        return try Value.createFunction(self, func, name);
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
    /// when the scope is closed via `deinit()`. Ensure `deinit()` is called, typically with `defer`.
    pub fn openEscapeScope(self: Env) !scope(true) {
        return try scope(true).init(self);
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
        fn init(c_env: c.napi_env, c_exports: c.napi_value) callconv(.C) c.napi_value {
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

        pub fn deinit(self: Self) !void {
            try callNodeApi(
                self.env.c_handle,
                if (escape) c.napi_close_escapable_handle_scope else c.napi_close_handle_scope,
                .{self.c_handle},
            );
        }
    };
}
