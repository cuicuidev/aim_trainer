const rl = @import("raylib");

const MovementStepFn = *const fn (ctx: *const anyopaque, time: f32) rl.Vector3;

pub const MovementModule = struct {
    ctx: *const anyopaque,
    applyFn: MovementStepFn,
    weight: f32,
};

pub const MovementModifiers = struct {
    modules: ?[]const MovementModule,
};
