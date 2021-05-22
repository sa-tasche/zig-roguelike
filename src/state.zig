const std = @import("std");
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;

const astar = @import("astar.zig");
const utils = @import("utils.zig");
const gas = @import("gas.zig");
const rng = @import("rng.zig");
const fov = @import("fov.zig");
usingnamespace @import("types.zig");

pub const mapgeometry = Coord.new(WIDTH, HEIGHT);
pub var dungeon: Dungeon = .{};
pub var mobs: MobList = undefined;
pub var machines: MachineList = undefined;
pub var props: PropList = undefined;
pub var player: *Mob = undefined;
pub var ticks: usize = 0;
pub var messages: MessageArrayList = undefined;
pub var score: usize = 0;

// STYLE: change to Tile.soundOpacity
pub fn tile_sound_opacity(coord: Coord) f64 {
    return if (dungeon.at(coord).type == .Wall) 0.4 else 0.2;
}

// STYLE: change to Tile.opacity
fn tile_opacity(coord: Coord) f64 {
    const tile = dungeon.at(coord);
    if (tile.type == .Wall) return 1.0;

    var o: f64 = 0.0;
    if (tile.surface) |surface| {
        switch (surface) {
            .Machine => |m| o += m.opacity,
            else => {},
        }
    }

    const gases = dungeon.atGas(coord);
    for (gases) |q, g| {
        if (q > 0) o += gas.Gases[g].opacity;
    }

    return o;
}

// STYLE: change to Tile.isWalkable
pub fn is_walkable(coord: Coord) bool {
    if (dungeon.at(coord).type == .Wall)
        return false;
    if (dungeon.at(coord).mob != null)
        return false;
    if (dungeon.at(coord).surface) |surface| {
        switch (surface) {
            .Machine => |m| if (m.should_be_avoided) return true,
            else => {},
        }
    }
    return true;
}

// TODO: get rid of this
pub fn createMobList(include_player: bool, only_if_infov: bool, level: usize, alloc: *mem.Allocator) MobArrayList {
    var moblist = std.ArrayList(*Mob).init(alloc);
    var y: usize = 0;
    while (y < HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < WIDTH) : (x += 1) {
            const coord = Coord.new(x, y);

            if (!include_player and coord.eq(player.coord))
                continue;

            if (dungeon.at(Coord.new2(level, x, y)).mob) |mob| {
                if (only_if_infov and !player.cansee(coord))
                    continue;

                moblist.append(mob) catch unreachable;
            }
        }
    }
    return moblist;
}

fn _update_fov(mob: *Mob) void {
    const all_octants = [_]?usize{ 0, 1, 2, 3, 4, 5, 6, 7 };

    mob.fov.shrinkRetainingCapacity(0);
    const apparent_vision = if (mob.facing_wide) mob.vision / 2 else mob.vision;

    if (mob.coord.eq(player.coord)) {
        fov.shadowcast(player.coord, all_octants, mob.vision, mapgeometry, tile_opacity, &mob.fov);
    } else {
        const octants = fov.octants(mob.facing, mob.facing_wide);
        fov.shadowcast(mob.coord, octants, apparent_vision, mapgeometry, tile_opacity, &mob.fov);
    }

    for (mob.fov.items) |fc| {
        var tile: u21 = if (dungeon.at(fc).type == .Wall) '▓' else ' ';
        if (dungeon.at(fc).mob) |tilemob| {
            if (!tilemob.is_dead) {
                tile = tilemob.tile;
            }
        }

        mob.memory.put(fc, tile) catch unreachable;
    }
}

fn _can_hear_hostile(mob: *Mob, moblist: *const MobArrayList) ?Coord {
    for (moblist.items) |othermob| {
        if (mob.canHear(othermob.coord)) |sound| {
            if (mob.isHostileTo(othermob)) {
                return othermob.coord;
            } else if (sound > 20) {
                // Sounds like one of our friends is having quite a party, let's
                // go join the fun~
                return othermob.coord;
            }
        }
    }

    return null;
}

fn _can_see_hostile(mob: *Mob) ?Coord {
    for (mob.fov.items) |fitem| {
        if (dungeon.at(fitem).mob) |othermob| {
            if (othermob.allegiance != mob.allegiance and !othermob.is_dead) {
                return fitem;
            }
        }
    }
    return null;
}

fn _mob_occupation_tick(mob: *Mob, moblist: *const MobArrayList, alloc: *mem.Allocator) void {
    if (mob.occupation.phase != .SawHostile) {
        if (_can_see_hostile(mob)) |hostile| {
            mob.noise += Mob.NOISE_YELL;
            mob.occupation.phase = .SawHostile;
            mob.occupation.target = hostile;
        } else if (_can_hear_hostile(mob, moblist)) |dest| {
            // Let's investigate
            mob.occupation.phase = .GoTo;
            mob.occupation.target = dest;
        }
    }

    if (mob.occupation.phase == .Work) {
        mob.occupation.work_fn(mob, alloc);
        return;
    }

    if (mob.occupation.phase == .GoTo) {
        const target_coord = mob.occupation.target.?;

        if (mob.coord.eq(target_coord)) {
            // We're here, let's just look around a bit before leaving
            //
            // 1 in 8 chance of leaving every turn
            if (rng.int(u3) == 0) {
                mob.facing_wide = false;
                mob.occupation.target = null;
                mob.occupation.phase = .Work;
            } else {
                mob.facing_wide = true;
                mob.facing = rng.choose(Direction, &CARDINAL_DIRECTIONS, &[_]usize{ 1, 1, 1, 1 }) catch unreachable;
            }
        } else {
            if (astar.nextDirectionTo(mob.coord, target_coord, mapgeometry, is_walkable)) |d| {
                _ = mob.moveInDirection(d);
            }
        }
    }

    if (mob.occupation.phase == .SawHostile and mob.occupation.is_combative) {
        const target_coord = mob.occupation.target.?;

        if (dungeon.at(target_coord).mob == null) {
            mob.occupation.phase = .GoTo;
            _mob_occupation_tick(mob, moblist, alloc);
        }

        if (mob.coord.eq(target_coord)) {
            mob.occupation.target = null;
            mob.occupation.phase = .Work;
            return;
        }

        if (astar.nextDirectionTo(mob.coord, target_coord, mapgeometry, is_walkable)) |d| {
            _ = mob.moveInDirection(d);
        }
    }
}

pub fn tick(alloc: *mem.Allocator) void {
    ticks += 1;

    const cur_level = player.coord.z;

    const moblist = createMobList(true, false, cur_level, alloc);
    defer moblist.deinit();

    for (moblist.items) |mob| {
        if (mob.is_dead) {
            continue;
        } else if (mob.should_be_dead()) {
            mob.kill();
            continue;
        }

        mob.tick_hp();
        mob.tick_pain();
        mob.tick_noise();
        _update_fov(mob);

        if (!mob.coord.eq(player.coord)) {
            _mob_occupation_tick(mob, &moblist, alloc);
        }

        _update_fov(mob);
    }
}

pub fn tickAtmosphere(cur_gas: usize) void {
    const dissipation = gas.Gases[cur_gas].dissipation_rate;
    const cur_lev = player.coord.z;
    var new: [HEIGHT][WIDTH]f64 = undefined;
    {
        var y: usize = 0;
        while (y < HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < WIDTH) : (x += 1) {
                const coord = Coord.new2(cur_lev, x, y);

                if (dungeon.at(coord).type == .Wall)
                    continue;

                var avg: f64 = dungeon.atGas(coord)[cur_gas];
                var neighbors: f64 = 1;
                for (&DIRECTIONS) |d, i| {
                    var n = coord;
                    if (!n.move(d, mapgeometry)) continue;

                    if (dungeon.at(n).type == .Wall)
                        continue;

                    if (dungeon.atGas(n)[cur_gas] == 0)
                        continue;

                    avg += dungeon.atGas(n)[cur_gas] - dissipation;
                    neighbors += 1;
                }

                avg /= neighbors;
                avg = math.max(avg, 0);

                new[y][x] = avg;
            }
        }
    }

    {
        var y: usize = 0;
        while (y < HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < WIDTH) : (x += 1)
                dungeon.atGas(Coord.new2(cur_lev, x, y))[cur_gas] = new[y][x];
        }
    }

    if (cur_gas < (gas.GAS_NUM - 1))
        tickAtmosphere(cur_gas + 1);
}

pub fn freeall() void {
    var iter = mobs.iterator();
    while (iter.next()) |*mob| {
        if (mob.is_dead) continue;
        mob.kill();
    }
}

pub fn reset_marks() void {
    var z: usize = 0;
    while (z < LEVELS) : (z += 1) {
        var y: usize = 0;
        while (y < HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < WIDTH) : (x += 1) {
                dungeon.at(Coord.new2(z, x, y)).marked = false;
            }
        }
    }
}

pub fn message(mtype: MessageType, comptime fmt: []const u8, args: anytype) void {
    var buf: [128]u8 = undefined;
    for (buf) |*i| i.* = 0;
    var fbs = std.io.fixedBufferStream(&buf);
    std.fmt.format(fbs.writer(), fmt, args) catch |_| @panic("format error");
    const str = fbs.getWritten();
    messages.append(.{ .msg = buf, .type = mtype }) catch @panic("OOM");
}
