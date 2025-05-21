const std = @import("std");

const rl = @import("raylib");

const c = @import("constraints/root.zig");
const m = @import("modifiers/root.zig");

pub const KineticConfig = struct {
    constraints: c.Constraints,
    modifiers: m.MovementModifiers,
};

pub const KineticHandler = struct {
    position: rl.Vector3,
    velocity: rl.Vector3,
    time: f32,
    config: KineticConfig,

    const Self = @This();

    pub fn init(position: rl.Vector3, config: KineticConfig) Self {
        return .{
            .position = position,
            .velocity = rl.Vector3.init(0.0, 0.0, 0.0),
            .time = 0.0,
            .config = config,
        };
    }

    // pub fn staticInstance() Self {}

    // pub fn rawControlInstance(position: rl.Vector3) Self {
    //     return .{
    //         .position = position,
    //         .velocity = rl.Vector3.init(0.0, 0.0, 0.0),
    //         .time = 0.0,
    //         .config = KINETIC_CONFIG,
    //     };
    // }

    pub fn step(self: *Self, dt: f32) void {
        self.time += dt;

        const base_accel = self._getBaseAccel(dt);
        const constrained_accel = self._applyAccelConstraints(base_accel);

        var new_velocity = rl.Vector3.add(self.velocity, rl.Vector3.scale(constrained_accel, dt));
        new_velocity = self._applyVelocityConstraints(new_velocity);

        self.velocity = new_velocity;
        self.position = rl.Vector3.add(self.position, rl.Vector3.scale(self.velocity, dt));
    }

    fn _getBaseAccel(self: *Self, dt: f32) rl.Vector3 {
        var accel = rl.Vector3.init(0, 0, 0);
        if (self.config.modifiers.modules) |modules| {
            for (modules) |mod| {
                const result = mod.applyFn(mod.ctx, self.time + dt);
                accel = rl.Vector3.add(accel, result);
            }
        }
        return accel;
    }

    fn _applyAccelConstraints(self: *Self, accel: rl.Vector3) rl.Vector3 {
        var adjusted = accel;
        if (self.config.constraints.accel_constraints) |accel_constraints| {
            for (accel_constraints) |con| {
                adjusted = con.applyFn(con.ctx, adjusted, self.position, self.velocity);
            }
        }
        return adjusted;
    }

    fn _applyVelocityConstraints(self: *Self, velocity: rl.Vector3) rl.Vector3 {
        var adjusted = velocity;
        if (self.config.constraints.velocity_constraints) |velocity_constraints| {
            for (velocity_constraints) |con| {
                adjusted = con.applyFn(con.ctx, adjusted);
            }
        }
        return adjusted;
    }
};
