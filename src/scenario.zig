const std = @import("std");

const rl = @import("raylib");

const bot = @import("bot.zig");
const sp = @import("spawn.zig");
const geo = @import("geometry/root.zig");

const mov = @import("movement/root.zig");

pub fn OneWallThreeTargetsSmall(comptime distance: f32) type {
    const RADIUS = 0.3;
    const COLOR = rl.Color.red;

    return struct {
        spawn: sp.Spawn,
        bots: [3]bot.Bot,
        last_hit: ?rl.Vector3,
        n_clicks: usize,
        n_hits: usize,

        const Self = @This();

        pub fn init(camera: *rl.Camera3D) Self {
            var spawn = sp.Spawn.init(camera, distance, 60.0, 30.0, 0.01);
            return .{
                .spawn = spawn,
                .bots = .{
                    bot.Bot.init(geo.Geometry{ .sphere = geo.Sphere.init(
                        spawn.getRandomPosition(),
                        RADIUS,
                        COLOR,
                        STATIC_CONFIG,
                    ) }),
                    bot.Bot.init(geo.Geometry{ .sphere = geo.Sphere.init(
                        spawn.getRandomPosition(),
                        RADIUS,
                        COLOR,
                        STATIC_CONFIG,
                    ) }),
                    bot.Bot.init(geo.Geometry{ .sphere = geo.Sphere.init(
                        spawn.getRandomPosition(),
                        RADIUS,
                        COLOR,
                        STATIC_CONFIG,
                    ) }),
                },
                .last_hit = null,
                .n_clicks = 0,
                .n_hits = 0,
            };
        }

        pub fn draw(self: *Self) void {
            self.spawn.draw(rl.Color.green);

            for (&self.bots) |*b| {
                b.draw();
            }
        }

        pub fn kill(self: *Self, camera: *rl.Camera3D) void {
            for (&self.bots) |*b| {
                const delta = rl.getFrameTime();
                b.step(delta);
            }
            if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
                var i: usize = 0;

                while (i < self.bots.len) : (i += 1) {
                    if (self.bots[i].hitScan(camera)) |hit_vec| {
                        const new_bot = bot.Bot.init(geo.Geometry{ .sphere = geo.Sphere.init(
                            self.spawn.getRandomPosition(),
                            RADIUS,
                            COLOR,
                            STATIC_CONFIG,
                        ) });

                        self.bots[i] = new_bot;
                        self.last_hit = hit_vec;
                        self.n_hits += 1;
                        std.debug.print("Hits: {} | Clicks {}\n", .{ self.n_hits, self.n_clicks });
                        break;
                    }
                }

                self.n_clicks += 1;
            }
        }

        pub fn getScore(self: *Self) f64 {
            if (self.n_clicks == 0) {
                return 0.0;
            }
            const score = @as(f64, @floatFromInt(self.n_hits)) / @as(f64, @floatFromInt(self.n_clicks));
            return score;
        }
    };
}

pub fn RawControl(comptime distance: f32) type {
    const RADIUS = 1.0;
    // const HEIGHT = null;
    const COLOR = rl.Color.red;

    return struct {
        spawn: sp.Spawn,
        bots: [1]bot.Bot,
        last_hit: ?rl.Vector3,
        hit_frames: usize,
        total_frames: usize,

        const Self = @This();

        pub fn init(camera: *rl.Camera3D) Self {
            const spawn = sp.Spawn.init(camera, distance, 60.0, 30.0, 20.0);
            return .{
                .spawn = spawn,
                .bots = .{
                    bot.Bot.init(
                        geo.Geometry{
                            .sphere = geo.Sphere.init(
                                spawn.origin,
                                RADIUS,
                                COLOR,
                                KINETIC_CONFIG,
                            ),
                        },
                    ),
                },
                .last_hit = null,
                .hit_frames = 0.0,
                .total_frames = 0.0,
            };
        }

        pub fn draw(self: *Self) void {
            self.spawn.draw(rl.Color.green);

            for (&self.bots) |*b| {
                b.draw();
            }
        }

        pub fn kill(self: *Self, camera: *rl.Camera3D) void {
            for (&self.bots) |*b| {
                const delta = rl.getFrameTime();
                b.step(delta);
            }
            if (rl.isMouseButtonDown(rl.MouseButton.left)) {
                var i: usize = 0;

                while (i < self.bots.len) : (i += 1) {
                    if (self.bots[i].hitScan(camera)) |hit_vec| {
                        // self.bots[i].update(self.spawn.getRandomPosition(), RADIUS, COLOR, HEIGHT);
                        self.last_hit = hit_vec;
                        self.hit_frames += 1;
                        // std.debug.print("V(x={d:2.2}, y={d:2.2}, z={d:2.2})\n", .{ hit_vec.x, hit_vec.y, hit_vec.z });
                    }
                }
            }
            self.total_frames += 1;
        }

        pub fn getScore(self: *Self) f64 {
            if (self.total_frames == 0) {
                return 0.0;
            }
            const score = @as(f64, @floatFromInt(self.hit_frames)) / @as(f64, @floatFromInt(self.total_frames));
            return score;
        }
    };
}

// TODO: allocate wanderers dynamically instead of using global variables.
var sin_wander = mov.modifiers.sinusoidal.SinusoidalWanderModifier{
    .amplitude = 20.0,
    .freq = 2.0,
};

var noise_wander = mov.modifiers.noise.NoiseWanderModifier{
    .strength = 3.0,
};

var min_speed = mov.constraints.velocity.MinSpeedConstraint{ .min_speed = 12.0 };

var max_speed = mov.constraints.velocity.MaxSpeedConstraint{ .max_speed = 20.0 };

var bias = mov.constraints.acceleration.PointBiasConstraint{
    .point = rl.Vector3.init(50.0, 2.0, 0.0),
    .strength = 2.0,
};

const modifiers_arr = [2]mov.modifiers.MovementModule{
    sin_wander.toModule(1.0),
    noise_wander.toModule(1.0),
};

const modifiers = mov.modifiers.MovementModifiers{
    .modules = &modifiers_arr,
};

const vel_constraints_arr = [2]mov.constraints.VelocityConstraintModule{
    min_speed.toModule(),
    max_speed.toModule(),
};

const acc_constraints_arr = [1]mov.constraints.AccelConstraintModule{
    bias.toModule(),
};

const constraints = mov.constraints.Constraints{
    .accel_constraints = &acc_constraints_arr,
    .velocity_constraints = &vel_constraints_arr,
};

const KINETIC_CONFIG = mov.kinetic.KineticConfig{
    .constraints = constraints,
    .modifiers = modifiers,
};

const STATIC_CONFIG = mov.kinetic.KineticConfig{
    .constraints = mov.constraints.Constraints{ .accel_constraints = null, .velocity_constraints = null },
    .modifiers = mov.modifiers.MovementModifiers{ .modules = null },
};
