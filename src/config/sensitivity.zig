const std = @import("std");

pub const Sensitivity = struct {
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
