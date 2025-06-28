const napi = @import("napi");
const std = @import("std");

pub fn callAddTwoNumbers(env: napi.Env, num: napi.Value) !napi.Value {
    const global = try env.getGlobal();
    const add_two = try global.getNamedProperty("AddTwo");
    const args = [_]napi.Value{num};
    return add_two.callFunction(args.len, global, args);
}

comptime {
    napi.registerModule(init);
}

fn init(env: napi.Env, exports: napi.Value) !napi.Value {
    try exports.setNamedProperty(
        "callAddTwoNumbers",
        try env.createFunction(callAddTwoNumbers, null),
    );

    return exports;
}
