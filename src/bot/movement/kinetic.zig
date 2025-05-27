const std = @import("std");

const rl = @import("raylib");

const c = @import("constraints/root.zig");
const m = @import("modifiers/root.zig");

pub const KineticConfig = struct {
    constraints: c.Constraints,
    modifiers: m.MovementModifiers,
};

pub const KineticHandler = struct {
    velocity: rl.Vector3,
    time: f32,
    config: KineticConfig,

    const Self = @This();

    pub fn init(config: KineticConfig) Self {
        return .{
            .velocity = rl.Vector3.init(0.0, 0.0, 0.0),
            .time = 0.0,
            .config = config,
        };
    }

    pub fn step(self: *Self, position: rl.Vector3, dt: f32) rl.Vector3 {
        self.time += dt;

        const base_accel = self._getBaseAccel(dt);
        const constrained_accel = self._applyAccelConstraints(position, base_accel);

        var new_velocity = rl.Vector3.add(self.velocity, rl.Vector3.scale(constrained_accel, dt));
        new_velocity = self._applyVelocityConstraints(new_velocity);

        self.velocity = new_velocity;
        return rl.Vector3.add(position, rl.Vector3.scale(self.velocity, dt));
    }

    fn _getBaseAccel(self: *Self, dt: f32) rl.Vector3 {
        // std.debug.print("--- KineticHandler._getBaseAccel (dt: {d}) ---\n", .{dt});
        // std.debug.print("  self ptr: {*}\n", .{self});

        // if (self.config.modifiers.modules) |mods_slice| {
        //     std.debug.print("  self.config.modifiers.modules: SOME\n", .{});
        //     std.debug.print("    Slice Ptr: {*}, Length: {}\n", .{ mods_slice.ptr, mods_slice.len });
        //     if (@as(usize, @intFromPtr(mods_slice.ptr)) == std.math.maxInt(usize) and mods_slice.len > 0) {
        //         std.debug.print("    !!!! SLICE POINTER IS usize.max AND LENGTH > 0 !!!!\n", .{});
        //     }
        // } else {
        //     std.debug.print("  self.config.modifiers.modules: NULL\n", .{});
        // }
        // No need to print "--- End Debug ---" here, we want to see prints from inside the loop

        var accel = rl.Vector3.init(0, 0, 0);
        if (self.config.modifiers.modules) |modules_slice_for_loop| { // Renamed to avoid confusion with `mod`
            // std.debug.print("  Iterating over modules_slice_for_loop (len={})...\n", .{modules_slice_for_loop.len});
            for (modules_slice_for_loop, 0..) |mod_item, i| { // Added index `i` for clarity
                _ = i;
                // std.debug.print("    Module index [{}]:\n", .{i});
                // Print the function pointer address for applyFn
                // The type of mod_item.applyFn will be something like:
                // *const fn (ctx: ?*any, time: f32) callconv(.Inline) Vector3
                // We can cast it to an opaque pointer for printing.
                // const apply_fn_ptr_val = @as(usize, @intFromPtr(mod_item.applyFn));
                // std.debug.print("      applyFn ptr val: 0x{x}\n", .{apply_fn_ptr_val});

                // Print the context pointer
                // Assuming mod_item.ctx is some kind of pointer (e.g., ?*any, *SomeStruct, etc.)
                // If it's not a pointer, this print will need adjustment.
                // Let's assume it's an optional pointer for now.

                // std.debug.print("      ctx ptr: {*} (non-null)\n", .{mod_item.ctx});
                // if (@as(usize, @intFromPtr(mod_item.ctx)) == std.math.maxInt(usize)) {
                // std.debug.print("      !!!! CTX POINTER IS usize.max !!!!\n", .{});
                // }
                // std.debug.print("      Calling applyFn...\n", .{});
                const result = mod_item.applyFn(mod_item.ctx, self.time + dt); // CRASH LIKELY HERE OR INSIDE
                // std.debug.print("      applyFn returned.\n", .{});
                accel = rl.Vector3.add(accel, result);
            }
            // std.debug.print("  Finished iterating modules.\n", .{});
        } else {
            // std.debug.print("  No modules to iterate.\n", .{});
        }
        // std.debug.print("--- _getBaseAccel returning ---\n", .{});
        return accel;
    }

    fn _applyAccelConstraints(self: *Self, position: rl.Vector3, accel: rl.Vector3) rl.Vector3 {
        var adjusted = accel;
        if (self.config.constraints.accel_constraints) |accel_constraints| {
            for (accel_constraints) |con| {
                adjusted = con.applyFn(con.ctx, adjusted, position, self.velocity);
            }
        }
        return adjusted;
    }

    fn _applyVelocityConstraints(self: *Self, velocity: rl.Vector3) rl.Vector3 {
        var adjusted = velocity;
        if (self.config.constraints.velocity_constraints) |velocity_constraints| {
            for (velocity_constraints) |con| {
                adjusted = con.applyFn(con.ctx, adjusted);
            }
        }
        return adjusted;
    }
};
