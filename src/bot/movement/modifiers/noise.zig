const rl = @import("raylib");

const m = @import("modifiers.zig");

pub const NoiseWanderModifier = struct {
    strength: f32,

    pub fn apply(ctx: *const anyopaque, dt: f32) rl.Vector3 {
        _ = dt;
        const self = @as(*const NoiseWanderModifier, @ptrCast(@alignCast(ctx)));
        return noiseWander(self.strength);
    }

    pub fn toModule(self: *const NoiseWanderModifier, weight: f32) m.MovementModule {
        return m.MovementModule{
            .ctx = self,
            .applyFn = NoiseWanderModifier.apply,
            .weight = weight,
        };
    }
};

pub fn noiseWander(strength: f32) rl.Vector3 {
    const rx = (@as(f32, @floatFromInt(rl.getRandomValue(-10, 10))) / 10.0) * strength;
    const ry = (@as(f32, @floatFromInt(rl.getRandomValue(-10, 10))) / 10.0) * strength;
    const rz = (@as(f32, @floatFromInt(rl.getRandomValue(-10, 10))) / 10.0) * strength;
    return rl.Vector3.init(rx, ry, rz);
}
