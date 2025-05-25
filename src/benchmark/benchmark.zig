const std = @import("std");

const rl = @import("raylib");

const scen = @import("../scen/root.zig");
const bot = @import("../bot/root.zig");
const rand = @import("../rand/root.zig");

pub const Benchmark = struct {
    allocator: std.mem.Allocator,
    scenarios: []const scen.Scenario,
    scores: []f64,
    at: usize,

    const Self = @This();

    pub fn default(allocator: std.mem.Allocator, random_state_ptr: *rand.RandomState) !Self {
        var scenarios = try allocator.alloc(scen.Scenario, 2);
        const scores = try allocator.alloc(f64, 2);

        var modifiers_arr = try allocator.alloc(bot.mov.modifiers.MovementModule, 2);
        var vel_constraints_arr = try allocator.alloc(bot.mov.constraints.VelocityConstraintModule, 2);
        var acc_constraints_arr = try allocator.alloc(bot.mov.constraints.AccelConstraintModule, 1);

        const spawn_0 = scen.Spawn.init(
            random_state_ptr,
            rl.Vector3.init(50.0, 2.0, 0.0),
            rl.Vector3.init(1.0, 0.0, 0.0),
            rl.Vector3.init(0.0, 0.0, 1.0),
            rl.Vector3.init(0.0, 1.0, 0.0),
            60.0,
            30.0,
            0.01,
        );

        const bot_config_0 = bot.BotConfig{
            .n_bots = 3,
            .bot_initial_position = null,
            .geometry = bot.Geometry{
                .sphere = bot.geo.Sphere.init(
                    spawn_0.origin,
                    0.3,
                    rl.Color.red,
                    STATIC_CONFIG,
                ),
            },
        };

        scenarios[0] = try scen.Scenario.init(
            allocator,
            spawn_0,
            bot_config_0,
            scen.ScenarioType{
                .clicking = scen.Clicking{},
            },
        );

        const sin_wander = bot.mov.modifiers.sinusoidal.SinusoidalWanderModifier{
            .amplitude = 20.0,
            .freq = 2.0,
        };

        const noise_wander = bot.mov.modifiers.noise.NoiseWanderModifier{
            .strength = 3.0,
            .random_state_ptr = random_state_ptr,
        };

        const min_speed = bot.mov.constraints.velocity.MinSpeedConstraint{ .min_speed = 12.0 };

        const max_speed = bot.mov.constraints.velocity.MaxSpeedConstraint{ .max_speed = 20.0 };

        const bias = bot.mov.constraints.acceleration.PointBiasConstraint{
            .point = rl.Vector3.init(50.0, 2.0, 0.0),
            .strength = 2.0,
        };

        modifiers_arr[0] = sin_wander.toModule(1.0);
        modifiers_arr[1] = noise_wander.toModule(1.0);

        vel_constraints_arr[0] = min_speed.toModule();
        vel_constraints_arr[1] = max_speed.toModule();

        acc_constraints_arr[0] = bias.toModule();

        const KINETIC_CONFIG = bot.mov.kinetic.KineticConfig{
            .constraints = bot.mov.constraints.Constraints{
                .accel_constraints = acc_constraints_arr,
                .velocity_constraints = vel_constraints_arr,
            },
            .modifiers = bot.mov.modifiers.MovementModifiers{
                .modules = modifiers_arr,
            },
        };

        const spawn_1 = scen.Spawn.init(
            random_state_ptr,
            rl.Vector3.init(50.0, 2.0, 0.0),
            rl.Vector3.init(1.0, 0.0, 0.0),
            rl.Vector3.init(0.0, 0.0, 1.0),
            rl.Vector3.init(0.0, 1.0, 0.0),
            30.0,
            15.0,
            10.0,
        );

        const bot_config_1 = bot.BotConfig{
            .n_bots = 1,
            .bot_initial_position = spawn_1.origin,
            .geometry = bot.Geometry{
                .capsule = bot.geo.Capsule.init(
                    spawn_1.origin,
                    1.0,
                    5.0,
                    rl.Color.red,
                    KINETIC_CONFIG,
                ),
            },
        };

        scenarios[1] = try scen.Scenario.init(
            allocator,
            spawn_1,
            bot_config_1,
            scen.ScenarioType{
                .tracking = scen.Tracking{},
            },
        );

        return .{
            .allocator = allocator,
            .scenarios = scenarios,
            .scores = scores,
            .at = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.scenarios) |*s| {
            @constCast(s).deinit();
        }
        self.allocator.free(self.scenarios);
        self.allocator.free(self.scores);
    }

    pub fn next(self: *Self) void {
        self.at += 1;
    }

    pub fn setScore(self: *Self, score: f64) void {
        self.scores[self.at] = score;
    }

    pub fn scenario(self: *Self) scen.Scenario {
        return self.scenarios[self.at];
    }

    pub fn reset(self: *Self) void {
        self.at = 0;
    }
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

// -----------------------------------------------------------------------------------------------
