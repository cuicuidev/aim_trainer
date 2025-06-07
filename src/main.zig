const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const scen = @import("scen/root.zig");
const replay = @import("replay/root.zig");
const bot = @import("bot/root.zig");
const menu = @import("menu/root.zig");
const bm = @import("benchmark/root.zig");
const config = @import("config/root.zig");

const MAX_FPS: i32 = 999;

pub const GameState = enum {
    main_menu,
    benchmark_main_menu,
    replay_main_menu,
    scenario_gameplay,
    scenario_replay,
    quit,
};

pub fn main() !void {
    // Alocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Raylib window initialization
    const dims = getMainMonitorDimensions();
    const SCREEN_WIDTH = dims[0];
    const SCREEN_HEIGHT = dims[1];

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

    rl.setTargetFPS(MAX_FPS);

    // Game config initialization
    const sensitivity = config.Sensitivity.init(70.0, 1600.0);

    var STATE = GameState.main_menu;
    var camera: rl.Camera3D = undefined;
    var time_elapsed: f32 = 0.0;

    var crosshair = try config.Crosshair.init(
        allocator,
        0.003,
        rl.Color.black,
    );
    defer crosshair.deinit();

    var benchmark = try bm.Benchmark.default(allocator);
    defer benchmark.deinit();

    var scenario: scen.Scenario = undefined;
    errdefer scenario.deinit();

    var replay_tape: replay.ReplayTape = undefined;
    errdefer replay_tape.deinit();

    // Game menu initialization
    var tapes: [2][:0]const u8 = .{
        "ww2ts",
        "controlsphere",
    };

    var current_tape_idx: u1 = 0;

    var main_menu = menu.MainMenu.init(SCREEN_HEIGHT, SCREEN_WIDTH, "Aimalytics");
    var benchmark_menu = menu.BenchmarkMenu.init(SCREEN_HEIGHT, SCREEN_WIDTH, "Benchmark", &benchmark);
    var replay_menu = menu.ReplayMenu.init(SCREEN_HEIGHT, SCREEN_WIDTH, "Benchmark", &tapes, &current_tape_idx);
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
                        .replay_scenario => {
                            STATE = GameState.replay_main_menu;
                            _menu = replay_menu.toMenu();
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
                            STATE = GameState.main_menu;
                            benchmark.reset();
                            _menu = main_menu.toMenu();
                        },
                        else => unreachable,
                    }
                }
            },
            .replay_main_menu => {
                if (rl.isCursorHidden()) {
                    rl.enableCursor();
                }

                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(rl.Color.dark_gray);

                if (_menu.draw()) |option| {
                    switch (option) {
                        .next_scenario => {},
                        .prev_scenario => {},
                        .goto_main_menu => {
                            STATE = GameState.main_menu;
                            benchmark.reset();
                            _menu = main_menu.toMenu();
                        },
                        .replay_scenario => {
                            STATE = GameState.scenario_replay;
                            benchmark.reset();
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
                    scenario = try benchmark.nextScenario();
                    replay_tape = replay.ReplayTape.init(allocator, &scenario);
                }

                // Scenario end update
                const delta_time = rl.getFrameTime();
                time_elapsed += delta_time;

                if (time_elapsed >= scenario.duration_ms) {
                    STATE = GameState.benchmark_main_menu;
                    time_elapsed = 0.0;

                    // TODO: Large files take a while to store. They also take up much space.
                    try replay_tape.saveToFile(scenario.name);

                    replay_tape.deinit();
                    scenario.deinit();

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

                scenario.kill(&camera, lmb_pressed, lmb_down, delta_time, 1);

                try replay_tape.record(
                    delta_time,
                    camera.target,
                    lmb_pressed,
                    lmb_down,
                    &scenario,
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
                    crosshair.drawCenter(&camera);
                }

                // 2D
                rl.drawFPS(SCREEN_WIDTH - 200, 40);
            },
            .scenario_replay => {
                // Scenario initialization
                if (!rl.isCursorHidden()) {
                    rl.disableCursor();

                    camera = getCamera();

                    scenario = try benchmark.getScenario(tapes[current_tape_idx]);
                    replay_tape = try replay.ReplayTape.loadFromFile(allocator, scenario.name);
                }

                // Update at a set FPS
                const delta_time = rl.getFrameTime();
                time_elapsed += delta_time;

                const frame = replay_tape.nextFrame(delta_time);

                if (frame) |data| {
                    camera.target = data.input.camera_target;
                    crosshair.updateTrail(&camera);

                    scenario.replay(data);
                }

                // Scenario end update
                if (time_elapsed >= scenario.duration_ms or replay_tape._at >= replay_tape.frames.items.len) {
                    STATE = GameState.replay_main_menu;
                    time_elapsed = 0.0;

                    scenario.deinit();
                    replay_tape.deinit();
                    _menu = replay_menu.toMenu();
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
                    crosshair.drawTrail();
                    crosshair.drawCenter(&camera);
                }

                // 2D
                // scenario.drawLineToClosestBot(&camera, rl.Color.sky_blue);

                rl.drawFPS(SCREEN_WIDTH - 200, 40);
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
