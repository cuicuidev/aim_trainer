const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const scen = @import("scen/root.zig");
const bot = @import("bot/root.zig");
const menu = @import("menu/root.zig");
const bm = @import("benchmark/root.zig");

const SCREEN_WIDTH = 1920;
const SCREEN_HEIGHT = 1080;

pub const GameState = enum {
    main_menu,
    benchmark_main_menu,
    benchmark_scenario_end_menu,
    benchmark_results_menu,
    scenario_selection_menu,
    scenario_gameplay,
    quit,
};

const Sensitivity = struct {
    base_cpi: f32 = 1600.0,
    cm360_to_sens_ratio: f32 = 0.6,
    cpi: f32,
    cm360: f32,
    value: f32,

    const Self = @This();

    pub fn init(cm360: f32, cpi: f32) Self {
        const base_cpi: f32 = 1600.0;
        const cm360_to_sens_ratio: f32 = 0.6;

        return .{
            .base_cpi = base_cpi,
            .cm360_to_sens_ratio = cm360_to_sens_ratio,
            .cpi = cpi,
            .cm360 = cm360,
            .value = ((cpi / base_cpi) * cm360_to_sens_ratio) / cm360,
        };
    }

    pub fn setCM360(self: *Self, cm360: f32) void {
        self.cm360 = cm360;
        self.value = ((self.cpi / self.base_cpi) * self.cm360_to_sens_ratio) / self.cm360;
    }

    pub fn setCPI(self: *Self, cpi: f32) void {
        self.cpi = cpi;
        self.setCM360(self.cm360);
    }

    pub fn allocPrintCM360(self: *Self, allocator: std.mem.Allocator) ![:0]const u8 {
        return try std.fmt.allocPrintZ(allocator, "CM360: {d:3.0}", .{self.cm360});
    }
};

pub fn main() anyerror!void {
    var STATE = GameState.main_menu;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    // Initialization
    const config_flags = rl.ConfigFlags{
        .fullscreen_mode = true,
        .window_unfocused = false,
        .msaa_4x_hint = true,
    };

    rl.setConfigFlags(config_flags);

    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Aimalytics");
    errdefer rl.closeWindow();

    rl.setExitKey(rl.KeyboardKey.null);

    var camera = rl.Camera3D{
        .position = rl.Vector3.init(0.0, 2.0, 0.0),
        .target = rl.Vector3.init(10.0, 2.0, 0.0),
        .up = rl.Vector3.init(0.0, 1.0, 0.0),
        .fovy = 58.0,
        .projection = rl.CameraProjection.perspective,
    };

    const sensitivity = Sensitivity.init(70.0, 1600.0);

    // Benchmark prep
    var benchmark = try bm.Benchmark.default(allocator);
    defer benchmark.deinit();

    var scenario: scen.Scenario = undefined;
    var time_elapsed: f32 = 0.0;

    // Menu prep
    var main_menu = menu.MainMenu.init(SCREEN_HEIGHT, SCREEN_WIDTH, "Aymalitcs");
    var benchmark_menu = menu.BenchmarkMenu.init(SCREEN_HEIGHT, SCREEN_WIDTH, "Benchmark", &benchmark);
    var _menu = main_menu.toMenu();

    // Main game loop
    while (!rl.windowShouldClose()) {
        switch (STATE) {
            .main_menu => {
                if (rl.isCursorHidden()) {
                    rl.enableCursor();
                }

                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(rl.Color.dark_gray);

                if (_menu.draw()) |option| {
                    switch (option) {
                        .goto_benchmark_menu => {
                            STATE = GameState.benchmark_main_menu;
                            _menu = benchmark_menu.toMenu();
                        },
                        .quit_trainer => STATE = GameState.quit,
                        else => unreachable,
                    }
                }
            },
            .benchmark_main_menu => {
                if (rl.isCursorHidden()) {
                    rl.enableCursor();
                }

                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(rl.Color.dark_gray);

                if (_menu.draw()) |option| {
                    switch (option) {
                        .next_scenario => STATE = GameState.scenario_gameplay,
                        .goto_main_menu => {
                            for (benchmark.scores) |score| {
                                std.debug.print("{d}\n", .{score});
                            }

                            STATE = GameState.main_menu;
                            benchmark.reset();
                            _menu = main_menu.toMenu();
                        },
                        else => unreachable,
                    }
                }
            },
            .scenario_gameplay => {
                if (!rl.isCursorHidden()) {
                    rl.disableCursor();
                    camera = rl.Camera3D{
                        .position = rl.Vector3.init(0.0, 2.0, 0.0),
                        .target = rl.Vector3.init(10.0, 2.0, 0.0),
                        .up = rl.Vector3.init(0.0, 1.0, 0.0),
                        .fovy = 58.0,
                        .projection = rl.CameraProjection.perspective,
                    };
                    scenario = benchmark.scenario();
                }

                // ---------------------------------------------------------------------------------------
                // UPDATE --------------------------------------------------------------------------------
                // ---------------------------------------------------------------------------------------

                time_elapsed += rl.getFrameTime();

                if (time_elapsed >= scenario.duration_ms) {
                    const score = scenario.getScore();
                    benchmark.setScore(score);
                    benchmark.next();
                    STATE = GameState.benchmark_main_menu;
                    time_elapsed = 0.0;
                    continue;
                }

                // Camera update
                const mouse_delta = rl.getMouseDelta();
                const rotation = rl.Vector3.init(
                    mouse_delta.x * sensitivity.value, // pitch (up/down)
                    mouse_delta.y * sensitivity.value, // yaw (left/right)
                    0.0, // roll
                );
                const movement = rl.Vector3.init(0.0, 0.0, 0.0);
                rl.updateCameraPro(&camera, movement, rotation, 0.0);

                // Scenario events
                scenario.kill(&camera);

                // -----------------------------------------------------------------------------------------
                // RENDER ----------------------------------------------------------------------------------
                // -----------------------------------------------------------------------------------------

                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(rl.Color.dark_gray);

                // 3D RENDER -------------------------------------------------------------------------------
                {
                    rl.beginMode3D(camera);
                    defer rl.endMode3D();

                    scenario.draw();
                }

                // 2D RENDER -------------------------------------------------------------------------------
                rl.drawFPS(SCREEN_WIDTH - 200, 40);
                rl.drawCircle(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, 2.5, rl.Color.black);
            },
            .quit => rl.closeWindow(),
            else => unreachable,
        }
    }
}
