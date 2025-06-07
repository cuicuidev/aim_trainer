const scenario = @import("scenario.zig");
const scenarios = @import("scenarios.zig");
const spawn = @import("spawn.zig");

pub const Scenario = scenario.Scenario;
pub const ScenarioType = scenario.ScenarioType;
pub const Clicking = scenario.Clicking;
pub const Tracking = scenario.Tracking;

pub const Spawn = spawn.Spawn;
pub const SpawnConfig = spawn.SpawnConfig;

pub const ScenarioLookup = scenarios.ScenarioLookup;
