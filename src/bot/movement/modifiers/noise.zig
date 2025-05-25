const rl = @import("raylib");

const m = @import("modifiers.zig");

const rand = @import("../../../rand/root.zig");

pub const NoiseWanderModifier = struct {
    random_state_ptr: *rand.RandomState,
    strength: f32,

    pub fn apply(ctx: *const anyopaque, dt: f32) rl.Vector3 {
        _ = dt;
        const self = @as(*const NoiseWanderModifier, @ptrCast(@alignCast(ctx)));
        return noiseWander(self.strength, self.random_state_ptr);
    }

    pub fn toModule(self: *const NoiseWanderModifier, weight: f32) m.MovementModule {
        return m.MovementModule{
            .ctx = self,
            .applyFn = NoiseWanderModifier.apply,
            .weight = weight,
        };
    }
};

pub fn noiseWander(strength: f32, random_state: *rand.RandomState) rl.Vector3 {
    const rx = random_state.getRange(-1, 1) * strength;
    const ry = random_state.getRange(-1, 1) * strength;
    const rz = random_state.getRange(-1, 1) * strength;
    return rl.Vector3.init(rx, ry, rz);
}
