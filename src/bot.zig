const std = @import("std");
const rl = @import("raylib");

const geo = @import("geometry.zig");
const mov = @import("movement/root.zig");

pub const Bot = struct {
    geometry: geo.Geometry,
    movement: mov.kinetic.KineticHandler,

    const Self = @This();

    pub fn init(position: rl.Vector3, geometry: geo.Geometry, kinetic_config: mov.kinetic.KineticConfig) Self {
        const kinetic_handler = mov.kinetic.KineticHandler.init(position, kinetic_config);
        return .{
            .geometry = geometry,
            .movement = kinetic_handler,
        };
    }

    pub fn syncMovGeo(self: *Self) void {
        self.geometry.setPosition(&self.movement.position);
    }

    pub fn draw(self: *Self) void {
        self.geometry.draw();
    }

    pub fn hitScan(self: *Self, camera: *rl.Camera3D) ?rl.Vector3 {
        return self.geometry.hitScan(camera);
    }

    pub fn update(self: *Self, position: rl.Vector3, radius: f32, color: rl.Color, height: ?f32) void {
        self.movement.position = position;
        self.movement.velocity = rl.Vector3.init(0.0, 0.0, 0.0);
        self.geometry.update(radius, color, height);
    }

    pub fn step(self: *Self, dt: f32) void {
        self.movement.step(dt);
    }
};
