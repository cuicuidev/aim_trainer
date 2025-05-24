const rl = @import("raylib");
const rg = @import("raygui");

const menu = @import("menu.zig");

pub const MainMenu = struct {
    _start_benchmark_rect: rl.Rectangle,
    _quit_trainer_rect: rl.Rectangle,

    const Self = @This();

    pub fn init(start_benchmark_rect: rl.Rectangle, quit_trainer_rect: rl.Rectangle) Self {
        return .{
            ._start_benchmark_rect = start_benchmark_rect,
            ._quit_trainer_rect = quit_trainer_rect,
        };
    }

    pub fn draw(ctx: *anyopaque) ?menu.MenuOptions {
        const self = @as(*Self, @ptrCast(@alignCast(ctx)));
        if (rg.guiButton(self._start_benchmark_rect, "Benchmark") == 1) {
            return menu.MenuOptions.start_benchmark;
        }

        if (rg.guiButton(self._quit_trainer_rect, "Quit") == 1) {
            return menu.MenuOptions.quit;
        }

        return null;
    }

    pub fn toMenu(self: *Self, screen_height: i32, screen_width: i32, font_size: i32, title: [:0]const u8) menu.Menu {
        return menu.Menu{
            ._screen_height = screen_height,
            ._screen_width = screen_width,
            ._font_size = font_size,
            .title = title,
            ._layout_ptr = self,
            ._draw_layout = MainMenu.draw,
        };
    }
};
