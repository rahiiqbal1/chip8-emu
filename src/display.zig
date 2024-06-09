const std = @import("std");
const c = @import("c.zig");
const Bitmap = @import("bitmap.zig").Bitmap;

pub const Display = struct {
    window: *c.SDL_Window,
    open: bool,
    renderer: *c.SDL_Renderer,
    framebuffer: *c.SDL_Texture,
    framebuffer_width: u8,
    framebuffer_height: u8,
    keys: [16]bool,

    // Creates SDL window instance:
    pub fn create(title: [*]const u8, width: i32, height: i32,
        framebuffer_width: u8, framebuffer_height: u8) !Display {
        // Initialise SDL2:
        if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO) != 0) {
            return error.SDLInitialisationFailed;
        }

        // Create SDL2 window:
        const window = c.SDL_CreateWindow(
            title,
            c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED,
            width, height, c.SDL_WINDOW_SHOWN,
        ) orelse {
            c.SDL_Quit();
            return error.SDLWindowCreationFailed;
        };

        // Create SDL2 renderer:
        const renderer = c.SDL_CreateRenderer(
            window, -1, c.SDL_RENDERER_ACCELERATED
            ) orelse {
            c.SDL_DestroyWindow(window);
            c.SDL_Quit();
            return error.SDLRendererCreationFailed;
        };

        // Create display framebuffer:
        const framebuffer = c.SDL_CreateTexture(
            renderer,
            c.SDL_PIXELFORMAT_RGBA8888,
            c.SDL_TEXTUREACCESS_STREAMING,
            framebuffer_width, framebuffer_height
        ) orelse {
            c.SDL_DestroyRenderer(renderer);
            c.SDL_DestroyWindow(window);
            c.SDL_Quit();
            return error.SDLTextureNull;
        };

        // Return display:
        return Display {
            .window = window,
            .open = true,
            .renderer = renderer,
            .framebuffer = framebuffer,
            .framebuffer_width = framebuffer_width,
            .framebuffer_height = framebuffer_height,
            .keys = std.mem.zeroes([16]bool),
        };
    }

    // Destroys SDL window instance:
    pub fn free(self: *Display) void {
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    // Handles SDL's queue of events:
    pub fn input(self: *Display) void {
        var event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&event) != 0) {
            switch(event.@"type") {
                c.SDL_QUIT => {
                    self.open = false;
                },
                c.SDL_KEYDOWN => {
                    switch(event.@"key".@"keysym".@"scancode") {
                        c.SDL_SCANCODE_1 => {
                            self.keys[0x1] = true; 
                            std.debug.print("1DOWN\n", .{});
                        },
                        c.SDL_SCANCODE_2 => {
                            self.keys[0x2] = true; 
                            std.debug.print("2DOWN\n", .{});
                        },
                        c.SDL_SCANCODE_3 => {
                            self.keys[0x3] = true; 
                            std.debug.print("3DOWN\n", .{});
                        },
                        c.SDL_SCANCODE_4 => {
                            self.keys[0xC] = true; 
                            std.debug.print("4DOWN\n", .{});
                        },
                        c.SDL_SCANCODE_Q => {
                            self.keys[0x4] = true; 
                            std.debug.print("QDOWN\n", .{});
                        },
                        c.SDL_SCANCODE_W => {
                            self.keys[0x5] = true; 
                            std.debug.print("WDOWN\n", .{});
                        },
                        c.SDL_SCANCODE_E => {
                            self.keys[0x6] = true; 
                            std.debug.print("EDOWN\n", .{});
                        },
                        c.SDL_SCANCODE_R => {
                            self.keys[0xD] = true; 
                            std.debug.print("RDOWN\n", .{});
                        },
                        c.SDL_SCANCODE_A => {
                            self.keys[0x7] = true; 
                            std.debug.print("ADOWN\n", .{});
                        },
                        c.SDL_SCANCODE_S => {
                            self.keys[0x8] = true; 
                            std.debug.print("SDOWN\n", .{});
                        },
                        c.SDL_SCANCODE_D => {
                            self.keys[0x9] = true; 
                            std.debug.print("DDOWN\n", .{});
                        },
                        c.SDL_SCANCODE_F => {
                            self.keys[0xE] = true; 
                            std.debug.print("FDOWN\n", .{});
                        },
                        c.SDL_SCANCODE_Z => {
                            self.keys[0xA] = true; 
                            std.debug.print("ZDOWN\n", .{});
                        },
                        c.SDL_SCANCODE_X => {
                            self.keys[0x0] = true; 
                            std.debug.print("XDOWN\n", .{});
                        },
                        c.SDL_SCANCODE_C => {
                            self.keys[0xB] = true; 
                            std.debug.print("CDOWN\n", .{});
                        },
                        c.SDL_SCANCODE_V => {
                            self.keys[0xF] = true; 
                            std.debug.print("VDOWN\n", .{});
                        },
                        else => {},
                    }
                },
                c.SDL_KEYUP => {
                    switch(event.@"key".@"keysym".@"scancode") {
                        c.SDL_SCANCODE_1 => {
                            self.keys[0x1] = false; 
                            std.debug.print("1UP\n", .{});
                        },
                        c.SDL_SCANCODE_2 => {
                            self.keys[0x2] = false; 
                            std.debug.print("2UP\n", .{});
                        },
                        c.SDL_SCANCODE_3 => {
                            self.keys[0x3] = false; 
                            std.debug.print("3UP\n", .{});
                        },
                        c.SDL_SCANCODE_4 => {
                            self.keys[0xC] = false; 
                            std.debug.print("4UP\n", .{});
                        },
                        c.SDL_SCANCODE_Q => {
                            self.keys[0x4] = false; 
                            std.debug.print("QUP\n", .{});
                        },
                        c.SDL_SCANCODE_W => {
                            self.keys[0x5] = false; 
                            std.debug.print("WUP\n", .{});
                        },
                        c.SDL_SCANCODE_E => {
                            self.keys[0x6] = false; 
                            std.debug.print("EUP\n", .{});
                        },
                        c.SDL_SCANCODE_R => {
                            self.keys[0xD] = false; 
                            std.debug.print("RUP\n", .{});
                        },
                        c.SDL_SCANCODE_A => {
                            self.keys[0x7] = false; 
                            std.debug.print("AUP\n", .{});
                        },
                        c.SDL_SCANCODE_S => {
                            self.keys[0x8] = false; 
                            std.debug.print("SUP\n", .{});
                        },
                        c.SDL_SCANCODE_D => {
                            self.keys[0x9] = false; 
                            std.debug.print("DUP\n", .{});
                        },
                        c.SDL_SCANCODE_F => {
                            self.keys[0xE] = false; 
                            std.debug.print("FUP\n", .{});
                        },
                        c.SDL_SCANCODE_Z => {
                            self.keys[0xA] = false; 
                            std.debug.print("ZUP\n", .{});
                        },
                        c.SDL_SCANCODE_X => {
                            self.keys[0x0] = false; 
                            std.debug.print("XUP\n", .{});
                        },
                        c.SDL_SCANCODE_C => {
                            self.keys[0xB] = false; 
                            std.debug.print("CUP\n", .{});
                        },
                        c.SDL_SCANCODE_V => {
                            self.keys[0xF] = false; 
                            std.debug.print("VUP\n", .{});
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }
    }

    pub fn draw(self: *Display, bitmap: *Bitmap) void {
        if (bitmap.width != self.framebuffer_width) return;
        if (bitmap.height != self.framebuffer_height) return;

        // Display colours are chosen here:
        const clear_value = c.SDL_Color {
            .r = 0,
            .g = 0,
            .b = 0,
            .a = 255,
        };
        const colour_value = c.SDL_Color {
            .r = 255,
            .g = 255,
            .b = 255,
            .a = 255,
        };

        var pixels: ?*anyopaque = null;
        var pitch: i32 = 0;

        // Lock framebuffer so we can write pixel data to it:
        if (c.SDL_LockTexture(self.framebuffer, null, &pixels, &pitch) != 0) {
            c.SDL_Log("Failed to lock texture: %s\n", c.SDL_GetError());
            return;
        }

        // Cast pixels pointer so that we can use offsets:
        const upixels: [*]u32 = @ptrCast(@alignCast(pixels.?));

        // Copy pixel loop:
        var y: u8 = 0;
        while (y < self.framebuffer_height) : (y += 1) {

            var x: u8 = 0;

            while (x < self.framebuffer_width) : (x += 1) {

                const index: usize =
                    @as(usize, y) * 
                    @divExact(@as(usize, @intCast(pitch)), @sizeOf(u32)) +
                    @as(usize, x);

                const colour = if (bitmap.getPixel(x, y) == 1) colour_value 
                    else clear_value;

                const r: u32 = @as(u32, colour.r) << 24;
                const g: u32 = @as(u32, colour.g) << 16;
                const b: u32 = @as(u32, colour.b) << 8;
                const a: u32 = @as(u32, colour.a) << 0;

                upixels[index]  = r | g | b | a;
            }
        }

        _ = c.SDL_UnlockTexture(self.framebuffer);

        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderCopy(self.renderer, self.framebuffer, null, null);
        _ = c.SDL_RenderPresent(self.renderer);
    }
};
