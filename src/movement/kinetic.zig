const std = @import("std");

const rl = @import("raylib");

const c = @import("constraints.zig");
const m = @import("movement.zig");

const sin = @import("sinusoidal.zig");
const noise = @import("noise.zig");
const vel = @import("velocity.zig");
const acc = @import("acceleration.zig");

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

    pub fn init(position: rl.Vector3, velocity: rl.Vector3, config: KineticConfig) Self {
        return .{
            .position = position,
            .velocity = velocity,
            .time = 0.0,
            .config = config,
        };
    }

    // pub fn staticInstance() Self {}

    pub fn rawControlInstance(position: rl.Vector3) Self {
        return .{
            .position = position,
            .velocity = rl.Vector3.init(0.0, 0.0, 0.0),
            .time = 0.0,
            .config = KINETIC_CONFIG,
        };
    }

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

// TODO: allocate wanderers dynamically instead of using global variables.
var sin_wander = sin.SinusoidalWanderModifier{
    .amplitude = 20.0,
    .freq = 2.0,
};

var noise_wander = noise.NoiseWanderModifier{
    .strength = 3.0,
};

// var min_speed = vel.MinSpeedConstraint{ .min_speed = 20.0 };

// var max_speed = vel.MaxSpeedConstraint{ .max_speed = 30.0 };

var bias = acc.PointBiasConstraint{
    .point = rl.Vector3.init(50.0, 2.0, 0.0),
    .strength = 10.0,
};

const modifiers_arr = [2]m.MovementModule{
    sin_wander.toModule(1.0),
    noise_wander.toModule(1.0),
};

const modifiers = m.MovementModifiers{
    .modules = &modifiers_arr,
};

// const vel_constraints_arr = [2]c.VelocityConstraintModule{
//     min_speed.toModule(),
//     max_speed.toModule(),
// };

const acc_constraints_arr = [1]c.AccelConstraintModule{
    bias.toModule(),
};

const constraints = c.Constraints{
    .accel_constraints = &acc_constraints_arr,
    .velocity_constraints = null, //&vel_constraints_arr,
};

const KINETIC_CONFIG = KineticConfig{
    .constraints = constraints,
    .modifiers = modifiers,
};
