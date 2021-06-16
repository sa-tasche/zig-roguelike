// Originally ripped out of:
// https://github.com/fengb/zigbot9001, main.zig

const std = @import("std");
const mem = std.mem;

pub fn StackBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        data: [capacity]T = undefined,
        len: usize = 0,
        capacity: usize = capacity,

        const Self = @This();

        pub fn init(data: ?[]const T) Self {
            if (data) |d| {
                var b: Self = .{ .len = d.len };
                mem.copy(T, &b.data, d);
                return b;
            } else {
                return .{};
            }
        }

        pub fn slice(self: *Self) []T {
            return self.data[0..self.len];
        }

        pub fn constSlice(self: *const Self) []const T {
            return self.data[0..self.len];
        }

        pub fn orderedRemove(self: *Self, index: usize) !T {
            if (self.len == 0 or index >= self.len) {
                return error.IndexOutOfRange;
            }

            const newlen = self.len - 1;
            if (newlen == index) {
                return try self.pop();
            }

            const item = self.data[index];
            for (self.data[index..newlen]) |*data, j|
                data.* = self.data[index + 1 + j];
            self.len = newlen;
            return item;
        }

        pub fn pop(self: *Self) !T {
            if (self.len == 0) return error.IndexOutOfRange;
            self.len -= 1;
            return self.data[self.len];
        }

        pub fn append(self: *Self, item: T) !void {
            if (self.len >= capacity) {
                return error.NoSpaceLeft;
            }

            self.data[self.len] = item;
            self.len += 1;
        }
    };
}
