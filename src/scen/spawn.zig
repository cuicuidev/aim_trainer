const std = @import("std");

const rl = @import("raylib");

const bot = @import("../bot/root.zig");

pub const SpawnConfig = struct {
    origin: [3]f32,
    right: [3]f32,
    up: [3]f32,
    forward: [3]f32,
    width: f32,
    height: f32,
    depth: f32,
};

pub const Spawn = struct {
    origin: rl.Vector3,
    right: rl.Vector3, // local X-axis (width direction)
    up: rl.Vector3, // local Y-axis (height direction)
    forward: rl.Vector3, // local Z-axis (depth direction)
    width: f32,
    height: f32,
    depth: f32,

    const Self = @This();

    pub fn init(origin: rl.Vector3, forward: rl.Vector3, right: rl.Vector3, up: rl.Vector3, width: f32, height: f32, depth: f32) Self {
        const forward_norm = rl.Vector3.normalize(forward);
        const right_norm = rl.Vector3.normalize(right);
        const up_norm = rl.Vector3.normalize(up);

        return .{
            .origin = origin,
            .right = right_norm,
            .up = up_norm,
            .forward = forward_norm,
            .width = width,
            .height = height,
            .depth = depth,
        };
    }

    pub fn fromConfig(spawn_config: SpawnConfig) Self {
        const origin = rl.Vector3.init(spawn_config.origin[0], spawn_config.origin[1], spawn_config.origin[2]);
        const forward = rl.Vector3.init(spawn_config.forward[0], spawn_config.forward[1], spawn_config.forward[2]);
        const right = rl.Vector3.init(spawn_config.right[0], spawn_config.right[1], spawn_config.right[2]);
        const up = rl.Vector3.init(spawn_config.up[0], spawn_config.up[1], spawn_config.up[2]);

        return Self.init(
            origin,
            forward,
            right,
            up,
            spawn_config.width,
            spawn_config.height,
            spawn_config.depth,
        );
    }

    pub fn draw(self: *const Self, color: rl.Color) void {
        const hw = self.width / 2.0;
        const hh = self.height / 2.0;
        const hd = self.depth / 2.0;

        const r = rl.Vector3.scale(self.right, hw);
        const u = rl.Vector3.scale(self.up, hh);
        const f = rl.Vector3.scale(self.forward, hd);

        // Compute the 8 corners of the prism
        const corners = [8]rl.Vector3{
            rl.Vector3.add(rl.Vector3.subtract(rl.Vector3.subtract(self.origin, r), u), f), // 0
            rl.Vector3.add(rl.Vector3.add(rl.Vector3.subtract(self.origin, r), u), f), // 1
            rl.Vector3.add(rl.Vector3.add(rl.Vector3.add(self.origin, r), u), f), // 2
            rl.Vector3.add(rl.Vector3.subtract(rl.Vector3.add(self.origin, r), u), f), // 3
            rl.Vector3.subtract(rl.Vector3.subtract(rl.Vector3.subtract(self.origin, r), u), f), // 4
            rl.Vector3.subtract(rl.Vector3.add(rl.Vector3.subtract(self.origin, r), u), f), // 5
            rl.Vector3.subtract(rl.Vector3.add(rl.Vector3.add(self.origin, r), u), f), // 6
            rl.Vector3.subtract(rl.Vector3.subtract(rl.Vector3.add(self.origin, r), u), f), // 7
        };

        // Define the 12 edges of the box (pairs of corner indices)
        const edges = [12][2]usize{
            // Front face edges
            .{ 0, 1 }, .{ 1, 2 }, .{ 2, 3 }, .{ 3, 0 },
            // Back face edges
            .{ 4, 5 }, .{ 5, 6 }, .{ 6, 7 }, .{ 7, 4 },
            // Side edges
            .{ 0, 4 }, .{ 1, 5 }, .{ 2, 6 }, .{ 3, 7 },
        };

        for (edges) |edge| {
            rl.drawLine3D(corners[edge[0]], corners[edge[1]], color);
        }
    }

    pub fn getRandomPosition(self: *Self, prng_ptr: *std.Random.Xoshiro256) rl.Vector3 {
        const rand_x = (prng_ptr.random().float(f32) * 2 - 1) * (self.width / 2.0);
        const rand_y = (prng_ptr.random().float(f32) * 2 - 1) * (self.height / 2.0);
        const rand_z = (prng_ptr.random().float(f32) * 2 - 1) * (self.depth / 2.0);

        const offset_right = rl.Vector3.scale(self.right, rand_x);
        const offset_up = rl.Vector3.scale(self.up, rand_y);
        const offset_forward = rl.Vector3.scale(self.forward, rand_z);

        return rl.Vector3.add(self.origin, rl.Vector3.add(offset_right, rl.Vector3.add(offset_up, offset_forward)));
    }
};
