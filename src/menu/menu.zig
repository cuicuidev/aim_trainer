pub const std = @import("std");

pub const rl = @import("raylib");
pub const rg = @import("raygui");

pub const DrawLayoutFn = *const fn (ctx: *anyopaque) ?MenuOptions;

pub const Menu = struct {
    _screen_width: i32,
    _screen_height: i32,
    _font_size: i32,
    title: [:0]const u8,

    _layout_ptr: *anyopaque,
    _draw_layout: DrawLayoutFn,

    const Self = @This();

    pub fn draw(self: *Self) ?MenuOptions {
        rl.drawText(
            self.title,
            @divFloor((self._screen_width - rl.measureText(self.title, self._font_size)), @as(i32, 2)),
            @divFloor(self._screen_height, 8),
            self._font_size,
            rl.Color.black,
        );

        return self._draw_layout(self._layout_ptr);
    }
};

pub const MenuOptions = enum {
    start_benchmark,
    quit,
};
