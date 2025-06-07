const std = @import("std");

const rl = @import("raylib");

const m = @import("modifiers.zig");

pub const NoiseWanderModifier = struct {
    strength: f32,

    pub fn apply(ctx: *const anyopaque, dt: f32, prng_ptr: *std.Random.Xoshiro256, frame_delta: usize) rl.Vector3 {
        _ = dt;
        const self = @as(*const NoiseWanderModifier, @ptrCast(@alignCast(ctx)));
        var wander = rl.Vector3.init(0.0, 0.0, 0.0);

        var i: usize = 0;
        while (i < frame_delta) : (i += 1) {
            wander = wander.add(noiseWander(self.strength, prng_ptr));
        }
        return wander;
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
