const std = @import("std");

const rl = @import("raylib");

const bot = @import("bot.zig");

pub const SpawnPlane = struct {
    origin: rl.Vector3,
    right: rl.Vector3, // direction vector along the plane's width
    forward: rl.Vector3, // direction vector along the plane's height
    width: f32,
    height: f32,

    const Self = @This();

    pub fn init(camera: *rl.Camera3D, distance: f32, width: f32, height: f32) Self {
        const forward = rl.Vector3.normalize(rl.Vector3.subtract(camera.target, camera.position));
        const right = rl.Vector3.normalize(rl.Vector3.crossProduct(forward, camera.up));
        const up = rl.Vector3.normalize(camera.up);

        // Move the origin forward along the camera's direction
        const origin = rl.Vector3.add(camera.position, rl.Vector3.scale(forward, distance));

        return .{
            .origin = origin,
            .right = right,
            .forward = up,
            .width = width,
            .height = height,
        };
    }

    pub fn draw(self: *Self, color: rl.Color) void {
        const half_width = self.width / 2.0;
        const half_height = self.height / 2.0;

        // Scaled axes
        const right_scaled = rl.Vector3.scale(self.right, half_width);
        const forward_scaled = rl.Vector3.scale(self.forward, half_height);

        // Corners of the plane
        const top_left = rl.Vector3.subtract(rl.Vector3.subtract(self.origin, right_scaled), forward_scaled);
        const top_right = rl.Vector3.add(rl.Vector3.subtract(self.origin, forward_scaled), right_scaled);
        const bottom_right = rl.Vector3.add(rl.Vector3.add(self.origin, right_scaled), forward_scaled);
        const bottom_left = rl.Vector3.subtract(rl.Vector3.add(self.origin, forward_scaled), right_scaled);

        // Draw the quad
        rl.drawTriangle3D(top_left, top_right, bottom_right, color);
        rl.drawTriangle3D(top_left, bottom_right, bottom_left, color);
    }

    pub fn getRandomPosition(self: *Self) rl.Vector3 {
        const rand_x = (@as(f32, @floatFromInt(rl.getRandomValue(-1000, 1000))) / 1000.0) * (self.width / 2.0);
        const rand_z = (@as(f32, @floatFromInt(rl.getRandomValue(-1000, 1000))) / 1000.0) * (self.height / 2.0);

        const offset_right = rl.Vector3.scale(self.right, rand_x);
        const offset_forward = rl.Vector3.scale(self.forward, rand_z);

        const new_position = rl.Vector3.add(self.origin, rl.Vector3.add(offset_right, offset_forward));

        return new_position;
    }
};
