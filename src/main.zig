const std = @import("std");
const Display = @import("display.zig").Display;
const Bitmap = @import("bitmap.zig").Bitmap;

pub fn main() !void {
    // General purpose memory allocator:
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak\n");
        }
    }

    // Creating bitmap:
    var bitmap = try Bitmap.create(allocator, 64, 32);
    defer bitmap.free();

    // Initialising display:
    var display = try Display.create("CHIP-8", 800, 400);
    defer display.free();

    // Display loop:
    while (display.open == true) {
        display.input();
    }
}
