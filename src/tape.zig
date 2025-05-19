const std = @import("std");

const rl = @import("raylib");

const bot = @import("bot.zig");

// Camera position will not change
pub const BotSnapshot = struct {
    position: rl.Vector3,
    bot_type: bot.BotType,
};
