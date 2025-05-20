const std = @import("std");
const rl = @import("raylib");

const geo = @import("geometry.zig");

pub const Bot = struct {
    geometry: geo.Geometry,
    position: rl.Vector3,
    velocity: rl.Vector3,
    time: f32, // time tracker for sin motion

    const Self = @This();

    pub fn init(geometry: geo.Geometry) Self {
        const pos = switch (geometry) {
            .sphere => |s| s.position,
            .capsule => |c| c.position,
        };
        return .{
            .geometry = geometry,
            .position = pos,
            .velocity = rl.Vector3.init(0.0, 0.0, 0.0),
            .time = 0.0,
        };
    }

    pub fn draw(self: *Self) void {
        self.geometry.draw();
    }

    pub fn hitScan(self: *Self, camera: *rl.Camera3D) ?rl.Vector3 {
        return self.geometry.hitScan(camera);
    }

    pub fn update(self: *Self, position: rl.Vector3, radius: f32, color: rl.Color, height: ?f32) void {
        self.position = position;
        self.velocity = rl.Vector3.init(0.0, 0.0, 0.0);
        self.geometry.update(position, radius, color, height);
    }

    pub fn step(self: *Self, dt: f32, bias: rl.Vector3) void {
        // Sinusoidal + noise wandering
        self.time += dt;

        // Params
        const amplitude = 10.0;
        const freq = 2.0;
        const wander_strength = 3.0;
        const max_speed = 20.0;
        const bias_strength: f32 = 1.5;

        const ax = amplitude * @sin(self.time * freq);
        const ay = amplitude * @cos(self.time * freq * 1.2);
        const az = amplitude * @sin(self.time * freq * 0.7 + 1.0);

        // Add some noise
        const rx = (@as(f32, @floatFromInt(rl.getRandomValue(-10, 10))) / 10.0) * wander_strength;
        const ry = (@as(f32, @floatFromInt(rl.getRandomValue(-10, 10))) / 10.0) * wander_strength;
        const rz = (@as(f32, @floatFromInt(rl.getRandomValue(-10, 10))) / 10.0) * wander_strength;

        const base_accel = rl.Vector3.init(ax + rx, ay + ry, az + rz);

        const to_bias_vec = rl.Vector3.subtract(bias, self.position);
        const to_bias_squared = rl.Vector3.init(
            to_bias_vec.x * @abs(to_bias_vec.x),
            to_bias_vec.y * @abs(to_bias_vec.y),
            to_bias_vec.z * @abs(to_bias_vec.z),
        );

        const bias_accel = rl.Vector3.scale(to_bias_squared, bias_strength);

        const acceleration = rl.Vector3.add(base_accel, bias_accel);

        // Simple Euler integration
        self.velocity = rl.Vector3.add(self.velocity, rl.Vector3.scale(acceleration, dt));

        // Clamp speed
        const speed_sq = rl.Vector3.lengthSqr(self.velocity);
        if (speed_sq > max_speed * max_speed) {
            self.velocity = rl.Vector3.scale(rl.Vector3.normalize(self.velocity), max_speed);
        }

        // Update position
        self.position = rl.Vector3.add(self.position, rl.Vector3.scale(self.velocity, dt));

        // Update geometry position
        switch (self.geometry) {
            .sphere => |*s| s.position = self.position,
            .capsule => |*c| c.position = self.position,
        }
    }
};
