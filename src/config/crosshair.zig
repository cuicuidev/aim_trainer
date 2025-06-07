const std = @import("std");

const rl = @import("raylib");

pub const Crosshair = struct {
    allocator: std.mem.Allocator,
    size: f32, // Size of the central crosshair sphere
    color: rl.Color, // Color of the central crosshair sphere and trail

    trail_array: []rl.Vector3, // Stores 3D positions of the trail points
    trail_array_pos: usize, // Current index in trail_array to write the next point (circular buffer)
    trail_count: usize, // Number of valid points currently in trail_array (from 0 to trail_array.len)

    const TRAIL_CAPACITY = 1024; // Max number of points in the trail
    const CROSSHAIR_DISTANCE: f32 = 1.0; // How far in front of the camera the 3D crosshair point is

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, size: f32, color: rl.Color) !Self {
        const points = try allocator.alloc(rl.Vector3, TRAIL_CAPACITY);

        for (points) |*pt| {
            pt.* = rl.Vector3.zero();
        }

        return .{
            .allocator = allocator,
            .size = size,
            .color = color,
            .trail_array = points,
            .trail_array_pos = 0,
            .trail_count = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.trail_array);
    }

    /// Draws the central crosshair sphere.
    /// Must be called within a BeginMode3D/EndMode3D block.
    pub fn drawCenter(self: *const Self, camera_ptr: *const rl.Camera3D) void {
        const camera_forward = camera_ptr.target.subtract(camera_ptr.position).normalize();
        const crosshair_3d_pos = camera_ptr.position.add(camera_forward.scale(CROSSHAIR_DISTANCE));

        rl.drawSphere(crosshair_3d_pos, self.size, self.color);
    }

    /// Updates the trail with the current crosshair position.
    /// Call this function *after* the camera has been updated for the frame.
    /// The `camera_ptr` should point to the up-to-date camera.
    pub fn updateTrail(self: *Self, camera_ptr: *const rl.Camera3D) void {
        const camera_forward = camera_ptr.target.subtract(camera_ptr.position).normalize();
        const current_crosshair_pos = camera_ptr.position.add(camera_forward.scale(CROSSHAIR_DISTANCE));

        self.trail_array[self.trail_array_pos] = current_crosshair_pos;
        self.trail_array_pos = (self.trail_array_pos + 1) % self.trail_array.len;

        if (self.trail_count < self.trail_array.len) {
            self.trail_count += 1;
        }
    }

    /// Draws the crosshair trail as a series of connected lines.
    /// Must be called within a BeginMode3D/EndMode3D block.
    pub fn drawTrail(self: *const Self) void {
        if (self.trail_count < 2) {
            return; // Not enough points to draw any segments
        }

        // Determine the index of the oldest point in the circular buffer.
        // If the buffer is full, the oldest point is at `self.trail_array_pos`.
        // Otherwise, the oldest point is at index 0.
        var idx_of_oldest_point_in_buffer: usize = 0;
        if (self.trail_count == self.trail_array.len) {
            idx_of_oldest_point_in_buffer = self.trail_array_pos;
        }

        // We will draw `self.trail_count - 1` segments.
        // `segment_iter_idx` goes from 0 (oldest segment) to `self.trail_count - 2` (newest segment).
        for (0..(self.trail_count - 1)) |segment_iter_idx| {
            const p1_buffer_idx = (idx_of_oldest_point_in_buffer + segment_iter_idx) % self.trail_array.len;
            const p2_buffer_idx = (idx_of_oldest_point_in_buffer + segment_iter_idx + 1) % self.trail_array.len;

            const p1 = self.trail_array[p1_buffer_idx];
            const p2 = self.trail_array[p2_buffer_idx];

            // Calculate alpha for fading: oldest segments are more transparent, newest are more opaque.
            // `alpha_lerp_factor` ranges from near 0.0 (oldest) to 1.0 (newest visible segment).
            // For `trail_count` points, there are `trail_count - 1` segments.
            // `segment_iter_idx = 0` is the oldest segment.
            // `segment_iter_idx = self.trail_count - 2` is the newest segment.
            var alpha_lerp_factor: f32 = 0.0;
            if ((self.trail_count - 1) > 1) { // Avoid division by zero if only one segment; handle below
                alpha_lerp_factor = @as(f32, @floatFromInt(segment_iter_idx)) / @as(f32, @floatFromInt(self.trail_count - 2));
            } else if ((self.trail_count - 1) == 1) { // Exactly one segment
                alpha_lerp_factor = 1.0; // Full desired alpha for a single segment trail
            }

            var trail_segment_color = rl.Color.magenta;
            trail_segment_color.a = @as(u8, @intFromFloat(255.0 * alpha_lerp_factor));

            rl.drawLine3D(p1, p2, trail_segment_color);
        }
    }
};
