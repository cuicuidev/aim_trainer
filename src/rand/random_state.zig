const std = @import("std");

pub const getRange = *const fn (self: *RandomState, min: f32, max: f32) f32;

pub const RandomStateData = extern struct {
    s: [4]u64,
};

pub const RandomState = struct {
    prng: std.Random.Xoshiro256,

    const Self = @This();

    pub fn init(seed: u64) Self {
        return .{
            .prng = std.Random.Xoshiro256.init(seed),
        };
    }

    pub fn getRange(self: *Self, min: f32, max: f32) f32 {
        return self.prng.random().float(f32) * (max - min) + min;
    }

    pub fn getState(self: *Self) RandomStateData {
        return .{
            .s = self.prng.s,
        };
    }

    pub fn setState(self: *Self, state: RandomStateData) void {
        self.prng.s = state.s;
    }
};
