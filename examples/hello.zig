const std = @import("std");
const napi = @import("napi");

// Every napi module needs to call `registerModule` to register it with the N-API runtime.
comptime {
    napi.registerModule(init);
}

fn hello(e: napi.Env, who: napi.Value) !napi.Value {
    var buf: [64]u8 = undefined;
    const len = try who.getValueString(.utf8, &buf);
    const allocator = std.heap.page_allocator;
    const message = try std.fmt.allocPrint(allocator, "Hello {s}", .{buf[0..len]});
    defer allocator.free(message);

    return try e.createString(.utf8, message);
}

fn init(env: napi.Env, exports: napi.Value) !napi.Value {
    try exports.setNamedProperty(
        "hello",
        try env.createFunction(hello, null),
    );

    return exports;
}
