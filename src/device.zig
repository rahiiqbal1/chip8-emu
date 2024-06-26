const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const Bitmap = @import("bitmap.zig").Bitmap;
const Display = @import("display.zig").Display;

const DEFAULT_FONT = [80]u8 {
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80  // F
};

pub const Device = struct {
    cpu: CPU,

    // Create the device:
    pub fn create(bitmap: *Bitmap, display: *Display) Device {
        return Device {
            .cpu = CPU.init(bitmap, display),
        };
    }

    // Load the ROM data from a file:
    pub fn loadROM(self: *Device, filepath: []const u8) !bool {
        // Opening file with given name:
        const file: std.fs.File = try std.fs.openFileAbsolute(filepath, .{});
        defer file.close();

        std.debug.print("Loading ROM...\n", .{});
        // Getting size of file:
        const size: usize = try file.getEndPos();
        std.debug.print("ROM File Size: {}B\n", .{size});
        const reader = file.reader();

        // Reading bytes into memory:
        var i: usize = 0;
        while (i < size) : (i += 1) {
            // Starting at position 0x200 in "ram":
            self.cpu.ram[i + 0x200] = try reader.readByte();
        }

        std.debug.print("Loading ROM Succeeded!\n", .{});
        return true;
    }
};
