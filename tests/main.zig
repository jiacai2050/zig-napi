const std = @import("std");
const napi = @import("napi");

const Input = union(enum) {
    basic: []const [:0]const u8,
    array: []const [:0]const u8,
    object: []const [:0]const u8,

    fn definitions(self: Input) []const [:0]const u8 {
        return switch (self) {
            .basic => |defs| defs,
            .array => |defs| defs,
            .object => |defs| defs,
        };
    }

    fn Module(self: Input) type {
        return switch (self) {
            .basic => @import("basic.zig"),
            .array => @import("array.zig"),
            .object => @import("object.zig"),
        };
    }
};

fn init(env: napi.Env, exports: napi.Value) !napi.Value {
    inline for (.{
        Input{ .basic = &.{ "hello", "greeting", "add" } },
        Input{ .array = &.{ "visitArrayInScope", "makeArrayBuffer" } },
        Input{ .object = &.{"makeObject"} },
    }) |input| {
        const mod = comptime input.Module();
        inline for (comptime input.definitions()) |name| {
            std.log.debug("[{any}] set prop: {s}", .{ mod, name });

            try exports.setNamedProperty(
                name,
                try env.createFunction(@field(mod, name), null),
            );
        }
    }

    return exports;
}

comptime {
    napi.registerModule(init);
}
