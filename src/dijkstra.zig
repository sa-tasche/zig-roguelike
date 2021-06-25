// FIXME: next() should never return starting coord

const std = @import("std");
const mem = std.mem;

usingnamespace @import("types.zig");
const state = @import("state.zig");

const Node = struct {
    c: Coord,
    n: usize,
};
const NodeArrayList = std.ArrayList(Node);

fn coordInList(coord: Coord, list: *NodeArrayList) ?usize {
    for (list.items) |item, index| if (coord.eq(item.c)) return index;
    return null;
}

pub const Dijkstra = struct {
    center: Coord,
    current: Node,
    max: usize,
    limit: Coord,
    is_valid: fn (Coord, state.IsWalkableOptions) bool,
    is_valid_opts: state.IsWalkableOptions,
    open: NodeArrayList,
    closed: NodeArrayList,

    const Self = @This();

    pub fn init(
        start: Coord,
        limit: Coord,
        max_distance: usize,
        is_valid: fn (Coord, state.IsWalkableOptions) bool,
        is_valid_opts: state.IsWalkableOptions,
        allocator: *mem.Allocator,
    ) Self {
        const n = Node{ .c = start, .n = 0 };
        var s = Self{
            .center = start,
            .current = n,
            .max = max_distance,
            .limit = limit,
            .is_valid = is_valid,
            .is_valid_opts = is_valid_opts,
            .open = NodeArrayList.init(allocator),
            .closed = NodeArrayList.init(allocator),
        };
        s.open.append(n) catch unreachable;
        return s;
    }

    pub fn deinit(self: *Self) void {
        self.open.deinit();
        self.closed.deinit();
    }

    pub fn next(self: *Self) ?Coord {
        if (self.open.items.len == 0) {
            return null;
        }

        self.closed.append(self.current) catch unreachable;

        for (&DIRECTIONS) |neighbor| {
            var coord = self.current;
            if (!coord.c.move(neighbor, self.limit)) continue;
            coord.n += 1;

            if (coord.n > self.max) continue;
            if (!self.is_valid(coord.c, self.is_valid_opts)) continue;
            if (coordInList(coord.c, &self.closed)) |_| continue;
            if (coordInList(coord.c, &self.open)) |_| continue;

            self.open.append(coord) catch unreachable;
        }

        if (self.open.items.len == 0) {
            return null;
        } else {
            self.current = self.open.orderedRemove(0);
            return self.current.c;
        }
    }
};
