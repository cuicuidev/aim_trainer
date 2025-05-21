const rl = @import("raylib");

const c = @import("constraints.zig");

pub const PointBiasConstraint = struct {
    point: rl.Vector3,
    strength: f32, // Positive = attract, Negative = repel

    pub fn apply(ctx: *anyopaque, accel: rl.Vector3, position: rl.Vector3, velocity: rl.Vector3) rl.Vector3 {
        _ = velocity;
        const self = @as(*PointBiasConstraint, @ptrCast(@alignCast(ctx)));

        const to_point = rl.Vector3.subtract(self.point, position);
        const dir = rl.Vector3.normalize(to_point);
        const bias = rl.Vector3.scale(dir, self.strength);

        return rl.Vector3.add(accel, bias);
    }

    pub fn toModule(self: *PointBiasConstraint) c.AccelConstraintModule {
        return c.AccelConstraintModule{
            .ctx = self,
            .applyFn = PointBiasConstraint.apply,
        };
    }
};
