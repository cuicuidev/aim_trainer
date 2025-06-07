const std = @import("std");

const rl = @import("raylib");

const c = @import("constraints/root.zig");
const m = @import("modifiers/root.zig");

pub const KineticConfig = struct {
    constraints: c.Constraints,
    modifiers: m.MovementModifiers,
};

pub const KineticHandler = struct {
    velocity: rl.Vector3,
    time: f32,
    config: KineticConfig,

    const Self = @This();

    pub fn init(config: KineticConfig) Self {
        return .{
            .velocity = rl.Vector3.init(0.0, 0.0, 0.0),
            .time = 0.0,
            .config = config,
        };
    }

    pub fn step(self: *Self, position: rl.Vector3, dt: f32, prng_ptr: *std.Random.Xoshiro256, frame_delta: usize) rl.Vector3 {
        self.time += dt;

        const base_accel = self._getBaseAccel(dt, prng_ptr, frame_delta);
        const constrained_accel = self._applyAccelConstraints(position, base_accel);

        var new_velocity = rl.Vector3.add(self.velocity, rl.Vector3.scale(constrained_accel, dt));
        new_velocity = self._applyVelocityConstraints(new_velocity);

        self.velocity = new_velocity;
        return rl.Vector3.add(position, rl.Vector3.scale(self.velocity, dt));
    }

    fn _getBaseAccel(self: *Self, dt: f32, prng_ptr: *std.Random.Xoshiro256, frame_delta: usize) rl.Vector3 {
        var accel = rl.Vector3.init(0, 0, 0);
        if (self.config.modifiers.modules) |modules_slice_for_loop| {
            for (modules_slice_for_loop) |mod_item| {
                const result = mod_item.applyFn(mod_item.ctx, self.time + dt, prng_ptr, frame_delta);
                accel = rl.Vector3.add(accel, result);
            }
        }
        return accel;
    }

    fn _applyAccelConstraints(self: *Self, position: rl.Vector3, accel: rl.Vector3) rl.Vector3 {
        var adjusted = accel;
        if (self.config.constraints.accel_constraints) |accel_constraints| {
            for (accel_constraints) |con| {
                adjusted = con.applyFn(con.ctx, adjusted, position, self.velocity);
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
