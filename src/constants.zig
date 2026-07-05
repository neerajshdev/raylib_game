const rl = @import("rl.zig").c;

pub const screen_width = 800;
pub const screen_height = 600;

// Colors
pub const color_bg = rl.Color{ .r = 15, .g = 15, .b = 20, .a = 255 };
pub const color_player = rl.Color{ .r = 0, .g = 228, .b = 255, .a = 255 }; // Cyan glow
pub const color_good = rl.Color{ .r = 57, .g = 255, .b = 20, .a = 255 }; // Neon green
pub const color_bad = rl.Color{ .r = 255, .g = 0, .b = 60, .a = 255 }; // Neon red
pub const color_text = rl.Color{ .r = 240, .g = 240, .b = 245, .a = 255 };
