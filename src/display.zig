const std = @import("std");
const c = @import("c.zig");

pub const Display = struct {
    window: *c.SDL_Window,
    open: bool,

    // Creates SDL window instance:
    pub fn create(title: [*]const u8, width: i32, height: i32) !Display {
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

        // Return display:
        return Display {
            .window = window,
            .open = true,
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
