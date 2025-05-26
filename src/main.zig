const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const scen = @import("scen/root.zig");
const bot = @import("bot/root.zig");
const menu = @import("menu/root.zig");
const bm = @import("benchmark/root.zig");
const tape = @import("tape/root.zig");
const rand = @import("rand/root.zig");
const config = @import("config/root.zig");

pub const GameState = enum {
    main_menu,
    benchmark_main_menu,
    scenario_gameplay,
    scenario_replay,
    quit,
};

pub fn main() !void {
    // Alocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // PRNG
    const time = std.time.timestamp();
    const seed = @as(u64, @bitCast(time));
    var random = rand.RandomState.init(seed);

    // Raylib window initialization
    const dims = getMainMonitorDimensions();
    const SCREEN_WIDTH = dims[0];
    const SCREEN_HEIGHT = dims[1];

    const HALF_SCREEN_WIDTH = @divFloor(SCREEN_WIDTH, @as(i32, 2));
    const HALF_SCREEN_HEIGHT = @divFloor(SCREEN_HEIGHT, @as(i32, 2));

    const config_flags = rl.ConfigFlags{
        .fullscreen_mode = true,
        .window_unfocused = false,
        .msaa_4x_hint = true,
        .window_hidden = false,
    };

    rl.setConfigFlags(config_flags);

    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Aimalytics");
    errdefer rl.closeWindow();

    rl.setExitKey(rl.KeyboardKey.null);

    // Game config initialization
    const sensitivity = config.Sensitivity.init(70.0, 1600.0);

    var STATE = GameState.main_menu;
    var camera: rl.Camera3D = undefined;
    var time_elapsed: f32 = 0.0;

    var crosshair = try Crosshair.init(
        allocator,
        3.0,
        rl.Color.black,
        HALF_SCREEN_WIDTH,
        HALF_SCREEN_HEIGHT,
    );
    defer crosshair.deinit();

    // Replay system initialization
    var scenario_tape = tape.ScenarioTape.init(allocator, 144.0, &random);
    defer scenario_tape.deinit();

    // Game scenarios initialization
    var benchmark = try bm.Benchmark.default(allocator, &random);
    defer benchmark.deinit();

    var scenario: scen.Scenario = undefined;

    // Game menu initialization
    var main_menu = menu.MainMenu.init(SCREEN_HEIGHT, SCREEN_WIDTH, "Aimalytics");
    var benchmark_menu = menu.BenchmarkMenu.init(SCREEN_HEIGHT, SCREEN_WIDTH, "Benchmark", &benchmark);
    var _menu = main_menu.toMenu();

    // ------------------------------------------------------------------------------------------------------------------
    // ------------------------------------------------- MAIN GAME LOOP -------------------------------------------------
    // ------------------------------------------------------------------------------------------------------------------
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
                        .replay_scenario => STATE = GameState.scenario_replay,
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
                // Scenario initialization
                if (!rl.isCursorHidden()) {
                    rl.disableCursor();
                    camera = getCamera();
                    scenario = benchmark.scenario();
                }

                // Scenario end update
                const delta_time = rl.getFrameTime();
                time_elapsed += delta_time;

                if (time_elapsed >= scenario.duration_ms) {
                    STATE = GameState.benchmark_main_menu;
                    time_elapsed = 0.0;

                    benchmark.setScore(scenario.getScore());
                    benchmark.next();

                    try scenario_tape.saveToFile("tape");
                    scenario_tape.reset();
                    continue;
                }

                // Camera update
                const mouse_delta = rl.getMouseDelta();
                const rotation = rl.Vector3.init(
                    mouse_delta.x * sensitivity.value,
                    mouse_delta.y * sensitivity.value,
                    0.0,
                );

                const movement = rl.Vector3.init(0.0, 0.0, 0.0);

                rl.updateCameraPro(&camera, movement, rotation, 0.0);

                // Scenario events update
                const lmb_pressed = rl.isMouseButtonPressed(rl.MouseButton.left);
                const lmb_down = rl.isMouseButtonDown(rl.MouseButton.left);

                scenario.kill(&camera, lmb_pressed, lmb_down);

                try scenario_tape.record(
                    delta_time,
                    mouse_delta,
                    lmb_pressed,
                    lmb_down,
                );

                // RENDER ----------------------------------------------------------------------------------
                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(rl.Color.dark_gray);

                // 3D
                {
                    rl.beginMode3D(camera);
                    defer rl.endMode3D();

                    scenario.draw();
                }

                // 2D
                rl.drawFPS(SCREEN_WIDTH - 200, 40);
                crosshair.drawCenter();
            },
            .scenario_replay => {
                // Scenario initialization
                if (!rl.isCursorHidden()) {
                    rl.disableCursor();

                    // TODO: tape must hold the scenario too, so benchmark deinit is not necesary.
                    camera = getCamera();

                    benchmark.deinit();
                    try scenario_tape.loadFromFile("tape");
                    random.setState(scenario_tape.initial_random_state);
                    benchmark = try bm.Benchmark.default(allocator, &random);

                    scenario = benchmark.scenario();
                }

                // Update at a set FPS
                const delta_time = rl.getFrameTime();
                time_elapsed += delta_time;

                const frame = scenario_tape.advanceAndGetFrame(delta_time);

                if (frame) |input| {
                    const rotation = rl.Vector3.init(
                        input.mouse_delta.x,
                        input.mouse_delta.y,
                        0.0,
                    ).scale(sensitivity.value);
                    const movement = rl.Vector3.init(0.0, 0.0, 0.0);
                    rl.updateCameraPro(&camera, movement, rotation, 0.0);

                    scenario.kill(&camera, input.lmb_pressed, input.lmb_down);
                }

                // Scenario end update
                if (time_elapsed >= scenario.duration_ms or scenario_tape.replay_index >= scenario_tape.frames.items.len) {
                    STATE = GameState.main_menu;
                    time_elapsed = 0.0;

                    scenario_tape.reset();
                    continue;
                }

                // RENDER
                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(rl.Color.dark_gray);

                // 3D
                {
                    rl.beginMode3D(camera);
                    defer rl.endMode3D();
                    scenario.draw();
                }

                // 2D
                scenario.drawLineToClosestBot(&camera);

                rl.drawFPS(SCREEN_WIDTH - 200, 40);
                crosshair.drawCenter();
            },
            .quit => rl.closeWindow(),
        }
    }
}

fn getMainMonitorDimensions() [2]i32 {
    rl.initWindow(1, 1, "Dummy");
    defer rl.closeWindow();

    const flags = rl.ConfigFlags{
        .window_hidden = true,
    };
    rl.setConfigFlags(flags);

    const main_monitor = rl.getCurrentMonitor();
    const width = rl.getMonitorWidth(main_monitor);
    const height = rl.getMonitorHeight(main_monitor);

    return .{ width, height };
}

fn getCamera() rl.Camera3D {
    return rl.Camera3D{
        .position = rl.Vector3.init(0.0, 2.0, 0.0),
        .target = rl.Vector3.init(10.0, 2.0, 0.0),
        .up = rl.Vector3.init(0.0, 1.0, 0.0),
        .fovy = 58.0,
        .projection = rl.CameraProjection.perspective,
    };
}

pub const Crosshair = struct {
    allocator: std.mem.Allocator,
    center_pos: rl.Vector2,
    size: f32,
    color: rl.Color,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        size: f32,
        color: rl.Color,
        half_screen_width: i32,
        half_screen_height: i32,
    ) !Self {
        const center = rl.Vector2.init(@as(f32, @floatFromInt(half_screen_width)), @as(f32, @floatFromInt(half_screen_height)));
        return .{
            .allocator = allocator,
            .center_pos = center,
            .size = size,
            .color = color,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn drawCenter(self: *const Self) void {
        rl.drawCircleV(self.center_pos, self.size, self.color);
    }
};
