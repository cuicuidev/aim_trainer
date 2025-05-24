pub const std = @import("std");

pub const rl = @import("raylib");
pub const rg = @import("raygui");

pub const DrawLayoutFn = *const fn (ctx: *anyopaque) ?MenuOptions;

pub const Menu = struct {
    ctx: *anyopaque,
    draw_fn: DrawLayoutFn,

    const Self = @This();

    pub fn draw(self: *Self) ?MenuOptions {
        return self.draw_fn(self.ctx);
    }
};

pub const MenuOptions = enum {
    goto_main_menu,
    goto_benchmark_menu,
    goto_analysis_menu,

    next_scenario,
    repeat_scenario,
    prev_scenario,

    quit_trainer,
};
