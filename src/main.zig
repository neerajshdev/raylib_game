const std = @import("std");
const rl = @import("rl.zig").c;

const constants = @import("constants.zig");
const player_mod = @import("player.zig");
const objects_mod = @import("objects.zig");
const particles_mod = @import("particles.zig");

const Player = player_mod.Player;
const FallingObject = objects_mod.FallingObject;
const ObjectType = objects_mod.ObjectType;
const ParticleSystem = particles_mod.ParticleSystem;

const GameState = enum {
    TITLE,
    PLAYING,
    GAME_OVER,
};

pub fn main() !void {
    // Enable VSync and Anti-Aliasing for perfectly smooth movement and rendering
    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT | rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(constants.screen_width, constants.screen_height, "Square Rush");
    defer rl.CloseWindow();

    var state = GameState.TITLE;

    var player = Player{
        .rect = rl.Rectangle{
            .x = constants.screen_width / 2.0 - 30.0,
            .y = constants.screen_height - 50.0,
            .width = 60.0,
            .height = 15.0,
        },
        .vel_x = 0,
        .color = constants.color_player,
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
                    player.rect.x = constants.screen_width / 2.0 - player.rect.width / 2.0;
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
                                particles.spawn(obj.rect.x + obj.rect.width / 2, obj.rect.y + obj.rect.height, constants.color_good, 15);
                            } else {
                                score -= 30;
                                screen_shake_timer = 0.3; // 300ms shake
                                particles.spawn(obj.rect.x + obj.rect.width / 2, obj.rect.y + obj.rect.height, constants.color_bad, 30);
                            }
                        } else if (obj.rect.y > constants.screen_height) {
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
        rl.ClearBackground(constants.color_bg);

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
                rl.DrawText(title_text, @divTrunc(constants.screen_width, 2) - @divTrunc(title_width, 2), 200, 50, constants.color_good);

                const subtitle = "Avoid the red bombs!";
                const sub_width = rl.MeasureText(subtitle, 20);
                rl.DrawText(subtitle, @divTrunc(constants.screen_width, 2) - @divTrunc(sub_width, 2), 270, 20, constants.color_bad);

                const prompt = "Press ENTER to Start";
                const prompt_width = rl.MeasureText(prompt, 20);
                if (@mod(@as(i32, @intFromFloat(rl.GetTime() * 2.0)), 2) == 0) {
                    rl.DrawText(prompt, @divTrunc(constants.screen_width, 2) - @divTrunc(prompt_width, 2), 400, 20, constants.color_text);
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
                rl.DrawText(score_text.ptr, 20, 20, 30, constants.color_text);

                if (high_score > 0) {
                    var hs_buf: [64]u8 = undefined;
                    const hs_text = try std.fmt.bufPrintZ(&hs_buf, "Best: {d}", .{high_score});
                    rl.DrawText(hs_text.ptr, constants.screen_width - 150, 20, 20, constants.color_text);
                }
            },
            .GAME_OVER => {
                particles.draw();

                const go_text = "GAME OVER!";
                const go_width = rl.MeasureText(go_text, 60);
                rl.DrawText(go_text, @divTrunc(constants.screen_width, 2) - @divTrunc(go_width, 2), constants.screen_height / 2 - 80, 60, constants.color_bad);

                var buf: [64]u8 = undefined;
                const score_text = try std.fmt.bufPrintZ(&buf, "Final Score: {d}", .{score});
                const score_width = rl.MeasureText(score_text.ptr, 30);
                rl.DrawText(score_text.ptr, @divTrunc(constants.screen_width, 2) - @divTrunc(score_width, 2), constants.screen_height / 2, 30, constants.color_text);

                const prompt = "Press ENTER to Return to Title";
                const prompt_width = rl.MeasureText(prompt, 20);
                if (@mod(@as(i32, @intFromFloat(rl.GetTime() * 2.0)), 2) == 0) {
                    rl.DrawText(prompt, @divTrunc(constants.screen_width, 2) - @divTrunc(prompt_width, 2), constants.screen_height / 2 + 60, 20, constants.color_text);
                }
            },
        }

        rl.EndMode2D();
        rl.EndDrawing();
    }
}
