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
        std.debug.print("getState\ns[0] = {}\ns[1] = {}\ns[2] = {}\ns[3] = {}\n\n", .{ self.prng.s[0], self.prng.s[1], self.prng.s[2], self.prng.s[3] });
        return .{
            .s = self.prng.s,
        };
    }

    pub fn setState(self: *Self, state: RandomStateData) void {
        std.debug.print("setState\ns[0] = {}\ns[1] = {}\ns[2] = {}\ns[3] = {}\n\n", .{ state.s[0], state.s[1], state.s[2], state.s[3] });
        self.prng.s = state.s;
    }
};
