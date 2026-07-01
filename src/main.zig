const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

const screen_width = 800;
const screen_height = 600;

// Colors
const color_bg = rl.Color{ .r = 15, .g = 15, .b = 20, .a = 255 };
const color_player = rl.Color{ .r = 0, .g = 228, .b = 255, .a = 255 }; // Cyan glow
const color_good = rl.Color{ .r = 57, .g = 255, .b = 20, .a = 255 }; // Neon green
const color_bad = rl.Color{ .r = 255, .g = 0, .b = 60, .a = 255 }; // Neon red
const color_text = rl.Color{ .r = 240, .g = 240, .b = 245, .a = 255 };

const GameState = enum {
    TITLE,
    PLAYING,
    GAME_OVER,
};

const ObjectType = enum {
    GOOD,
    BAD,
};

const Player = struct {
    rect: rl.Rectangle,
    vel_x: f32,
    color: rl.Color,

    // Physics constants
    const accel: f32 = 2.0;
    const max_vel: f32 = 12.0;
    const friction: f32 = 0.85; // Multiplied each frame when no input

    fn update(self: *Player, dt_mult: f32) void {
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
        if (self.rect.x > screen_width - self.rect.width) {
            self.rect.x = screen_width - self.rect.width;
            self.vel_x *= -0.5;
        }
    }
};

const FallingObject = struct {
    rect: rl.Rectangle,
    vel_y: f32,
    active: bool,
    color: rl.Color,
    obj_type: ObjectType,

    fn reset(self: *FallingObject, score: i32) void {
        self.rect.y = @as(f32, @floatFromInt(-50 - rl.GetRandomValue(0, 400)));
        self.rect.x = @as(f32, @floatFromInt(rl.GetRandomValue(50, screen_width - 50)));
        self.vel_y = @as(f32, @floatFromInt(rl.GetRandomValue(1, 3))); // Initial downward velocity
        self.active = true;

        // Difficulty scaling: more bad objects as score goes up
        const bad_chance = @min(10 + @divTrunc(score, 50) * 5, 40); // caps at 40%
        if (rl.GetRandomValue(0, 100) < bad_chance) {
            self.obj_type = .BAD;
            self.color = color_bad;
            self.rect.width = 25;
            self.rect.height = 25;
        } else {
            self.obj_type = .GOOD;
            self.color = color_good;
            self.rect.width = 30;
            self.rect.height = 30;
        }
    }

    fn update(self: *FallingObject, gravity: f32, dt_mult: f32) void {
        if (!self.active) return;

        self.vel_y += gravity * dt_mult;
        self.rect.y += self.vel_y * dt_mult;
    }
};

const Particle = struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    color: rl.Color,
    life: f32,
    active: bool,
};

const ParticleSystem = struct {
    particles: [100]Particle,

    fn init() ParticleSystem {
        var ps = ParticleSystem{ .particles = undefined };
        for (&ps.particles) |*p| {
            p.active = false;
        }
        return ps;
    }

    fn spawn(self: *ParticleSystem, x: f32, y: f32, color: rl.Color, count: usize) void {
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

    fn update(self: *ParticleSystem, dt_mult: f32) void {
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

    fn draw(self: *ParticleSystem) void {
        for (&self.particles) |*p| {
            if (p.active) {
                var c = p.color;
                c.a = @as(u8, @intFromFloat(p.life * 255.0));
                rl.DrawRectangle(@as(i32, @intFromFloat(p.pos.x)), @as(i32, @intFromFloat(p.pos.y)), 4, 4, c);
            }
        }
    }
};

pub fn main() !void {
    // Enable VSync and Anti-Aliasing for perfectly smooth movement and rendering
    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT | rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(screen_width, screen_height, "Square Rush");
    defer rl.CloseWindow();

    var state = GameState.TITLE;

    var player = Player{
        .rect = rl.Rectangle{
            .x = screen_width / 2.0 - 30.0,
            .y = screen_height - 50.0,
            .width = 60.0,
            .height = 15.0,
        },
        .vel_x = 0,
        .color = color_player,
    };

    var objects: [8]FallingObject = undefined;
    for (&objects) |*obj| {
        obj.reset(0);
    }

    var particles = ParticleSystem.init();

    var score: i32 = 0;
    var high_score: i32 = 0;

    var base_gravity: f32 = 0.1;

    var screen_shake_timer: f32 = 0;

    while (!rl.WindowShouldClose()) {
        // UPDATE
        const dt_mult = rl.GetFrameTime() * 60.0;
        
        switch (state) {
            .TITLE => {
                if (rl.IsKeyPressed(rl.KEY_ENTER) or rl.IsKeyPressed(rl.KEY_SPACE)) {
                    state = .PLAYING;
                    score = 0;
                    base_gravity = 0.1;
                    player.vel_x = 0;
                    player.rect.x = screen_width / 2.0 - player.rect.width / 2.0;
                    for (&objects) |*obj| {
                        obj.reset(0);
                    }
                }
            },
            .PLAYING => {
                player.update(dt_mult);
                particles.update(dt_mult);

                if (screen_shake_timer > 0) {
                    screen_shake_timer -= rl.GetFrameTime();
                }

                // Difficulty increase
                base_gravity = 0.1 + (@as(f32, @floatFromInt(score)) / 1000.0);
                if (base_gravity > 0.4) base_gravity = 0.4;

                for (&objects) |*obj| {
                    if (obj.active) {
                        obj.update(base_gravity, dt_mult);

                        if (rl.CheckCollisionRecs(player.rect, obj.rect)) {
                            obj.active = false;

                            if (obj.obj_type == .GOOD) {
                                score += 10;
                                particles.spawn(obj.rect.x + obj.rect.width / 2, obj.rect.y + obj.rect.height, color_good, 15);
                            } else {
                                score -= 30;
                                screen_shake_timer = 0.3; // 300ms shake
                                particles.spawn(obj.rect.x + obj.rect.width / 2, obj.rect.y + obj.rect.height, color_bad, 30);
                            }
                        } else if (obj.rect.y > screen_height) {
                            obj.active = false;
                            if (obj.obj_type == .GOOD) {
                                score -= 5;
                            }
                        }
                    } else {
                        obj.reset(score);
                    }
                }

                if (score < -20) {
                    state = .GAME_OVER;
                    if (score > high_score) high_score = score;
                    screen_shake_timer = 0.5;
                }
            },
            .GAME_OVER => {
                particles.update(dt_mult);
                if (screen_shake_timer > 0) {
                    screen_shake_timer -= rl.GetFrameTime();
                }
                if (rl.IsKeyPressed(rl.KEY_ENTER) or rl.IsKeyPressed(rl.KEY_SPACE)) {
                    state = .TITLE;
                }
            },
        }

        // DRAW
        rl.BeginDrawing();
        rl.ClearBackground(color_bg);

        var shake_offset_x: f32 = 0;
        var shake_offset_y: f32 = 0;
        if (screen_shake_timer > 0) {
            shake_offset_x = @as(f32, @floatFromInt(rl.GetRandomValue(-5, 5)));
            shake_offset_y = @as(f32, @floatFromInt(rl.GetRandomValue(-5, 5)));
        }

        const camera = rl.Camera2D{
            .offset = rl.Vector2{ .x = shake_offset_x, .y = shake_offset_y },
            .target = rl.Vector2{ .x = 0, .y = 0 },
            .rotation = 0.0,
            .zoom = 1.0,
        };

        rl.BeginMode2D(camera);

        switch (state) {
            .TITLE => {
                const title_text = "SQUARE RUSH";
                const title_width = rl.MeasureText(title_text, 50);
                rl.DrawText(title_text, @divTrunc(screen_width, 2) - @divTrunc(title_width, 2), 200, 50, color_good);

                const subtitle = "Avoid the red bombs!";
                const sub_width = rl.MeasureText(subtitle, 20);
                rl.DrawText(subtitle, @divTrunc(screen_width, 2) - @divTrunc(sub_width, 2), 270, 20, color_bad);

                const prompt = "Press ENTER to Start";
                const prompt_width = rl.MeasureText(prompt, 20);
                if (@mod(@as(i32, @intFromFloat(rl.GetTime() * 2.0)), 2) == 0) {
                    rl.DrawText(prompt, @divTrunc(screen_width, 2) - @divTrunc(prompt_width, 2), 400, 20, color_text);
                }
            },
            .PLAYING => {
                // Draw Player
                rl.DrawRectangleRounded(player.rect, 0.5, 8, player.color);

                // Draw Objects
                for (&objects) |*obj| {
                    if (obj.active) {
                        if (obj.obj_type == .GOOD) {
                            rl.DrawRectangleRounded(obj.rect, 0.3, 8, obj.color);
                        } else {
                            rl.DrawRectangleRounded(obj.rect, 1.0, 8, obj.color);
                        }
                    }
                }

                particles.draw();

                // UI
                var buf: [64]u8 = undefined;
                const score_text = try std.fmt.bufPrintZ(&buf, "Score: {d}", .{score});
                rl.DrawText(score_text.ptr, 20, 20, 30, color_text);

                if (high_score > 0) {
                    var hs_buf: [64]u8 = undefined;
                    const hs_text = try std.fmt.bufPrintZ(&hs_buf, "Best: {d}", .{high_score});
                    rl.DrawText(hs_text.ptr, screen_width - 150, 20, 20, color_text);
                }
            },
            .GAME_OVER => {
                particles.draw();

                const go_text = "GAME OVER!";
                const go_width = rl.MeasureText(go_text, 60);
                rl.DrawText(go_text, @divTrunc(screen_width, 2) - @divTrunc(go_width, 2), screen_height / 2 - 80, 60, color_bad);

                var buf: [64]u8 = undefined;
                const score_text = try std.fmt.bufPrintZ(&buf, "Final Score: {d}", .{score});
                const score_width = rl.MeasureText(score_text.ptr, 30);
                rl.DrawText(score_text.ptr, @divTrunc(screen_width, 2) - @divTrunc(score_width, 2), screen_height / 2, 30, color_text);

                const prompt = "Press ENTER to Return to Title";
                const prompt_width = rl.MeasureText(prompt, 20);
                if (@mod(@as(i32, @intFromFloat(rl.GetTime() * 2.0)), 2) == 0) {
                    rl.DrawText(prompt, @divTrunc(screen_width, 2) - @divTrunc(prompt_width, 2), screen_height / 2 + 60, 20, color_text);
                }
            },
        }

        rl.EndMode2D();
        rl.EndDrawing();
    }
}
