const std = @import("std");
const Display = @import("display.zig").Display;

pub fn main() !void {
    // Initialising display:
    var display = try Display.create("CHIP-8", 800, 400);
    defer display.free();

    // Display loop:
    while (display.open == true) {
        display.input();
    }
}
