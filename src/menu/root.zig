const menu = @import("menu.zig");
const main_menu = @import("main_menu.zig");
const benchmark_menu = @import("benchmark_menu.zig");
const replay_menu = @import("replay_menu.zig");

pub const Menu = menu.Menu;
pub const MenuOptions = menu.MenuOptions;

pub const MainMenu = main_menu.MainMenu;
pub const BenchmarkMenu = benchmark_menu.BenchmarkMenu;
pub const ReplayMenu = replay_menu.ReplayMenu;
