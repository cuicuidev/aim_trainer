const std = @import("std");
const rl = @import("raylib");

pub const FrameInput = extern struct {
    frame_time: f32,
    mouse_delta: rl.Vector2,
    lmb_pressed: bool,
    lmb_down: bool,
};

pub const ScenarioTape = struct {
    // Base
    allocator: std.mem.Allocator,
    prng: std.Random.Xoshiro256,
    initial_random_state: [4]u64,
    target_fps: f32,

    // Variables
    frames: std.ArrayList(FrameInput),
    replay_index: usize = 0,

    // FPS adjustment
    time_accumulator: f32 = 0.0,
    accumulated_mouse_delta: rl.Vector2 = rl.Vector2.init(0.0, 0.0),
    accumulated_lmb_pressed: bool = false,
    accumulated_lmb_down: bool = false,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        target_fps: f32,
        random_state: [4]u64,
    ) Self {
        var self = Self{
            .allocator = allocator,
            .prng = std.Random.Xoshiro256.init(0),
            .initial_random_state = random_state,
            .target_fps = target_fps,
            .frames = std.ArrayList(FrameInput).init(allocator),
        };

        self.prng.s = random_state;

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.frames.deinit();
    }

    pub fn setRandomState(self: *Self, random_state: [4]u64) void {
        self.prng.s = random_state;
    }

    pub fn record(
        self: *Self,
        delta_time: f32,
        mouse_delta: rl.Vector2,
        lmb_pressed: bool,
        lmb_down: bool,
    ) !void {
        self.time_accumulator += delta_time;
        self.accumulated_mouse_delta.x += mouse_delta.x;
        self.accumulated_mouse_delta.y += mouse_delta.y;

        if (!self.accumulated_lmb_pressed) {
            self.accumulated_lmb_pressed = lmb_pressed;
        }
        if (!self.accumulated_lmb_down) {
            self.accumulated_lmb_down = lmb_down;
        }

        const frame_interval = 1.0 / self.target_fps;

        while (self.time_accumulator >= frame_interval) {
            const input = FrameInput{
                .frame_time = frame_interval,
                .mouse_delta = self.accumulated_mouse_delta,
                .lmb_pressed = self.accumulated_lmb_pressed,
                .lmb_down = self.accumulated_lmb_down,
            };
            try self.frames.append(input);

            self.time_accumulator -= frame_interval;

            // Reset accumulators for next frame period
            self.accumulated_mouse_delta = rl.Vector2.init(0.0, 0.0);
            self.accumulated_lmb_pressed = false;
            self.accumulated_lmb_down = false;
        }
    }

    pub fn nextFrame(self: *Self, delta_time: f32) ?FrameInput {
        self.time_accumulator += delta_time;

        while (self.replay_index < self.frames.items.len) {
            const input = self.frames.items[self.replay_index];

            if (self.time_accumulator >= input.frame_time) {
                self.time_accumulator -= input.frame_time;
                self.replay_index += 1;
                return input;
            } else {
                break;
            }
        }

        return null;
    }

    pub fn saveToFile(self: *Self, scenario_name: []const u8) !void {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "{s}.tape",
            .{scenario_name},
        );
        defer self.allocator.free(path);

        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        var writer = file.writer();

        // Write the random state first

        std.debug.print("ScenarioTape.saveToFile | s[0] = {}\n", .{self.initial_random_state[0]});
        std.debug.print("ScenarioTape.saveToFile | s[1] = {}\n", .{self.initial_random_state[1]});
        std.debug.print("ScenarioTape.saveToFile | s[2] = {}\n", .{self.initial_random_state[2]});
        std.debug.print("ScenarioTape.saveToFile | s[3] = {}\n\n", .{self.initial_random_state[3]});

        for (0..4) |i| {
            try writer.writeInt(u64, self.initial_random_state[i], std.builtin.Endian.little);
        }

        // Write each frame input
        for (self.frames.items) |frame| {
            try writer.writeStruct(frame);
        }
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Self {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const reader = file.reader();

        var self = Self{
            .allocator = allocator,
            .prng = std.Random.Xoshiro256.init(0),
            .initial_random_state = .{undefined} ** 4,
            .target_fps = 144.0,
            .frames = std.ArrayList(FrameInput).init(allocator),
        };

        // Read the random state
        for (0..4) |i| {
            self.initial_random_state[i] = try reader.readInt(u64, std.builtin.Endian.little);
        }

        self.prng.s = self.initial_random_state;

        std.debug.print("ScenarioTape.loadFromFile | s[0] = {}\n", .{self.prng.s[0]});
        std.debug.print("ScenarioTape.loadFromFile | s[1] = {}\n", .{self.prng.s[1]});
        std.debug.print("ScenarioTape.loadFromFile | s[2] = {}\n", .{self.prng.s[2]});
        std.debug.print("ScenarioTape.loadFromFile | s[3] = {}\n\n", .{self.prng.s[3]});

        // Read all frames until EOF
        while (true) {
            const read = reader.readStruct(FrameInput);
            if (read == error.EndOfStream) break;
            try self.frames.append(try read);
        }

        return self;
    }
};
