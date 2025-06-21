const std = @import("std");
const napi = @import("napi");

comptime {
    napi.registerModule(init);
}

fn arraybuffer_demo(
    env: napi.Env,
    str: napi.Value,
) !napi.Value {
    var buffer: [64]u8 = undefined;
    const len = try str.getValueString(.utf8, &buffer);
    var data: [*]u8 = undefined;
    const array_buffer = try napi.Value.createArrayBuffer(env, len, @ptrCast(&data));
    // Fill the array buffer with the given string data
    const slice = data[0..len];
    std.mem.copyForwards(u8, slice, buffer[0..len]);

    return array_buffer;
}

pub fn init(env: napi.Env, exports: napi.Value) !napi.Value {
    try exports.setNamedProperty(
        "arraybuffer_demo",
        try env.createFunction(arraybuffer_demo, null),
    );

    return exports;
}
