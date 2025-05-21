const std = @import("std");
const rl = @import("raylib");

const geo = @import("geometry/root.zig");
const mov = @import("movement/root.zig");

pub const BotConfig = struct {
    n_bots: usize,
    geometry: geo.Geometry,
    bot_initial_position: ?rl.Vector3 = null,
};

pub const Bot = struct {
    geometry: geo.Geometry,

    const Self = @This();

    pub fn init(geometry: geo.Geometry) Self {
        return .{
            .geometry = geometry,
        };
    }

    pub fn draw(self: *Self) void {
        self.geometry.draw();
    }

    pub fn hitScan(self: *Self, camera: *rl.Camera3D) ?rl.Vector3 {
        return self.geometry.hitScan(camera);
    }

    pub fn step(self: *Self, dt: f32) void {
        self.geometry.kineticHandlerStep(dt);
    }

    pub fn setPosition(self: *Self, position: rl.Vector3) void {
        self.geometry.setPosition(position);
    }
};
