const std = @import("std");
const napi = @import("napi");

fn init(env: napi.Env, exports: napi.Value) !napi.Value {
    inline for (.{
        .{ @import("basic.zig"), .{ "hello", "greeting", "add" } },
        .{ @import("array.zig"), .{ "visitArrayInScope", "makeArrayBuffer" } },
        .{ @import("object.zig"), .{"makeObject"} },
        .{ @import("coerce.zig"), .{ "coerceStrToNumber", "coerceNumberToStr" } },
    }) |definitions| {
        const Module, const decls = definitions;
        inline for (decls) |name| {
            std.log.debug("[{any}] set prop: {s}", .{ Module, name });

            try exports.setNamedProperty(
                name,
                try env.createFunction(@field(Module, name), null),
            );
        }
    }

    return exports;
}

comptime {
    napi.registerModule(init);
}
