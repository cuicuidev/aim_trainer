const std = @import("std");
const rl = @import("raylib");

pub const BotType = enum {
    click,
    track,
    invincible,
};

pub const BotGeometryType = enum {
    sphere,
    capsule,
};

pub fn BotGeometry(comptime geometry_type: BotGeometryType) type {
    return struct {
        radius: f32,
        height: ?f32,

        const Self = @This();

        pub fn init(radius: f32, height: ?f32) Self {
            if (geometry_type == BotGeometryType.capsule and height == null) unreachable;
            return .{
                .radius = radius,
                .height = height,
            };
        }

        // Function to calculate the intersection of a ray with a sphere
        fn rayIntersectsSphere(self: *Self, ray_origin: rl.Vector3, ray_dir: rl.Vector3, sphere_center: rl.Vector3, sphere_radius: f32) ?rl.Vector3 {
            _ = self;
            const L = rl.Vector3.subtract(ray_origin, sphere_center);
            const a = 1.0; // Ray direction is normalized
            const b = 2.0 * rl.Vector3.dotProduct(ray_dir, L);
            const c = rl.Vector3.dotProduct(L, L) - sphere_radius * sphere_radius;

            const discriminant = b * b - 4.0 * a * c;
            if (discriminant < 0.0) {
                return null; // No intersection
            }

            const t = (-b - std.math.sqrt(discriminant)) / (2.0 * a);
            if (t < 0.0) {
                return null; // The intersection is behind the ray's origin
            }

            // Calculate the intersection point
            const hit_point = rl.Vector3.init(
                ray_origin.x + ray_dir.x * t,
                ray_origin.y + ray_dir.y * t,
                ray_origin.z + ray_dir.z * t,
            );
            return hit_point;
        }

        // Function to calculate if a ray intersects with a capsule and return the intersection point
        fn rayIntersectsCapsule(self: *Self, ray_origin: rl.Vector3, ray_dir: rl.Vector3, capsule_center: rl.Vector3) ?rl.Vector3 {
            const half_cylinder_height = (self.height.? - 2.0 * self.radius) / 2.0;

            // Capsule ends are at y = ±half_cylinder_height from the capsule center
            const bottom_end = rl.Vector3.init(capsule_center.x, capsule_center.y - half_cylinder_height, capsule_center.z);
            const top_end = rl.Vector3.init(capsule_center.x, capsule_center.y + half_cylinder_height, capsule_center.z);

            // Check intersection with the capsule's two hemispherical ends
            const bottom_hit = self.rayIntersectsSphere(ray_origin, ray_dir, bottom_end, self.radius);
            if (bottom_hit) |bh| {
                return bh; // Return the hit point
            }

            const top_hit = self.rayIntersectsSphere(ray_origin, ray_dir, top_end, self.radius);
            if (top_hit) |th| {
                return th; // Return the hit point
            }

            const cyl_origin = capsule_center;
            const d = ray_dir;
            const o = rl.Vector3.subtract(ray_origin, cyl_origin);

            // Project ray dir and origin onto XZ plane (ignore Y axis)
            const dxz = rl.Vector3.init(d.x, 0.0, d.z);
            const oxz = rl.Vector3.init(o.x, 0.0, o.z);

            // Quadratic coefficients for intersection with infinite cylinder
            const a = rl.Vector3.dotProduct(dxz, dxz);
            const b = 2.0 * rl.Vector3.dotProduct(dxz, oxz);
            const c = rl.Vector3.dotProduct(oxz, oxz) - self.radius * self.radius;

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
                    const y_local = hit.y - capsule_center.y;
                    if (y_local >= -half_cylinder_height and y_local <= half_cylinder_height) {
                        return hit;
                    }
                }
            }

            return null; // No intersection with capsule
        }

        // Perform a hit scan to check for intersection with the geometry and return the hit point
        pub fn hitScan(self: *Self, camera: *rl.Camera3D, position: rl.Vector3) ?rl.Vector3 {
            const ray_dir = rl.Vector3.normalize(rl.Vector3.subtract(camera.target, camera.position));

            return switch (geometry_type) {
                .sphere => {
                    // Perform ray-sphere intersection and return the hit point
                    return self.rayIntersectsSphere(
                        camera.position,
                        ray_dir,
                        position,
                        self.radius,
                    );
                },

                .capsule => {
                    // Perform ray-capsule intersection and return the hit point
                    return self.rayIntersectsCapsule(
                        camera.position,
                        ray_dir,
                        position,
                    );
                },
            };
        }

        // Draw the geometry (sphere or capsule)
        pub fn draw(self: *Self, position: rl.Vector3, color: rl.Color) void {
            switch (geometry_type) {
                .sphere => {
                    rl.drawSphere(position, self.radius, color);
                },
                .capsule => {
                    const capsule_height = self.height orelse return;
                    const half_cylinder_height = (capsule_height - 2.0 * self.radius) / 2.0;
                    const start_pos = rl.Vector3.init(position.x, position.y - half_cylinder_height, position.z);
                    const end_pos = rl.Vector3.init(position.x, position.y + half_cylinder_height, position.z);
                    rl.drawCapsule(start_pos, end_pos, self.radius, 16, 8, color);
                },
            }
        }
    };
}

pub fn Bot(comptime geometry_type: BotGeometryType, comptime geometry: BotGeometry(geometry_type), comptime bot_type: BotType) type {
    return struct {
        position: rl.Vector3,
        geometry: BotGeometry(geometry_type) = geometry,
        bot_type: BotType = bot_type,
        color: rl.Color,

        const Self = @This();

        // Initialize the bot with position and color
        pub fn init(position: rl.Vector3, color: rl.Color) Self {
            return .{
                .position = position,
                .color = color,
            };
        }

        // Draw the bot by drawing its geometry
        pub fn draw(self: *Self) void {
            self.geometry.draw(self.position, self.color);
        }

        // Perform a hit scan on the bot to check if it intersects with the camera's view and return the hit point
        pub fn hitScan(self: *Self, camera: *rl.Camera3D) ?rl.Vector3 {
            return self.geometry.hitScan(camera, self.position);
        }
    };
}
