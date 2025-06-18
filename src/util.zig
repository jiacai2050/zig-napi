const std = @import("std");
const Value = @import("Value.zig");

pub fn isReturnValue(fn_info: std.builtin.Type.Fn) bool {
    if (fn_info.return_type) |ret_type| {
        return ret_type == Value;
    }

    return false;
}

pub fn isReturnErrValue(fn_info: std.builtin.Type.Fn) bool {
    if (fn_info.return_type) |ret_type| {
        switch (@typeInfo(ret_type)) {
            .error_union => |err_union| return err_union.payload == Value,
            else => {},
        }
    }

    return false;
}
