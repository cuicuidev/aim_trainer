const std = @import("std");

const rl = @import("raylib");

const bot = @import("bot.zig");
const sp = @import("spawn_plane.zig");

pub fn OneWallThreeTargetsSmall(comptime distance: f32) type {
    const geometry_type = bot.BotGeometryType.sphere;
    const geometry = bot.BotGeometry(geometry_type).init(0.3, 4.0);
    const bot_type = bot.BotType.click;
    const Bot = bot.Bot(geometry_type, geometry, bot_type);
    return struct {
        spawn: sp.SpawnPlane,
        bots: [3]Bot,
        last_hit: ?rl.Vector3,

        const Self = @This();

        pub fn init(camera: *rl.Camera3D) Self {
            var spawn = sp.SpawnPlane.init(camera, distance, 60.0, 30.0);
            return .{
                .spawn = spawn,
                .bots = .{
                    Bot.init(spawn.getRandomPosition(), rl.Color.red),

                    Bot.init(spawn.getRandomPosition(), rl.Color.red),

                    Bot.init(spawn.getRandomPosition(), rl.Color.red),
                },
                .last_hit = null,
            };
        }

        pub fn draw(self: *Self) void {
            self.spawn.draw(rl.Color.light_gray);

            for (&self.bots) |*b| {
                b.draw();
            }
        }

        pub fn kill(self: *Self, camera: *rl.Camera3D) void {
            if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
                var i: usize = 0;

                while (i < self.bots.len) : (i += 1) {
                    if (self.bots[i].hitScan(camera)) |hit_vec| {
                        self.bots[i].position = self.spawn.getRandomPosition();
                        self.last_hit = hit_vec;
                        std.debug.print("V(x={d:2.2}, y={d:2.2}, z={d:2.2})\n", .{ hit_vec.x, hit_vec.y, hit_vec.z });
                    }
                }
            }
        }
    };
}
