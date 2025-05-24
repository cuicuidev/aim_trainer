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
    start_benchmark,
    quit,
};
