const std = @import("std");
const rl = @import("raylib");

const geo = @import("geometry.zig");

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

    pub fn update(self: *Self, position: rl.Vector3, radius: f32, color: rl.Color, height: ?f32) void {
        self.geometry.update(position, radius, color, height);
    }
};
