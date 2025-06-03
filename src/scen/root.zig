const scenario = @import("scenario.zig");
const scenarios = @import("scenarios.zig");
const spawn = @import("spawn.zig");
const tape = @import("tape.zig");

pub const Scenario = scenario.Scenario;
pub const ScenarioType = scenario.ScenarioType;
pub const Clicking = scenario.Clicking;
pub const Tracking = scenario.Tracking;

pub const Spawn = spawn.Spawn;
pub const SpawnConfig = spawn.SpawnConfig;

pub const ScenarioTape = tape.ScenarioTape;
pub const FrameInput = tape.FrameInput;

pub const ScenarioLookup = scenarios.ScenarioLookup;
