const std = @import("std");

const rl = @import("raylib");

const scen = @import("scen/root.zig");
const bot = @import("bot/root.zig");

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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    // Initialization
    const screen_width = 1920;
    const screen_height = 1080;

    const config_flags = rl.ConfigFlags{
        .fullscreen_mode = true,
        .msaa_4x_hint = true,
    };

    rl.setConfigFlags(config_flags);

    rl.initWindow(screen_width, screen_height, "Aimalytics");
    defer rl.closeWindow();

    rl.disableCursor();

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

    const bot_config = scen.BotConfig{
        .n_bots = 3,
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

    var scenario = scen.Scenario{
        .clicking = scen.Clicking.init(
            allocator,
            spawn,
            bot_config,
        ) catch unreachable,
    };

    // Main game loop
    while (!rl.windowShouldClose()) {
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
        rl.drawCircle(screen_width - screen_width / 2, screen_height - screen_height / 2, 3.0, rl.Color.black);
    }
}

const STATIC_CONFIG = bot.mov.kinetic.KineticConfig{
    .constraints = bot.mov.constraints.Constraints{
        .accel_constraints = null,
        .velocity_constraints = null,
    },
    .modifiers = bot.mov.modifiers.MovementModifiers{
        .modules = null,
    },
};
