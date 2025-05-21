const rl = @import("raylib");

const AccelConstraintFn = *const fn (ctx: *anyopaque, accel: rl.Vector3, position: rl.Vector3, velocity: rl.Vector3) rl.Vector3;
const VelocityConstraintFn = *const fn (ctx: *anyopaque, velocity: rl.Vector3) rl.Vector3;

pub const AccelConstraintModule = struct {
    ctx: *anyopaque,
    applyFn: AccelConstraintFn,
};

pub const VelocityConstraintModule = struct {
    ctx: *anyopaque,
    applyFn: VelocityConstraintFn,
};

pub const Constraints = struct {
    accel_constraints: ?[]const AccelConstraintModule,
    velocity_constraints: ?[]const VelocityConstraintModule,
};
