const std = @import("std");
const rl = @import("raylib");

const geo = @import("geometry/root.zig");
const mov = @import("movement/root.zig");

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
};
