const std = @import("std");

const rl = @import("raylib");

const scen = @import("../scen/root.zig");

pub const FrameInputData = extern struct {
    camera_target: rl.Vector3,
    fire_button_pressed: bool,
    fire_button_down: bool,
};

pub const FrameBotData = struct {
    positions: []rl.Vector3,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, n_bots: usize) !Self {
        return .{
            .positions = try allocator.alloc(rl.Vector3, n_bots),
        };
    }

    pub fn setPositions(self: *Self, positions: []const rl.Vector3) void {
        for (0..positions.len) |i| {
            self.positions[i] = positions[i];
        }
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.positions);
    }
};

pub const FrameData = struct {
    time: f32,
    input: FrameInputData,
    bots: FrameBotData,
    playback_time: f32,
};

pub const ScenarioData = extern struct {
    hash: [4]u64,
    n_bots: usize,
};

/// Protocol v0 byte layout
/// | version |   scen_data  | n_frames | frame_0 | frame_1 | frame_2 | ... | frame_n |
/// |   u32   | u256 + usize |   usize  |   ...   |   ...   |   ...   | ... |   ...   |
pub const ReplayTape = struct {
    allocator: std.mem.Allocator,
    frames: std.ArrayList(FrameData),
    scenario_data: ScenarioData,

    _protocol_version: u32 = 0,

    _playback_time: f32 = 0.0,
    _at: usize = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, scenario_ptr: *scen.Scenario) Self {
        return .{
            .allocator = allocator,
            .frames = std.ArrayList(FrameData).init(allocator),
            .scenario_data = ScenarioData{
                .hash = scenario_ptr.hash,
                .n_bots = scenario_ptr.bot_config.n_bots,
            },
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.frames.items) |*frame| {
            frame.bots.deinit(self.allocator);
        }
        self.frames.deinit();
    }

    pub fn record(
        self: *Self,
        delta_time: f32,

        // Input
        camera_target: rl.Vector3,
        fire_button_pressed: bool,
        fire_button_down: bool,

        // Scenario State
        scenario_ptr: *scen.Scenario,
    ) !void {
        const input = FrameInputData{
            .camera_target = camera_target,
            .fire_button_pressed = fire_button_pressed,
            .fire_button_down = fire_button_down,
        };

        const bots = try FrameBotData.init(
            self.allocator,
            scenario_ptr.bot_config.n_bots,
        );

        var playback_time: f32 = 0.0;
        if (self.frames.items.len != 0) {
            playback_time = self.frames.items[self.frames.items.len - 1].playback_time;
        }

        const frame = FrameData{
            .time = delta_time,
            .input = input,
            .bots = bots,
            .playback_time = playback_time + delta_time,
        };
        try self.frames.append(frame);
    }
    pub fn nextFrame(self: *Self, dt: f32) ?FrameData {
        self._playback_time += dt;

        while (self._at < self.frames.items.len) {
            const frame = self.frames.items[self._at];

            // Sum of all previous frame times up to this frame
            const total_time: f32 = self.frames.items[self._at].playback_time;

            // If the playback time has caught up with or surpassed this frame
            if (self._playback_time >= total_time) {
                self._at += 1;
                return frame;
            } else {
                return null; // Not yet time for this frame
            }
        }

        return null; // All frames exhausted
    }

    pub fn saveToFile(self: *const Self, file_name: []const u8) !void {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "{s}.tape",
            .{file_name},
        );
        defer self.allocator.free(path);

        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        var writer = file.writer();

        // Version First
        try writer.writeInt(u32, self._protocol_version, std.builtin.Endian.big);

        // Scenario Data
        try writer.writeStruct(self.scenario_data);

        // N Frames
        try writer.writeInt(usize, self.frames.items.len, std.builtin.Endian.big);

        // Frames
        for (self.frames.items) |frame| {
            // Time
            const time_bit = @as(u32, @bitCast(frame.time));
            try writer.writeInt(u32, time_bit, std.builtin.Endian.big);

            // InputData
            try writer.writeStruct(frame.input);

            // BotData
            for (frame.bots.positions) |position| {
                try writer.writeStruct(position);
            }

            // Playback
            const playback_bit = @as(u32, @bitCast(frame.playback_time));
            try writer.writeInt(u32, playback_bit, std.builtin.Endian.big);
        }
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, file_name: []const u8) !Self {
        const path = try std.fmt.allocPrint(
            allocator,
            "{s}.tape",
            .{file_name},
        );
        defer allocator.free(path);

        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const reader = file.reader();

        var self = Self{
            .allocator = allocator,
            .frames = std.ArrayList(FrameData).init(allocator),
            ._protocol_version = undefined,
            .scenario_data = undefined,
        };

        // Version
        self._protocol_version = try reader.readInt(u32, std.builtin.Endian.big);

        if (self._protocol_version != 0) {
            return error.UnsupportedReplayProtocolVersion;
        }

        // Scenario Data
        self.scenario_data = try reader.readStruct(ScenarioData);

        // N Frames
        const n_frames = try reader.readInt(usize, std.builtin.Endian.big);

        // Frames
        for (0..n_frames) |_| {
            // Time
            const time_bit: u32 = try reader.readInt(u32, std.builtin.Endian.big);
            const time = @as(f32, @bitCast(time_bit));

            // InputData
            const input_data: FrameInputData = try reader.readStruct(FrameInputData);

            // BotData
            var bot_data = try FrameBotData.init(self.allocator, self.scenario_data.n_bots);
            for (0..self.scenario_data.n_bots) |i| {
                bot_data.positions[i] = try reader.readStruct(rl.Vector3);
            }

            // Playback
            const playback_bit: u32 = try reader.readInt(u32, std.builtin.Endian.big);
            const playback = @as(f32, @bitCast(playback_bit));

            // FrameData
            const frame_data = FrameData{
                .time = time,
                .input = input_data,
                .bots = bot_data,
                .playback_time = playback,
            };
            try self.frames.append(frame_data);
        }
        return self;
    }
};
