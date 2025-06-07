const std = @import("std");

const rl = @import("raylib");

const m = @import("modifiers.zig");

pub const NoiseWanderModifier = struct {
    strength: f32,

    pub fn apply(ctx: *const anyopaque, dt: f32, prng_ptr: *std.Random.Xoshiro256) rl.Vector3 {
        _ = dt;
        const self = @as(*const NoiseWanderModifier, @ptrCast(@alignCast(ctx)));
        return noiseWander(self.strength, prng_ptr);
    }

    pub fn toModule(self: *const NoiseWanderModifier, weight: f32) m.MovementModule {
        return m.MovementModule{
            .ctx = self,
            .applyFn = NoiseWanderModifier.apply,
            .weight = weight,
        };
    }
};

pub fn noiseWander(strength: f32, prng_ptr: *std.Random.Xoshiro256) rl.Vector3 {
    const rx = (prng_ptr.random().float(f32) * 2 - 1) * strength;
    const ry = (prng_ptr.random().float(f32) * 2 - 1) * strength;
    const rz = (prng_ptr.random().float(f32) * 2 - 1) * strength;
    return rl.Vector3.init(rx, ry, rz);
}
