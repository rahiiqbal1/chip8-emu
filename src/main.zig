const std = @import("std");
const Display = @import("display.zig").Display;
const Bitmap = @import("bitmap.zig").Bitmap;
const Device = @import("device.zig").Device;

pub fn main() !void {
    // General purpose memory allocator:
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
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
    _ = bitmap.setPixel(5, 5);

    // Initialising display:
    var display = try Display.create("CHIP-8", 800, 400,
        bitmap.width, bitmap.height
    );
    defer display.free();

    var dev_test: Device = Device.create();
    _ = try dev_test.loadROM("/home/rahi/projs/chip8-emu/roms/tetris.rom");

    // Display loop:
    while (display.open == true) {
        display.input();
        display.draw(&bitmap);
    }
}
