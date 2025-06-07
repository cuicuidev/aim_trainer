const std = @import("std");

const rl = @import("raylib");

const mov = @import("../movement/root.zig");

const sphere = @import("sphere.zig");

pub const Capsule = struct {
    position: rl.Vector3,
    radius: f32,
    height: f32,
    color: rl.Color,
    kinetic_handler: mov.kinetic.KineticHandler,

    const Self = @This();

    pub fn init(position: rl.Vector3, radius: f32, height: f32, color: rl.Color, kinetic_config: mov.kinetic.KineticConfig) Self {
        const kinetic_handler = mov.kinetic.KineticHandler.init(kinetic_config);
        return .{
            .position = position,
            .radius = radius,
            .height = height,
            .color = color,
            .kinetic_handler = kinetic_handler,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn hitScan(self: *Self, camera: *rl.Camera3D) ?rl.Vector3 {
        const ray_dir = rl.Vector3.normalize(rl.Vector3.subtract(camera.target, camera.position));

        return rayIntersectsCapsule(
            camera.position,
            ray_dir,
            self.position,
            self.height,
            self.radius,
        );
    }

    pub fn draw(self: *Self) void {
        const half_cylinder_height = (self.height - 2.0 * self.radius) / 2.0;
        const start_pos = rl.Vector3.init(self.position.x, self.position.y - half_cylinder_height, self.position.z);
        const end_pos = rl.Vector3.init(self.position.x, self.position.y + half_cylinder_height, self.position.z);
        rl.drawCapsule(start_pos, end_pos, self.radius, 16, 8, self.color);
    }
};

pub fn rayIntersectsCapsule(ray_origin: rl.Vector3, ray_dir: rl.Vector3, capsule_position: rl.Vector3, capsule_height: f32, capsule_radius: f32) ?rl.Vector3 {
    const half_cylinder_height = (capsule_height - 2.0 * capsule_radius) / 2.0;

    // Capsule ends are at y = ±half_cylinder_height from the capsule center
    const bottom_end = rl.Vector3.init(capsule_position.x, capsule_position.y - half_cylinder_height, capsule_position.z);
    const top_end = rl.Vector3.init(capsule_position.x, capsule_position.y + half_cylinder_height, capsule_position.z);

    // Check intersection with the capsule's two hemispherical ends
    const bottom_hit = sphere.rayIntersectsSphere(ray_origin, ray_dir, bottom_end, capsule_radius);
    if (bottom_hit) |bh| {
        return bh; // Return the hit point
    }

    const top_hit = sphere.rayIntersectsSphere(ray_origin, ray_dir, top_end, capsule_radius);
    if (top_hit) |th| {
        return th; // Return the hit point
    }

    const cyl_origin = capsule_position;
    const d = ray_dir;
    const o = rl.Vector3.subtract(ray_origin, cyl_origin);

    // Project ray dir and origin onto XZ plane (ignore Y axis)
    const dxz = rl.Vector3.init(d.x, 0.0, d.z);
    const oxz = rl.Vector3.init(o.x, 0.0, o.z);

    // Quadratic coefficients for intersection with infinite cylinder
    const a = rl.Vector3.dotProduct(dxz, dxz);
    const b = 2.0 * rl.Vector3.dotProduct(dxz, oxz);
    const c = rl.Vector3.dotProduct(oxz, oxz) - capsule_radius * capsule_radius;

    const discriminant = b * b - 4.0 * a * c;

    if (discriminant >= 0.0) {
        const sqrt_disc = @sqrt(discriminant);
        const t1 = (-b - sqrt_disc) / (2.0 * a);
        const t2 = (-b + sqrt_disc) / (2.0 * a);

        // Check both possible hits
        for ([2]f32{ t1, t2 }) |t| {
            if (t < 0.0) continue; // Ignore behind ray

            const hit = rl.Vector3.init(
                ray_origin.x + d.x * t,
                ray_origin.y + d.y * t,
                ray_origin.z + d.z * t,
            );

            // Check if the hit is within the vertical bounds of the finite cylinder
            const y_local = hit.y - capsule_position.y;
            if (y_local >= -half_cylinder_height and y_local <= half_cylinder_height) {
                return hit;
            }
        }
    }

    return null; // No intersection with capsule
}
