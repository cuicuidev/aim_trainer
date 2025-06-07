const std = @import("std");

const rl = @import("raylib");

const m = @import("modifiers.zig");

pub const SinusoidalWanderModifier = struct {
    amplitude: f32,
    freq: f32,

    pub fn apply(ctx: *const anyopaque, time: f32, prng_ptr: *std.Random.Xoshiro256) rl.Vector3 {
        _ = prng_ptr;
        const self = @as(*const SinusoidalWanderModifier, @ptrCast(@alignCast(ctx)));
        return sinusoidalWander(time, self.amplitude, self.freq);
    }

    pub fn toModule(self: *const SinusoidalWanderModifier, weight: f32) m.MovementModule {
        return m.MovementModule{
            .ctx = self,
            .applyFn = SinusoidalWanderModifier.apply,
            .weight = weight,
        };
    }
};

pub fn sinusoidalWander(time: f32, amplitude: f32, freq: f32) rl.Vector3 {
    const ax = amplitude * @sin(time * freq);
    const ay = amplitude * @cos(time * freq * 1.2);
    const az = amplitude * @sin(time * freq * 0.7 + 1.0);
    return rl.Vector3.init(ax, ay, az);
}
