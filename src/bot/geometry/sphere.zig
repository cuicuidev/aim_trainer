const std = @import("std");

const rl = @import("raylib");

const mov = @import("../movement/root.zig");

pub const Sphere = struct {
    position: rl.Vector3,
    radius: f32,
    color: rl.Color,
    kinetic_handler: mov.kinetic.KineticHandler,

    const Self = @This();

    pub fn init(position: rl.Vector3, radius: f32, color: rl.Color, kinetic_config: mov.kinetic.KineticConfig) Self {
        const kinetic_handler = mov.kinetic.KineticHandler.init(kinetic_config);
        return .{
            .position = position,
            .radius = radius,
            .color = color,
            .kinetic_handler = kinetic_handler,
        };
    }

    pub fn hitScan(self: *Self, camera: *rl.Camera3D) ?rl.Vector3 {
        const ray_dir = rl.Vector3.normalize(rl.Vector3.subtract(camera.target, camera.position));

        return rayIntersectsSphere(
            camera.position,
            ray_dir,
            self.position,
            self.radius,
        );
    }

    pub fn draw(self: *Self) void {
        rl.drawSphere(self.position, self.radius, self.color);
    }
};

pub fn rayIntersectsSphere(ray_origin: rl.Vector3, ray_dir_norm: rl.Vector3, sphere_position: rl.Vector3, sphere_radius: f32) ?rl.Vector3 {
    const L = rl.Vector3.subtract(ray_origin, sphere_position);
    const a = 1.0;
    const b = 2.0 * rl.Vector3.dotProduct(ray_dir_norm, L);
    const c = rl.Vector3.dotProduct(L, L) - sphere_radius * sphere_radius;

    const discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) {
        return null; // No intersection
    }

    const t = (-b - std.math.sqrt(discriminant)) / (2.0 * a);
    if (t < 0.0) {
        return null; // The intersection is behind the ray's origin
    }

    const hit_point = rl.Vector3.init(
        ray_origin.x + ray_dir_norm.x * t,
        ray_origin.y + ray_dir_norm.y * t,
        ray_origin.z + ray_dir_norm.z * t,
    );
    return hit_point;
}
