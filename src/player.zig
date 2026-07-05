const std = @import("std");
const rl = @import("rl.zig").c;
const constants = @import("constants.zig");

pub const Player = struct {
    rect: rl.Rectangle,
    vel_x: f32,
    color: rl.Color,

    // Physics constants
    const accel: f32 = 2.0;
    const max_vel: f32 = 12.0;
    const friction: f32 = 0.85; // Multiplied each frame when no input

    pub fn update(self: *Player, dt_mult: f32) void {
        var input_x: f32 = 0;
        if (rl.IsKeyDown(rl.KEY_LEFT) or rl.IsKeyDown(rl.KEY_A)) input_x -= 1;
        if (rl.IsKeyDown(rl.KEY_RIGHT) or rl.IsKeyDown(rl.KEY_D)) input_x += 1;

        if (input_x != 0) {
            self.vel_x += input_x * accel * dt_mult;
            // Cap velocity
            if (self.vel_x > max_vel) self.vel_x = max_vel;
            if (self.vel_x < -max_vel) self.vel_x = -max_vel;
        } else {
            // Apply friction
            self.vel_x *= std.math.pow(f32, friction, dt_mult);
            if (@abs(self.vel_x) < 0.1) self.vel_x = 0;
        }

        self.rect.x += self.vel_x * dt_mult;

        // Boundaries with bounce
        if (self.rect.x < 0) {
            self.rect.x = 0;
            self.vel_x *= -0.5; // Bounce off wall
        }
        if (self.rect.x > constants.screen_width - self.rect.width) {
            self.rect.x = constants.screen_width - self.rect.width;
            self.vel_x *= -0.5;
        }
    }
};
