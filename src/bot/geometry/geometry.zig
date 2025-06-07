const std = @import("std");

const rl = @import("raylib");

const mov = @import("../movement/root.zig");

const sphere = @import("sphere.zig");
const capsule = @import("capsule.zig");

pub const Geometry = union(enum) {
    sphere: sphere.Sphere,
    capsule: capsule.Capsule,

    const Self = @This();

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .sphere => |*g| g.deinit(allocator),
            .capsule => |*g| g.deinit(allocator),
        }
    }

    pub fn hitScan(self: *Self, camera: *rl.Camera3D) ?rl.Vector3 {
        return switch (self.*) {
            .sphere => |*g| g.hitScan(camera),
            .capsule => |*g| g.hitScan(camera),
        };
    }

    pub fn draw(self: *Self) void {
        switch (self.*) {
            .sphere => |*g| g.draw(),
            .capsule => |*g| g.draw(),
        }
    }

    pub fn kineticHandlerStep(self: *Self, dt: f32, prng_ptr: *std.Random.Xoshiro256) void {
        switch (self.*) {
            .sphere => |*g| {
                g.position = g.kinetic_handler.step(g.position, dt, prng_ptr);
            },
            .capsule => |*g| {
                g.position = g.kinetic_handler.step(g.position, dt, prng_ptr);
            },
        }
    }

    pub fn getPosition(self: *Self) rl.Vector3 {
        return switch (self.*) {
            .sphere => |*g| return g.position,
            .capsule => |*g| return g.position,
        };
    }

    pub fn setPosition(self: *Self, position: rl.Vector3) void {
        switch (self.*) {
            .sphere => |*g| {
                g.position = position;
            },
            .capsule => |*g| {
                g.position = position;
            },
        }
    }

    pub fn getRadius(self: *Self) f32 {
        return switch (self.*) {
            .sphere => |*g| return g.radius,
            .capsule => |*g| return g.radius,
        };
    }

    pub fn getHeight(self: *Self) ?f32 {
        return switch (self.*) {
            .sphere => return null,
            .capsule => |*g| return g.radius,
        };
    }

    pub fn getKineticHandler(self: *Self) mov.kinetic.KineticHandler {
        return switch (self.*) {
            .sphere => |*g| return g.kinetic_handler,
            .capsule => |*g| return g.kinetic_handler,
        };
    }
};
