const rl = @import("raylib");

const c = @import("constraints.zig");

pub const MaxSpeedConstraint = struct {
    max_speed: f32,

    pub fn apply(ctx: *const anyopaque, velocity: rl.Vector3) rl.Vector3 {
        const self = @as(*const MaxSpeedConstraint, @ptrCast(@alignCast(ctx)));
        const speed_sq = rl.Vector3.lengthSqr(velocity);
        if (speed_sq > self.max_speed * self.max_speed) {
            return rl.Vector3.scale(rl.Vector3.normalize(velocity), self.max_speed);
        }
        return velocity;
    }

    pub fn toModule(self: *const MaxSpeedConstraint) c.VelocityConstraintModule {
        return c.VelocityConstraintModule{
            .ctx = self,
            .applyFn = MaxSpeedConstraint.apply,
        };
    }
};

pub const MinSpeedConstraint = struct {
    min_speed: f32,

    pub fn apply(ctx: *const anyopaque, velocity: rl.Vector3) rl.Vector3 {
        const self = @as(*const MinSpeedConstraint, @ptrCast(@alignCast(ctx)));
        const speed_sq = rl.Vector3.lengthSqr(velocity);
        if (speed_sq < self.min_speed * self.min_speed) {
            return rl.Vector3.scale(rl.Vector3.normalize(velocity), self.min_speed);
        }
        return velocity;
    }

    pub fn toModule(self: *const MinSpeedConstraint) c.VelocityConstraintModule {
        return c.VelocityConstraintModule{
            .ctx = self,
            .applyFn = MinSpeedConstraint.apply,
        };
    }
};
