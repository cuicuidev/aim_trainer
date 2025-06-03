const std = @import("std");

const rl = @import("raylib");

const scen = @import("../scen/root.zig");
const bot = @import("../bot/root.zig");

pub const Benchmark = struct {
    allocator: std.mem.Allocator,
    prng_ptr: *std.Random.Xoshiro256,
    scenario_lookup: scen.ScenarioLookup,
    at: usize,

    const Self = @This();

    pub fn default(allocator: std.mem.Allocator, prng_ptr: *std.Random.Xoshiro256) !Self {
        const scenario_lookup = try scen.ScenarioLookup.init(allocator, 3);

        return .{
            .allocator = allocator,
            .prng_ptr = prng_ptr,
            .scenario_lookup = scenario_lookup,
            .at = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        std.debug.print("benchmark.deinit() called\n", .{});

        self.scenario_lookup.deinit();
    }

    fn next(self: *Self) void {
        self.at += 1;
    }

    pub fn setScore(self: *Self, score: f64) void {
        self.scores[self.at] = score;
    }

    pub fn nextScenario(self: *Self) !scen.Scenario {
        const scenario = try scen.Scenario.fromConfig(
            self.allocator,
            self.scenario_lookup.scenario_configs[self.at],
            self.prng_ptr,
        );
        self.next();
        return scenario;
    }

    pub fn reset(self: *Self) void {
        self.at = 0;
    }
};

// const sin_wander = bot.mov.modifiers.sinusoidal.SinusoidalWanderModifier{
//     .amplitude = 20.0,
//     .freq = 2.0,
// };

// var modifiers_arr = try allocator.alloc(bot.mov.modifiers.MovementModule, 1);
// var vel_constraints_arr = try allocator.alloc(bot.mov.constraints.VelocityConstraintModule, 2);
// var acc_constraints_arr = try allocator.alloc(bot.mov.constraints.AccelConstraintModule, 1);

// // TODO: FIX RANDOMSTATE SEGFAULT
// // const noise_wander = bot.mov.modifiers.noise.NoiseWanderModifier{
// //     .strength = 3.0,
// //     .random_state_ptr = random_state_ptr,
// // };

// const min_speed = bot.mov.constraints.velocity.MinSpeedConstraint{ .min_speed = 12.0 };

// const max_speed = bot.mov.constraints.velocity.MaxSpeedConstraint{ .max_speed = 20.0 };

// const bias = bot.mov.constraints.acceleration.PointBiasConstraint{
//     .point = rl.Vector3.init(50.0, 2.0, 0.0),
//     .strength = 2.0,
// };

// modifiers_arr[0] = sin_wander.toModule(1.0);
// // modifiers_arr[1] = noise_wander.toModule(1.0);

// vel_constraints_arr[0] = min_speed.toModule();
// vel_constraints_arr[1] = max_speed.toModule();

// acc_constraints_arr[0] = bias.toModule();

// const KINETIC_CONFIG = bot.mov.kinetic.KineticConfig{
//     .constraints = bot.mov.constraints.Constraints{
//         .accel_constraints = acc_constraints_arr,
//         .velocity_constraints = vel_constraints_arr,
//     },
//     .modifiers = bot.mov.modifiers.MovementModifiers{
//         .modules = modifiers_arr,
//     },
// };

// const spawn_1 = scen.Spawn.init(
//     rl.Vector3.init(50.0, 2.0, 0.0),
//     rl.Vector3.init(1.0, 0.0, 0.0),
//     rl.Vector3.init(0.0, 0.0, 1.0),
//     rl.Vector3.init(0.0, 1.0, 0.0),
//     30.0,
//     15.0,
//     10.0,
// );

// const bot_config_1 = bot.BotConfig{
//     .n_bots = 1,
//     .bot_initial_position = spawn_1.origin,
//     .geometry = bot.Geometry{
//         .capsule = bot.geo.Capsule.init(
//             spawn_1.origin,
//             1.0,
//             5.0,
//             rl.Color.red,
//             KINETIC_CONFIG,
//         ),
//     },
// };

// scenarios[1] = try scen.Scenario.init(
//     allocator,
//     spawn_1,
//     bot_config_1,
//     scen.ScenarioType{
//         .tracking = scen.Tracking{},
//     },
// );
