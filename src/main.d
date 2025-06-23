import bindbc.loader;  
import bindbc.sdl;
import bindbc.opengl;
import std.stdio : writeln;
import std.string;
import window;
import editor;
import defines;

SDL_Texture* renderText(SDL_Renderer* ren, TTF_Font* font, string text, SDL_Color color, SDL_Rect* outDst)
{
    auto surface = TTF_RenderText_Blended(font, text.toStringz(), cast(ulong)text.length, color);
    if (surface is null)
        return null;

    auto tex = SDL_CreateTextureFromSurface(ren, surface);
    outDst.x = 50;
    outDst.y = 100;
    outDst.w = surface.w;
    outDst.h = surface.h;
    SDL_DestroySurface(surface);
    return tex;
}

void main()
{
    LoadMsg ret = loadSDL();
    if (ret != LoadMsg.success)
    {
        foreach (err; bindbc.loader.errors)
        {
            writeln("%s\n", err.message);
        }
        return;
    }
    LoadMsg retttf = loadSDLTTF();
    if (retttf != LoadMsg.success)
    {
        foreach (err; bindbc.loader.errors)
        {
            writeln("%s\n", err.message);
        }
        return;
    }

    Window win = createWindow("dGame", 800, 600);
    string inputtext = "";
    string fontPath = r"D:\Personal\dGame\build\debug\assets\Roboto-Regular.ttf";
    
    TTF_Font* font = TTF_OpenFont(fontPath.toStringz(), 32.0);
    if (font is null) {
        writeln("Failed to load font");
        return;
    }

    SDL_Texture* textTex = null;
    SDL_Rect textRect;
    SDL_Color white = SDL_Color(255, 255, 255, 255);

    SDL_StartTextInput(win.sdlWindow);

    while (true)
    {
        bool tab, quit;
        if (!pollWindowEvents(&win, tab, quit, &inputtext) || quit)
            break;

        /* Clear and draw scene here */
        if (textTex !is null)
            SDL_DestroyTexture(textTex);
        
        textTex = renderText(win.renderer, font, inputtext, white, &textRect);

        SDL_SetRenderDrawColor(win.renderer, 20, 20, 20, 255);
        SDL_RenderClear(win.renderer);
        SDL_FRect frect;
        SDL_RectToFRect(&textRect, &frect);
        if (textTex !is null)
            SDL_RenderTexture(win.renderer, textTex, null, &frect);
        SDL_RenderPresent(win.renderer);       /* … draw textures / shapes … */

        presentWindow(&win);

    }

    destroyWindow(&win);
    TTF_CloseFont(font);
}

