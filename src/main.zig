const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
});
const assert = @import("std").debug.assert;

const std = @import("std");

const Width: u32 = 1500;
const Height: u32 = 1000;

const Font = struct {
    inner: *c.struct__TTF_Font,

    const FontError = error{
        FailedToLoadFont,
    };
    const Measurement = struct {
        width: u32,
        height: u32,

        pub fn width_c(self: Measurement) c_int {
            return @intCast(self.width);
        }

        pub fn height_c(self: Measurement) c_int {
            return @intCast(self.height);
        }
    };

    fn init(path: []const u8, ptsize: i32) FontError!Font {
        const font = c.TTF_OpenFont(path.ptr, ptsize) orelse {
            c.SDL_Log("Unable to initialize font: %s", c.SDL_GetError());
            return FontError.FailedToLoadFont;
        };

        return .{ .inner = font };
    }

    fn deinit(self: *const Font) void {
        c.TTF_CloseFont(self.inner);
    }

    fn measure(self: *const Font, text: []const u8) Measurement {
        var h_c: c_int = 0;
        var w_c: c_int = 0;
        _ = c.TTF_SizeUTF8(self.inner, text.ptr, &w_c, &h_c);

        const h: u32 = @intCast(h_c);
        const w: u32 = @intCast(w_c);

        return .{ .width = w, .height = h };
    }

    fn render(self: *const Font, text: []const u8) *c.struct_SDL_Surface {
        const white = c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
        return c.TTF_RenderText_Solid(self.inner, text.ptr, white);
    }
};

pub fn main() !void {
    _ = c.TTF_Init();
    defer _ = c.TTF_Quit();
    const font = try Font.init("OpenSans-Regular.ttf", 155);
    defer font.deinit();
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const text = "hallo welt dies ist ein test";
    const surface = font.render(text);
    const font_measure = font.measure(text);

    const screen = c.SDL_CreateWindow(
        "Slides",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        Width,
        Height,
        c.SDL_WINDOW_OPENGL,
    ) orelse
        {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    // _ = c.SDL_SetWindowFullscreen(screen, 1);
    const renderer = c.SDL_CreateRenderer(
        screen,
        -1,
        c.SDL_RENDERER_PRESENTVSYNC,
    ) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);
    const texture = c.SDL_CreateTextureFromSurface(renderer, surface);

    const mid = Height / 2 - (font_measure.height / 2);
    const mid_c: c_int = @intCast(mid);

    var rect =
        c.SDL_Rect{
        .x = 0,
        .y = mid_c,
        .w = font_measure.width_c(),
        .h = font_measure.height_c(),
    };
    const speed: f32 = 1150 / 3;
    var quit = false;
    var last_ticks: f32 = @floatFromInt(c.SDL_GetTicks());
    var is_fullscreen = false;
    main_loop: while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.sym) {
                        c.SDLK_q => break :main_loop,
                        c.SDLK_f => {
                            is_fullscreen = !is_fullscreen;
                            const flags: u32 = @intFromBool(is_fullscreen);
                            _ = c.SDL_SetWindowFullscreen(screen, flags);
                        },
                        else => {},
                    }
                    if (event.key.keysym.sym == c.SDLK_q) {
                        break :main_loop;
                    }
                },
                else => {},
            }
        }
        const now_ticks_i: u32 = c.SDL_GetTicks();
        const now_ticks: f32 = @floatFromInt(now_ticks_i);
        const delta_time = ((now_ticks) - last_ticks) * 0.001;

        const speed_i: i32 = @intFromFloat(speed * delta_time);
        rect.x += speed_i;
        if (rect.x - @divTrunc(font_measure.width_c(), 2) >= Width) {
            rect.x = 0 - font_measure.width_c();
        }

        last_ticks = now_ticks;

        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_RenderCopy(renderer, texture, null, &rect);
        c.SDL_RenderPresent(renderer);

        // c.SDL_Delay(10);
    }
}
