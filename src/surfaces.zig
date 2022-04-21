// TODO: add state to machines

const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const meta = std.meta;
const math = std.math;
const enums = std.enums;

const spells = @import("spells.zig");
const colors = @import("colors.zig");
const err = @import("err.zig");
const main = @import("root");
const utils = @import("utils.zig");
const state = @import("state.zig");
const explosions = @import("explosions.zig");
const gas = @import("gas.zig");
const tsv = @import("tsv.zig");
const rng = @import("rng.zig");
const materials = @import("materials.zig");
const types = @import("types.zig");

const Coord = types.Coord;
const Direction = types.Direction;
const Item = types.Item;
const Weapon = types.Weapon;
const Mob = types.Mob;
const Machine = types.Machine;
const PropArrayList = types.PropArrayList;
const Container = types.Container;
const Material = types.Material;
const Vial = types.Vial;
const Prop = types.Prop;
const Stat = types.Stat;
const Resistance = types.Resistance;
const StatusDataInfo = types.StatusDataInfo;

const DIRECTIONS = types.DIRECTIONS;
const CARDINAL_DIRECTIONS = types.CARDINAL_DIRECTIONS;
const LEVELS = state.LEVELS;
const HEIGHT = state.HEIGHT;
const WIDTH = state.WIDTH;

const StackBuffer = @import("buffer.zig").StackBuffer;

// ---

pub var props: PropArrayList = undefined;
pub var prison_item_props: PropArrayList = undefined;
pub var laboratory_item_props: PropArrayList = undefined;
pub var laboratory_props: PropArrayList = undefined;
pub var vault_props: PropArrayList = undefined;
pub var statue_props: PropArrayList = undefined;

pub const Terrain = struct {
    id: []const u8,
    name: []const u8,
    color: u32,
    tile: u21,
    stats: enums.EnumFieldStruct(Stat, isize, 0) = .{},
    resists: enums.EnumFieldStruct(Resistance, isize, 0) = .{},
    effects: []const StatusDataInfo = &[_]StatusDataInfo{},
    flammability: usize = 0,
    fire_retardant: bool = false,
    repairable: bool = true,
    luminescence: usize = 0,
    opacity: usize = 0,

    for_levels: []const []const u8,
    placement: TerrainPlacement,
    weight: usize,

    pub const TerrainPlacement = union(enum) {
        EntireRoom,
        RoomSpotty: usize, // place_num = min(number, room_area * number / 100),
        RoomBlob,
        RoomPortion,
    };
};

pub const DefaultTerrain = Terrain{
    .id = "t_default",
    .name = "",
    .color = colors.DOBALENE_BLUE,
    .tile = '·',

    // for_levels and placement have no effect, since this is the default
    // terrain.
    .for_levels = &[_][]const u8{"ANY"},
    .placement = .EntireRoom,

    .weight = 20,
};

pub const CarpetTerrain = Terrain{
    .id = "t_carpet",
    .name = "carpet",
    .color = 0xff5011, // orange red
    .tile = '·',
    .stats = .{ .Sneak = 2 },
    .flammability = 5,

    .for_levels = &[_][]const u8{ "PRI", "QRT" },
    .placement = .EntireRoom,
    .weight = 7,
};

pub const GravelTerrain = Terrain{
    .id = "t_gravel",
    .name = "gravel",
    .color = 0xdadada,
    .tile = ',',
    .stats = .{ .Sneak = -1 },

    .for_levels = &[_][]const u8{"CAV"},
    .placement = .EntireRoom,
    .weight = 5,
};

pub const MetalTerrain = Terrain{
    .id = "t_metal",
    .name = "metal",
    .color = 0xa0b4ce, // light steel blue
    .tile = ',',
    .resists = .{ .rElec = -25 },

    .for_levels = &[_][]const u8{ "PRI", "LAB", "QRT" },
    .placement = .RoomPortion,
    .weight = 5,
};

pub const CopperTerrain = Terrain{
    .id = "t_copper",
    .name = "copper",
    .color = 0xff7035, // orange red
    .tile = ',',
    .resists = .{ .rElec = -25 },
    .effects = &[_]StatusDataInfo{
        .{ .status = .Conductive, .duration = .{ .Ctx = null } },
    },

    .for_levels = &[_][]const u8{ "PRI", "LAB", "QRT" },
    .placement = .RoomPortion,
    .weight = 6,
};

pub const WoodTerrain = Terrain{
    .id = "t_wood",
    .name = "wood",
    .color = 0xdaa520, // wood
    .tile = '·',
    .stats = .{ .Sneak = -1 },
    .resists = .{ .rFire = -25, .rElec = 25 },

    .for_levels = &[_][]const u8{ "PRI", "QRT" },
    .placement = .RoomPortion,
    .weight = 5,
};

pub const ShallowWaterTerrain = Terrain{
    .id = "t_water",
    .name = "shallow water",
    .color = 0x3c73b1, // medium blue
    .tile = '≈',
    .stats = .{ .Sneak = -2 },
    .resists = .{ .rFire = 50, .rElec = -50 },
    .effects = &[_]StatusDataInfo{
        .{ .status = .Conductive, .duration = .{ .Ctx = null } },
    },
    .fire_retardant = true,

    .for_levels = &[_][]const u8{"CAV"},
    .placement = .RoomBlob,
    .weight = 3,
};

pub const LuminescentFungiTerrain = Terrain{
    .id = "t_f_lumi",
    .name = "glowing fungi",
    .color = 0x3cb371, // medium sea blue
    .tile = '"',
    .luminescence = 45,
    .flammability = 5,
    .repairable = false,

    .for_levels = &[_][]const u8{"ANY"},
    .placement = .{ .RoomSpotty = 10 },
    .weight = 8,
};

pub const DeadFungiTerrain = Terrain{
    .id = "t_f_dead",
    .name = "dead fungi",
    .color = 0xaaaaaa,
    .tile = '"',
    .opacity = 60,
    .resists = .{ .rFire = -25 },
    .flammability = 15,
    .repairable = false,

    .for_levels = &[_][]const u8{"ANY"},
    .placement = .RoomBlob,
    .weight = 5,
};

pub const TallFungiTerrain = Terrain{
    .id = "t_f_tall",
    .name = "tall fungi",
    .color = 0x0a8505,
    .tile = '&',
    .opacity = 100,
    .flammability = 20,
    .repairable = false,

    .for_levels = &[_][]const u8{ "PRI", "QRT" },
    .placement = .RoomBlob,
    .weight = 7,
};

pub const PillarTerrain = Terrain{
    .id = "t_pillar",
    .name = "pillar",
    .color = 0xffffff,
    .tile = '8',
    .stats = .{ .Evade = 25 },
    .opacity = 50,
    .repairable = false,

    .for_levels = &[_][]const u8{ "PRI", "LAB", "QRT" },
    .placement = .{ .RoomSpotty = 5 },
    .weight = 8,
};

pub const PlatformTerrain = Terrain{
    .id = "t_platform",
    .name = "platform",
    .color = 0xffffff,
    .tile = '_',
    .stats = .{ .Evade = -10, .Melee = 10, .Missile = 20, .Vision = 3 },
    .opacity = 20,

    .for_levels = &[_][]const u8{ "PRI", "LAB", "QRT" },
    .placement = .{ .RoomSpotty = 5 },
    .weight = 8,
};

pub const TERRAIN = [_]*const Terrain{
    &DefaultTerrain,
    &CarpetTerrain,
    &GravelTerrain,
    &MetalTerrain,
    &CopperTerrain,
    &WoodTerrain,
    &ShallowWaterTerrain,
    &LuminescentFungiTerrain,
    &DeadFungiTerrain,
    &TallFungiTerrain,
    &PillarTerrain,
    &PlatformTerrain,
};

pub const MACHINES = [_]Machine{
    SteamVent,
    ResearchCore,
    ElevatorMotor,
    Extractor,
    BlastFurnace,
    BatteryPack,
    TurbinePowerSupply,
    HealingGasPump,
    Brazier,
    Lamp,
    StairExit,
    NormalDoor,
    LabDoor,
    VaultDoor,
    LockedDoor,
    ParalysisGasTrap,
    PoisonGasTrap,
    ConfusionGasTrap,
    Mine,
    RechargingStation,
    Drain,
    Fountain,
};

pub const Bin = Container{ .name = "bin", .tile = '∑', .capacity = 14, .type = .Utility, .item_repeat = 20 };
pub const Barrel = Container{ .name = "barrel", .tile = 'ʊ', .capacity = 7, .type = .Eatables, .item_repeat = 0 };
pub const Cabinet = Container{ .name = "cabinet", .tile = 'π', .capacity = 5, .type = .Wearables };
//pub const Chest = Container{ .name = "chest", .tile = 'æ', .capacity = 7, .type = .Valuables };
pub const LabCabinet = Container{ .name = "cabinet", .tile = 'π', .capacity = 8, .type = .Utility, .item_repeat = 70 };
pub const VOreCrate = Container{ .name = "crate", .tile = '∐', .capacity = 21, .type = .VOres, .item_repeat = 60 };

pub const SteamVent = Machine{
    .id = "steam_vent",
    .name = "steam vent",

    .powered_tile = '=',
    .unpowered_tile = '=',

    .power_drain = 0,
    .power = 100,

    .powered_walkable = true,
    .unpowered_walkable = true,

    .on_power = struct {
        pub fn f(machine: *Machine) void {
            if (state.ticks % 40 == 0) {
                state.dungeon.atGas(machine.coord)[gas.Steam.id] += 2;
            }
        }
    }.f,
};

pub const ResearchCore = Machine{
    .id = "research_core",
    .name = "research core",

    .powered_tile = '█',
    .unpowered_tile = '▓',

    .power_drain = 0,
    .power = 100,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .on_power = powerResearchCore,
};

pub const ElevatorMotor = Machine{
    .id = "elevator_motor",
    .name = "motor",

    .powered_tile = '⊛',
    .unpowered_tile = '⊚',

    .power_drain = 0,
    .power = 100,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .on_power = powerElevatorMotor,
};

pub const Extractor = Machine{
    .id = "extractor",
    .name = "machine",

    .powered_tile = '⊟',
    .unpowered_tile = '⊞',

    .power_drain = 0,
    .power = 100,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .on_power = powerExtractor,
};

pub const BlastFurnace = Machine{
    .id = "blast_furnace",
    .name = "blast furnace",

    .powered_tile = '≡',
    .unpowered_tile = '≡',

    .power_drain = 0,
    .power = 0,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_luminescence = 100,
    .unpowered_luminescence = 0,
    .dims = true,

    .on_power = powerBlastFurnace,
};

pub const BatteryPack = Machine{
    .id = "battery_pack",
    .name = "battery pack",

    .powered_tile = 'Ÿ',
    .unpowered_tile = 'Ÿ',

    .powered_fg = 0x90a3b7,
    .unpowered_fg = 0x90a3b7,

    .power_drain = 0,
    .power = 100,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .on_power = powerNone,

    .malfunction_effect = Machine.MalfunctionEffect{
        .Electrocute = .{ .chance = 30, .damage = 2, .radius = 6 },
    },
};

pub const TurbinePowerSupply = Machine{
    .id = "turbine_power_supply",
    .name = "turbine controller",

    .powered_tile = '≡',
    .unpowered_tile = '≡',

    .power_drain = 0,
    .power = 100, // Start out fully powered

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 0,
    .unpowered_opacity = 0,

    .on_power = powerTurbinePowerSupply,
};

pub const HealingGasPump = Machine{
    .id = "healing_gas_pump",
    .name = "machine",

    .powered_tile = '█',
    .unpowered_tile = '▓',

    .power_drain = 100,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 0,
    .unpowered_opacity = 0,

    .on_power = powerHealingGasPump,
};

pub const Brazier = Machine{
    .name = "brazier",

    .powered_tile = '╋',
    .unpowered_tile = '┽',

    .powered_fg = 0xeee088,
    .unpowered_fg = 0xffffff,

    .powered_bg = 0xb7b7b7,
    .unpowered_bg = 0xaaaaaa,

    .power_drain = 0,
    .power = 100,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 1.0,
    .unpowered_opacity = 1.0,

    // maximum, could be much lower (see mapgen:placeLights)
    .powered_luminescence = 60,
    .unpowered_luminescence = 0,

    .flammability = 8,
    .malfunction_effect = Machine.MalfunctionEffect{
        .Electrocute = .{ .chance = 40, .damage = 2, .radius = 3 },
    },

    .on_power = powerNone,
};

pub const Lamp = Machine{
    .name = "lamp",

    .powered_tile = '•',
    .unpowered_tile = '○',

    .powered_fg = 0xffdf12,
    .unpowered_fg = 0x88e0ee,

    .power_drain = 0,
    .power = 100,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 1.0,
    .unpowered_opacity = 1.0,

    // maximum, could be lower (see mapgen:placeLights)
    .powered_luminescence = 100,
    .unpowered_luminescence = 0,

    .flammability = 8,
    .malfunction_effect = Machine.MalfunctionEffect{
        .Electrocute = .{ .chance = 40, .damage = 1, .radius = 5 },
    },

    .on_power = powerNone,
};

pub const StairExit = Machine{
    .id = "stair_exit",
    .name = "exit staircase",
    .powered_tile = '«',
    .unpowered_tile = '«',
    .on_power = powerStairExit,
};

pub const PoisonGasTrap = Machine{
    .name = "poison gas trap",
    .powered_tile = '^',
    .unpowered_tile = '^',
    .evoke_confirm = "Really trigger the poison gas trap?",
    .on_power = powerPoisonGasTrap,
};

pub const ParalysisGasTrap = Machine{
    .name = "paralysis gas trap",
    .powered_tile = '^',
    .unpowered_tile = '^',
    .evoke_confirm = "Really trigger the paralysis gas trap?",
    .on_power = powerParalysisGasTrap,
};

pub const ConfusionGasTrap = Machine{
    .name = "confusion gas trap",
    .powered_tile = '^',
    .unpowered_tile = '^',
    .evoke_confirm = "Really trigger the confusion gas trap?",
    .on_power = powerConfusionGasTrap,
};

pub const NormalDoor = Machine{
    .name = "door",
    .powered_tile = '□',
    .unpowered_tile = '■',
    .powered_fg = 0xeab530, // light wood brown
    .unpowered_fg = 0xeab530,
    .power_drain = 49,
    .powered_walkable = true,
    .unpowered_walkable = true,
    .powered_opacity = 0.2,
    .unpowered_opacity = 1.0,
    .flammability = 15,
    .can_be_jammed = true,
    .on_power = powerNone,
};

pub const LabDoor = Machine{
    .name = "door",
    .powered_tile = '+',
    .unpowered_tile = 'x',
    .powered_fg = 0xffdf10,
    .unpowered_fg = 0xffbfff,
    .power_drain = 0,
    .power = 100,
    .powered_walkable = false,
    .unpowered_walkable = true,
    .powered_opacity = 1.0,
    .unpowered_opacity = 0.0,
    .flammability = 15,
    .can_be_jammed = true,
    .on_power = powerLabDoor,
};

pub const VaultDoor = Machine{
    .name = "door",
    .powered_tile = '░',
    .unpowered_tile = '+',
    .powered_fg = 0xaaaaaa,
    .unpowered_bg = 0xffffff,
    .unpowered_fg = 0x000000,
    .power_drain = 49,
    .powered_walkable = true,
    .unpowered_walkable = false,
    .powered_opacity = 0.0,
    .unpowered_opacity = 1.0,
    .flammability = 15,
    .can_be_jammed = true,
    .on_power = powerNone,
};

pub const LockedDoor = Machine{
    .name = "locked door",
    .powered_tile = '□',
    .unpowered_tile = '■',
    .unpowered_fg = 0xcfcfff,
    .power_drain = 90,
    .restricted_to = .Necromancer,
    .powered_walkable = true,
    .unpowered_walkable = false,
    .flammability = 15,
    .can_be_jammed = true,
    .on_power = powerNone,
    .pathfinding_penalty = 5,
};

pub const Mine = Machine{
    .name = "mine",
    .powered_fg = 0xff34d7,
    .unpowered_fg = 0xff3434,
    .powered_tile = ':',
    .unpowered_tile = ':',
    .power_drain = 0, // Stay powered on once activated
    .on_power = powerMine,
    .flammability = 15,
    .malfunction_effect = .{ .Explode = .{ .chance = 50, .power = 80 } },
    .pathfinding_penalty = 10,
};

pub const RechargingStation = Machine{
    .id = "recharging_station",
    .name = "recharging station",
    .announce = true,
    .powered_tile = 'R',
    .unpowered_tile = 'x',
    .powered_fg = 0x000000,
    .unpowered_fg = 0x000000,
    .bg = 0x90a3b7,
    .power_drain = 0,
    .power = 100,
    .on_power = powerNone,
    .flammability = 15,
    .interact1 = .{
        .name = "recharge",
        .success_msg = "All evocables recharged.",
        .no_effect_msg = "No evocables to recharge!",
        .max_use = 3,
        .func = interact1RechargingStation,
    },
};

pub const Drain = Machine{
    .id = "drain",
    .name = "drain",
    .announce = true,
    .powered_tile = '∩',
    .unpowered_tile = '∩',
    .powered_fg = 0x888888,
    .unpowered_fg = 0x888888,
    .powered_walkable = true,
    .unpowered_walkable = true,
    .on_power = powerNone,
    .interact1 = .{
        .name = "crawl",
        .success_msg = "You crawl into the drain and emerge from another!",
        .no_effect_msg = "You crawl into the drain, but it's a dead end!",
        .needs_power = false,
        .max_use = 1,
        .func = interact1Drain,
    },
};

pub const Fountain = Machine{
    .id = "fountain",
    .name = "fountain",
    .announce = true,
    .powered_tile = '¶',
    .unpowered_tile = '¶',
    .powered_fg = 0x00d7ff,
    .unpowered_fg = 0x00d7ff,
    .powered_walkable = true,
    .unpowered_walkable = true,
    .on_power = powerNone,
    .interact1 = .{
        .name = "quaff",
        .success_msg = "The fountain refreshes you.",
        .no_effect_msg = "The fountain is dry!",
        .needs_power = false,
        .max_use = 1,
        .func = interact1Fountain,
    },
};

fn powerNone(_: *Machine) void {}

fn powerResearchCore(machine: *Machine) void {
    // Only function on every 32nd turn, to give the impression that it takes
    // a while to process vials
    if ((state.ticks % 32) != 0 or rng.onein(3)) return;

    for (&DIRECTIONS) |direction| if (machine.coord.move(direction, state.mapgeometry)) |neighbor| {
        for (state.dungeon.itemsAt(neighbor).constSlice()) |item, i| switch (item) {
            .Vial => {
                _ = state.dungeon.itemsAt(neighbor).orderedRemove(i) catch unreachable;
                return;
            },
            else => {},
        };
    };
}

fn powerElevatorMotor(machine: *Machine) void {
    assert(machine.areas.len > 0);

    // Only function on every 32th turn or so, to give the impression that it takes
    // a while to bring up more ores
    if ((state.ticks % 32) != 0 or rng.onein(3)) return;

    for (machine.areas.constSlice()) |coord| {
        if (!state.dungeon.itemsAt(coord).isFull()) {
            var material: ?*const Material = null;

            material = (rng.choose(Vial.OreAndVial, &Vial.VIAL_ORES, &Vial.VIAL_COMMONICITY) catch unreachable).m;

            if (material) |mat| {
                state.dungeon.itemsAt(coord).append(Item{ .Boulder = mat }) catch unreachable;
            }
        }
    }
}

fn powerExtractor(machine: *Machine) void {
    assert(machine.areas.len == 2);

    // Only function on every 32th turn, to give the impression that it takes
    // a while to extract more vials
    if ((state.ticks % 32) != 0) return;

    var input = machine.areas.data[0];
    var output = machine.areas.data[1];

    if (state.dungeon.itemsAt(output).isFull())
        return;

    // TODO: don't eat items that can't be processed

    var input_item: ?Item = null;
    if (state.dungeon.hasContainer(input)) |container| {
        if (container.items.len > 0) input_item = container.items.pop() catch unreachable;
    } else {
        const t_items = state.dungeon.itemsAt(input);
        if (t_items.len > 0) input_item = t_items.pop() catch unreachable;
    }

    if (input_item != null) switch (input_item.?) {
        .Boulder => |b| for (&Vial.VIAL_ORES) |vd| if (vd.m) |m|
            if (mem.eql(u8, m.name, b.name)) {
                state.dungeon.itemsAt(output).append(Item{ .Vial = vd.v }) catch unreachable;
                state.dungeon.atGas(machine.coord)[gas.Dust.id] = rng.range(f64, 0.1, 0.2);
            },
        else => {},
    };
}

fn powerBlastFurnace(machine: *Machine) void {
    assert(machine.areas.len == 9);

    // Only function on every 8th turn, to give the impression that it takes
    // a while to smelt more ores
    if ((state.ticks % 8) != 0) return;

    const areas = machine.areas.constSlice();
    const input_areas = areas[0..4];
    const furnace_area = areas[4];
    const output_areas = areas[5..7];
    //const refuse_areas = areas[7..9];

    // Move input items to furnace
    for (input_areas) |input_area| {
        if (state.dungeon.itemsAt(furnace_area).isFull())
            break;

        var input_item: ?Item = null;
        if (state.dungeon.hasContainer(input_area)) |container| {
            if (container.items.len > 0) input_item = container.items.pop() catch unreachable;
        } else {
            const t_items = state.dungeon.itemsAt(input_area);
            if (t_items.len > 0) input_item = t_items.pop() catch unreachable;
        }

        if (input_item) |item| {
            // XXX: it may be desirable later to handle this in a cleaner manner
            assert(meta.activeTag(item) == .Boulder);

            state.dungeon.itemsAt(furnace_area).append(item) catch unreachable;
            return;
        }
    }

    // Process items in furnace area and move to output area.
    var output_spot: ?Coord = null;
    for (output_areas) |output_area| {
        if (state.dungeon.hasContainer(output_area)) |container| {
            if (!container.items.isFull()) {
                output_spot = output_area;
                break;
            }
        } else {
            if (!state.dungeon.itemsAt(output_area).isFull()) {
                output_spot = output_area;
                break;
            }
        }
    }

    if (output_spot != null and state.dungeon.itemsAt(furnace_area).len > 0) {
        const item = state.dungeon.itemsAt(furnace_area).pop() catch unreachable;

        // XXX: it may be desirable later to handle this in a cleaner manner
        assert(meta.activeTag(item) == .Boulder);

        const result_mat = item.Boulder.smelt_result.?;
        state.dungeon.itemsAt(output_spot.?).append(Item{ .Boulder = result_mat }) catch unreachable;
    }
}

fn powerTurbinePowerSupply(machine: *Machine) void {
    assert(machine.areas.len > 0);

    var steam: f64 = 0.0;

    for (machine.areas.constSlice()) |area| {
        const prop = state.dungeon.at(area).surface.?.Prop;

        // Anathema, we're modifying a game object this way! the horrors!
        prop.tile = switch (prop.tile) {
            '◴' => rng.chooseUnweighted(u21, &[_]u21{ '◜', '◠', '◝', '◡' }),
            '◜' => '◠',
            '◠' => '◝',
            '◝' => '◟',
            '◟' => '◡',
            '◡' => '◞',
            '◞' => '◜',
            else => unreachable,
        };

        steam += state.dungeon.atGas(area)[gas.Steam.id];
    }
}

fn powerHealingGasPump(machine: *Machine) void {
    assert(machine.areas.len > 0);

    for (machine.areas.constSlice()) |coord| {
        state.dungeon.atGas(coord)[gas.Healing.id] = 1.0;
    }
}

fn powerPoisonGasTrap(machine: *Machine) void {
    if (machine.last_interaction) |culprit| {
        if (culprit.allegiance == .Necromancer) return;

        for (machine.props) |maybe_prop| {
            if (maybe_prop) |vent| {
                state.dungeon.atGas(vent.coord)[gas.Poison.id] = 1.0;
            }
        }

        if (culprit == state.player)
            state.message(.Trap, "Noxious fumes seep through the gas vents!", .{});

        machine.disabled = true;
        state.dungeon.at(machine.coord).surface = null;
    }
}

fn powerParalysisGasTrap(machine: *Machine) void {
    if (machine.last_interaction) |culprit| {
        if (culprit.allegiance == .Necromancer) return;

        for (machine.props) |maybe_prop| {
            if (maybe_prop) |vent| {
                state.dungeon.atGas(vent.coord)[gas.Paralysis.id] = 1.0;
            }
        }

        if (culprit == state.player)
            state.message(.Trap, "Paralytic gas seeps out of the gas vents!", .{});

        machine.disabled = true;
        state.dungeon.at(machine.coord).surface = null;
    }
}

fn powerConfusionGasTrap(machine: *Machine) void {
    if (machine.last_interaction) |culprit| {
        if (culprit.allegiance == .Necromancer) return;

        for (machine.props) |maybe_prop| {
            if (maybe_prop) |vent| {
                state.dungeon.atGas(vent.coord)[gas.Confusion.id] = 1.0;
            }
        }

        if (culprit == state.player)
            state.message(.Trap, "Confusing gas seeps out of the gas vents!", .{});

        machine.disabled = true;
        state.dungeon.at(machine.coord).surface = null;
    }
}

fn powerStairExit(machine: *Machine) void {
    assert(machine.coord.z == 0);
    if (machine.last_interaction) |culprit| {
        if (!culprit.coord.eq(state.player.coord)) return;
        state.state = .Win;
    }
}

fn powerLabDoor(machine: *Machine) void {
    var has_mob = if (state.dungeon.at(machine.coord).mob != null) true else false;
    for (&DIRECTIONS) |d| {
        if (has_mob) break;
        if (machine.coord.move(d, state.mapgeometry)) |neighbor| {
            if (state.dungeon.at(neighbor).mob != null) has_mob = true;
        }
    }

    if (has_mob) {
        machine.powered_tile = '\\';
        machine.powered_walkable = true;
        machine.powered_opacity = 0.0;
    } else {
        machine.powered_tile = '+';
        machine.powered_walkable = false;
        machine.powered_opacity = 1.0;
    }
}

fn powerMine(machine: *Machine) void {
    if (machine.last_interaction) |mob|
        if (mob == state.player) {
            // Deactivate.
            // TODO: either one of two things should be done:
            //       - Make it so that goblins won't trigger it, and make use of the
            //         restricted_to field on this machine.
            //       - Add a restricted_from field to ensure player won't trigger it.
            machine.power = 0;
            return;
        };

    if (rng.tenin(25)) {
        state.dungeon.at(machine.coord).surface = null;
        machine.disabled = true;

        explosions.kaboom(machine.coord, .{
            .strength = 3 * 100,
            .culprit = state.player,
        });
    }
}

fn interact1RechargingStation(_: *Machine, by: *Mob) bool {
    // XXX: All messages are printed in invokeRecharger().
    assert(by == state.player);

    var num_recharged: usize = 0;
    for (state.player.inventory.pack.slice()) |item| switch (item) {
        .Evocable => |e| if (e.rechargable and e.charges < e.max_charges) {
            e.charges = e.max_charges;
            num_recharged += 1;
        },
        else => {},
    };

    return num_recharged > 0;
}

fn interact1Drain(machine: *Machine, mob: *Mob) bool {
    assert(mob == state.player);

    var drains = StackBuffer(*Machine, 32).init(null);
    for (state.dungeon.map[state.player.coord.z]) |*row| {
        for (row) |*tile| {
            if (tile.surface) |s|
                if (meta.activeTag(s) == .Machine and
                    s.Machine != machine and
                    mem.eql(u8, s.Machine.id, "drain"))
                {
                    drains.append(s.Machine) catch err.wat();
                };
        }
    }

    if (drains.len == 0) {
        return false;
    }
    const drain = rng.chooseUnweighted(*Machine, drains.constSlice());

    const succeeded = mob.teleportTo(drain.coord, null, true);
    assert(succeeded);

    if (rng.onein(3)) {
        mob.addStatus(.Nausea, 0, .{ .Tmp = 10 });
    }

    return true;
}

fn interact1Fountain(_: *Machine, mob: *Mob) bool {
    assert(mob == state.player);

    const HP = state.player.HP;
    state.player.HP = math.clamp(HP + ((state.player.max_HP - HP) / 2), 0, state.player.max_HP);

    // Remove some harmful statuses.
    state.player.cancelStatus(.Fire);
    state.player.cancelStatus(.Poison);
    state.player.cancelStatus(.Nausea);
    state.player.cancelStatus(.Pain);

    return true;
}

// ----------------------------------------------------------------------------

pub fn readProps(alloc: mem.Allocator) void {
    const PropData = struct {
        id: []u8 = undefined,
        name: []u8 = undefined,
        tile: u21 = undefined,
        fg: ?u32 = undefined,
        bg: ?u32 = undefined,
        walkable: bool = undefined,
        opacity: f64 = undefined,
        flammability: usize = undefined,
        function: Function = undefined,
        holder: bool = undefined,

        pub const Function = enum { Laboratory, Vault, LaboratoryItem, Statue, None };
    };

    props = PropArrayList.init(alloc);
    prison_item_props = PropArrayList.init(alloc);
    laboratory_item_props = PropArrayList.init(alloc);
    laboratory_props = PropArrayList.init(alloc);
    vault_props = PropArrayList.init(alloc);
    statue_props = PropArrayList.init(alloc);

    const data_dir = std.fs.cwd().openDir("data", .{}) catch unreachable;
    const data_file = data_dir.openFile("props.tsv", .{
        .read = true,
        .lock = .None,
    }) catch unreachable;

    var rbuf: [65535]u8 = undefined;
    const read = data_file.readAll(rbuf[0..]) catch unreachable;

    const result = tsv.parse(
        PropData,
        &[_]tsv.TSVSchemaItem{
            .{ .field_name = "id", .parse_to = []u8, .parse_fn = tsv.parseUtf8String },
            .{ .field_name = "name", .parse_to = []u8, .parse_fn = tsv.parseUtf8String },
            .{ .field_name = "tile", .parse_to = u21, .parse_fn = tsv.parseCharacter },
            .{ .field_name = "fg", .parse_to = ?u32, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = null },
            .{ .field_name = "bg", .parse_to = ?u32, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = null },
            .{ .field_name = "walkable", .parse_to = bool, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = true },
            .{ .field_name = "opacity", .parse_to = f64, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = 0.0 },
            .{ .field_name = "flammability", .parse_to = usize, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = 0 },
            .{ .field_name = "function", .parse_to = PropData.Function, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = .None },
            .{ .field_name = "holder", .parse_to = bool, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = false },
        },
        .{},
        rbuf[0..read],
        alloc,
    );

    if (!result.is_ok()) {
        err.bug(
            "Cannot read props: {} (line {}, field {})",
            .{ result.Err.type, result.Err.context.lineno, result.Err.context.field },
        );
    } else {
        const propdatas = result.unwrap();
        defer propdatas.deinit();

        for (propdatas.items) |propdata| {
            const prop = Prop{
                .id = propdata.id,
                .name = propdata.name,
                .tile = propdata.tile,
                .fg = propdata.fg,
                .bg = propdata.bg,
                .walkable = propdata.walkable,
                .flammability = propdata.flammability,
                .opacity = propdata.opacity,
                .holder = propdata.holder,
            };

            switch (propdata.function) {
                .Laboratory => laboratory_props.append(prop) catch err.oom(),
                .LaboratoryItem => laboratory_item_props.append(prop) catch err.oom(),
                .Vault => vault_props.append(prop) catch err.oom(),
                .Statue => statue_props.append(prop) catch err.oom(),
                else => {},
            }

            props.append(prop) catch unreachable;
        }

        std.log.info("Loaded {} props.", .{props.items.len});
    }
}

pub fn freeProps(alloc: mem.Allocator) void {
    for (props.items) |prop| prop.deinit(alloc);

    props.deinit();
    prison_item_props.deinit();
    laboratory_item_props.deinit();
    laboratory_props.deinit();
    vault_props.deinit();
    statue_props.deinit();
}

pub fn tickMachines(level: usize) void {
    var y: usize = 0;
    while (y < HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < WIDTH) : (x += 1) {
            const coord = Coord.new2(level, x, y);
            if (state.dungeon.at(coord).surface == null or
                meta.activeTag(state.dungeon.at(coord).surface.?) != .Machine)
                continue;

            const machine = state.dungeon.at(coord).surface.?.Machine;
            if (machine.disabled)
                continue;

            if (machine.isPowered()) {
                machine.on_power(machine);
                machine.power = machine.power -| machine.power_drain;
            } else if (state.dungeon.at(machine.coord).broken and machine.malfunctioning) {
                if (machine.malfunction_effect) |effect| switch (effect) {
                    .Electrocute => |e| {
                        var zy: usize = coord.y -| e.radius;
                        find_mob: while (zy < math.min(zy + e.radius, HEIGHT)) : (zy += 1) {
                            var zx: usize = coord.x -| e.radius;
                            while (zx < math.min(zx + e.radius, WIDTH)) : (zx += 1) {
                                const zcoord = Coord.new2(level, zx, zy);
                                if (state.dungeon.at(zcoord).mob == null or
                                    !utils.hasClearLOF(coord, zcoord) or
                                    state.dungeon.at(zcoord).mob.?.resistance(.rElec) == 0)
                                {
                                    continue;
                                }

                                if (rng.tenin(e.chance)) {
                                    spells.BOLT_LIGHTNING.use(null, coord, zcoord, .{
                                        .spell = &spells.BOLT_LIGHTNING,
                                        .caster_name = machine.name,
                                        .power = e.damage,
                                    }, "The broken {0s} shoots a spark!");
                                    break :find_mob;
                                }
                            }
                        }
                    },
                    .Explode => |e| {
                        if (rng.tenin(e.chance)) {
                            explosions.kaboom(coord, .{ .strength = e.power });
                        } else if (state.player.cansee(coord)) {
                            state.message(.Info, "The broken {s} hums ominously!", .{machine.name});
                        }
                    },
                };
            }
        }
    }
}
