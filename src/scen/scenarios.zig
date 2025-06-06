const std = @import("std");

const rl = @import("raylib");

const scen = @import("scenario.zig");
const sp = @import("spawn.zig");

const bot = @import("../bot/root.zig");

pub const ScenarioLookup = struct {
    allocator: std.mem.Allocator,
    scenario_configs: []const scen.ScenarioConfig,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, size: usize) !Self {
        const spawn = sp.Spawn.init(
            rl.Vector3.init(50.0, 2.0, 0.0),
            rl.Vector3.init(1.0, 0.0, 0.0),
            rl.Vector3.init(0.0, 0.0, 1.0),
            rl.Vector3.init(0.0, 1.0, 0.0),
            60.0,
            30.0,
            0.01,
        );

        const wide_wall_2_targets_small_conf = scen.ScenarioConfig{
            .bot_config = bot.BotConfig{
                .n_bots = 2,
                .bot_initial_position = null,
                .geometry = bot.Geometry{
                    .sphere = bot.geo.Sphere.init(
                        spawn.origin,
                        0.3,
                        rl.Color.red,
                        STATIC_CONFIG,
                    ),
                },
            },
            .spawn = spawn,
            .duration = 10.0,
            .scenario_type = scen.ScenarioType{ .clicking = scen.Clicking{} },
            .name = "ww2ts",
        };

        const wide_wall_3_targets_small_conf = scen.ScenarioConfig{
            .bot_config = bot.BotConfig{
                .n_bots = 3,
                .bot_initial_position = null,
                .geometry = bot.Geometry{
                    .sphere = bot.geo.Sphere.init(
                        spawn.origin,
                        0.3,
                        rl.Color.red,
                        STATIC_CONFIG,
                    ),
                },
            },
            .spawn = spawn,
            .duration = 10.0,
            .scenario_type = scen.ScenarioType{ .clicking = scen.Clicking{} },
            .name = "ww3ts",
        };

        const wide_wall_4_targets_small_conf = scen.ScenarioConfig{
            .bot_config = bot.BotConfig{
                .n_bots = 4,
                .bot_initial_position = null,
                .geometry = bot.Geometry{
                    .sphere = bot.geo.Sphere.init(
                        spawn.origin,
                        0.3,
                        rl.Color.red,
                        STATIC_CONFIG,
                    ),
                },
            },
            .spawn = spawn,
            .duration = 10.0,
            .scenario_type = scen.ScenarioType{ .clicking = scen.Clicking{} },
            .name = "ww4ts",
        };

        // Tracking
        const controlsphere = scen.ScenarioConfig{
            .bot_config = bot.BotConfig{
                .n_bots = 1,
                .bot_initial_position = spawn.origin,
                .geometry = bot.Geometry{
                    .capsule = bot.geo.Capsule.init(
                        spawn.origin,
                        0.3,
                        0.9,
                        rl.Color.red,
                        KINETIC_CONFIG,
                    ),
                },
            },
            .spawn = spawn,
            .duration = 10.0,
            .scenario_type = scen.ScenarioType{ .tracking = scen.Tracking{} },
            .name = "controlsphere",
        };

        var config = try allocator.alloc(scen.ScenarioConfig, size);
        config[0] = wide_wall_2_targets_small_conf;
        config[1] = wide_wall_3_targets_small_conf;
        config[2] = wide_wall_4_targets_small_conf;
        config[1] = controlsphere;
        return .{
            .allocator = allocator,
            .scenario_configs = config,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.scenario_configs);
    }

    pub fn get(self: *Self, scenario_name: []const u8) ?scen.ScenarioConfig {
        for (self.scenario_configs) |conf| {
            if (std.mem.eql(u8, conf.name, scenario_name)) {
                return conf;
            }
        }
        return null;
    }
};

// TODO: FIX RANDOMSTATE SEGFAULT
// const noise_wander = bot.mov.modifiers.noise.NoiseWanderModifier{
//     .strength = 3.0,
//     .random_state_ptr = random_state_ptr,
// };

const sin_wander = bot.mov.modifiers.sinusoidal.SinusoidalWanderModifier{
    .amplitude = 20.0,
    .freq = 2.0,
};

const min_speed = bot.mov.constraints.velocity.MinSpeedConstraint{ .min_speed = 12.0 };

const max_speed = bot.mov.constraints.velocity.MaxSpeedConstraint{ .max_speed = 20.0 };

const bias = bot.mov.constraints.acceleration.PointBiasConstraint{
    .point = rl.Vector3.init(50.0, 2.0, 0.0),
    .strength = 2.0,
};

var modifiers_arr: [1]bot.mov.modifiers.MovementModule = .{
    sin_wander.toModule(1.0),
    // noise_wander.toModule(1.0),
};
var vel_constraints_arr: [2]bot.mov.constraints.VelocityConstraintModule = .{
    min_speed.toModule(),
    max_speed.toModule(),
};
var acc_constraints_arr: [1]bot.mov.constraints.AccelConstraintModule = .{
    bias.toModule(),
};

const KINETIC_CONFIG = bot.mov.kinetic.KineticConfig{
    .constraints = bot.mov.constraints.Constraints{
        .accel_constraints = &acc_constraints_arr,
        .velocity_constraints = &vel_constraints_arr,
    },
    .modifiers = bot.mov.modifiers.MovementModifiers{
        .modules = &modifiers_arr,
    },
};

const STATIC_CONFIG = bot.mov.kinetic.KineticConfig{
    .constraints = bot.mov.constraints.Constraints{
        .accel_constraints = null,
        .velocity_constraints = null,
    },
    .modifiers = bot.mov.modifiers.MovementModifiers{
        .modules = null,
    },
};
