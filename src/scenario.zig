const std = @import("std");

const rl = @import("raylib");

const bot = @import("bot.zig");
const sp = @import("spawn.zig");
const geo = @import("geometry.zig");

const mov = @import("movement/root.zig");

// pub fn OneWallThreeTargetsSmall(comptime distance: f32) type {
//     const RADIUS = 0.3;
//     const HEIGHT = null;
//     const COLOR = rl.Color.red;

//     return struct {
//         spawn: sp.SpawnPlane,
//         bots: [3]bot.Bot,
//         last_hit: ?rl.Vector3,

//         const Self = @This();

//         pub fn init(camera: *rl.Camera3D) Self {
//             var spawn = sp.SpawnPlane.init(camera, distance, 60.0, 30.0);
//             return .{
//                 .spawn = spawn,
//                 .bots = .{
//                     bot.Bot.init(geo.Geometry{ .sphere = geo.Sphere.init(spawn.getRandomPosition(), RADIUS, COLOR) }),
//                     bot.Bot.init(geo.Geometry{ .sphere = geo.Sphere.init(spawn.getRandomPosition(), RADIUS, COLOR) }),
//                     bot.Bot.init(geo.Geometry{ .sphere = geo.Sphere.init(spawn.getRandomPosition(), RADIUS, COLOR) }),
//                 },
//                 .last_hit = null,
//             };
//         }

//         pub fn draw(self: *Self) void {
//             self.spawn.draw(rl.Color.green);

//             for (&self.bots) |*b| {
//                 b.draw();
//             }
//         }

//         pub fn kill(self: *Self, camera: *rl.Camera3D) void {
//             if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
//                 var i: usize = 0;

//                 while (i < self.bots.len) : (i += 1) {
//                     if (self.bots[i].hitScan(camera)) |hit_vec| {
//                         self.bots[i].update(self.spawn.getRandomPosition(), RADIUS, COLOR, HEIGHT);
//                         self.last_hit = hit_vec;
//                         std.debug.print("V(x={d:2.2}, y={d:2.2}, z={d:2.2})\n", .{ hit_vec.x, hit_vec.y, hit_vec.z });
//                     }
//                 }
//             }
//         }
//     };
// }

pub fn RawControl(comptime distance: f32) type {
    const RADIUS = 1.0;
    // const HEIGHT = null;
    const COLOR = rl.Color.red;

    return struct {
        spawn: sp.Spawn,
        bots: [1]bot.Bot,
        last_hit: ?rl.Vector3,
        hit_frames: f64,
        total_frames: f64,

        const Self = @This();

        pub fn init(camera: *rl.Camera3D) Self {
            const spawn = sp.Spawn.init(camera, distance, 60.0, 30.0, 20.0);
            return .{
                .spawn = spawn,
                .bots = .{
                    bot.Bot.init(
                        spawn.origin,
                        geo.Geometry{ .sphere = geo.Sphere.init(RADIUS, COLOR) },
                        KINETIC_CONFIG,
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
            if (self.total_frames == 0) {
                for (&self.bots) |*b| {
                    b.syncMovGeo();
                }
            }

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
                        self.hit_frames += 1.0;
                        // std.debug.print("V(x={d:2.2}, y={d:2.2}, z={d:2.2})\n", .{ hit_vec.x, hit_vec.y, hit_vec.z });
                    }
                }
            }
            self.total_frames += 1.0;
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
