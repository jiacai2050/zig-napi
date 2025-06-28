const napi = @import("napi");

pub fn makeObject(env: napi.Env) !napi.Value {
    const object = try env.createObject();
    try object.setNamedProperty("str-key", try env.create([]const u8, "string prop"));
    try object.setNamedProperty("i64-key", try env.create(i64, 100));
    try object.setNamedProperty("i32-key", try env.create(i32, 200));
    try object.setNamedProperty("u32-key", try env.create(u32, 201));
    try object.setNamedProperty("f64-key", try env.create(f64, 300.0));
    try object.setNamedProperty("null-key", try env.create(void, {}));
    try object.setNamedProperty("true-key", try env.create(bool, true));
    try object.setNamedProperty("false-key", try env.create(bool, false));

    return object;
}
