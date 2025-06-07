const std = @import("std");

const rl = @import("raylib");

const scen = @import("../scen/root.zig");
const bot = @import("../bot/root.zig");

pub const Benchmark = struct {
    allocator: std.mem.Allocator,
    scenario_lookup: scen.ScenarioLookup,
    at: usize,

    const Self = @This();

    pub fn default(allocator: std.mem.Allocator) !Self {
        const scenario_lookup = try scen.ScenarioLookup.init(allocator, 4);

        return .{
            .allocator = allocator,
            .scenario_lookup = scenario_lookup,
            .at = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        std.debug.print("benchmark.deinit() called\n", .{});

        self.scenario_lookup.deinit();
    }

    fn next(self: *Self) void {
        self.at += 1;
    }

    pub fn setScore(self: *Self, score: f64) void {
        self.scores[self.at] = score;
    }

    pub fn getScenario(self: *Self, name: []const u8) !scen.Scenario {
        const scenario = try scen.Scenario.fromConfig(
            self.allocator,
            self.scenario_lookup.get(name).?,
        );
        return scenario;
    }

    pub fn nextScenario(self: *Self) !scen.Scenario {
        const scenario = try scen.Scenario.fromConfig(
            self.allocator,
            self.scenario_lookup.scenario_configs[self.at],
        );
        self.next();
        return scenario;
    }

    pub fn reset(self: *Self) void {
        self.at = 0;
    }
};
