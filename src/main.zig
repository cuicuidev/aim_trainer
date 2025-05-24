const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const scen = @import("scen/root.zig");
const bot = @import("bot/root.zig");
const menu = @import("menu/root.zig");

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

    // Scenario prep
    var sensitivity = Sensitivity.init(70.0, 1600.0);
    const spawn = scen.Spawn.init(
        rl.Vector3.init(50.0, 2.0, 0.0),
        rl.Vector3.init(1.0, 0.0, 0.0),
        rl.Vector3.init(0.0, 0.0, 1.0),
        rl.Vector3.init(0.0, 1.0, 0.0),
        30.0,
        15.0,
        10.0,
    );

    const bot_config = bot.BotConfig{
        .n_bots = 5,
        .bot_initial_position = null,
        .geometry = bot.Geometry{
            .sphere = bot.geo.Sphere.init(
                spawn.origin,
                0.3,
                rl.Color.red,
                STATIC_CONFIG,
            ),
        },
    };

    var scenario = try scen.Scenario.init(
        allocator,
        spawn,
        bot_config,
        scen.ScenarioType{
            .clicking = scen.Clicking{},
        },
    );
    errdefer scenario.deinit();

    // Menu prep
    const button_width = SCREEN_WIDTH * 0.2;
    const button_height = SCREEN_HEIGHT * 0.08;

    const start_benchmark_rect = rl.Rectangle.init(
        (SCREEN_WIDTH - button_width) / 2,
        SCREEN_HEIGHT / 2 - button_height * 1.5,
        button_width,
        button_height,
    );

    const quit_trainer_rect = rl.Rectangle.init(
        (SCREEN_WIDTH - button_width) / 2,
        SCREEN_HEIGHT / 2 + button_height * 0.5,
        button_width,
        button_height,
    );

    var main_menu = menu.MainMenu.init(
        start_benchmark_rect,
        quit_trainer_rect,
    );
    var _menu = main_menu.toMenu(SCREEN_HEIGHT, SCREEN_WIDTH, 200, "Aimalytcs");

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
                        .start_benchmark => STATE = GameState.scenario_gameplay,
                        .quit => STATE = GameState.quit,
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
                }

                // ---------------------------------------------------------------------------------------
                // UPDATE --------------------------------------------------------------------------------
                // ---------------------------------------------------------------------------------------

                // Sens adjustment
                if (rl.isKeyPressed(rl.KeyboardKey.page_up)) {
                    sensitivity.setCM360(sensitivity.cm360 + 1.0);
                }
                if (rl.isKeyPressed(rl.KeyboardKey.page_down)) {
                    sensitivity.setCM360(sensitivity.cm360 - 1.0);
                }
                const cm360_str = try sensitivity.allocPrintCM360(allocator);
                defer allocator.free(cm360_str);

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
                const score = try std.fmt.allocPrintZ(allocator, "Score {d:2.2}", .{scenario.getScore()});
                defer allocator.free(score);

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
                rl.drawText(cm360_str, SCREEN_WIDTH - 200, 10, 20, rl.Color.dark_green);
                rl.drawText(score, SCREEN_WIDTH - 300, 100, 20, rl.Color.dark_green);
                rl.drawCircle(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, 3.0, rl.Color.black);

                if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
                    STATE = GameState.main_menu;
                    std.time.sleep(100_000_000);
                }
            },
            .quit => rl.closeWindow(),
            else => unreachable,
        }
    }
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

const STATIC_CONFIG = bot.mov.kinetic.KineticConfig{
    .constraints = bot.mov.constraints.Constraints{
        .accel_constraints = null,
        .velocity_constraints = null,
    },
    .modifiers = bot.mov.modifiers.MovementModifiers{
        .modules = null,
    },
};

// TODO: allocate wanderers dynamically instead of using global variables.
var sin_wander = bot.mov.modifiers.sinusoidal.SinusoidalWanderModifier{
    .amplitude = 20.0,
    .freq = 2.0,
};

var noise_wander = bot.mov.modifiers.noise.NoiseWanderModifier{
    .strength = 3.0,
};

var min_speed = bot.mov.constraints.velocity.MinSpeedConstraint{ .min_speed = 12.0 };

var max_speed = bot.mov.constraints.velocity.MaxSpeedConstraint{ .max_speed = 20.0 };

var bias = bot.mov.constraints.acceleration.PointBiasConstraint{
    .point = rl.Vector3.init(50.0, 2.0, 0.0),
    .strength = 2.0,
};

const modifiers_arr = [2]bot.mov.modifiers.MovementModule{
    sin_wander.toModule(1.0),
    noise_wander.toModule(1.0),
};

const modifiers = bot.mov.modifiers.MovementModifiers{
    .modules = &modifiers_arr,
};

const vel_constraints_arr = [2]bot.mov.constraints.VelocityConstraintModule{
    min_speed.toModule(),
    max_speed.toModule(),
};

const acc_constraints_arr = [1]bot.mov.constraints.AccelConstraintModule{
    bias.toModule(),
};

const constraints = bot.mov.constraints.Constraints{
    .accel_constraints = &acc_constraints_arr,
    .velocity_constraints = &vel_constraints_arr,
};

const KINETIC_CONFIG = bot.mov.kinetic.KineticConfig{
    .constraints = constraints,
    .modifiers = modifiers,
};

// bot_config = bot.BotConfig{
//     .n_bots = 3,
//     .bot_initial_position = null,
//     .geometry = bot.Geometry{
//         .sphere = bot.geo.Sphere.init(
//             spawn.origin,
//             1.0,
//             rl.Color.red,
//             STATIC_CONFIG,
//         ),
//     },
// };

// scenario = try scen.Scenario.init(
//     allocator,
//     spawn,
//     bot_config,
//     scen.ScenarioType{
//         .clicking = scen.Clicking{},
//     },
// );

// bot_config = bot.BotConfig{
//     .n_bots = 1,
//     .bot_initial_position = spawn.origin,
//     .geometry = bot.Geometry{
//         .capsule = bot.geo.Capsule.init(
//             spawn.origin,
//             1.0,
//             3.0,
//             rl.Color.red,
//             KINETIC_CONFIG,
//         ),
//     },
// };

// scenario = try scen.Scenario.init(
//     allocator,
//     spawn,
//     bot_config,
//     scen.ScenarioType{
//         .tracking = scen.Tracking{},
//     },
// );
