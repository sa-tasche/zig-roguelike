const state = @import("state.zig");
usingnamespace @import("types.zig");

pub const AlarmTrap = Machine{
    .name = "alarm trap",
    .tile = '^',
    .walkable = true,
    .opacity = 0.0,
    .coord = Coord.new(0, 0),
    .on_trigger = triggerAlarmTrap,
    .props = [_]?Prop{null} ** 40,
};

pub const NormalDoor = Machine{
    .name = "door",
    .tile = '+', // TODO: red background?
    .walkable = true,
    .opacity = 1.0,
    .coord = Coord.new(0, 0),
    .on_trigger = triggerNone,
    .props = [_]?Prop{null} ** 40,
};

pub fn triggerNone(_: *Mob, __: *Machine) void {}

pub fn triggerAlarmTrap(culprit: *Mob, machine: *Machine) void {
    culprit.noise += 1000; // muahahaha
}
