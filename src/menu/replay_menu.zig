const rl = @import("raylib");
const rg = @import("raygui");

const menu = @import("menu.zig");
const bm = @import("../benchmark/root.zig");

pub const ReplayMenu = struct {
    _pos_1: rl.Rectangle,
    _pos_2: rl.Rectangle,
    _pos_3: rl.Rectangle,
    _pos_4: rl.Rectangle,
    _title: [:0]const u8,
    _font_size: i32 = 200,

    _tapes: [][:0]const u8,
    _tape_idx_ptr: *u1,

    _screen_width: i32,
    _screen_height: i32,

    const Self = @This();

    pub fn init(screen_height: i32, screen_width: i32, title: [:0]const u8, tapes: [][:0]const u8, tape_idx_ptr: *u1) Self {
        const screen_height_f: f32 = @as(f32, @floatFromInt(screen_height));
        const screen_width_f: f32 = @as(f32, @floatFromInt(screen_width));
        const small_button_height: f32 = screen_height_f * 0.02;
        const small_button_width: f32 = screen_width_f * 0.05;
        const button_height: f32 = screen_height_f * 0.08;
        const button_width: f32 = screen_width_f * 0.2;

        const pos_1_rect = rl.Rectangle.init(
            ((screen_width_f - small_button_width) / 3) * 2,
            screen_height_f / 2 - small_button_height * 0.5,
            small_button_width,
            small_button_height,
        );

        const pos_2_rect = rl.Rectangle.init(
            (screen_width_f - button_width) / 2,
            screen_height_f / 2 - button_height * 0.5,
            button_width,
            button_height,
        );

        const pos_3_rect = rl.Rectangle.init(
            (screen_width_f - small_button_width) / 3,
            screen_height_f / 2 - small_button_height * 0.5,
            small_button_width,
            small_button_height,
        );

        const pos_4_rect = rl.Rectangle.init(
            (screen_width_f - button_width) / 2,
            screen_height_f / 2 + button_height * 1.5,
            button_width,
            button_height,
        );

        return .{
            ._pos_1 = pos_1_rect,
            ._pos_2 = pos_2_rect,
            ._pos_3 = pos_3_rect,
            ._pos_4 = pos_4_rect,
            ._title = title,
            ._screen_width = screen_width,
            ._screen_height = screen_height,
            ._tapes = tapes,
            ._tape_idx_ptr = tape_idx_ptr,
        };
    }

    pub fn draw(ctx: *anyopaque) ?menu.MenuOptions {
        const self = @as(*Self, @ptrCast(@alignCast(ctx)));

        rl.drawText(
            self._title,
            @divFloor((self._screen_width - rl.measureText(self._title, self._font_size)), @as(i32, 2)),
            @divFloor(self._screen_height, 8),
            self._font_size,
            rl.Color.black,
        );

        if (rg.guiButton(self._pos_1, "Next") == 1) {
            self._tape_idx_ptr.* +%= 1;
            return menu.MenuOptions.next_scenario;
        }

        if (rg.guiButton(self._pos_2, self._tapes[self._tape_idx_ptr.*]) == 1) {
            return menu.MenuOptions.replay_scenario;
        }

        if (rg.guiButton(self._pos_3, "Prev") == 1) {
            self._tape_idx_ptr.* -%= 1;
            return menu.MenuOptions.prev_scenario;
        }

        if (rg.guiButton(self._pos_4, "Quit") == 1) {
            return menu.MenuOptions.goto_main_menu;
        }

        return null;
    }

    pub fn toMenu(self: *Self) menu.Menu {
        return menu.Menu{
            .ctx = self,
            .draw_fn = ReplayMenu.draw,
        };
    }
};
