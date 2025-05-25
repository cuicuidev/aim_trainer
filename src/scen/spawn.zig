const std = @import("std");

const rl = @import("raylib");

const bot = @import("../bot/root.zig");
const rand = @import("../rand/root.zig");

pub const Spawn = struct {
    random_state_ptr: *rand.RandomState,
    origin: rl.Vector3,
    right: rl.Vector3, // local X-axis (width direction)
    up: rl.Vector3, // local Y-axis (height direction)
    forward: rl.Vector3, // local Z-axis (depth direction)
    width: f32,
    height: f32,
    depth: f32,

    const Self = @This();

    pub fn init(random_state_ptr: *rand.RandomState, origin: rl.Vector3, forward: rl.Vector3, right: rl.Vector3, up: rl.Vector3, width: f32, height: f32, depth: f32) Self {
        const forward_norm = rl.Vector3.normalize(forward);
        const right_norm = rl.Vector3.normalize(right);
        const up_norm = rl.Vector3.normalize(up);

        return .{
            .random_state_ptr = random_state_ptr,
            .origin = origin,
            .right = right_norm,
            .up = up_norm,
            .forward = forward_norm,
            .width = width,
            .height = height,
            .depth = depth,
        };
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

    pub fn getRandomPosition(self: *Self) rl.Vector3 {
        const rand_x = self.random_state_ptr.getRange(-1, 1) * (self.width / 2.0);
        const rand_y = self.random_state_ptr.getRange(-1, 1) * (self.height / 2.0);
        const rand_z = self.random_state_ptr.getRange(-1, 1) * (self.depth / 2.0);

        const offset_right = rl.Vector3.scale(self.right, rand_x);
        const offset_up = rl.Vector3.scale(self.up, rand_y);
        const offset_forward = rl.Vector3.scale(self.forward, rand_z);

        return rl.Vector3.add(self.origin, rl.Vector3.add(offset_right, rl.Vector3.add(offset_up, offset_forward)));
    }
};
