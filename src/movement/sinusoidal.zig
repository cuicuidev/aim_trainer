const rl = @import("raylib");

const m = @import("movement.zig");

pub const SinusoidalWanderModifier = struct {
    amplitude: f32,
    freq: f32,

    pub fn apply(ctx: *anyopaque, time: f32) rl.Vector3 {
        const self = @as(*SinusoidalWanderModifier, @ptrCast(@alignCast(ctx)));
        return sinusoidalWander(time, self.amplitude, self.freq);
    }

    pub fn toModule(self: *SinusoidalWanderModifier, weight: f32) m.MovementModule {
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
