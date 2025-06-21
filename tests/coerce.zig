const napi = @import("napi");

pub fn coerceStrToNumber(env: napi.Env, str: napi.Value) !napi.Value {
    _ = env;
    const coerced_num = try str.coerceTo(.Number);
    if (try coerced_num.typeOf() != .Number) {
        return error.InvalidType;
    }

    return coerced_num;
}

pub fn coerceNumberToStr(env: napi.Env, num: napi.Value) !napi.Value {
    _ = env;
    const coerced_str = try num.coerceTo(.String);
    if (try coerced_str.typeOf() != .String) {
        return error.InvalidType;
    }

    return coerced_str;
}
