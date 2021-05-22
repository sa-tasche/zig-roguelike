const std = @import("std");

const rng = @import("rng.zig");
const astar = @import("astar.zig");
const mapgen = @import("mapgen.zig");
const display = @import("display.zig");
const termbox = @import("termbox.zig");
const types = @import("types.zig");
const state = @import("state.zig");
usingnamespace @import("types.zig");

// Install a panic handler that tries to shutdown termbox before calling the
// default panic handler.
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    display.deinit() catch |e| {};
    std.builtin.default_panic(msg, error_return_trace);
}

// // Some debugging code. Nothing to see here, move along.
// fn debug_main() anyerror!void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{
//         // Probably should enable this later on to track memory usage, if
//         // allocations become too much
//         .enable_memory_limit = false,
//         .safety = true,

//         // Probably would enable this later, as we might want to run the ticks()
//         // on other dungeon levels in another thread
//         .thread_safe = true,

//         .never_unmap = false,
//     }){};

//     rng.init();
//     state.mobs = MobList.init(&gpa.allocator);
//     state.machines = MachineList.init(&gpa.allocator);
//     state.props = PropList.init(&gpa.allocator);

//     // mapgen.drunken_walk();
//     // mapgen.add_guard_stations(&gpa.allocator);
//     // mapgen.add_player(&gpa.allocator);
//     mapgen.placeRandomRooms(&gpa.allocator);

//     {
//         var y: usize = 0;
//         while (y < state.HEIGHT) : (y += 1) {
//             var x: usize = 0;
//             while (x < state.WIDTH) : (x += 1) {
//                 switch (state.dungeon[0][y][x].type) {
//                     .Wall => std.debug.print("\x1b[07m \x1b[m", .{}),
//                     .Floor => {
//                         var tile: u21 = '·';
//                         if (state.dungeon[0][y][x].surface) |surface| {
//                             switch (surface) {
//                                 .Machine => |m| tile = m.tile,
//                                 .Prop => |p| tile = p.tile,
//                             }
//                         }

//                         var buf: [4]u8 = .{ 0, 0, 0, 0 };
//                         _ = std.unicode.utf8Encode(tile, &buf) catch unreachable;
//                         std.debug.print("{}", .{buf});
//                     },
//                 }
//             }
//             std.debug.print("\n", .{});
//         }
//     }

//     std.process.exit(0);
// }

pub fn main() anyerror!void {
    if (display.init()) {} else |err| switch (err) {
        error.AlreadyInitialized => unreachable,
        error.TTYOpenFailed => @panic("Could not open TTY"),
        error.UnsupportedTerminal => @panic("Unsupported terminal"),
        error.PipeTrapFailed => @panic("Internal termbox error"),
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{
        // Probably should enable this later on to track memory usage, if
        // allocations become too much
        .enable_memory_limit = false,

        .safety = true,

        // Probably would enable this later, as we might want to run the ticks()
        // on other dungeon levels in another thread
        .thread_safe = true,

        .never_unmap = true,
    }){};

    state.messages = MessageArrayList.init(&gpa.allocator);
    state.mobs = MobList.init(&gpa.allocator);
    state.machines = MachineList.init(&gpa.allocator);
    state.props = PropList.init(&gpa.allocator);
    astar.initCache(&gpa.allocator);
    rng.init();

    for (state.dungeon.map) |_, level|
        mapgen.placeRandomRooms(level, &gpa.allocator);
    for (state.dungeon.map) |_, level|
        mapgen.placeRandomStairs(level);

    state.tick(&gpa.allocator);
    state.tickAtmosphere(0);
    display.draw();

    while (true) {
        var ev: termbox.tb_event = undefined;
        const t = termbox.tb_poll_event(&ev);

        if (t == -1) {
            @panic("Fatal termbox error");
        }

        if (t == termbox.TB_EVENT_RESIZE) {
            display.draw();
        } else if (t == termbox.TB_EVENT_KEY) {
            if (ev.key != 0) {
                if (ev.key == termbox.TB_KEY_CTRL_C)
                    break;
            } else if (ev.ch != 0) {
                const did_anything = switch (ev.ch) {
                    '.' => true,
                    'h' => state.player.moveInDirection(.West),
                    'j' => state.player.moveInDirection(.South),
                    'k' => state.player.moveInDirection(.North),
                    'l' => state.player.moveInDirection(.East),
                    'y' => state.player.moveInDirection(.NorthWest),
                    'u' => state.player.moveInDirection(.NorthEast),
                    'b' => state.player.moveInDirection(.SouthWest),
                    'n' => state.player.moveInDirection(.SouthEast),
                    's' => blk: {
                        state.dungeon.atGas(state.player.coord)[0] += 1.0;
                        break :blk true;
                    },
                    else => false,
                };

                if (did_anything) {
                    state.tickAtmosphere(0);
                    state.tick(&gpa.allocator);
                    if (state.player.is_dead) {
                        @panic("You died...");
                    } else {
                        display.draw();
                    }
                }
            } else unreachable;
        }
    }

    astar.deinitCache();
    display.deinit() catch unreachable;
    state.mobs.deinit();
    state.machines.deinit();
    state.props.deinit();
    state.freeall();
    _ = gpa.deinit();
}
