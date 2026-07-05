const std = @import("std");
const rl = @import("rl.zig").c;
const constants = @import("constants.zig");

pub const ObjectType = enum {
    GOOD,
    BAD,
};

pub const FallingObject = struct {
    rect: rl.Rectangle,
    vel_y: f32,
    active: bool,
    color: rl.Color,
    obj_type: ObjectType,

    pub fn reset(self: *FallingObject, score: i32) void {
        self.rect.y = @as(f32, @floatFromInt(-50 - rl.GetRandomValue(0, 400)));
        self.rect.x = @as(f32, @floatFromInt(rl.GetRandomValue(50, constants.screen_width - 50)));
        self.vel_y = @as(f32, @floatFromInt(rl.GetRandomValue(1, 3))); // Initial downward velocity
        self.active = true;

        // Difficulty scaling: more bad objects as score goes up
        const bad_chance = @min(10 + @divTrunc(score, 50) * 5, 40); // caps at 40%
        if (rl.GetRandomValue(0, 100) < bad_chance) {
            self.obj_type = .BAD;
            self.color = constants.color_bad;
            self.rect.width = 25;
            self.rect.height = 25;
        } else {
            self.obj_type = .GOOD;
            self.color = constants.color_good;
            self.rect.width = 30;
            self.rect.height = 30;
        }
    }

    pub fn update(self: *FallingObject, gravity: f32, dt_mult: f32) void {
        if (!self.active) return;

        self.vel_y += gravity * dt_mult;
        self.rect.y += self.vel_y * dt_mult;
    }
};
