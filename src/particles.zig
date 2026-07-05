const std = @import("std");
const rl = @import("rl.zig").c;

pub const Particle = struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    color: rl.Color,
    life: f32,
    active: bool,
};

pub const ParticleSystem = struct {
    particles: [100]Particle,

    pub fn init() ParticleSystem {
        var ps = ParticleSystem{ .particles = undefined };
        for (&ps.particles) |*p| {
            p.active = false;
        }
        return ps;
    }

    pub fn spawn(self: *ParticleSystem, x: f32, y: f32, color: rl.Color, count: usize) void {
        var spawned: usize = 0;
        for (&self.particles) |*p| {
            if (!p.active) {
                p.pos = rl.Vector2{ .x = x, .y = y };
                const angle = @as(f32, @floatFromInt(rl.GetRandomValue(0, 360))) * std.math.pi / 180.0;
                const speed = @as(f32, @floatFromInt(rl.GetRandomValue(20, 80))) / 10.0;
                p.vel = rl.Vector2{ .x = @cos(angle) * speed, .y = @sin(angle) * speed };
                p.color = color;
                p.life = 1.0;
                p.active = true;
                spawned += 1;
                if (spawned >= count) break;
            }
        }
    }

    pub fn update(self: *ParticleSystem, dt_mult: f32) void {
        for (&self.particles) |*p| {
            if (p.active) {
                p.pos.x += p.vel.x * dt_mult;
                p.pos.y += p.vel.y * dt_mult;
                p.vel.y += 0.1 * dt_mult; // slight gravity
                p.life -= 0.02 * dt_mult;
                if (p.life <= 0) {
                    p.active = false;
                }
            }
        }
    }

    pub fn draw(self: *ParticleSystem) void {
        for (&self.particles) |*p| {
            if (p.active) {
                var c = p.color;
                c.a = @as(u8, @intFromFloat(p.life * 255.0));
                rl.DrawRectangle(@as(i32, @intFromFloat(p.pos.x)), @as(i32, @intFromFloat(p.pos.y)), 4, 4, c);
            }
        }
    }
};
