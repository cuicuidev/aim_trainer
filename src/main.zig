const std = @import("std");

const rl = @import("raylib");

const scen = @import("scen/root.zig");
const bot = @import("bot/root.zig");

pub const GameState = enum {
    menu,
    scenario,
    exit,
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
    var STATE = GameState.menu;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    // Initialization
    const screen_width = 1920;
    const screen_height = 1080;

    const config_flags = rl.ConfigFlags{
        .fullscreen_mode = true,
        .window_unfocused = false,
        .msaa_4x_hint = true,
    };

    rl.setConfigFlags(config_flags);

    rl.initWindow(screen_width, screen_height, "Aimalytics");
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

    var bot_config: bot.BotConfig = undefined;

    var scenario: scen.Scenario = undefined;
    errdefer scenario.deinit();

    // Main game loop
    while (!rl.windowShouldClose()) {
        switch (STATE) {
            .menu => {
                if (rl.isCursorHidden()) {
                    rl.enableCursor();
                }

                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(rl.Color.dark_gray);

                rl.drawText(
                    "Aimalytics",
                    @divFloor((screen_width - rl.measureText("Aimalytics", 200)), @as(i32, 2)),
                    screen_height / 8,
                    200,
                    rl.Color.black,
                );

                const button_width = screen_width * 0.2;
                const button_height = screen_height * 0.08;

                const play_clicking_btn = rl.Rectangle.init(
                    (screen_width - button_width) / 2,
                    screen_height / 2 - button_height * 1.5,
                    button_width,
                    button_height,
                );

                const play_tracking_btn = rl.Rectangle.init(
                    (screen_width - button_width) / 2,
                    screen_height / 2 + button_height * 0.5,
                    button_width,
                    button_height,
                );

                const base_color = rl.Color.light_gray;
                const hover_color = rl.Color.white;
                const text_color = rl.Color.black;

                if (drawButton("Clicking", play_clicking_btn, base_color, hover_color, text_color)) {
                    STATE = GameState.scenario;
                    bot_config = bot.BotConfig{
                        .n_bots = 3,
                        .bot_initial_position = null,
                        .geometry = bot.Geometry{
                            .sphere = bot.geo.Sphere.init(
                                spawn.origin,
                                1.0,
                                rl.Color.red,
                                STATIC_CONFIG,
                            ),
                        },
                    };

                    scenario = try scen.Scenario.init(
                        allocator,
                        spawn,
                        bot_config,
                        scen.ScenarioType{
                            .clicking = scen.Clicking{},
                        },
                    );
                }

                if (drawButton("Tracking", play_tracking_btn, base_color, hover_color, text_color)) {
                    STATE = GameState.scenario;
                    bot_config = bot.BotConfig{
                        .n_bots = 1,
                        .bot_initial_position = spawn.origin,
                        .geometry = bot.Geometry{
                            .capsule = bot.geo.Capsule.init(
                                spawn.origin,
                                1.0,
                                3.0,
                                rl.Color.red,
                                KINETIC_CONFIG,
                            ),
                        },
                    };

                    scenario = try scen.Scenario.init(
                        allocator,
                        spawn,
                        bot_config,
                        scen.ScenarioType{
                            .tracking = scen.Tracking{},
                        },
                    );
                }

                if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
                    STATE = GameState.exit;
                    continue;
                }
            },
            .scenario => {
                if (!rl.isCursorHidden()) {
                    rl.disableCursor();
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
                rl.drawFPS(screen_width - 200, 40);
                rl.drawText(cm360_str, screen_width - 200, 10, 20, rl.Color.dark_green);
                rl.drawText(score, screen_width - 300, 100, 20, rl.Color.dark_green);
                rl.drawCircle(screen_width / 2, screen_height / 2, 3.0, rl.Color.black);

                if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
                    STATE = GameState.menu;
                    scenario.deinit();
                    std.time.sleep(100_000_000);
                }
            },
            .exit => rl.closeWindow(),
        }
    }
}

fn drawButton(label: [:0]const u8, rect: rl.Rectangle, base_color: rl.Color, hover_color: rl.Color, text_color: rl.Color) bool {
    const mouse_pos = rl.getMousePosition();
    const is_hovered = rl.checkCollisionPointRec(mouse_pos, rect);
    const is_clicked = is_hovered and rl.isMouseButtonPressed(rl.MouseButton.left);

    const bg_color = if (is_hovered) hover_color else base_color;

    rl.drawRectangleRec(rect, bg_color);

    // Center text within button
    const font_size = @as(i32, @intFromFloat(rect.height * 0.5));
    const text_width = rl.measureText(label, font_size);
    const text_x = @as(i32, @intFromFloat(rect.x + (rect.width - @as(f32, @floatFromInt(text_width))) / 2));
    const text_y = @as(i32, @intFromFloat(rect.y + (rect.height - @as(f32, @floatFromInt(font_size))) / 2));

    rl.drawText(label, text_x, text_y, font_size, text_color);

    return is_clicked;
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
