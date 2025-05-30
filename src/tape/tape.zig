const std = @import("std");
const rl = @import("raylib");

const rand = @import("../rand/root.zig");

pub const FrameInput = extern struct {
    frame_time: f32,
    mouse_delta: rl.Vector2,
    lmb_pressed: bool,
    lmb_down: bool,
};

pub const ScenarioTape = struct {
    allocator: std.mem.Allocator,
    initial_random_state: rand.RandomStateData,
    frames: std.ArrayList(FrameInput),
    replay_index: usize = 0,

    target_fps: f32 = 144.0,
    time_accumulator: f32 = 0.0,

    accumulated_mouse_delta: rl.Vector2 = rl.Vector2.init(0.0, 0.0),
    accumulated_lmb_pressed: bool = false,
    accumulated_lmb_down: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, fps: f32, random_state_ptr: *rand.RandomState) Self {
        return .{
            .allocator = allocator,
            .initial_random_state = random_state_ptr.getState(),
            .frames = std.ArrayList(FrameInput).init(allocator),
            .target_fps = fps,
        };
    }

    pub fn deinit(self: *Self) void {
        self.frames.deinit();
    }

    pub fn reset(self: *Self) void {
        self.replay_index = 0;
        self.time_accumulator = 0.0;
    }

    pub fn setState(self: *Self, random_state_ptr: rand.RandomState) void {
        self.initial_random_state = random_state_ptr.getState();
    }

    pub fn record(self: *Self, delta_time: f32, mouse_delta: rl.Vector2, lmb_pressed: bool, lmb_down: bool) !void {
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

    pub fn advanceAndGetFrame(self: *Self, delta_time: f32) ?FrameInput {
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

    pub fn saveToFile(self: *Self, path: []const u8) !void {
        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        var writer = file.writer();

        // Write the random state first
        try writer.writeStruct(self.initial_random_state);

        // Write each frame input
        for (self.frames.items) |frame| {
            try writer.writeStruct(frame);
        }
    }

    pub fn loadFromFile(self: *Self, path: []const u8) !void {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const reader = file.reader();

        self.frames.deinit();
        self.frames = std.ArrayList(FrameInput).init(self.allocator);
        self.replay_index = 0;

        // Read the random state
        self.initial_random_state = try reader.readStruct(rand.RandomStateData);

        // Read all frames until EOF
        while (true) {
            const read = reader.readStruct(FrameInput);
            if (read == error.EndOfStream) break;
            try self.frames.append(try read);
        }
    }
};
