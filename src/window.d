module window;

import bindbc.sdl;
import std.stdio;
import std.exception;
import std.string;
import core.stdc.stdlib;
import std.conv;

public struct Window
{
    SDL_Window* sdlWindow;       
    SDL_GLContext glContext;      
    int   width;
    int   height;
}
extern(C) @nogc nothrow
Window createWindow(const(char)* title, int w, int h)
{
    Window win;

    // Initialize SDL (or your window library)
    if (SDL_Init(SDL_INIT_VIDEO) < 0)
    {
        printf("SDL_Init failed: %s\n", SDL_GetError());
        abort();
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 6);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);

    win.sdlWindow = SDL_CreateWindow(
        title,
        w, h,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE
    );
    if (win.sdlWindow == null) {
        printf("Failed to create SDL Window: %s\n", SDL_GetError());
    }
    win.glContext = SDL_GL_CreateContext(win.sdlWindow);

    if (win.glContext == null) {
        printf("Failed to create gl context: %s\n", SDL_GetError());
    }

    SDL_GL_SetSwapInterval(1);

    win.width  = w;
    win.height = h;
    return win;
}

extern(C) @nogc nothrow
bool pollWindowEvents(Window* win,out bool keyTab, out bool quit)
{
    // Reset outputs
    keyTab = quit = false;

    SDL_Event e;
    while (SDL_PollEvent(&e) != 0)
    {

        switch (e.type)
        { 
            case SDL_EVENT_QUIT:
                quit = true;
                return false;

            /* case SDL_MOUSEBUTTONDOWN: */
            /*     if (e.button.button == SDL_BUTTON_LEFT) */
            /*     { */
            /*         mouseX    = e.button.x; */
            /*         mouseY    = e.button.y; */
            /*         mouseDown = true; */
            /*     } */
            /*     break; */

            /* case SDL_MOUSEBUTTONUP: */
            /*     if (e.button.button == SDL_BUTTON_LEFT) */
            /*     { */
            /*         mouseUp = true; */
            /*     } */
            /*     break; */

            case SDL_EVENT_KEY_DOWN:
                switch (e.key.key)
                {
                    case SDLK_TAB:
                        keyTab = true;
                        break;
                    case SDLK_ESCAPE:
                        quit = true;
                        return false;
                    default:
                        break;
                }
                break;

            default:
                break;
        }
    }
    return true;
}

extern(C) @nogc nothrow
void presentWindow(Window* win)
{
    SDL_GL_SwapWindow(cast(SDL_Window*)win.sdlWindow);
}

extern(C) @nogc nothrow
void destroyWindow(Window* win)
{
    if (win.glContext)
    SDL_GL_DestroyContext(cast(SDL_GLContext)win.glContext);
    if (win.sdlWindow)
        SDL_DestroyWindow(cast(SDL_Window*)win.sdlWindow);
    SDL_Quit();
}
