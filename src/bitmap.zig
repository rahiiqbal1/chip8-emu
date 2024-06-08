const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Bitmap = struct {
    allocator: Allocator,
    width: u8,
    height: u8,
    pixels: []u1,

    // Create bitmap:
    pub fn create(allocator: Allocator, width: u8, height: u8) !Bitmap {
        // Allocate pixel array:
        const pixels = try allocator.alloc(
            u1, @as(u16, width) * @as(u16, height)
        );

        return Bitmap {
            .allocator = allocator,
            .width = width,
            .height = height,
            .pixels = pixels,
        };
    }

    // Free bitmap:
    pub fn free(self: *Bitmap) void {
        // Free allocated data with allocator:
        self.allocator.free(self.pixels);
    }

    // Clear bitmap to specified value:
    pub fn clear(self: *Bitmap, value: u1) void {
        @memset(self.pixels, value);
    }

    // Set pixel value at (x, y) coordinate:
    pub fn setPixel(self: *Bitmap, x: u8, y: u8) bool {
        // Return if x or y is invalid:
        if (x >= self.width or y >= self.height) return false;

        const index: u16 = @as(u16, x) + @as(u16, y) * @as(u16, self.width);
        self.pixels[index] ^= 1;
        
        return (self.pixels[index] == 0);
    }

    // Get pixel value at (x, y) coordinate:
    pub fn getPixel(self: *Bitmap, x: u8, y: u8) u1 {
        // Return if x or y is invalid:
        if (x >= self.width or y >= self.height) return 0;

        const index: u16 = @as(u16, x) + @as(u16, y) * @as(u16, self.width);

        return self.pixels[index];
    }
};
