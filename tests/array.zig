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

/// When iterates over an array, it creates a new scope for each item.
/// This is useful to ensure that the items are properly cleaned up after use, since only the most recent item is used.
pub fn visitArrayInScope(env: napi.Env, arr: napi.Value) !napi.Value {
    const len = try arr.getArrayLength();
    var sum: u32 = 0;
    for (0..len) |i| {
        const scope = try env.openScope();
        defer scope.deinit() catch |err| {
            std.log.err("Deinit scope failed, err:{any}", .{err});
        };
        const item = try arr.getElement(@intCast(i));
        sum += try item.getValue(u32);
    }
    return env.create(u32, sum);
}
