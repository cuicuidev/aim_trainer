const std = @import("std");

const rl = @import("raylib");

const scen = @import("scenario.zig");

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

    rl.initWindow(screen_width, screen_height, "raylib-zig [core] example - basic window");
    defer rl.closeWindow();

    // rl.setTargetFPS(30);
    rl.disableCursor();

    var camera = rl.Camera3D{
        .position = rl.Vector3.init(0.0, 2.0, 0.0),
        .target = rl.Vector3.init(10.0, 2.0, 0.0),
        .up = rl.Vector3.init(0.0, 1.0, 0.0),
        .fovy = 58.0,
        .projection = rl.CameraProjection.perspective,
    };

    const base_cpi = 1600.0;
    const cpi = 1600.0;
    const cm_ratio = 0.6;
    var sensitivity: f32 = 0.008; // adjust this to change sensitivity

    // Scenario
    var scenario = scen.RawControl(50.0).init(&camera);

    // Main game loop
    while (!rl.windowShouldClose()) {
        // UPDATE --------------------------------------------------------------------------------

        // Sens adjustment
        if (rl.isKeyPressed(rl.KeyboardKey.page_up)) {
            sensitivity += 0.0003; // increase sensitivity
        }
        if (rl.isKeyPressed(rl.KeyboardKey.page_down)) {
            sensitivity -= 0.0003; // decrease sensitivity, but ensure it doesn't go negative
            if (sensitivity < 0.0001) {
                sensitivity = 0.0001; // Set a lower bound for sensitivity
            }
        }
        const cm_360 = (cpi / base_cpi) * (cm_ratio / sensitivity);

        // Camera update
        const mouse_delta = rl.getMouseDelta();
        const rotation = rl.Vector3.init(
            mouse_delta.x * sensitivity, // pitch (up/down)
            mouse_delta.y * sensitivity, // yaw (left/right)
            0.0, // roll (usually unused)
        );

        const movement = rl.Vector3.init(0.0, 0.0, 0.0);

        rl.updateCameraPro(&camera, movement, rotation, 0.0);

        // Scenario events
        scenario.kill(&camera);

        // DRAW ----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.dark_gray);

        // 3D rendering
        {
            rl.beginMode3D(camera);
            defer rl.endMode3D();

            // Scenario render
            scenario.draw();
        }

        // 2D rendering
        const cm360_str = try std.fmt.allocPrintZ(allocator, "CM360: {d:3.2}", .{cm_360});
        defer allocator.free(cm360_str);

        rl.drawText(cm360_str, screen_width - 200, 10, 20, rl.Color.dark_green);
        rl.drawFPS(screen_width - 200, 40);
        if (scenario.last_hit) |last_hit| {
            const last_hit_text = try std.fmt.allocPrintZ(allocator, "V(x={d:2.2}, y={d:2.2}, z={d:2.2})", .{ last_hit.x, last_hit.y, last_hit.z });
            defer allocator.free(last_hit_text);
            rl.drawText(last_hit_text, screen_width - 300, 70, 20, rl.Color.dark_green);
        }
        rl.drawCircle(screen_width - screen_width / 2, screen_height - screen_height / 2, 3.0, rl.Color.black);
        //----------------------------------------------------------------------------------
    }
}
