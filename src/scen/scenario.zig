const std = @import("std");

const rl = @import("raylib");

const sp = @import("spawn.zig");

const bot = @import("../bot/root.zig");
const geo = bot.geo;
const mov = bot.mov;

const rep = @import("../replay/root.zig");

pub const ScenarioType = union(enum) {
    clicking: Clicking,
    tracking: Tracking,
};

pub const ScenarioConfig = struct {
    name: []const u8,
    bot_config: bot.BotConfig,
    spawn: sp.Spawn,
    duration: f32,
    scenario_type: ScenarioType,
};

pub const Scenario = struct {
    // Base
    allocator: std.mem.Allocator,
    name: []const u8,
    hash: [4]u64 = .{ 0, 0, 0, 0 },

    // Environment
    spawn: sp.Spawn,

    // Configuration
    scenario_type: ScenarioType,
    bot_config: bot.BotConfig,
    duration_ms: f32,

    // Variables
    prng: std.Random.Xoshiro256,
    bots: []bot.Bot,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        spawn: sp.Spawn,
        scenario_type: ScenarioType,
        bot_config: bot.BotConfig,
        duration_ms: f32,
    ) !Self {
        const time = std.time.timestamp();
        const seed = @as(u64, @bitCast(time));
        const prng = std.Random.Xoshiro256.init(seed);

        const bots = try allocator.alloc(
            bot.Bot,
            bot_config.n_bots,
        );

        var self = Self{
            .allocator = allocator,
            .name = name,
            .spawn = spawn,
            .scenario_type = scenario_type,
            .bot_config = bot_config,
            .duration_ms = duration_ms,
            .prng = prng,
            .bots = bots,
        };

        var i: usize = 0;
        while (i < self.bot_config.n_bots) : (i += 1) {
            self.bots[i] = bot.Bot.init(self.bot_config.geometry);
            self.spawnBot(i);
        }

        return self;
    }

    pub fn fromConfig(allocator: std.mem.Allocator, config: ScenarioConfig) !Self {
        return try Self.init(
            allocator,
            config.name,
            config.spawn,
            config.scenario_type,
            config.bot_config,
            config.duration,
        );
    }

    pub fn deinit(self: *Self) void {
        self.bot_config.geometry.deinit(self.allocator);
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
        const pos = self.spawn.getRandomPosition(&self.prng);
        self.bots[idx].geometry.setPosition(pos);
    }

    pub fn draw(self: *Self) void {
        self.spawn.draw(rl.Color.green);
        for (self.bots) |*b| {
            b.draw();
        }
    }

    pub fn drawLineToClosestBot(self: *Self, camera_ptr: *rl.Camera3D, color: rl.Color) void {
        if (self.bots.len == 0) return;

        const screen_center = rl.Vector2.init(
            @as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0,
            @as(f32, @floatFromInt(rl.getScreenHeight())) / 2.0,
        );

        const ray = rl.getScreenToWorldRay(screen_center, camera_ptr.*);

        var closest_idx: usize = 0;
        var closest_dist_sq: f32 = std.math.floatMax(f32);

        var i: usize = 0;
        while (i < self.bots.len) : (i += 1) {
            const bot_pos = self.bots[i].geometry.getPosition();

            const to_bot = rl.Vector3.subtract(bot_pos, ray.position);
            const t = rl.Vector3.dotProduct(to_bot, ray.direction);
            const closest_point_on_ray = rl.Vector3.add(ray.position, rl.Vector3.scale(ray.direction, t));

            const diff = rl.Vector3.subtract(bot_pos, closest_point_on_ray);
            const dist_sq = rl.Vector3.lengthSqr(diff);

            if (dist_sq < closest_dist_sq) {
                closest_dist_sq = dist_sq;
                closest_idx = i;
            }
        }

        const target_pos = self.bots[closest_idx].geometry.getPosition();
        const target_screen_pos = rl.getWorldToScreen(target_pos, camera_ptr.*);

        rl.drawLine(
            @as(i32, @intFromFloat(screen_center.x)),
            @as(i32, @intFromFloat(screen_center.y)),
            @as(i32, @intFromFloat(target_screen_pos.x)),
            @as(i32, @intFromFloat(target_screen_pos.y)),
            color,
        );
    }

    pub fn kill(self: *Self, camera: *rl.Camera3D, lmb_pressed: bool, lmb_down: bool, dt: f32, frame_delta: usize) void {
        switch (self.scenario_type) {
            .clicking => |*s| s.kill(self, camera, lmb_pressed, lmb_down, dt, &self.prng, frame_delta),
            .tracking => |*s| s.kill(self, camera, lmb_pressed, lmb_down, dt, &self.prng, frame_delta),
        }
    }

    pub fn replay(self: *Self, frame_data: rep.FrameData) void {
        switch (self.scenario_type) {
            .clicking => |*s| s.replay(self, frame_data),
            .tracking => |*s| s.replay(self, frame_data),
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

    pub fn kill(
        self: *Self,
        scenario: *Scenario,
        camera: *rl.Camera3D,
        lmb_pressed: bool,
        lmb_down: bool,
        dt: f32,
        prng_ptr: *std.Random.Xoshiro256,
        frame_delta: usize,
    ) void {
        for (scenario.bots) |*b| {
            b.step(dt, prng_ptr, frame_delta);
        }

        _ = lmb_down;
        if (lmb_pressed) {
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

    pub fn replay(
        self: *Self,
        scenario: *Scenario,
        frame_data: rep.FrameData,
    ) void {
        _ = self;

        for (scenario.bots, frame_data.bots.positions) |*b, pos| {
            b.*.setPosition(pos);
        }
    }

    pub fn getScore(self: *Self) f64 {
        if (self.n_clicks == 0) {
            return 0.0;
        }
        const accuracy = @as(f64, @floatFromInt(self.n_hits)) / @as(f64, @floatFromInt(self.n_clicks));
        const accuracy_sqrt = @sqrt(accuracy);
        return @as(f64, @floatFromInt(self.n_hits)) * accuracy_sqrt;
    }
};

pub const Tracking = struct {
    n_kills: usize = 0,
    hit_frames: usize = 0,
    total_frames: usize = 0,

    const Self = @This();

    pub fn kill(
        self: *Self,
        scenario: *Scenario,
        camera: *rl.Camera3D,
        lmb_pressed: bool,
        lmb_down: bool,
        dt: f32,
        prng_ptr: *std.Random.Xoshiro256,
        frame_delta: usize,
    ) void {
        for (scenario.bots) |*b| {
            b.step(dt, prng_ptr, frame_delta);
        }

        _ = lmb_pressed;
        if (lmb_down) {
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

    pub fn replay(
        self: *Self,
        scenario: *Scenario,
        frame_data: rep.FrameData,
    ) void {
        _ = self;

        for (scenario.bots, frame_data.bots.positions) |*b, pos| {
            b.*.setPosition(pos);
        }
    }

    pub fn getScore(self: *Self) f64 {
        if (self.total_frames == 0) {
            return 0.0;
        }
        const score = @as(f64, @floatFromInt(self.hit_frames)) / @as(f64, @floatFromInt(self.total_frames)) * 100;
        return score;
    }
};
