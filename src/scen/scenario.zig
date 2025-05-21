const std = @import("std");

const rl = @import("raylib");

const sp = @import("spawn.zig");

const bot = @import("../bot/root.zig");
const geo = bot.geo;
const mov = bot.mov;

const RADIUS = 0.3;
const HEIGHT = 4.0;
const COLOR = rl.Color.red;

pub const Scenario = union(enum) {
    clicking: Clicking,
    tracking: Tracking,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        switch (self.*) {
            .clicking => |*s| s.deinit(),
            .tracking => |*s| s.deinit(),
        }
    }

    pub fn draw(self: *Self) void {
        switch (self.*) {
            .clicking => |*s| s.draw(),
            .tracking => |*s| s.draw(),
        }
    }

    pub fn kill(self: *Self, camera: *rl.Camera3D) void {
        switch (self.*) {
            .clicking => |*s| s.kill(camera),
            .tracking => |*s| s.kill(camera),
        }
    }

    pub fn getScore(self: *Self) f64 {
        return switch (self.*) {
            .clicking => |*s| s.getScore(),
            .tracking => |*s| s.getScore(),
        };
    }
};

pub const BotConfig = struct {
    n_bots: usize,
    geometry: geo.Geometry,
    bot_initial_position: ?rl.Vector3 = null,
};

pub const Clicking = struct {
    allocator: std.mem.Allocator,
    spawn: sp.Spawn,
    bots: []bot.Bot,
    bot_config: BotConfig,
    n_clicks: usize = 0,
    n_hits: usize = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, spawn: sp.Spawn, bot_config: BotConfig) !Self {
        const bots = try allocator.alloc(bot.Bot, bot_config.n_bots);
        var self = Self{
            .allocator = allocator,
            .spawn = spawn,
            .bots = bots,
            .bot_config = bot_config,
        };

        var i: usize = 0;
        while (i < self.bot_config.n_bots) : (i += 1) {
            self.bots[i] = bot.Bot.init(self.bot_config.geometry);
            self.spawnBot(i);
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.bots);
    }

    fn spawnBot(self: *Self, idx: usize) void {
        if (self.bot_config.bot_initial_position) |pos| {
            self.bots[idx].setPosition(pos);
        } else {
            self.randomizeBotPosition(idx);
        }
    }

    fn randomizeBotPosition(self: *Self, idx: usize) void {
        const pos = self.spawn.getRandomPosition();
        self.bots[idx].geometry.setPosition(pos);
    }

    pub fn draw(self: *Self) void {
        self.spawn.draw(rl.Color.green);

        for (self.bots) |*b| {
            b.draw();
        }
    }

    pub fn kill(self: *Self, camera: *rl.Camera3D) void {
        for (self.bots) |*b| {
            const delta = rl.getFrameTime();
            b.step(delta);
        }
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            var i: usize = 0;

            while (i < self.bots.len) : (i += 1) {
                if (self.bots[i].hitScan(camera)) |_| {
                    self.bots[i] = bot.Bot.init(self.bot_config.geometry);
                    self.spawnBot(i);
                    self.n_hits += 1;
                    break;
                }
            }

            self.n_clicks += 1;
        }
    }

    pub fn getScore(self: *Self) f64 {
        if (self.n_clicks == 0) {
            return 0.0;
        }
        const score = @as(f64, @floatFromInt(self.n_hits)) / @as(f64, @floatFromInt(self.n_clicks));
        return score;
    }
};

pub const Tracking = struct {
    spawn: sp.Spawn,
    bots: [1]bot.Bot,
    last_hit: ?rl.Vector3,
    hit_frames: usize,
    total_frames: usize,

    const Self = @This();

    pub fn init(spawn: sp.Spawn) Self {
        return .{
            .spawn = spawn,
            .bots = .{
                bot.Bot.init(
                    geo.Geometry{
                        .sphere = geo.Sphere.init(
                            spawn.origin,
                            RADIUS,
                            COLOR,
                            KINETIC_CONFIG,
                        ),
                    },
                ),
            },
            .last_hit = null,
            .hit_frames = 0.0,
            .total_frames = 0.0,
        };
    }

    pub fn draw(self: *Self) void {
        self.spawn.draw(rl.Color.green);

        for (&self.bots) |*b| {
            b.draw();
        }
    }

    pub fn kill(self: *Self, camera: *rl.Camera3D) void {
        for (&self.bots) |*b| {
            const delta = rl.getFrameTime();
            b.step(delta);
        }
        if (rl.isMouseButtonDown(rl.MouseButton.left)) {
            var i: usize = 0;

            while (i < self.bots.len) : (i += 1) {
                if (self.bots[i].hitScan(camera)) |hit_vec| {
                    // self.bots[i].update(self.spawn.getRandomPosition(), RADIUS, COLOR, HEIGHT);
                    self.last_hit = hit_vec;
                    self.hit_frames += 1;
                    // std.debug.print("V(x={d:2.2}, y={d:2.2}, z={d:2.2})\n", .{ hit_vec.x, hit_vec.y, hit_vec.z });
                }
            }
        }
        self.total_frames += 1;
    }

    pub fn getScore(self: *Self) f64 {
        if (self.total_frames == 0) {
            return 0.0;
        }
        const score = @as(f64, @floatFromInt(self.hit_frames)) / @as(f64, @floatFromInt(self.total_frames));
        return score;
    }
};

// TODO: allocate wanderers dynamically instead of using global variables.
var sin_wander = mov.modifiers.sinusoidal.SinusoidalWanderModifier{
    .amplitude = 20.0,
    .freq = 2.0,
};

var noise_wander = mov.modifiers.noise.NoiseWanderModifier{
    .strength = 3.0,
};

var min_speed = mov.constraints.velocity.MinSpeedConstraint{ .min_speed = 12.0 };

var max_speed = mov.constraints.velocity.MaxSpeedConstraint{ .max_speed = 20.0 };

var bias = mov.constraints.acceleration.PointBiasConstraint{
    .point = rl.Vector3.init(50.0, 2.0, 0.0),
    .strength = 2.0,
};

const modifiers_arr = [2]mov.modifiers.MovementModule{
    sin_wander.toModule(1.0),
    noise_wander.toModule(1.0),
};

const modifiers = mov.modifiers.MovementModifiers{
    .modules = &modifiers_arr,
};

const vel_constraints_arr = [2]mov.constraints.VelocityConstraintModule{
    min_speed.toModule(),
    max_speed.toModule(),
};

const acc_constraints_arr = [1]mov.constraints.AccelConstraintModule{
    bias.toModule(),
};

const constraints = mov.constraints.Constraints{
    .accel_constraints = &acc_constraints_arr,
    .velocity_constraints = &vel_constraints_arr,
};

const KINETIC_CONFIG = mov.kinetic.KineticConfig{
    .constraints = constraints,
    .modifiers = modifiers,
};
