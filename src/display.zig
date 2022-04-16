// TODO: rename this module to 'ui'

const std = @import("std");
const math = std.math;
const io = std.io;
const assert = std.debug.assert;
const mem = std.mem;
const enums = std.enums;

const colors = @import("colors.zig");
const player = @import("player.zig");
const spells = @import("spells.zig");
const combat = @import("combat.zig");
const err = @import("err.zig");
const gas = @import("gas.zig");
const state = @import("state.zig");
const surfaces = @import("surfaces.zig");
const termbox = @import("termbox.zig");
const utils = @import("utils.zig");
const types = @import("types.zig");

const StackBuffer = @import("buffer.zig").StackBuffer;

const Mob = types.Mob;
const StatusDataInfo = types.StatusDataInfo;
const SurfaceItem = types.SurfaceItem;
const Stat = types.Stat;
const Resistance = types.Resistance;
const Coord = types.Coord;
const Direction = types.Direction;
const Tile = types.Tile;
const Status = types.Status;
const Item = types.Item;
const CoordArrayList = types.CoordArrayList;
const DIRECTIONS = types.DIRECTIONS;

const LEVELS = state.LEVELS;
const HEIGHT = state.HEIGHT;
const WIDTH = state.WIDTH;

// -----------------------------------------------------------------------------

pub const LEFT_INFO_WIDTH: usize = 24;
pub const RIGHT_INFO_WIDTH: usize = 30;
pub const LOG_HEIGHT: usize = 8;

// tb_shutdown() calls abort() if tb_init() wasn't called, or if tb_shutdown()
// was called twice. Keep track of termbox's state to prevent this.
var is_tb_inited = false;

pub fn init() !void {
    if (is_tb_inited)
        return error.AlreadyInitialized;

    switch (termbox.tb_init()) {
        0 => is_tb_inited = true,
        termbox.TB_EFAILED_TO_OPEN_TTY => return error.TTYOpenFailed,
        termbox.TB_EUNSUPPORTED_TERMINAL => return error.UnsupportedTerminal,
        termbox.TB_EPIPE_TRAP_ERROR => return error.PipeTrapFailed,
        else => unreachable,
    }

    _ = termbox.tb_select_output_mode(termbox.TB_OUTPUT_TRUECOLOR);
    _ = termbox.tb_set_clear_attributes(termbox.TB_WHITE, termbox.TB_BLACK);
    clearScreen();
}

// Check that the window is the minimum size.
//
// Return true if the user resized the window, false if the user press Ctrl+C.
pub fn checkWindowSize() bool {
    const min_height = HEIGHT + LOG_HEIGHT + 2;
    const min_width = WIDTH + LEFT_INFO_WIDTH + RIGHT_INFO_WIDTH + 2;

    while (true) {
        const cur_w = termbox.tb_width();
        const cur_h = termbox.tb_height();

        if (cur_w >= min_width and cur_h >= min_height) {
            // All's well
            clearScreen();
            return true;
        }

        _ = _drawStr(1, 1, cur_w, "Your terminal is too small.", .{}, .{});
        _ = _drawStr(1, 3, cur_w, "Minimum: {}x{}.", .{ min_width, min_height }, .{});
        _ = _drawStr(1, 4, cur_w, "Current size: {}x{}.", .{ cur_w, cur_h }, .{});

        termbox.tb_present();

        var ev: termbox.tb_event = undefined;
        const t = termbox.tb_poll_event(&ev);

        if (t == -1) @panic("Fatal termbox error");

        if (t == termbox.TB_EVENT_KEY) {
            if (ev.key != 0) {
                switch (ev.key) {
                    termbox.TB_KEY_CTRL_C, termbox.TB_KEY_ESC => return false,
                    else => {},
                }
                continue;
            } else if (ev.ch != 0) {
                switch (ev.ch) {
                    'q' => return false,
                    else => {},
                }
            } else unreachable;
        }
    }
}

pub fn deinit() !void {
    if (!is_tb_inited)
        return error.AlreadyDeinitialized;
    termbox.tb_shutdown();
    is_tb_inited = false;
}

pub const DisplayWindow = enum { PlayerInfo, Main, EnemyInfo, Log };
pub const Dimension = struct { startx: isize, endx: isize, starty: isize, endy: isize };

pub fn dimensions(w: DisplayWindow) Dimension {
    const height = termbox.tb_height();
    const width = termbox.tb_width();

    const playerinfo_width = LEFT_INFO_WIDTH;
    //const enemyinfo_width = RIGHT_INFO_WIDTH;

    const playerinfo_start = 1;
    const main_start = playerinfo_start + playerinfo_width + 1;
    const main_width = WIDTH;
    const main_height = HEIGHT;
    const log_start = main_start;
    const enemyinfo_start = main_start + main_width + 1;

    return switch (w) {
        .PlayerInfo => .{
            .startx = playerinfo_start,
            .endx = playerinfo_start + playerinfo_width,
            .starty = 0,
            .endy = height - 1,
            //.width = playerinfo_width,
            //.height = height - 1,
        },
        .Main => .{
            .startx = main_start,
            .endx = main_start + main_width,
            .starty = 1,
            .endy = main_height + 2,
            //.width = main_width,
            //.height = main_height,
        },
        .EnemyInfo => .{
            .startx = enemyinfo_start,
            .endx = width - 1,
            .starty = 1,
            .endy = height - 1,
            //.width = math.max(enemyinfo_width, width - enemyinfo_start),
            //.height = height - 1,
        },
        .Log => .{
            .startx = log_start,
            .endx = log_start + main_width,
            .starty = 2 + main_height,
            .endy = height - 1,
            //.width = main_width,
            //.height = math.max(LOG_HEIGHT, height - (2 + main_height) - 1),
        },
    };
}

// Formatting descriptions for stuff. {{{

// XXX: Uses a static internal buffer. Buffer must be consumed before next call,
// not thread safe, etc.
fn _formatStatusInfo(statusinfo: *const StatusDataInfo) []const u8 {
    var buf: [65535]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var w = fbs.writer();

    const sname = statusinfo.status.string(state.player);
    switch (statusinfo.duration) {
        .Prm => _writerWrite(w, "$bPrm$. {s}\n", .{sname}),
        .Equ => _writerWrite(w, "$bEqu$. {s}\n", .{sname}),
        .Tmp => _writerWrite(w, "$bTmp$. {s} $g({})$.\n", .{ sname, statusinfo.duration.Tmp }),
        .Ctx => _writerWrite(w, "$bCtx$. {s}\n", .{sname}),
    }

    return fbs.getWritten();
}

fn _writerWrite(writer: io.FixedBufferStream([]u8).Writer, comptime fmt: []const u8, args: anytype) void {
    writer.print(fmt, args) catch err.wat();
}

fn _writerHLine(writer: io.FixedBufferStream([]u8).Writer, linewidth: usize) void {
    var i: usize = 0;
    while (i < linewidth) : (i += 1)
        writer.writeAll("─") catch err.wat();
}

fn _writerMonsHostility(w: io.FixedBufferStream([]u8).Writer, mob: *Mob) void {
    if (mob.isHostileTo(state.player)) {
        if (mob.ai.is_combative) {
            _writerWrite(w, "$rhostile$.\n", .{});
        } else {
            _writerWrite(w, "$gnon-combatant$.\n", .{});
        }
    } else {
        _writerWrite(w, "$bneutral$.\n", .{});
    }
}

fn _writerMobStats(
    w: io.FixedBufferStream([]u8).Writer,
    mob: *Mob,
) void {
    // TODO: don't manually tabulate this?
    _writerWrite(w, "$cstat       value$.\n", .{});
    inline for (@typeInfo(Stat).Enum.fields) |statv| {
        const stat = @intToEnum(Stat, statv.value);
        const stat_val = mob.stat(stat);
        if (stat == .Sneak) continue;
        _writerWrite(w, "{s: <8} $a{: >5}$.\n", .{ stat.string(), stat_val });
    }
    inline for (@typeInfo(Resistance).Enum.fields) |resistancev| {
        const resist = @intToEnum(Resistance, resistancev.value);
        const resist_val = mob.resistance(resist);
        if (resist_val != 0) {
            _writerWrite(w, "{s: <8} $a{: >5}$.\n", .{ resist.string(), resist_val });
        }
    }
    _writerWrite(w, "\n", .{});
}

fn _writerStats(
    w: io.FixedBufferStream([]u8).Writer,
    p_stats: ?enums.EnumFieldStruct(Stat, isize, 0),
    p_resists: ?enums.EnumFieldStruct(Resistance, isize, 0),
) void {
    // TODO: don't manually tabulate this?
    _writerWrite(w, "$cstat       value$.\n", .{});
    if (p_stats) |stats| {
        inline for (@typeInfo(Stat).Enum.fields) |statv| {
            const stat = @intToEnum(Stat, statv.value);

            const x_stat_val = utils.getFieldByEnum(Stat, stats, stat);
            // var base_stat_val = @intCast(isize, switch (stat) {
            //     .Missile => combat.chanceOfMissileLanding(state.player),
            //     .Melee => combat.chanceOfMeleeLanding(state.player, null),
            //     .Evade => combat.chanceOfAttackEvaded(state.player, null),
            //     else => state.player.stat(stat),
            // });
            // if (state.dungeon.terrainAt(state.player.coord) == terrain) {
            //     base_stat_val -= terrain_stat_val;
            // }
            // const new_stat_val = base_stat_val + terrain_stat_val;

            if (x_stat_val > 0) {
                // // TODO: use $r for negative '->' values, I tried to do this with
                // // Zig v9.1 but ran into a compiler bug where the `color` variable
                // // was replaced with random garbage.
                // _writerWrite(w, "{s: <8} $a{: >5}$. $b{: >5}$. $a{: >5}$.\n", .{
                //     stat.string(), base_stat_val, terrain_stat_val, new_stat_val,
                // });
                _writerWrite(w, "{s: <8} $a{: >5}$.\n", .{ stat.string(), x_stat_val });
            }
        }
    }
    if (p_resists) |resists| {
        inline for (@typeInfo(Resistance).Enum.fields) |resistancev| {
            const resist = @intToEnum(Resistance, resistancev.value);

            const x_resist_val = utils.getFieldByEnum(Resistance, resists, resist);
            // var base_resist_val = @intCast(isize, state.player.resistance(resist));
            // if (state.dungeon.terrainAt(state.player.coord) == terrain) {
            //     base_resist_val -= terrain_resist_val;
            // }
            // const new_resist_val = base_resist_val + terrain_resist_val;

            if (x_resist_val != 0) {
                // // TODO: use $r for negative '->' values, I tried to do this with
                // // Zig v9.1 but ran into a compiler bug where the `color` variable
                // // was replaced with random garbage.
                // _writerWrite(w, "{s: <8} $a{: >5}$. $b{: >5}$. $a{: >5}$.\n", .{
                //     resist.string(), base_resist_val, terrain_resist_val, new_resist_val,
                // });
                _writerWrite(w, "{s: <8} $a{: >5}$.\n", .{ resist.string(), x_resist_val });
            }
        }
    }
    _writerWrite(w, "\n", .{});
}

fn _getTerrDescription(w: io.FixedBufferStream([]u8).Writer, terrain: *const surfaces.Terrain, linewidth: usize) void {
    _ = linewidth;

    _writerWrite(w, "$c{s}$.\n", .{terrain.name});
    _writerWrite(w, "terrain\n", .{});
    _writerWrite(w, "\n", .{});

    if (terrain.fire_retardant) {
        _writerWrite(w, "It will put out fires.\n", .{});
        _writerWrite(w, "\n", .{});
    } else if (terrain.flammability > 0) {
        _writerWrite(w, "It is flammable.\n", .{});
        _writerWrite(w, "\n", .{});
    }

    _writerStats(w, terrain.stats, terrain.resists);
    _writerWrite(w, "\n", .{});

    if (terrain.effects.len > 0) {
        _writerWrite(w, "$ceffects:$.\n", .{});
        for (terrain.effects) |effect| {
            _writerWrite(w, "{s}\n", .{_formatStatusInfo(&effect)});
        }
    }
}

fn _getSurfDescription(w: io.FixedBufferStream([]u8).Writer, surface: SurfaceItem, linewidth: usize) void {
    switch (surface) {
        .Machine => |m| {
            _writerWrite(w, "$c{s}$.\n", .{m.name});
            _writerWrite(w, "machine\n", .{});
            _writerWrite(w, "\n", .{});

            if (m.interact1) |interaction| {
                const remaining = interaction.max_use - interaction.used;
                const plural: []const u8 = if (remaining == 1) "" else "s";
                _writerWrite(w, "You used this machine $b{}$. times.\n", .{interaction.used});
                _writerWrite(w, "It can be used $b{}$. more time{s}.\n", .{ remaining, plural });
                _writerWrite(w, "\n", .{});
            }

            if (m.malfunction_effect) |effect| {
                switch (effect) {
                    .Electrocute => |elec_effect| {
                        const chance = 100 / (elec_effect.chance / 10);
                        _writerWrite(w, "$cmalfunction effect:$. electrocute\n", .{});
                        _writerWrite(w, "· $cradius:$. {}\n", .{elec_effect.radius});
                        _writerWrite(w, "· $cchance:$. {}%\n", .{chance});
                        _writerWrite(w, "· $cdamage:$. {}\n", .{elec_effect.damage});
                    },
                    .Explode => |expl_effect| {
                        const chance = 100 / (expl_effect.chance / 10);
                        _writerWrite(w, "$cmalfunction effect:$. explode\n", .{});
                        _writerWrite(w, "· $cradius:$. ~{}\n", .{expl_effect.power / 100});
                        _writerWrite(w, "· $cchance:$. {}%\n", .{chance});
                        _writerWrite(w, "· $cdamage:$. massive\n", .{});
                    },
                }
            } else {
                _writerWrite(w, "$cmalfunction effect: $gnone$.\n", .{});
            }
            _writerWrite(w, "\n", .{});
        },
        .Prop => |p| _writerWrite(w, "$c{s}$.\nprop\n\n$gNothing to see here.$.\n", .{p.name}),
        .Container => |c| {
            _writerWrite(w, "$cA {s}$.\nContainer\n\n", .{c.name});
            _writerWrite(w, "$gPress $b,$. $gover it to see its contents.$.\n", .{});
        },
        .Poster => |p| {
            _writerWrite(w, "$cPoster$.\n\n", .{});
            _writerWrite(w, "Some writing on a board:\n", .{});
            _writerHLine(w, linewidth);
            _writerWrite(w, "$g{s}$.\n", .{p.text});
            _writerHLine(w, linewidth);
        },
        .Stair => |s| {
            if (s == null) {
                _writerWrite(w, "$cDownward Stairs$.\n\n", .{});
                _writerWrite(w, "$gGoing back down would sure be dumb.$.\n", .{});
            } else {
                _writerWrite(w, "$cUpward Stairs$.\n\nStairs to {s}.\n", .{
                    state.levelinfo[s.?.z].name,
                });
            }
        },
        .Corpse => |c| {
            // Since the mob object was deinit'd, we can't rely on
            // mob.displayName() working
            const name = c.ai.profession_name orelse c.species.name;
            _writerWrite(w, "$c{s} remains$.\n", .{name});
            _writerWrite(w, "corpse\n\n", .{});
            _writerWrite(w, "This corpse is just begging for a necromancer to raise it.", .{});
        },
    }
}

fn _getMonsStatsDescription(w: io.FixedBufferStream([]u8).Writer, mob: *Mob, linewidth: usize) void {
    _ = linewidth;

    _writerWrite(w, "$c{s}$.\n", .{mob.displayName()});
    _writerMonsHostility(w, mob);
    _writerWrite(w, "\n", .{});

    _writerMobStats(w, mob);
}

fn _getMonsSpellsDescription(w: io.FixedBufferStream([]u8).Writer, mob: *Mob, linewidth: usize) void {
    _ = linewidth;

    _writerWrite(w, "$c{s}$.\n", .{mob.displayName()});
    _writerMonsHostility(w, mob);
    _writerWrite(w, "\n", .{});

    if (mob.spells.len == 0) {
        _writerWrite(w, "$gThis monster has no spells, and is thus (relatively) safe to underestimate.$.\n", .{});
        _writerWrite(w, "\n", .{});
    } else {
        const chance = spells.appxChanceOfWillOverpowered(mob, state.player);
        const colorset = [_]u21{ 'g', 'b', 'b', 'p', 'p', 'r', 'r', 'r', 'r', 'r' };
        _writerWrite(w, "$cChance to overpower your will$.: ${u}{}%$.\n", .{
            colorset[chance / 10], chance,
        });
        _writerWrite(w, "\n", .{});

        for (mob.spells) |spellcfg| {
            _writerWrite(w, "$c{s}$. ({} mp)\n", .{
                spellcfg.spell.name, spellcfg.MP_cost,
            });

            if (spellcfg.spell.cast_type == .Smite) {
                const target = @as([]const u8, switch (spellcfg.spell.smite_target_type) {
                    .Self => "$bself$.",
                    .UndeadAlly => "undead ally",
                    .Mob => "you",
                    .Corpse => "corpse",
                });
                _writerWrite(w, "· $ctarget$.: {s}\n", .{target});
            } else if (spellcfg.spell.cast_type == .Bolt) {
                const dodgeable = spellcfg.spell.bolt_dodgeable;
                const color: u21 = if (dodgeable) 'b' else 'r';
                const string = if (dodgeable) @as([]const u8, "yes") else "no";
                _writerWrite(w, "· $cdodgeable$.: ${u}{s}\n", .{ color, string });
            }

            const targeting = @as([]const u8, switch (spellcfg.spell.cast_type) {
                .Ray => @panic("TODO"),
                .Smite => "smite-targeted",
                .Bolt => "bolt",
            });
            _writerWrite(w, "· $ctype$.: {s}\n", .{targeting});

            if (spellcfg.spell.checks_will) {
                _writerWrite(w, "· $cwill-checked$.: $byes$.\n", .{});
            } else {
                _writerWrite(w, "· $cwill-checked$.: $rno$.\n", .{});
            }

            if (spellcfg.spell.effect_type == .Status) {
                _writerWrite(w, "· $gTmp$. {s} ({})\n", .{
                    spellcfg.spell.effect_type.Status.string(state.player), spellcfg.power,
                });
            }

            _writerWrite(w, "\n", .{});
        }
    }
}

fn _getMonsDescription(w: io.FixedBufferStream([]u8).Writer, mob: *Mob, linewidth: usize) void {
    _ = linewidth;

    if (mob == state.player) {
        _writerWrite(w, "$cYou.$.\n", .{});
        _writerWrite(w, "\n", .{});
        _writerMobStats(w, state.player);
        return;
    }

    _writerWrite(w, "$c{s}$.\n", .{mob.displayName()});
    _writerMonsHostility(w, mob);
    _writerWrite(w, "\n", .{});

    const asterisk_col = if (mob.HP <= (mob.max_HP / 5)) @as(u21, 'r') else '.';
    _writerWrite(w, "${u}*$. {}/{} HP\n", .{
        asterisk_col,
        @floatToInt(usize, math.round(mob.HP)),
        @floatToInt(usize, math.round(mob.max_HP)),
    });

    if (mob.prisoner_status) |ps| {
        const desc = if (ps.held_by) |_| "chained" else "prisoner";
        _writerWrite(w, "$cp$. {s}\n", .{desc});
    }

    if (mob.resistance(.rFume) == 0) {
        _writerWrite(w, "$cu$. unbreathing\n", .{});
    }

    if (mob.immobile) {
        _writerWrite(w, "$ci$. immobile\n", .{});
    }

    const mobspeed = mob.stat(.Speed);
    const youspeed = state.player.stat(.Speed);
    if (mobspeed != youspeed) {
        const ch = if (mobspeed < youspeed) @as(u21, 'f') else 's';
        const desc = if (mobspeed < youspeed) "faster than you" else "slower than you";
        const col = if (mobspeed < youspeed) @as(u21, 'p') else 'b';

        _writerWrite(w, "${u}{u}$. {s}\n", .{ col, ch, desc });
    }

    if (mob.ai.phase == .Investigate) {
        var you_str: []const u8 = "";
        if (state.dungeon.soundAt(mob.ai.target.?).mob_source) |soundsource| {
            if (soundsource == state.player) {
                you_str = "you";
            }
        }
        _writerWrite(w, "? investigating {s}\n", .{you_str});
    } else if (mob.ai.phase == .Flee) {
        _writerWrite(w, "$b!$. fleeing\n", .{});
    }

    if (mob.isHostileTo(state.player) and mob.ai.is_combative) {
        var color: u21 = '.';
        var text: []const u8 = "this is a bug";

        const Awareness = enum { Seeing, Remember, None };
        const awareness: Awareness = for (mob.enemies.items) |enemyrec| {
            if (enemyrec.mob == state.player) {
                // Zig, why the fuck do I need to cast the below as Awareness?
                // Wouldn't I like to fucking chop your fucking type checker into
                // tiny shreds with a +9 halberd of flaming.
                break if (mob.cansee(state.player.coord)) @as(Awareness, .Seeing) else .Remember;
            }
        } else .None;

        switch (awareness) {
            .Seeing => {
                color = 'r';
                text = "aware";
            },
            .Remember => {
                color = 'p';
                text = "remembers you";
            },
            .None => {
                color = 'b';
                text = "unaware";
            },
        }

        _writerWrite(w, "${u}@$. {s}\n", .{ color, text });
    } else {
        _writerWrite(w, "$g@$. doesn't care\n", .{});
    }

    _writerWrite(w, "\n", .{});

    const you_melee = combat.chanceOfMeleeLanding(state.player, mob);
    const you_evade = combat.chanceOfAttackEvaded(state.player, null);
    const mob_melee = combat.chanceOfMeleeLanding(mob, state.player);
    const mob_evade = combat.chanceOfAttackEvaded(mob, null);

    const c_melee_you = mob_melee * (100 - you_evade) / 100;
    const c_evade_you = 100 - (you_melee * (100 - mob_evade) / 100);

    const m_colorsets = [_]u21{ 'g', 'g', 'g', 'g', 'b', 'b', 'b', 'b', 'r', 'r', 'r' };
    const e_colorsets = [_]u21{ 'g', 'b', 'r', 'r', 'r', 'r', 'r', 'r', 'r', 'r', 'r' };
    const c_melee_you_color = m_colorsets[c_melee_you / 10];
    const c_evade_you_color = e_colorsets[c_evade_you / 10];

    _writerWrite(w, "${u}{}%$. to hit you.\n", .{ c_melee_you_color, c_melee_you });
    _writerWrite(w, "${u}{}%$. to evade you.\n", .{ c_evade_you_color, c_evade_you });
    _writerWrite(w, "\n", .{});

    const you_armor = @intCast(usize, state.player.resistance(.Armor));
    const mob_damage_output = math.max(1, mob.totalMeleeOutput() * you_armor / 100);
    _writerWrite(w, "Hits for max $r{}$. damage.\n", .{mob_damage_output});
    _writerWrite(w, "\n", .{});

    var statuses = mob.statuses.iterator();
    while (statuses.next()) |entry| {
        if (mob.isUnderStatus(entry.key) == null)
            continue;
        _writerWrite(w, "{s}", .{_formatStatusInfo(entry.value)});
    }
    _writerWrite(w, "\n", .{});
}

fn _getItemDescription(w: io.FixedBufferStream([]u8).Writer, item: Item, linewidth: usize) void {
    _ = linewidth;

    const shortname = (item.shortName() catch err.wat()).constSlice();

    //S.appendChar(w, ' ', (linewidth / 2) -| (shortname.len / 2));
    _writerWrite(w, "$c{s}$.\n", .{shortname});

    const itemtype: []const u8 = switch (item) {
        .Ring => "ring",
        .Potion => "potion",
        .Vial => "vial",
        .Projectile => "projectile",
        .Armor => "armor",
        .Cloak => "cloak",
        .Weapon => "weapon",
        .Boulder => "boulder",
        .Prop => "prop",
        .Evocable => "evocable",
    };
    _writerWrite(w, "{s}\n", .{itemtype});

    _writerWrite(w, "\n", .{});

    switch (item) {
        .Ring => _writerWrite(w, "TODO: ring descriptions.", .{}),
        .Potion => |p| {
            _writerWrite(w, "$ceffects$.:\n", .{});
            switch (p.type) {
                .Gas => |g| _writerWrite(w, "$gGas$. {s}\n", .{gas.Gases[g].name}),
                .Status => |s| _writerWrite(w, "$gTmp$. {s}\n", .{s.string(state.player)}),
                .Custom => _writerWrite(w, "$G(See description)$.\n", .{}),
            }
            _writerWrite(w, "\n", .{});

            _writerWrite(w, "$cdip effect:$.\n", .{});
            if (p.dip_effect) |effect| {
                _writerWrite(w, "{s}", .{_formatStatusInfo(&effect)});
            } else {
                _writerWrite(w, "$gCannot dip.$.\n", .{});
            }
        },
        .Projectile => |p| {
            const dmg = p.damage orelse @as(usize, 0);
            _writerWrite(w, "$cdamage$.: {}\n", .{dmg});
            switch (p.effect) {
                .Status => |sinfo| {
                    _writerWrite(w, "$ceffects$.:\n", .{});
                    _writerWrite(w, "{s}", .{_formatStatusInfo(&sinfo)});
                },
            }
        },
        .Cloak => |c| _writerStats(w, c.stats, c.resists),
        .Armor => |a| _writerStats(w, a.stats, a.resists),
        .Weapon => |p| {
            // stats: enums.EnumFieldStruct(Stat, isize, 0) = .{},
            // effects: []const StatusDataInfo = &[_]StatusDataInfo{},
            // equip_effects: []const StatusDataInfo = &[_]StatusDataInfo{},

            _writerWrite(w, "$cdamage:$. {}\n", .{p.damage});
            if (p.reach != 1) _writerWrite(w, "$creach:$. {}\n", .{p.reach});
            if (p.delay != 100) {
                const col: u21 = if (p.delay > 100) 'r' else 'a';
                _writerWrite(w, "$cdelay:$. ${u}{}%$.\n", .{ col, p.delay });
            }
            if (p.knockback != 0) _writerWrite(w, "$cknockback:$. {}\n", .{p.knockback});
            _writerWrite(w, "\n", .{});

            if (p.is_dippable) {
                _writerWrite(w, "$aCan be dipped.$.\n", .{});
            } else {
                _writerWrite(w, "$rCan't be dipped.$.\n", .{});
            }
            if (p.dip_effect) |potion| {
                assert(p.dip_counter > 0);
                _writerWrite(w, "· {s}", .{_formatStatusInfo(&potion.dip_effect.?)});
                _writerWrite(w, "· {} attacks left", .{p.dip_counter});
            }
            _writerWrite(w, "\n", .{});

            _writerStats(w, p.stats, null);

            if (p.equip_effects.len > 0) {
                _writerWrite(w, "$cequip effects:$.\n", .{});
                for (p.equip_effects) |effect|
                    _writerWrite(w, "{s}", .{_formatStatusInfo(&effect)});
                _writerWrite(w, "\n", .{});
            }

            if (p.effects.len > 0) {
                _writerWrite(w, "$cattack effects:$.\n", .{});
                for (p.effects) |effect|
                    _writerWrite(w, "{s}", .{_formatStatusInfo(&effect)});
                _writerWrite(w, "\n", .{});
            }
        },
        .Evocable => _writerWrite(w, "TODO", .{}),
        .Boulder, .Prop, .Vial => _writerWrite(w, "$G(This item is useless.)$.", .{}),
    }

    _writerWrite(w, "\n", .{});
}

// }}}

fn _clearLineWith(from: isize, to: isize, y: isize, ch: u32, fg: u32, bg: u32) void {
    var x = from;
    while (x <= to) : (x += 1)
        termbox.tb_change_cell(x, y, ch, fg, bg);
}

pub fn clearScreen() void {
    const height = termbox.tb_height();
    const width = termbox.tb_width();

    var y: isize = 0;
    while (y < height) : (y += 1)
        _clearLineWith(0, width, y, ' ', 0, colors.BG);
}

fn _clear_line(from: isize, to: isize, y: isize) void {
    _clearLineWith(from, to, y, ' ', 0, colors.BG);
}

pub fn _drawBorder(color: u32, d: Dimension) void {
    var y = d.starty;
    while (y <= d.endy) : (y += 1) {
        var x = d.startx;
        while (x <= d.endx) : (x += 1) {
            if (y != d.starty and y != d.endy and x != d.startx and x != d.endx) {
                continue;
            }

            const char: u21 = if (y == d.starty or y == d.endy) '─' else '│';
            termbox.tb_change_cell(x, y, char, color, colors.BG);
        }
    }

    // Fix corners
    termbox.tb_change_cell(d.startx, d.starty, '╭', color, colors.BG);
    termbox.tb_change_cell(d.endx, d.starty, '╮', color, colors.BG);
    termbox.tb_change_cell(d.startx, d.endy, '╰', color, colors.BG);
    termbox.tb_change_cell(d.endx, d.endy, '╯', color, colors.BG);

    termbox.tb_present();
}

const DrawStrOpts = struct {
    bg: ?u32 = colors.BG,
    fg: u32 = 0xe6e6e6,
    endy: ?isize = null,
    fold: bool = true,
    // When folding text, skip the first X lines. Used to implement scrolling.
    skip_lines: usize = 0,
};

// Escape characters:
//     $g       fg = GREY
//     $G       fg = DARK_GREY
//     $c       fg = LIGHT_CONCRETE
//     $a       fg = AQUAMARINE
//     $p       fg = PINK
//     $b       fg = LIGHT_STEEL_BLUE
//     $r       fg = PALE_VIOLET_RED
//     $.       reset fg and bg to defaults
fn _drawStr(_x: isize, _y: isize, endx: isize, comptime format: []const u8, args: anytype, opts: DrawStrOpts) isize {
    const termbox_width = termbox.tb_width();
    const termbox_buffer = termbox.tb_cell_buffer();

    var buf: [65535]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    std.fmt.format(fbs.writer(), format, args) catch err.bug("format error!", .{});
    const str = fbs.getWritten();

    var x = _x;
    var y = _y;
    var skipped: usize = 0;

    var fg = opts.fg;
    var bg: ?u32 = opts.bg;

    const linewidth = if (opts.fold) @intCast(usize, endx - x) else str.len;

    var fold_iter = utils.FoldedTextIterator.init(str, linewidth);
    while (fold_iter.next()) |line| : ({
        y += 1;
        x = _x;
    }) {
        if (skipped < opts.skip_lines) {
            skipped += 1;
            y -= 1; // Stay on the same line
            continue;
        }

        if (opts.endy) |endy| {
            if (endy == y) {
                break;
            }
        }

        var utf8 = (std.unicode.Utf8View.init(line) catch err.bug("bad utf8", .{})).iterator();
        while (utf8.nextCodepointSlice()) |encoded_codepoint| {
            const codepoint = std.unicode.utf8Decode(encoded_codepoint) catch err.bug("bad utf8", .{});
            const def_bg = termbox_buffer[@intCast(usize, y * termbox_width + x)].bg;

            switch (codepoint) {
                '\n' => {
                    y += 1;
                    x = _x;
                    continue;
                },
                '\r' => err.bug("Bad character found in string.", .{}),
                '$' => {
                    const next_encoded_codepoint = utf8.nextCodepointSlice() orelse
                        err.bug("Found incomplete escape sequence", .{});
                    const next_codepoint = std.unicode.utf8Decode(next_encoded_codepoint) catch err.bug("bad utf8", .{});
                    switch (next_codepoint) {
                        '.' => {
                            fg = opts.fg;
                            bg = opts.bg;
                        },
                        'g' => fg = colors.GREY,
                        'G' => fg = colors.DARK_GREY,
                        'c' => fg = colors.LIGHT_CONCRETE,
                        'p' => fg = colors.PINK,
                        'b' => fg = colors.LIGHT_STEEL_BLUE,
                        'r' => fg = colors.PALE_VIOLET_RED,
                        'a' => fg = colors.AQUAMARINE,
                        else => err.bug("Found unknown escape sequence '${u}' (line: '{s}')", .{ next_codepoint, line }),
                    }
                    continue;
                },
                else => {
                    termbox.tb_change_cell(x, y, codepoint, fg, bg orelse def_bg);
                    x += 1;
                },
            }

            if (!opts.fold and x == endx) {
                x -= 1;
            }
        }
    }

    return y;
}

fn _draw_bar(y: isize, startx: isize, endx: isize, current: usize, max: usize, description: []const u8, bg: u32, fg: u32) void {
    const bg2 = colors.darken(bg, 3); // Color used to display depleted bar
    const percent = (current * 100) / max;
    const bar = @divTrunc((endx - startx - 1) * @intCast(isize, percent), 100);
    const bar_end = startx + bar;

    _clearLineWith(startx, bar_end, y, ' ', fg, bg);
    _clearLineWith(bar_end, endx - 1, y, ' ', fg, bg2);

    _ = _drawStr(startx + 1, y, endx, "{s}", .{description}, .{ .fg = fg, .bg = null });
}

fn drawEnemyInfo(
    moblist: []const *Mob,
    startx: isize,
    starty: isize,
    endx: isize,
    endy: isize,
) void {
    var y = starty;
    while (y < endy) : (y += 1) _clear_line(startx, endx, y);
    y = starty;

    for (moblist) |mob| {
        if (mob.is_dead) continue;

        _clear_line(startx, endx, y);
        _clear_line(startx, endx, y + 1);

        var mobcell = Tile.displayAs(mob.coord, false);
        termbox.tb_put_cell(startx, y, &mobcell);

        y = _drawStr(startx + 2, y, endx, "{s}", .{mob.displayName()}, .{});

        _draw_bar(y, startx, endx, @floatToInt(usize, mob.HP), @floatToInt(usize, mob.max_HP), "health", 0x232faa, 0xffffff);
        y += 1;

        var statuses = mob.statuses.iterator();
        while (statuses.next()) |entry| {
            const status = entry.key;
            const se = entry.value.*;

            const duration = switch (se.duration) {
                .Prm, .Equ, .Ctx => Status.MAX_DURATION,
                .Tmp => |t| t,
            };

            if (duration == 0) continue;

            _draw_bar(y, startx, endx, duration, Status.MAX_DURATION, status.string(mob), 0x77452e, 0xffffff);
            y += 1;
        }

        const activity = if (mob.prisoner_status != null) if (mob.prisoner_status.?.held_by != null) "(chained)" else "(prisoner)" else mob.activity_description();
        y = _drawStr(endx - @divTrunc(endx - startx, 2) - @intCast(isize, activity.len / 2), y, endx, "{s}", .{activity}, .{ .fg = 0x9a9a9a });

        y += 2;
    }
}

fn drawPlayerInfo(moblist: []const *Mob, startx: isize, starty: isize, endx: isize, endy: isize) void {
    // const last_action_cost = if (state.player.activities.current()) |lastaction| b: {
    //     const spd = @intToFloat(f64, state.player.speed());
    //     break :b (spd * @intToFloat(f64, lastaction.cost())) / 100.0 / 10.0;
    // } else 0.0;

    var y = starty;
    while (y < endy) : (y += 1) _clear_line(startx, endx, y);
    y = starty + 1;

    y = _drawStr(startx, y, endx, "--- {s} ---", .{
        state.levelinfo[state.player.coord.z].name,
    }, .{ .fg = 0xffffff });
    y += 1;

    inline for (@typeInfo(Stat).Enum.fields) |statv| {
        const stat = @intToEnum(Stat, statv.value);
        const base_stat_val = utils.getFieldByEnum(Stat, state.player.stats, stat);

        const cur_stat_val = @intCast(isize, switch (stat) {
            .Missile => combat.chanceOfMissileLanding(state.player),
            .Melee => combat.chanceOfMeleeLanding(state.player, null),
            .Evade => combat.chanceOfAttackEvaded(state.player, null),
            else => state.player.stat(stat),
        });

        if (cur_stat_val > 0 or base_stat_val > 0) {
            if (cur_stat_val != base_stat_val) {
                const diff = cur_stat_val - base_stat_val;
                const abs = math.absInt(diff) catch unreachable;
                const sign = if (diff > 0) "+" else "-";
                y = _drawStr(startx, y, endx, "$c{s: <8}$. {: >4} ({s}{})", .{
                    stat.string(), cur_stat_val, sign, abs,
                }, .{});
            } else {
                y = _drawStr(startx, y, endx, "$c{s: <8}$. {: >4}", .{ stat.string(), cur_stat_val }, .{});
            }
        }
    }

    const armor = 100 - @intCast(isize, state.player.resistance(.Armor));
    y = _drawStr(startx, y, endx, "$carmor%$.   {: >4}%", .{armor}, .{});

    y += 1;

    _draw_bar(
        y,
        startx,
        endx,
        @floatToInt(usize, state.player.HP),
        @floatToInt(usize, state.player.max_HP),
        "health",
        0x232faa,
        0xffffff,
    );
    y += 1;

    var statuses = state.player.statuses.iterator();
    while (statuses.next()) |entry| {
        const status = entry.key;
        const se = entry.value.*;

        if (state.player.isUnderStatus(status) == null)
            continue;

        const duration = switch (se.duration) {
            .Prm, .Equ, .Ctx => Status.MAX_DURATION,
            .Tmp => |t| t,
        };

        _draw_bar(y, startx, endx, duration, Status.MAX_DURATION, status.string(state.player), 0x77452e, 0xffffff);
        y += 1;
    }
    y += 1;

    const sneak = @intCast(usize, state.player.stat(.Sneak));
    const is_walking = state.player.turnsSpentMoving() >= sneak;
    _draw_bar(y, startx, endx, math.min(sneak, state.player.turnsSpentMoving()), sneak, if (is_walking) "walking" else "sneaking", if (is_walking) 0x45772e else 0x25570e, 0xffffff);
    y += 2;

    const light = state.dungeon.lightAt(state.player.coord).*;
    const flanked = state.player.isFlanked();
    const spotted = b: for (moblist) |mob| {
        if (!mob.no_show_fov and mob.ai.is_combative and mob.isHostileTo(state.player)) {
            for (mob.enemies.items) |enemyrecord|
                if (enemyrecord.mob == state.player) break :b true;
        }
    } else false;

    if (light or flanked or spotted) {
        const lit_str = if (light) "Lit " else "";
        const flanked_str = if (flanked) "Flanked " else "";
        const spotted_str = if (spotted) "Spotted " else "";

        y = _drawStr(startx, y, endx, "$c{s}$.$b{s}$.$r{s}$.", .{
            lit_str, spotted_str, flanked_str,
        }, .{});
        y += 1;
    }

    y = _drawStr(startx, y, endx, "$cturns:$. {}", .{state.ticks}, .{});
    y += 1;

    const terrain = state.dungeon.terrainAt(state.player.coord);
    if (!mem.eql(u8, terrain.id, "t_default")) {
        y = _drawStr(startx, y, endx, "$cterrain$.: {s}", .{terrain.name}, .{});

        inline for (@typeInfo(Stat).Enum.fields) |statv| {
            const stat = @intToEnum(Stat, statv.value);
            const stat_val = utils.getFieldByEnum(Stat, terrain.stats, stat);
            if (stat_val != 0) {
                const abs = math.absInt(stat_val) catch unreachable;
                const sign = if (stat_val > 0) "+" else "-";
                y = _drawStr(startx, y, endx, "· $c{s: <5}$. {s}{}", .{
                    stat.string(), sign, abs,
                }, .{});
            }
        }

        inline for (@typeInfo(Resistance).Enum.fields) |resistv| {
            const resist = @intToEnum(Resistance, resistv.value);
            const resist_val = utils.getFieldByEnum(Resistance, terrain.resists, resist);
            if (resist_val != 0) {
                const abs = math.absInt(resist_val) catch unreachable;
                const sign = if (resist_val > 0) "+" else "-";
                y = _drawStr(startx, y, endx, "· {s: <5} {s}{}", .{
                    resist.string(), sign, abs,
                }, .{});
            }
        }

        for (terrain.effects) |effect| {
            const str = effect.status.string(state.player);
            y = switch (effect.duration) {
                .Prm => _drawStr(startx, y, endx, "$gPrm$. {s}\n", .{str}, .{}),
                .Equ => _drawStr(startx, y, endx, "$gEqu$. {s}\n", .{str}, .{}),
                .Tmp => _drawStr(startx, y, endx, "$gTmp$. {s} ({})\n", .{ str, effect.duration }, .{}),
                .Ctx => _drawStr(startx, y, endx, "$gCtx$. {s}\n", .{str}, .{}),
            };
        }
    }
}

fn drawLog(startx: isize, endx: isize, starty: isize, endy: isize) void {
    var y = starty;

    // Clear window.
    while (y <= endy) : (y += 1) _clear_line(startx, endx, y);
    y = starty;

    if (state.messages.items.len == 0)
        return;

    const msgcount = state.messages.items.len - 1;
    const first = msgcount - math.min(msgcount, @intCast(usize, endy - 1 - starty));
    var i: usize = first;
    while (i <= msgcount and y < endy) : (i += 1) {
        const msg = state.messages.items[i];
        const msgtext = utils.used(msg.msg);

        const col = if (msg.turn >= state.ticks -| 3 or i == msgcount)
            msg.type.color()
        else
            colors.darken(msg.type.color(), 2);

        _clear_line(startx, endx, y);

        if (msg.dups == 0) {
            y = _drawStr(startx, y, endx, "{s}", .{
                msgtext,
            }, .{ .fg = col, .fold = true });
        } else {
            y = _drawStr(startx, y, endx, "{s} (×{})", .{
                msgtext, msg.dups + 1,
            }, .{ .fg = col, .fold = true });
        }
    }
}

fn _mobs_can_see(moblist: []const *Mob, coord: Coord) bool {
    for (moblist) |mob| {
        if (mob.is_dead or mob.no_show_fov or
            !mob.ai.is_combative or !mob.isHostileTo(state.player))
            continue;
        if (mob.cansee(coord)) return true;
    }
    return false;
}

pub fn drawMap(moblist: []const *Mob, startx: isize, endx: isize, starty: isize, endy: isize) void {
    //const playery = @intCast(isize, state.player.coord.y);
    //const playerx = @intCast(isize, state.player.coord.x);
    const level = state.player.coord.z;

    var cursory: isize = starty;
    var cursorx: isize = startx;

    //const height = @intCast(usize, endy - starty);
    //const width = @intCast(usize, endx - startx);
    //const map_starty = playery - @intCast(isize, height / 2);
    //const map_endy = playery + @intCast(isize, height / 2);
    //const map_startx = playerx - @intCast(isize, width / 2);
    //const map_endx = playerx + @intCast(isize, width / 2);

    const map_starty: isize = 0;
    const map_endy: isize = HEIGHT;
    const map_startx: isize = 0;
    const map_endx: isize = WIDTH;

    var y = map_starty;
    while (y < map_endy and cursory < endy) : ({
        y += 1;
        cursory += 1;
        cursorx = startx;
    }) {
        var x: isize = map_startx;
        while (x < map_endx and cursorx < endx) : ({
            x += 1;
            cursorx += 1;
        }) {
            // if out of bounds on the map, draw a black tile
            if (y < 0 or x < 0 or y >= HEIGHT or x >= WIDTH) {
                termbox.tb_change_cell(cursorx, cursory, ' ', 0, colors.BG);
                continue;
            }

            const u_x: usize = @intCast(usize, x);
            const u_y: usize = @intCast(usize, y);
            const coord = Coord.new2(level, u_x, u_y);

            var tile = Tile.displayAs(coord, false);

            // if player can't see area, draw a blank/grey tile, depending on
            // what they saw last there
            if (!state.player.cansee(coord)) {
                tile = .{ .fg = 0, .bg = colors.BG, .ch = ' ' };

                if (state.memory.contains(coord)) {
                    const memt = state.memory.get(coord) orelse unreachable;
                    tile = .{ .fg = memt.fg, .bg = memt.bg, .ch = memt.ch };

                    tile.bg = colors.darken(colors.filterGrayscale(tile.bg), 4);
                    tile.fg = colors.darken(colors.filterGrayscale(tile.fg), 4);

                    if (tile.bg < colors.BG) tile.bg = colors.BG;
                }

                // Can we hear anything
                if (state.player.canHear(coord)) |noise| if (noise.state == .New) {
                    tile.fg = 0x00d610;
                    tile.ch = if (noise.intensity.radiusHeard() > 6) '♫' else '♩';
                };

                termbox.tb_put_cell(cursorx, cursory, &tile);

                continue;
            }

            // Draw noise and indicate if that tile is visible by another mob
            switch (state.dungeon.at(coord).type) {
                .Floor => {
                    const has_stuff = state.dungeon.at(coord).surface != null or
                        state.dungeon.at(coord).mob != null or
                        state.dungeon.itemsAt(coord).len > 0;

                    if (_mobs_can_see(moblist, coord)) {
                        // Treat this cell specially if it's the player and the player is
                        // being watched.
                        if (state.player.coord.eq(coord) and _mobs_can_see(moblist, coord)) {
                            termbox.tb_change_cell(cursorx, cursory, '@', 0, 0xffffff);
                            continue;
                        }

                        if (has_stuff) {
                            if (state.is_walkable(coord, .{ .right_now = true })) {
                                // Swap.
                                tile.fg ^= tile.bg;
                                tile.bg ^= tile.fg;
                                tile.fg ^= tile.bg;
                            }
                        } else {
                            tile.ch = '⬞';
                            //tile.fg = 0xffffff;
                        }
                    }
                },
                else => {},
            }

            termbox.tb_put_cell(cursorx, cursory, &tile);
        }
    }
}

pub fn draw() void {
    // TODO: do some tests and figure out what's the practical limit to memory
    // usage, and reduce the buffer's size to that.
    var membuf: [65535]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(membuf[0..]);

    const moblist = state.createMobList(false, true, state.player.coord.z, fba.allocator());

    const pinfo_win = dimensions(.PlayerInfo);
    const main_win = dimensions(.Main);
    const einfo_win = dimensions(.EnemyInfo);
    const log_window = dimensions(.Log);

    drawPlayerInfo(moblist.items, pinfo_win.startx, pinfo_win.starty, pinfo_win.endx, pinfo_win.endy);
    drawMap(moblist.items, main_win.startx, main_win.endx, main_win.starty, main_win.endy);
    drawEnemyInfo(moblist.items, einfo_win.startx, einfo_win.starty, einfo_win.endx, einfo_win.endy);
    drawLog(log_window.startx, log_window.endx, log_window.starty, log_window.endy);

    termbox.tb_present();
}

pub const ChooseCellOptions = struct {
    require_seen: bool = true,
};

pub fn chooseCell(opts: ChooseCellOptions) ?Coord {
    const mainw = dimensions(.Main);

    // TODO: do some tests and figure out what's the practical limit to memory
    // usage, and reduce the buffer's size to that.
    var membuf: [65535]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(membuf[0..]);

    const moblist = state.createMobList(false, true, state.player.coord.z, fba.allocator());

    var coord: Coord = state.player.coord;

    while (true) {
        drawMap(moblist.items, mainw.startx, mainw.endx, mainw.starty, mainw.endy);

        const display_x = mainw.startx + @intCast(isize, coord.x);
        const display_y = mainw.starty + @intCast(isize, coord.y);
        termbox.tb_change_cell(display_x - 1, display_y - 1, '╭', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x + 0, display_y - 1, '─', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y - 1, '╮', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x - 1, display_y + 0, '│', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y + 0, '│', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x - 1, display_y + 1, '╰', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x + 0, display_y + 1, '─', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y + 1, '╯', colors.CONCRETE, colors.BG);

        termbox.tb_present();

        // This is a bit of a hack, erase the bordering but don't present the
        // changes, so that if the user moves to the edge of the map and then moves
        // away, there won't be bordering left as an artifact (as the map drawing
        // routines won't erase it, since it's outside its window).
        termbox.tb_change_cell(display_x - 1, display_y - 1, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x + 0, display_y - 1, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y - 1, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x - 1, display_y + 0, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y + 0, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x - 1, display_y + 1, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x + 0, display_y + 1, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y + 1, ' ', 0, colors.BG);

        var ev: termbox.tb_event = undefined;
        const t = termbox.tb_poll_event(&ev);

        if (t == -1) @panic("Fatal termbox error");

        if (t == termbox.TB_EVENT_KEY) {
            if (ev.key != 0) {
                switch (ev.key) {
                    termbox.TB_KEY_CTRL_C,
                    termbox.TB_KEY_CTRL_G,
                    => return null,
                    termbox.TB_KEY_ENTER => {
                        if (opts.require_seen and !state.player.cansee(coord) and
                            !state.memory.contains(coord))
                        {
                            drawAlert("You haven't seen that place!", .{});
                        } else {
                            return coord;
                        }
                    },
                    else => continue,
                }
            } else if (ev.ch != 0) {
                switch (ev.ch) {
                    'h' => coord = coord.move(.West, state.mapgeometry) orelse coord,
                    'j' => coord = coord.move(.South, state.mapgeometry) orelse coord,
                    'k' => coord = coord.move(.North, state.mapgeometry) orelse coord,
                    'l' => coord = coord.move(.East, state.mapgeometry) orelse coord,
                    'y' => coord = coord.move(.NorthWest, state.mapgeometry) orelse coord,
                    'u' => coord = coord.move(.NorthEast, state.mapgeometry) orelse coord,
                    'b' => coord = coord.move(.SouthWest, state.mapgeometry) orelse coord,
                    'n' => coord = coord.move(.SouthEast, state.mapgeometry) orelse coord,
                    else => {},
                }
            } else unreachable;
        }
    }
}

pub const ExamineTileFocus = enum { Item, Surface, Mob };
pub fn drawExamineScreen(starting_focus: ?ExamineTileFocus) bool {
    const mainw = dimensions(.Main);
    const logw = dimensions(.Log);
    const infow = dimensions(.EnemyInfo);

    // TODO: do some tests and figure out what's the practical limit to memory
    // usage, and reduce the buffer's size to that.
    var membuf: [65535]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(membuf[0..]);

    const moblist = state.createMobList(false, true, state.player.coord.z, fba.allocator());

    const MobTileFocus = enum { Main, Stats, Spells };

    var coord: Coord = state.player.coord;
    var tile_focus = starting_focus orelse .Mob;
    var mob_tile_focus: MobTileFocus = .Main;
    var desc_scroll: usize = 0;

    var kbd_s = false;
    var kbd_a = false;
    var kbd_B = false;

    while (true) {
        const has_item = state.dungeon.itemsAt(coord).len > 0;
        const has_mons = state.dungeon.at(coord).mob != null;
        const has_surf = state.dungeon.at(coord).surface != null or !mem.eql(u8, state.dungeon.terrainAt(coord).id, "t_default");

        // Draw side info pane.
        if (has_mons or has_surf or has_item) {
            const linewidth = @intCast(usize, infow.endx - infow.startx);

            var textbuf: [4096]u8 = undefined;
            var text = io.fixedBufferStream(&textbuf);
            var writer = text.writer();

            const mons_tab = if (tile_focus == .Mob) "*$cMob$.*" else "$g Mob ";
            const surf_tab = if (tile_focus == .Surface) "*$cSurface$.*" else "$g Surface ";
            const item_tab = if (tile_focus == .Item) "*$cItem$.*" else "$g Item ";
            _writerWrite(writer, "{s} {s} {s}$.\n", .{ mons_tab, surf_tab, item_tab });

            _writerWrite(writer, "Press $b<>$. to switch tabs.\n", .{});
            _writerWrite(writer, "\n", .{});

            if (tile_focus == .Mob and has_mons) {
                const mob = state.dungeon.at(coord).mob.?;
                switch (mob_tile_focus) {
                    .Main => _getMonsDescription(writer, mob, linewidth),
                    .Spells => _getMonsSpellsDescription(writer, mob, linewidth),
                    .Stats => _getMonsStatsDescription(writer, mob, linewidth),
                }
            } else if (tile_focus == .Surface and has_surf) {
                if (state.dungeon.at(coord).surface) |surf| {
                    _getSurfDescription(writer, surf, linewidth);
                } else {
                    _getTerrDescription(writer, state.dungeon.terrainAt(coord), linewidth);
                }
            } else if (tile_focus == .Item and has_item) {
                _getItemDescription(writer, state.dungeon.itemsAt(coord).last().?, linewidth);
            }

            // Add keybinding descriptions
            if (tile_focus == .Mob and has_mons) {
                const mob = state.dungeon.at(coord).mob.?;
                if (mob != state.player) {
                    kbd_s = true;
                    switch (mob_tile_focus) {
                        .Main => _writerWrite(writer, "Press $bs$. to see stats.\n", .{}),
                        .Stats => _writerWrite(writer, "Press $bs$. to see spells.\n", .{}),
                        .Spells => _writerWrite(writer, "Press $bs$. to see mob.\n", .{}),
                    }
                }

                if (mob != state.player and state.player.canMelee(mob)) {
                    kbd_a = true;
                    _writerWrite(writer, "Press $ba$. to attack.\n", .{});
                }
            } else if (tile_focus == .Surface and has_surf) {
                if (coord.distance(state.player.coord) <= 1 and
                    state.dungeon.at(coord).surface != null and
                    state.dungeon.at(coord).surface.? == .Machine and
                    !state.dungeon.at(coord).broken)
                {
                    kbd_B = true;
                    _writerWrite(writer, "Press $bB$. to break this.\n", .{});
                }
            }

            var y = infow.starty;

            while (y < infow.endy) : (y += 1)
                _clear_line(infow.startx, infow.endx, y);
            y = infow.starty;

            y = _drawStr(infow.startx, y, infow.endx, "{s}", .{text.getWritten()}, .{});
        } else {
            var y = infow.starty;
            while (y < infow.endy) : (y += 1)
                _clear_line(infow.startx, infow.endx, y);
        }

        // Draw description pane.
        {
            const log_startx = logw.startx;
            const log_endx = logw.endx;
            const log_starty = logw.starty;
            const log_endy = logw.endy;

            var descbuf: [4096]u8 = undefined;
            var descbuf_stream = io.fixedBufferStream(&descbuf);
            var writer = descbuf_stream.writer();

            if (tile_focus == .Mob and state.dungeon.at(coord).mob != null) {
                const mob = state.dungeon.at(coord).mob.?;
                if (mob_tile_focus == .Spells) {
                    for (mob.spells) |spell| {
                        if (state.descriptions.get(spell.spell.id)) |spelldesc| {
                            _writerWrite(writer, "$c{s}$.: {s}", .{
                                spell.spell.name, spelldesc,
                            });
                            _writerWrite(writer, "\n\n", .{});
                        }
                    }
                } else {
                    if (state.descriptions.get(mob.id)) |mobdesc| {
                        _writerWrite(writer, "{s}", .{mobdesc});
                        _writerWrite(writer, "\n\n", .{});
                    }
                }
            }

            if (tile_focus == .Surface) {
                if (state.dungeon.at(coord).surface != null) {
                    const id = state.dungeon.at(coord).surface.?.id();
                    if (state.descriptions.get(id)) |surfdesc| {
                        _writerWrite(writer, "{s}", .{surfdesc});
                        _writerWrite(writer, "\n\n", .{});
                    }
                } else {
                    const id = state.dungeon.terrainAt(coord).id;
                    if (state.descriptions.get(id)) |terraindesc| {
                        _writerWrite(writer, "{s}", .{terraindesc});
                        _writerWrite(writer, "\n\n", .{});
                    }
                }
            }

            if (tile_focus == .Item and state.dungeon.itemsAt(coord).len > 0) {
                if (state.dungeon.itemsAt(coord).data[0].id()) |id|
                    if (state.descriptions.get(id)) |itemdesc| {
                        _writerWrite(writer, "{s}", .{itemdesc});
                        _writerWrite(writer, "\n\n", .{});
                    };
            }

            var y = log_starty;
            while (y < log_endy) : (y += 1) _clear_line(log_startx, log_endx, y);

            const lasty = _drawStr(log_startx, log_starty, log_endx, "{s}", .{
                descbuf_stream.getWritten(),
            }, .{
                .skip_lines = desc_scroll,
                .endy = log_endy,
            });

            if (desc_scroll > 0) {
                _ = _drawStr(log_endx - 14, log_starty, log_endx, " $p-- PgUp --$.", .{}, .{});
            }
            if (lasty == log_endy) {
                _ = _drawStr(log_endx - 14, log_endy - 1, log_endx, " $p-- PgDn --$.", .{}, .{});
            }
        }

        drawMap(moblist.items, mainw.startx, mainw.endx, mainw.starty, mainw.endy);

        const display_x = mainw.startx + @intCast(isize, coord.x);
        const display_y = mainw.starty + @intCast(isize, coord.y);
        termbox.tb_change_cell(display_x - 1, display_y - 1, '╭', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x + 0, display_y - 1, '─', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y - 1, '╮', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x - 1, display_y + 0, '│', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y + 0, '│', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x - 1, display_y + 1, '╰', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x + 0, display_y + 1, '─', colors.CONCRETE, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y + 1, '╯', colors.CONCRETE, colors.BG);

        termbox.tb_present();

        // This is a bit of a hack, erase the bordering but don't present the
        // changes, so that if the user moves to the edge of the map and then moves
        // away, there won't be bordering left as an artifact (as the map drawing
        // routines won't erase it, since it's outside its window).
        termbox.tb_change_cell(display_x - 1, display_y - 1, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x + 0, display_y - 1, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y - 1, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x - 1, display_y + 0, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y + 0, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x - 1, display_y + 1, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x + 0, display_y + 1, ' ', 0, colors.BG);
        termbox.tb_change_cell(display_x + 1, display_y + 1, ' ', 0, colors.BG);

        var ev: termbox.tb_event = undefined;
        const t = termbox.tb_poll_event(&ev);

        if (t == -1) @panic("Fatal termbox error");

        if (t == termbox.TB_EVENT_KEY) {
            if (ev.key != 0) {
                switch (ev.key) {
                    termbox.TB_KEY_PGUP => desc_scroll -|= 1,
                    termbox.TB_KEY_PGDN => desc_scroll += 1,
                    termbox.TB_KEY_CTRL_C,
                    termbox.TB_KEY_CTRL_G,
                    => break,
                    else => continue,
                }
            } else if (ev.ch != 0) {
                switch (ev.ch) {
                    'h' => coord = coord.move(.West, state.mapgeometry) orelse coord,
                    'j' => coord = coord.move(.South, state.mapgeometry) orelse coord,
                    'k' => coord = coord.move(.North, state.mapgeometry) orelse coord,
                    'l' => coord = coord.move(.East, state.mapgeometry) orelse coord,
                    'y' => coord = coord.move(.NorthWest, state.mapgeometry) orelse coord,
                    'u' => coord = coord.move(.NorthEast, state.mapgeometry) orelse coord,
                    'b' => coord = coord.move(.SouthWest, state.mapgeometry) orelse coord,
                    'n' => coord = coord.move(.SouthEast, state.mapgeometry) orelse coord,
                    'B' => if (kbd_B) {
                        return player.breakSomething(coord);
                    },
                    'a' => if (kbd_a) {
                        state.player.fight(state.dungeon.at(coord).mob.?, .{});
                        return true;
                    },
                    's' => if (kbd_s) {
                        mob_tile_focus = switch (mob_tile_focus) {
                            .Main => .Stats,
                            .Stats => .Spells,
                            .Spells => .Main,
                        };
                    },
                    '>' => {
                        tile_focus = switch (tile_focus) {
                            .Mob => .Surface,
                            .Surface => .Item,
                            .Item => .Mob,
                        };
                        if (tile_focus == .Mob) mob_tile_focus = .Main;
                    },
                    '<' => {
                        tile_focus = switch (tile_focus) {
                            .Mob => .Item,
                            .Surface => .Mob,
                            .Item => .Surface,
                        };
                        if (tile_focus == .Mob) mob_tile_focus = .Main;
                    },
                    else => {},
                }
            } else unreachable;
        }
    }

    return false;
}

// Wait for input. Return null if Ctrl+c or escape was pressed, default_input
// if <enter> is pressed ,otherwise the key pressed. Will continue waiting if a
// mouse event or resize event was recieved.
pub fn waitForInput(default_input: ?u8) ?u32 {
    while (true) {
        var ev: termbox.tb_event = undefined;
        const t = termbox.tb_poll_event(&ev);

        if (t == -1) @panic("Fatal termbox error");

        if (t == termbox.TB_EVENT_RESIZE) {
            draw();
        } else if (t == termbox.TB_EVENT_KEY) {
            if (ev.key != 0) switch (ev.key) {
                termbox.TB_KEY_ESC, termbox.TB_KEY_CTRL_C => return null,
                termbox.TB_KEY_ENTER => if (default_input) |def| return def else continue,
                termbox.TB_KEY_SPACE => return ' ',
                else => continue,
            };

            if (ev.ch != 0) {
                return ev.ch;
            }
        }
    }
}

pub fn drawInventoryScreen() bool {
    const playerinfo_window = dimensions(.PlayerInfo);
    const main_window = dimensions(.Main);
    const iteminfo_window = dimensions(.EnemyInfo);
    const log_window = dimensions(.Log);

    // TODO: do some tests and figure out what's the practical limit to memory
    // usage, and reduce the buffer's size to that.
    var membuf: [65535]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(membuf[0..]);

    const moblist = state.createMobList(false, true, state.player.coord.z, fba.allocator());

    const ItemListType = enum { Pack, Equip };

    var desc_scroll: usize = 0;
    var chosen: usize = 0;
    var chosen_itemlist: ItemListType = .Pack;
    var y: isize = 0;

    while (true) {
        clearScreen();

        drawPlayerInfo(moblist.items, playerinfo_window.startx, playerinfo_window.starty, playerinfo_window.endx, playerinfo_window.endy);

        const starty = main_window.starty;
        const x = main_window.startx;
        const endx = main_window.endx;

        const itemlist_len = if (chosen_itemlist == .Pack) state.player.inventory.pack.len else state.player.inventory.equ_slots.len;
        const chosen_item: ?Item = if (chosen_itemlist == .Pack) state.player.inventory.pack.data[chosen] else state.player.inventory.equ_slots[chosen];

        // Draw list of items
        {
            y = starty;
            for (state.player.inventory.pack.constSlice()) |item, i| {
                const startx = x;

                const name = (item.longName() catch err.wat()).constSlice();
                const color = if (i == chosen and chosen_itemlist == .Pack) colors.LIGHT_CONCRETE else colors.GREY;
                const arrow = if (i == chosen and chosen_itemlist == .Pack) ">" else " ";
                _clear_line(startx, endx, y);
                y = _drawStr(startx, y, endx, "{s} {s}", .{ arrow, name }, .{ .fg = color });
            }

            y = starty;
            inline for (@typeInfo(Mob.Inventory.EquSlot).Enum.fields) |slots_f, i| {
                const startx = endx - @divTrunc(endx - x, 2);
                const slot = @intToEnum(Mob.Inventory.EquSlot, slots_f.value);
                const arrow = if (i == chosen and chosen_itemlist == .Equip) ">" else " ";
                const color = if (i == chosen and chosen_itemlist == .Equip) colors.LIGHT_CONCRETE else colors.GREY;

                _clear_line(startx, endx, y);

                if (state.player.inventory.equipment(slot).*) |item| {
                    const name = (item.longName() catch unreachable).constSlice();
                    y = _drawStr(startx, y, endx, "{s} {s: >6}: {s}", .{ arrow, slot.name(), name }, .{ .fg = color });
                } else {
                    y = _drawStr(startx, y, endx, "{s} {s: >6}:", .{ arrow, slot.name() }, .{ .fg = color });
                }
            }
        }

        var dippable = false;
        var usable = false;
        var throwable = false;

        if (chosen_item != null and itemlist_len > 0) switch (chosen_item.?) {
            .Potion => |p| {
                usable = true;
                dippable = p.dip_effect != null;
                throwable = true;
            },
            .Evocable => usable = true,
            .Projectile => throwable = true,
            else => {},
        };

        // Draw item info
        if (chosen_item != null and itemlist_len > 0) {
            const ii_startx = iteminfo_window.startx;
            const ii_endx = iteminfo_window.endx;
            const ii_starty = iteminfo_window.starty;
            const ii_endy = iteminfo_window.endy;

            var ii_y = ii_starty;
            while (ii_y < ii_endy) : (ii_y += 1)
                _clear_line(ii_startx, ii_endx, ii_y);

            var descbuf: [4096]u8 = undefined;
            var descbuf_stream = io.fixedBufferStream(&descbuf);
            var writer = descbuf_stream.writer();
            _getItemDescription(
                descbuf_stream.writer(),
                chosen_item.?,
                RIGHT_INFO_WIDTH - 1,
            );

            if (usable) writer.print("$cSPACE$. to use.\n", .{}) catch err.wat();
            if (dippable) writer.print("$cD$. to dip your weapon.\n", .{}) catch err.wat();
            if (throwable) writer.print("$ct$. to throw.\n", .{}) catch err.wat();

            _ = _drawStr(ii_startx, ii_starty, ii_endx, "{s}", .{descbuf_stream.getWritten()}, .{});
        }

        // Draw item description
        if (chosen_item != null) {
            const log_startx = log_window.startx;
            const log_endx = log_window.endx;
            const log_starty = log_window.starty;
            const log_endy = log_window.endy;

            if (itemlist_len > 0) {
                const id = chosen_item.?.id();
                const default_desc = "(Missing description)";
                const desc: []const u8 = if (id) |i_id| state.descriptions.get(i_id) orelse default_desc else default_desc;

                const ending_y = _drawStr(log_startx, log_starty, log_endx, "{s}", .{desc}, .{
                    .skip_lines = desc_scroll,
                    .endy = log_endy,
                });

                if (desc_scroll > 0) {
                    _ = _drawStr(log_endx - 14, log_starty, log_endx, " $p-- PgUp --$.", .{}, .{});
                }
                if (ending_y == log_endy) {
                    _ = _drawStr(log_endx - 14, log_endy - 1, log_endx, " $p-- PgDn --$.", .{}, .{});
                }
            } else {
                _ = _drawStr(log_startx, log_starty, log_endx, "Your inventory is empty.", .{}, .{});
            }
        }

        termbox.tb_present();

        var ev: termbox.tb_event = undefined;
        const t = termbox.tb_poll_event(&ev);

        if (t == -1) @panic("Fatal termbox error");

        if (t == termbox.TB_EVENT_KEY) {
            if (ev.key != 0) {
                switch (ev.key) {
                    termbox.TB_KEY_ARROW_RIGHT => {
                        chosen_itemlist = .Equip;
                        chosen = 0;
                    },
                    termbox.TB_KEY_ARROW_LEFT => {
                        chosen_itemlist = .Pack;
                        chosen = 0;
                    },
                    termbox.TB_KEY_ARROW_DOWN => if (chosen < itemlist_len - 1) {
                        chosen += 1;
                    },
                    termbox.TB_KEY_ARROW_UP => chosen -|= 1,
                    termbox.TB_KEY_PGUP => desc_scroll -|= 1,
                    termbox.TB_KEY_PGDN => desc_scroll += 1,
                    termbox.TB_KEY_CTRL_C,
                    termbox.TB_KEY_CTRL_G,
                    termbox.TB_KEY_ESC,
                    => return false,
                    termbox.TB_KEY_SPACE,
                    termbox.TB_KEY_ENTER,
                    => if (itemlist_len > 0)
                        return player.useItem(chosen),
                    else => {},
                }
                continue;
            } else if (ev.ch != 0) {
                switch (ev.ch) {
                    'd' => if (chosen_itemlist == .Pack) {
                        if (itemlist_len > 0)
                            if (player.dropItem(chosen)) return true;
                    } else {
                        drawAlert("You can't drop that!", .{});
                    },
                    'D' => if (chosen_itemlist == .Pack) {
                        if (itemlist_len > 0)
                            if (player.dipWeapon(chosen)) return true;
                    } else {
                        drawAlert("Select a potion and press $bD$. to dip something in it.", .{});
                    },
                    't' => if (chosen_itemlist == .Pack) {
                        if (itemlist_len > 0)
                            if (player.throwItem(chosen)) return true;
                    } else {
                        drawAlert("You can't throw that!", .{});
                    },
                    'l' => {
                        chosen_itemlist = .Equip;
                        chosen = 0;
                    },
                    'h' => {
                        chosen_itemlist = .Pack;
                        chosen = 0;
                    },
                    'j' => if (itemlist_len > 0 and chosen < itemlist_len - 1) {
                        chosen += 1;
                    },
                    'k' => if (itemlist_len > 0 and chosen > 0) {
                        chosen -= 1;
                    },
                    else => {},
                }
            } else unreachable;
        }
    }
}

pub fn drawAlert(comptime fmt: []const u8, args: anytype) void {
    const wind = dimensions(.Log);

    var buf: [65535]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    std.fmt.format(fbs.writer(), fmt, args) catch err.bug("format error!", .{});
    const str = fbs.getWritten();

    // Get height of folded text, so that we can center it vertically
    const linewidth = @intCast(usize, (wind.endx - wind.startx) - 4);
    var text_height: usize = 0;
    var fold_iter = utils.FoldedTextIterator.init(str, linewidth);
    while (fold_iter.next()) |_| text_height += 1;

    // Clear log window
    var y = wind.starty;
    while (y < wind.endy) : (y += 1) _clear_line(wind.startx, wind.endx, y);

    const txt_starty = wind.endy -
        @divTrunc(wind.endy - wind.starty, 2) -
        @intCast(isize, text_height + 1 / 2);
    y = txt_starty;

    _ = _drawStr(wind.startx + 2, txt_starty, wind.endx, "{s}", .{str}, .{});

    termbox.tb_present();

    _drawBorder(colors.CONCRETE, wind);
    std.time.sleep(150_000_000);
    _drawBorder(colors.BG, wind);
    std.time.sleep(150_000_000);
    _drawBorder(colors.CONCRETE, wind);
    std.time.sleep(150_000_000);
    _drawBorder(colors.BG, wind);
    std.time.sleep(150_000_000);
    _drawBorder(colors.CONCRETE, wind);
    std.time.sleep(500_000_000);
}

pub fn drawAlertThenLog(comptime fmt: []const u8, args: anytype) void {
    const log_window = dimensions(.Log);
    drawAlert(fmt, args);
    drawLog(log_window.startx, log_window.endx, log_window.starty, log_window.endy);
}

pub fn drawChoicePrompt(comptime fmt: []const u8, args: anytype, options: []const []const u8) ?usize {
    assert(options.len > 0);

    const wind = dimensions(.Log);

    var buf: [65535]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    std.fmt.format(fbs.writer(), fmt, args) catch err.bug("format error!", .{});
    const str = fbs.getWritten();

    // Clear log window
    var y: isize = wind.starty;
    while (y < wind.endy) : (y += 1) _clear_line(wind.startx, wind.endx, y);
    y = wind.starty;

    var chosen: usize = 0;
    var cancelled = false;

    while (true) {
        y = wind.starty;
        y = _drawStr(wind.startx, y, wind.endx, "$c{s}$.", .{str}, .{});

        for (options) |option, i| {
            const ind = if (chosen == i) ">" else "-";
            const color = if (chosen == i) colors.LIGHT_CONCRETE else colors.GREY;
            y = _drawStr(wind.startx, y, wind.endx, "{s} {s}", .{ ind, option }, .{ .fg = color });
        }

        termbox.tb_present();
        var ev: termbox.tb_event = undefined;
        const t = termbox.tb_poll_event(&ev);

        if (t == -1) @panic("Fatal termbox error");

        if (t == termbox.TB_EVENT_KEY) {
            if (ev.key != 0) {
                switch (ev.key) {
                    termbox.TB_KEY_ARROW_DOWN,
                    termbox.TB_KEY_ARROW_LEFT,
                    => if (chosen < options.len - 1) {
                        chosen += 1;
                    },
                    termbox.TB_KEY_ARROW_UP,
                    termbox.TB_KEY_ARROW_RIGHT,
                    => if (chosen > 0) {
                        chosen -= 1;
                    },
                    termbox.TB_KEY_CTRL_C,
                    termbox.TB_KEY_CTRL_G,
                    termbox.TB_KEY_ESC,
                    => {
                        cancelled = true;
                        break;
                    },
                    termbox.TB_KEY_SPACE, termbox.TB_KEY_ENTER => break,
                    else => {},
                }
                continue;
            } else if (ev.ch != 0) {
                switch (ev.ch) {
                    'q' => {
                        cancelled = true;
                        break;
                    },
                    'j', 'h' => if (chosen < options.len - 1) {
                        chosen += 1;
                    },
                    'k', 'l' => if (chosen > 0) {
                        chosen -= 1;
                    },
                    '0'...'9' => {
                        const c: usize = ev.ch - '0';
                        if (c < options.len) {
                            chosen = c;
                        }
                    },
                    else => {},
                }
            } else unreachable;
        }
    }

    return if (cancelled) null else chosen;
}

pub fn drawYesNoPrompt(comptime fmt: []const u8, args: anytype) bool {
    const r = (drawChoicePrompt(fmt, args, &[_][]const u8{ "No", "Yes" }) orelse 0) == 1;
    if (!r) state.message(.Unimportant, "Cancelled.", .{});
    return r;
}

pub fn drawContinuePrompt(comptime fmt: []const u8, args: anytype) void {
    state.message(.Info, fmt, args);
    _ = drawChoicePrompt(fmt, args, &[_][]const u8{"Press $b<Enter>$. to continue."});
}

pub fn drawItemChoicePrompt(comptime fmt: []const u8, args: anytype, items: []const Item) ?usize {
    assert(items.len > 0); // This should have been handled previously.

    // A bit messy.
    var namebuf = std.ArrayList([]const u8).init(state.GPA.allocator());
    defer {
        for (namebuf.items) |str| state.GPA.allocator().free(str);
        namebuf.deinit();
    }

    for (items) |item| {
        const itemname = item.longName() catch err.wat();
        const string = state.GPA.allocator().alloc(u8, itemname.len) catch err.wat();
        std.mem.copy(u8, string, itemname.constSlice());
        namebuf.append(string) catch err.wat();
    }

    return drawChoicePrompt(fmt, args, namebuf.items);
}
