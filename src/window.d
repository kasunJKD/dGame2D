module window;

import bindbc.sdl;
import std.stdio;
import std.exception;
import std.string;
import core.stdc.stdlib;
import std.utf;

/// Simple wrapper holding an SDL window + accelerated renderer
public struct Window
{
    SDL_Window*   sdlWindow;  // native window handle
    SDL_Renderer* renderer;   // SDL 2D/3D renderer
    int           width;
    int           height;
}

Window createWindow(const(char)* title, int w, int h)
{
    Window win;

    /* Initialise SDL video subsystem */
    if (SDL_Init(SDL_INIT_VIDEO) < 0 || TTF_Init() < 0) {
        writeln("‼ SDL or TTF init failed: ", SDL_GetError());
        abort();
    }

    /* Create the window (no SDL_WINDOW_OPENGL flag!) */
    win.sdlWindow = SDL_CreateWindow(
        title,
        w,
        h,
        SDL_WINDOW_RESIZABLE
    );
    if (win.sdlWindow is null)
    {
        printf("Failed to create SDL window: %s\n", SDL_GetError());
        abort();
    }

    /* Create an accelerated renderer that syncs to the display’s refresh */
    win.renderer = SDL_CreateRenderer(
        win.sdlWindow,
        null,
    );
    if (win.renderer is null)
    {
        printf("Failed to create SDL renderer: %s\n", SDL_GetError());
        abort();
    }

    win.width  = w;
    win.height = h;
    return win;
}

bool pollWindowEvents(Window* win, out bool keyTab, out bool quit, ref string text)
{
    keyTab = quit = false;

    SDL_Event e;
    while (SDL_PollEvent(&e) != 0)
    {
        switch (e.type)
        {
            case SDL_EVENT_QUIT:
                quit = true;
                return false;

            case SDL_EVENT_WINDOW_RESIZED:
                win.width  = e.window.data1;
                win.height = e.window.data2;
                break;

            case SDL_EVENT_KEY_DOWN:
                switch (e.key.key)
                {
                    case SDLK_TAB:
                        keyTab = true;
                        break;
                    case SDLK_ESCAPE:
                        quit = true;
                        return false;
                    case SDLK_BACKSPACE:
                        if (!text.empty)                       // nothing to remove?
                        {
                            auto n = strideBack(text, text.length);
                            text = text[0 .. text.length - n];
                        }
                        break;
                    case SDLK_RETURN:
                        text ~= '\n';  
                        break;
                    default:
                        break;
                }
                break;
            case SDL_EVENT_TEXT_INPUT:
                text ~= e.text.text[0 .. SDL_strlen(e.text.text)].idup;
                break;

            default:
                break;
        }
    }
    return true;
}

void presentWindow(Window* win)
{
    /* Push everything we’ve drawn this frame to the screen */
    SDL_RenderPresent(win.renderer);
}

void destroyWindow(Window* win)
{
    if (win.renderer)
        SDL_DestroyRenderer(win.renderer);
    if (win.sdlWindow)
        SDL_DestroyWindow(win.sdlWindow);

    SDL_Quit();
}
