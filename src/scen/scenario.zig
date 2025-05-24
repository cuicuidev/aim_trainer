const std = @import("std");

const rl = @import("raylib");

const sp = @import("spawn.zig");

const bot = @import("../bot/root.zig");
const geo = bot.geo;
const mov = bot.mov;

pub const ScenarioType = union(enum) {
    clicking: Clicking,
    tracking: Tracking,
};

pub const Scenario = struct {
    allocator: std.mem.Allocator,
    spawn: sp.Spawn,
    bots: []bot.Bot,
    bot_config: bot.BotConfig,
    scenario_type: ScenarioType,
    duration_ms: f32 = 5.0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, spawn: sp.Spawn, bot_config: bot.BotConfig, scenario_type: ScenarioType) !Self {
        const bots = try allocator.alloc(bot.Bot, bot_config.n_bots);
        var self = Self{
            .allocator = allocator,
            .spawn = spawn,
            .bots = bots,
            .bot_config = bot_config,
            .scenario_type = scenario_type,
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
        switch (self.scenario_type) {
            .clicking => |*s| s.kill(self, camera),
            .tracking => |*s| s.kill(self, camera),
        }
    }

    pub fn getScore(self: *Self) f64 {
        return switch (self.scenario_type) {
            .clicking => |*s| s.getScore(),
            .tracking => |*s| s.getScore(),
        };
    }
};

pub const Clicking = struct {
    n_hits: usize = 0,
    n_clicks: usize = 0,

    const Self = @This();

    pub fn kill(self: *Self, scenario: *Scenario, camera: *rl.Camera3D) void {
        for (scenario.bots) |*b| {
            const delta = rl.getFrameTime();
            b.step(delta);
        }
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            var i: usize = 0;

            while (i < scenario.bots.len) : (i += 1) {
                if (scenario.bots[i].hitScan(camera)) |_| {
                    scenario.bots[i] = bot.Bot.init(scenario.bot_config.geometry);
                    scenario.spawnBot(i);
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
    n_kills: usize = 0,
    hit_frames: usize = 0,
    total_frames: usize = 0,

    const Self = @This();

    pub fn kill(self: *Self, scenario: *Scenario, camera: *rl.Camera3D) void {
        for (scenario.bots) |*b| {
            const delta = rl.getFrameTime();
            b.step(delta);
        }
        if (rl.isMouseButtonDown(rl.MouseButton.left)) {
            var i: usize = 0;

            while (i < scenario.bots.len) : (i += 1) {
                if (scenario.bots[i].hitScan(camera)) |_| {
                    self.hit_frames += 1;
                    break;
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
