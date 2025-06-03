const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const scen = @import("scen/root.zig");
const bot = @import("bot/root.zig");
const menu = @import("menu/root.zig");
const bm = @import("benchmark/root.zig");
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

    // Raylib window initialization
    const dims = getMainMonitorDimensions();
    const SCREEN_WIDTH = dims[0];
    const SCREEN_HEIGHT = dims[1];

    // const HALF_SCREEN_WIDTH = @divFloor(SCREEN_WIDTH, @as(i32, 2));
    // const HALF_SCREEN_HEIGHT = @divFloor(SCREEN_HEIGHT, @as(i32, 2));

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

    // rl.setTargetFPS(60);

    // Game config initialization
    const sensitivity = config.Sensitivity.init(70.0, 1600.0);

    var STATE = GameState.main_menu;
    var camera: rl.Camera3D = undefined;
    var time_elapsed: f32 = 0.0;

    var crosshair = try Crosshair.init(
        allocator,
        0.003,
        rl.Color.black,
    );
    defer crosshair.deinit();

    // Game scenarios initialization
    // TODO: Decouple Benchmark and Scenario structs. Scenario must be used independently from Benchmark,
    // while Benchmark should allow easy scenario initialization when several Scenario in a row are needed.
    // Maybe Benchmark is a bad idea and we could just have a lookup table to store scenario_name and
    // Scenario key-value pairs. That would make it easier to build a menu to select any scenario to play or
    // to watch the replay. The Benchmark struct could just consist of a series of ordered keys.
    var benchmark = try bm.Benchmark.default(allocator);
    defer benchmark.deinit();

    var scenario: scen.Scenario = undefined;
    errdefer scenario.deinit();

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
                            // for (benchmark.scores) |score| {
                            //     std.debug.print("{d}\n", .{score});
                            // }

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
                    scenario = try benchmark.nextScenario();
                }

                // Scenario end update
                const delta_time = rl.getFrameTime();
                time_elapsed += delta_time;

                if (time_elapsed >= scenario.duration_ms) {
                    STATE = GameState.benchmark_main_menu;
                    time_elapsed = 0.0;

                    const scen_name = scenario.name;
                    try scenario.scenario_tape.saveToFile(scen_name);

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

                scenario.kill(&camera, lmb_pressed, lmb_down);

                try scenario.scenario_tape.record(
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

                    scenario = try benchmark.getScenario("ww4ts");
                    try scenario.loadTape();
                }

                // Update at a set FPS
                const delta_time = rl.getFrameTime();
                time_elapsed += delta_time;

                const frame = scenario.scenario_tape.nextFrame(delta_time);

                if (frame) |input| {
                    const rotation = rl.Vector3.init(
                        input.mouse_delta.x,
                        input.mouse_delta.y,
                        0.0,
                    ).scale(sensitivity.value);
                    const movement = rl.Vector3.init(0.0, 0.0, 0.0);
                    rl.updateCameraPro(&camera, movement, rotation, 0.0);

                    crosshair.updateTrail(&camera);
                    scenario.kill(&camera, input.lmb_pressed, input.lmb_down);
                }

                // Scenario end update
                if (time_elapsed >= scenario.duration_ms or scenario.scenario_tape.replay_index >= scenario.scenario_tape.frames.items.len) {
                    STATE = GameState.main_menu;
                    time_elapsed = 0.0;

                    scenario.deinit();
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
                scenario.drawLineToClosestBot(&camera, rl.Color.sky_blue);

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

pub const Crosshair = struct {
    allocator: std.mem.Allocator,
    size: f32, // Size of the central crosshair sphere
    color: rl.Color, // Color of the central crosshair sphere and trail

    trail_array: []rl.Vector3, // Stores 3D positions of the trail points
    trail_array_pos: usize, // Current index in trail_array to write the next point (circular buffer)
    trail_count: usize, // Number of valid points currently in trail_array (from 0 to trail_array.len)

    const TRAIL_CAPACITY = 64; // Max number of points in the trail
    const CROSSHAIR_DISTANCE: f32 = 1.0; // How far in front of the camera the 3D crosshair point is

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, size: f32, color: rl.Color) !Self {
        const points = try allocator.alloc(rl.Vector3, TRAIL_CAPACITY);

        for (points) |*pt| {
            pt.* = rl.Vector3.zero();
        }

        return .{
            .allocator = allocator,
            .size = size,
            .color = color,
            .trail_array = points,
            .trail_array_pos = 0,
            .trail_count = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.trail_array);
    }

    /// Draws the central crosshair sphere.
    /// Must be called within a BeginMode3D/EndMode3D block.
    pub fn drawCenter(self: *const Self, camera_ptr: *const rl.Camera3D) void {
        const camera_forward = camera_ptr.target.subtract(camera_ptr.position).normalize();
        const crosshair_3d_pos = camera_ptr.position.add(camera_forward.scale(CROSSHAIR_DISTANCE));

        rl.drawSphere(crosshair_3d_pos, self.size, self.color);
    }

    /// Updates the trail with the current crosshair position.
    /// Call this function *after* the camera has been updated for the frame.
    /// The `camera_ptr` should point to the up-to-date camera.
    pub fn updateTrail(self: *Self, camera_ptr: *const rl.Camera3D) void {
        const camera_forward = camera_ptr.target.subtract(camera_ptr.position).normalize();
        const current_crosshair_pos = camera_ptr.position.add(camera_forward.scale(CROSSHAIR_DISTANCE));

        self.trail_array[self.trail_array_pos] = current_crosshair_pos;
        self.trail_array_pos = (self.trail_array_pos + 1) % self.trail_array.len;

        if (self.trail_count < self.trail_array.len) {
            self.trail_count += 1;
        }
    }

    /// Draws the crosshair trail as a series of connected lines.
    /// Must be called within a BeginMode3D/EndMode3D block.
    pub fn drawTrail(self: *const Self) void {
        if (self.trail_count < 2) {
            return; // Not enough points to draw any segments
        }

        // Determine the index of the oldest point in the circular buffer.
        // If the buffer is full, the oldest point is at `self.trail_array_pos`.
        // Otherwise, the oldest point is at index 0.
        var idx_of_oldest_point_in_buffer: usize = 0;
        if (self.trail_count == self.trail_array.len) {
            idx_of_oldest_point_in_buffer = self.trail_array_pos;
        }

        // We will draw `self.trail_count - 1` segments.
        // `segment_iter_idx` goes from 0 (oldest segment) to `self.trail_count - 2` (newest segment).
        for (0..(self.trail_count - 1)) |segment_iter_idx| {
            const p1_buffer_idx = (idx_of_oldest_point_in_buffer + segment_iter_idx) % self.trail_array.len;
            const p2_buffer_idx = (idx_of_oldest_point_in_buffer + segment_iter_idx + 1) % self.trail_array.len;

            const p1 = self.trail_array[p1_buffer_idx];
            const p2 = self.trail_array[p2_buffer_idx];

            // Calculate alpha for fading: oldest segments are more transparent, newest are more opaque.
            // `alpha_lerp_factor` ranges from near 0.0 (oldest) to 1.0 (newest visible segment).
            // For `trail_count` points, there are `trail_count - 1` segments.
            // `segment_iter_idx = 0` is the oldest segment.
            // `segment_iter_idx = self.trail_count - 2` is the newest segment.
            var alpha_lerp_factor: f32 = 0.0;
            if ((self.trail_count - 1) > 1) { // Avoid division by zero if only one segment; handle below
                alpha_lerp_factor = @as(f32, @floatFromInt(segment_iter_idx)) / @as(f32, @floatFromInt(self.trail_count - 2));
            } else if ((self.trail_count - 1) == 1) { // Exactly one segment
                alpha_lerp_factor = 1.0; // Full desired alpha for a single segment trail
            }

            var trail_segment_color = rl.Color.magenta;
            trail_segment_color.a = @as(u8, @intFromFloat(255.0 * alpha_lerp_factor));

            rl.drawLine3D(p1, p2, trail_segment_color);
        }
    }
};
