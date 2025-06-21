const napi = @import("napi");

pub fn makeObject(env: napi.Env) !napi.Value {
    const object = try env.createObject();
    try object.setNamedProperty("str-key", try env.createString(.utf8, "string prop"));
    try object.setNamedProperty("i64-key", try env.create(i64, 100));
    try object.setNamedProperty("u64-key", try env.create(i64, 101));
    try object.setNamedProperty("i32-key", try env.create(i64, 200));
    try object.setNamedProperty("u32-key", try env.create(i64, 201));
    try object.setNamedProperty("f64-key", try env.create(i64, 300));

    return object;
}
