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

    // Initialising display:
    var display = try Display.create("CHIP-8", 800, 400,
        bitmap.width, bitmap.height
    );
    defer display.free();

    // Creating device and loading rom:
    var chip8: Device = Device.create(&bitmap, &display);
    _ = try chip8.loadROM("/home/rahi/projs/chip8-emu/roms/pong.rom");

    // Display loop:
    const fps: f32 = 60.0;
    const fps_interval = 1000.0 / fps;
    var previous_time = std.time.milliTimestamp();
    var current_time = std.time.milliTimestamp();

    while (display.open == true) {
        display.input();

        current_time = std.time.milliTimestamp();
        const time_diff = @as(f32,
            @floatFromInt(current_time - previous_time)
        );
        if (time_diff > fps_interval) {
            previous_time = current_time;

            try chip8.cpu.cycle();

            chip8.cpu.display.draw(&bitmap);
        }
    }
}
