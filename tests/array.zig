const std = @import("std");
const napi = @import("napi");

pub fn makeArrayBuffer(
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

pub fn visitArrayInScope(env: napi.Env, arr: napi.Value) !napi.Value {
    const len = try arr.getArrayLength();
    var sum: u32 = 0;
    for (0..len) |i| {
        const scope = try env.openScope();
        defer scope.deinit() catch unreachable;
        const item = try arr.getElement(@intCast(i));
        sum += try item.getValue(u32);
    }
    return env.create(u32, sum);
}
