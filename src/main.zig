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
        rl.Color.sky_blue,
        HALF_SCREEN_WIDTH,
        HALF_SCREEN_HEIGHT,
        30,
    );
    defer crosshair.deinit();

    // Game scenarios initialization
    var benchmark = try bm.Benchmark.default(allocator, &random);
    defer benchmark.deinit();

    var scenario: scen.Scenario = undefined;

    // Game menu initialization
    var main_menu = menu.MainMenu.init(SCREEN_HEIGHT, SCREEN_WIDTH, "Aimalytics");
    var benchmark_menu = menu.BenchmarkMenu.init(SCREEN_HEIGHT, SCREEN_WIDTH, "Benchmark", &benchmark);
    var _menu = main_menu.toMenu();

    // Replay system initialization
    var scenario_tape = tape.ScenarioTape.init(allocator, 144.0, &random);
    defer scenario_tape.deinit();

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
                    const adjusted_mouse_delta = input.mouse_delta.multiply(rl.Vector2.init(sensitivity.value, sensitivity.value));
                    const rotation = rl.Vector3.init(
                        adjusted_mouse_delta.x,
                        adjusted_mouse_delta.y,
                        0.0,
                    );
                    const movement = rl.Vector3.init(0.0, 0.0, 0.0);
                    rl.updateCameraPro(&camera, movement, rotation, 0.0);

                    scenario.kill(&camera, input.lmb_pressed, input.lmb_down);
                    crosshair.updateAllTrails(delta_time, &camera, null);
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
                crosshair.drawCenter(); // Draw the main crosshair dot
                crosshair.drawActualTrail(); // Draw your actual mouse movement trail
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

pub const CrosshairTrailPoint = struct {
    pos: rl.Vector2,
    time: f32,
};

pub const Crosshair = struct {
    allocator: std.mem.Allocator,
    center_pos: rl.Vector2, // Position of the main crosshair dot (screen center)
    size: f32,
    actual_trail_color: rl.Color, // Color for main crosshair and actual trail

    actual_trail_points: []CrosshairTrailPoint,
    actual_trail_count: usize,

    perfect_trail_points: []CrosshairTrailPoint,
    perfect_trail_count: usize,
    perfect_trail_color: rl.Color,

    trail_lifetime_seconds: f32 = 1.0, // Increased for better visibility, adjust as needed
    trail_max_points: usize,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        size: f32,
        actual_color: rl.Color,
        perfect_color: rl.Color,
        half_screen_width: i32,
        half_screen_height: i32,
        max_points_per_trail: usize,
    ) !Self {
        const actual_trail = try allocator.alloc(CrosshairTrailPoint, max_points_per_trail);
        errdefer allocator.free(actual_trail);
        const perfect_trail = try allocator.alloc(CrosshairTrailPoint, max_points_per_trail);
        errdefer allocator.free(perfect_trail);

        const center = rl.Vector2.init(@as(f32, @floatFromInt(half_screen_width)), @as(f32, @floatFromInt(half_screen_height)));
        return .{
            .allocator = allocator,
            .center_pos = center,
            .size = size,
            .actual_trail_color = actual_color,
            .actual_trail_points = actual_trail,
            .actual_trail_count = 0,
            .perfect_trail_points = perfect_trail,
            .perfect_trail_count = 0,
            .perfect_trail_color = perfect_color,
            .trail_max_points = max_points_per_trail,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.actual_trail_points);
        self.allocator.free(self.perfect_trail_points);
    }

    pub fn drawCenter(self: *const Self) void {
        // Draws the main crosshair dot at the screen center
        rl.drawCircleV(self.center_pos, self.size, self.actual_trail_color);
    }

    // Helper to update one trail: ages points, adds new one, removes old ones
    fn updateTrail(
        trail_points: []CrosshairTrailPoint,
        trail_count: *usize,
        new_point_pos: rl.Vector2,
        delta_time: f32,
        lifetime: f32,
        max_points: usize,
    ) void {
        // 1. Age existing points
        for (trail_points[0..trail_count.*]) |*p| {
            p.time += delta_time;
        }

        // 2. Add new trail point
        if (trail_count.* < max_points) {
            trail_points[trail_count.*] = CrosshairTrailPoint{
                .pos = new_point_pos,
                .time = 0,
            };
            trail_count.* += 1;
        } else if (max_points > 0) {
            // If full, overwrite the oldest by shifting (could be improved with circular buffer for performance)
            // For simplicity here, we shift and add.
            std.mem.copyForwards(CrosshairTrailPoint, trail_points[0 .. max_points - 1], trail_points[1..max_points]);
            trail_points[max_points - 1] = CrosshairTrailPoint{
                .pos = new_point_pos,
                .time = 0,
            };
        }

        // 3. Remove old points (compaction method)
        var write_idx: usize = 0;
        var read_idx: usize = 0;
        while (read_idx < trail_count.*) {
            if (trail_points[read_idx].time < lifetime) {
                if (write_idx != read_idx) {
                    trail_points[write_idx] = trail_points[read_idx];
                }
                write_idx += 1;
            }
            read_idx += 1;
        }
        trail_count.* = write_idx;
    }

    // Helper to only age and remove points from a trail (e.g., if no new point is added)
    fn ageAndPruneTrail(
        trail_points: []CrosshairTrailPoint,
        trail_count: *usize,
        delta_time: f32,
        lifetime: f32,
    ) void {
        // 1. Age existing points
        for (trail_points[0..trail_count.*]) |*p| {
            p.time += delta_time;
        }

        // 2. Remove old points (compaction method)
        var write_idx: usize = 0;
        var read_idx: usize = 0;
        while (read_idx < trail_count.*) {
            if (trail_points[read_idx].time < lifetime) {
                if (write_idx != read_idx) {
                    trail_points[write_idx] = trail_points[read_idx];
                }
                write_idx += 1;
            }
            read_idx += 1;
        }
        trail_count.* = write_idx;
    }

    pub fn updateAllTrails(
        self: *Self,
        delta_time: f32,
        camera: *const rl.Camera3D,
        opt_ideal_aim_screen_pos: ?rl.Vector2, // Screen position of the ideal aim point (e.g., target)
    ) void {
        // --- Update Actual Trail (where the camera is aiming) ---
        // Assuming Raylib Zig bindings provide these vector methods.
        // If not, use component-wise math as in your original code or rl.vector3* C functions.
        const cam_pos = camera.position;
        const cam_target = camera.target;

        const forward = cam_target.subtract(cam_pos); // Assumes .subtract method
        const length_sq = forward.lengthSqr(); // Assumes .lengthSqr method

        const actual_aim_screen_pos: rl.Vector2 = if (length_sq > 0.000001) blk: { // Epsilon check
            const length = @sqrt(length_sq);
            const norm_forward = forward.scale(1.0 / length); // Assumes .scale method
            const point_in_front = cam_pos.add(norm_forward.scale(100.0)); // Assumes .add method. 100.0 is arbitrary distance.
            break :blk rl.getWorldToScreen(point_in_front, camera.*);
        } else blk: {
            // Camera position and target are the same, aim is at screen center.
            break :blk self.center_pos;
        };

        Self.updateTrail(
            self.actual_trail_points,
            &self.actual_trail_count,
            actual_aim_screen_pos,
            delta_time,
            self.trail_lifetime_seconds,
            self.trail_max_points,
        );

        // --- Update Perfect Trail (where the target is on screen) ---
        if (opt_ideal_aim_screen_pos) |ideal_pos| {
            Self.updateTrail(
                self.perfect_trail_points,
                &self.perfect_trail_count,
                ideal_pos,
                delta_time,
                self.trail_lifetime_seconds,
                self.trail_max_points,
            );
        } else {
            // No ideal target currently, just age and prune existing perfect trail points.
            Self.ageAndPruneTrail(
                self.perfect_trail_points,
                &self.perfect_trail_count,
                delta_time,
                self.trail_lifetime_seconds,
            );
        }
    }

    // Helper function to draw a generic trail
    fn drawGenericTrail(
        trail_points: []const CrosshairTrailPoint,
        trail_count: usize,
        base_color: rl.Color,
        point_size: f32,
        lifetime: f32,
    ) void {
        for (trail_points[0..trail_count]) |point| {
            const alpha_factor = @max(0.0, 1.0 - (point.time / lifetime));
            const faded_color = rl.Color{
                .r = base_color.r,
                .g = base_color.g,
                .b = base_color.b,
                .a = @as(u8, @intFromFloat(alpha_factor * 255.0)),
            };
            rl.drawCircleV(point.pos, point_size, faded_color);
        }
    }

    pub fn drawActualTrail(self: *const Self) void {
        Self.drawGenericTrail(
            self.actual_trail_points,
            self.actual_trail_count,
            self.actual_trail_color,
            self.size * 0.8, // Slightly smaller than main crosshair
            self.trail_lifetime_seconds,
        );
    }

    pub fn drawPerfectTrail(self: *const Self) void {
        Self.drawGenericTrail(
            self.perfect_trail_points,
            self.perfect_trail_count,
            self.perfect_trail_color,
            self.size * 0.7, // Maybe even smaller or different shape (e.g. DrawRectangle)
            self.trail_lifetime_seconds,
        );
    }
};
