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
