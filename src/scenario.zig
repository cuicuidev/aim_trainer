const std = @import("std");

const rl = @import("raylib");

const bot = @import("bot.zig");
const sp = @import("spawn.zig");
const geo = @import("geometry.zig");

pub fn OneWallThreeTargetsSmall(comptime distance: f32) type {
    const RADIUS = 0.3;
    const HEIGHT = null;
    const COLOR = rl.Color.red;

    return struct {
        spawn: sp.SpawnPlane,
        bots: [3]bot.Bot,
        last_hit: ?rl.Vector3,

        const Self = @This();

        pub fn init(camera: *rl.Camera3D) Self {
            var spawn = sp.SpawnPlane.init(camera, distance, 60.0, 30.0);
            return .{
                .spawn = spawn,
                .bots = .{
                    bot.Bot.init(geo.Geometry{ .sphere = geo.Sphere.init(spawn.getRandomPosition(), RADIUS, COLOR) }),
                    bot.Bot.init(geo.Geometry{ .sphere = geo.Sphere.init(spawn.getRandomPosition(), RADIUS, COLOR) }),
                    bot.Bot.init(geo.Geometry{ .sphere = geo.Sphere.init(spawn.getRandomPosition(), RADIUS, COLOR) }),
                },
                .last_hit = null,
            };
        }

        pub fn draw(self: *Self) void {
            self.spawn.draw(rl.Color.green);

            for (&self.bots) |*b| {
                b.draw();
            }
        }

        pub fn kill(self: *Self, camera: *rl.Camera3D) void {
            if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
                var i: usize = 0;

                while (i < self.bots.len) : (i += 1) {
                    if (self.bots[i].hitScan(camera)) |hit_vec| {
                        self.bots[i].update(self.spawn.getRandomPosition(), RADIUS, COLOR, HEIGHT);
                        self.last_hit = hit_vec;
                        std.debug.print("V(x={d:2.2}, y={d:2.2}, z={d:2.2})\n", .{ hit_vec.x, hit_vec.y, hit_vec.z });
                    }
                }
            }
        }
    };
}

pub fn RawControl(comptime distance: f32) type {
    const RADIUS = 1.0;
    const HEIGHT = null;
    const COLOR = rl.Color.red;

    return struct {
        spawn: sp.SpawnPrism,
        bots: [1]bot.Bot,
        last_hit: ?rl.Vector3,

        const Self = @This();

        pub fn init(camera: *rl.Camera3D) Self {
            var spawn = sp.SpawnPrism.init(camera, distance, 60.0, 30.0, 20.0);
            return .{
                .spawn = spawn,
                .bots = .{
                    bot.Bot.init(geo.Geometry{ .sphere = geo.Sphere.init(spawn.getRandomPosition(), RADIUS, COLOR) }),
                },
                .last_hit = null,
            };
        }

        pub fn draw(self: *Self) void {
            self.spawn.draw(rl.Color.green);

            for (&self.bots) |*b| {
                b.draw();
            }
        }

        pub fn kill(self: *Self, camera: *rl.Camera3D) void {
            if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
                var i: usize = 0;

                while (i < self.bots.len) : (i += 1) {
                    if (self.bots[i].hitScan(camera)) |hit_vec| {
                        self.bots[i].update(self.spawn.getRandomPosition(), RADIUS, COLOR, HEIGHT);
                        self.last_hit = hit_vec;
                        std.debug.print("V(x={d:2.2}, y={d:2.2}, z={d:2.2})\n", .{ hit_vec.x, hit_vec.y, hit_vec.z });
                    }
                }
            }
        }
    };
}
