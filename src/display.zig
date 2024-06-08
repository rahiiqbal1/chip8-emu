const std = @import("std");
const c = @import("c.zig");

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
            .framebuffer_heigth = framebuffer_height,
        };
    }

    // Destroys SDL window instance:
    pub fn free(self: *Display) void {
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    // Handles SDL's queue of events:
    pub fn input(self: *Display) void {
        const event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&event) != 0) {
            switch(event.@"type") {
                c.SDL_QUIT => {
                    self.open = false;
                },
                else => {},
            }
        }
    }
};
