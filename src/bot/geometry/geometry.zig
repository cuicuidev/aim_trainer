const std = @import("std");

const rl = @import("raylib");

const mov = @import("../movement/root.zig");

const sphere = @import("sphere.zig");
const capsule = @import("capsule.zig");

pub const Geometry = union(enum) {
    sphere: sphere.Sphere,
    capsule: capsule.Capsule,

    const Self = @This();

    pub fn hitScan(self: *Self, camera: *rl.Camera3D) ?rl.Vector3 {
        return switch (self.*) {
            .sphere => |*s| s.hitScan(camera),
            .capsule => |*c| c.hitScan(camera),
        };
    }

    pub fn draw(self: *Self) void {
        switch (self.*) {
            .sphere => |*s| s.draw(),
            .capsule => |*c| c.draw(),
        }
    }

    pub fn kineticHandlerStep(self: *Self, dt: f32) void {
        switch (self.*) {
            .sphere => |*s| {
                s.position = s.kinetic_handler.step(s.position, dt);
            },
            .capsule => |*c| {
                c.position = c.kinetic_handler.step(c.position, dt);
            },
        }
    }

    pub fn setPosition(self: *Self, position: rl.Vector3) void {
        switch (self.*) {
            .sphere => |*s| {
                s.position = position;
            },
            .capsule => |*c| {
                c.position = position;
            },
        }
    }
};
