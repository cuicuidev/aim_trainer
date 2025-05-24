const rl = @import("raylib");
const rg = @import("raygui");

const menu = @import("menu.zig");

pub const BenchmarkMenu = struct {
    _start_benchmark_rect: rl.Rectangle,
    _next_scenario_rect: rl.Rectangle,
    _quit_benchmark_rect: rl.Rectangle,
    _title: [:0]const u8,
    _font_size: i32 = 200,

    _screen_width: i32,
    _screen_height: i32,

    const Self = @This();

    pub fn init(screen_height: i32, screen_width: i32, title: [:0]const u8) Self {
        const screen_height_f: f32 = @as(f32, @floatFromInt(screen_height));
        const screen_width_f: f32 = @as(f32, @floatFromInt(screen_width));
        const button_height: f32 = screen_height_f * 0.08;
        const button_width: f32 = screen_width_f * 0.2;

        const start_benchmark_rect = rl.Rectangle.init(
            (screen_width_f - button_width) / 2,
            screen_height_f / 2 - button_height * 1.5,
            button_width,
            button_height,
        );

        const next_scenario_rect = rl.Rectangle.init(
            (screen_width_f - button_width) / 2,
            screen_height_f / 2 + button_height * 0.5,
            button_width,
            button_height,
        );

        const quit_benchmark_rect = rl.Rectangle.init(
            (screen_width_f - button_width) / 2,
            screen_height_f / 2 + button_height * 1.5,
            button_width,
            button_height,
        );

        return .{
            ._start_benchmark_rect = start_benchmark_rect,
            ._next_scenario_rect = next_scenario_rect,
            ._quit_benchmark_rect = quit_benchmark_rect,
            ._title = title,
            ._screen_width = screen_width,
            ._screen_height = screen_height,
        };
    }

    pub fn draw(ctx: *anyopaque) ?menu.MenuOptions {
        // TODO: This has to hide start and next buttons depending on the benchmark state
        const self = @as(*Self, @ptrCast(@alignCast(ctx)));

        rl.drawText(
            self._title,
            @divFloor((self._screen_width - rl.measureText(self._title, self._font_size)), @as(i32, 2)),
            @divFloor(self._screen_height, 8),
            self._font_size,
            rl.Color.black,
        );

        if (rg.guiButton(self._start_benchmark_rect, "Start") == 1) {
            return menu.MenuOptions.next_scenario;
        }

        if (rg.guiButton(self._next_scenario_rect, "Next") == 1) {
            return menu.MenuOptions.next_scenario;
        }

        if (rg.guiButton(self._quit_benchmark_rect, "Quit") == 1) {
            return menu.MenuOptions.goto_main_menu;
        }

        return null;
    }

    pub fn toMenu(self: *Self) menu.Menu {
        return menu.Menu{
            .ctx = self,
            .draw_fn = BenchmarkMenu.draw,
        };
    }
};
