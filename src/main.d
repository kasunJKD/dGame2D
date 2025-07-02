//TODO
//read file
//mappers
//movement of cuourser
//special windows

import bindbc.loader;  
import bindbc.sdl;
import bindbc.opengl;
import std.stdio : writeln;
import std.string;
import window;
import editor;
import defines;

immutable float LEFT_BAR_WIDTH   = 20.0f;   // px
immutable float BOTTOM_BAR_HEIGHT = 30.0f;   // px
immutable float MARGIN            = 10.0f;   // padding inside bars
immutable float FONT_SIZE = 24.0f;
immutable int TAB_SPACE_AMOUNT = 4;

enum ActionType {
    OPEN_FUZZY
}

struct CommandBind {
    SDL_KeyMod leader_key; //might or might not exists
    SDL_KeyMod keymod; //ctrl, alt, shift
    SDL_KeyCode key;
    string description;
};

ActionType[CommandBind] commandMapper;


void fillRect(SDL_Renderer* r, ubyte red, ubyte green, ubyte blue, ubyte alpha,
              in SDL_FRect rect)
{
    SDL_SetRenderDrawColor(r, red, green, blue, alpha);
    SDL_RenderFillRect(r, &rect);
}

void drawCaret(SDL_Renderer* r, in SDL_FRect rect)
{
    SDL_SetRenderDrawColor(r, 255, 255, 255, 255); // white
    SDL_RenderFillRect(r, &rect);
}

SDL_Texture* renderMultiline(SDL_Renderer* ren,
                             TTF_Font*     font,
                             string        text,
                             SDL_Color     color,
                             SDL_Rect*     outDst,
                             int           px,
                             int           py,
                             int           wrapWidth)
{
    import std.array            : split;         // split by '\n'
    import std.algorithm.comparison : max; 
    /* 1 ─ split the incoming string */
    SDL_Surface*[] rowSurfaces;
    int totalH = 0;
    int maxW   = 0;

    foreach (line; text.split('\n'))
    {
        SDL_Surface* s;

        /* --- blank row? fabricate a transparent spacer --- */
        if (line.length == 0)
        {
            int h = TTF_GetFontLineSkip(font);       // ← renamed function
            s = SDL_CreateSurface(1, h, SDL_PIXELFORMAT_RGBA32);
            SDL_SetSurfaceBlendMode(s, SDL_BLENDMODE_NONE);
            SDL_FillSurfaceRect(s, null, 0x00000000);
        }
        else
        {
            s = TTF_RenderText_Blended_Wrapped(font,
                                               line.toStringz,
                                               cast(ulong) line.length,
                                               color,
                                               wrapWidth);
            if (s is null) continue;
        }

        rowSurfaces ~= s;
        totalH += s.h;

        /* keep track of widest row, but never beyond wrapWidth */
        int candidate = s.w > wrapWidth ? wrapWidth : s.w;   // ← replaces clamp
        maxW = max(maxW, candidate);
    }

    if (rowSurfaces.length == 0)
        return null;

    /* 2 ─ create a transparent composite surface  (SDL-3 syntax) */
    auto finalSurf = SDL_CreateSurface(maxW,
                                       totalH,
                                       SDL_PIXELFORMAT_RGBA32);   // <- SDL 3
    SDL_SetSurfaceBlendMode(finalSurf, SDL_BLENDMODE_NONE);
    SDL_FillSurfaceRect(finalSurf, null, 0x00000000);             // SDL 3

    /* 3 ─ blit every row on top */
    int y = 0;
    foreach (s; rowSurfaces)
    {
        SDL_Rect dst = { 0, y, s.w, s.h };
        SDL_BlitSurface(s, null, finalSurf, &dst);  // still valid in SDL 3
        y += s.h;
        SDL_DestroySurface(s);                      // free row surface
    }

    /* 4 ─ promote to a texture */
    auto tex = SDL_CreateTextureFromSurface(ren, finalSurf);
    SDL_SetTextureBlendMode(tex, SDL_BLENDMODE_BLEND);

    outDst.x = px;
    outDst.y = py;
    outDst.w = finalSurf.w;
    outDst.h = finalSurf.h;

    SDL_DestroySurface(finalSurf);
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
    
    TTF_Font* font = TTF_OpenFont(fontPath.toStringz(), FONT_SIZE);
    if (font is null) {
        writeln("Failed to load font");
        return;
    }

    SDL_Texture* textTex = null;
    SDL_Rect textRect;
    SDL_Color white = SDL_Color(255, 255, 255, 255);

    SDL_StartTextInput(win.sdlWindow);

    bool  caretVisible = true;
    ulong lastBlink    = SDL_GetTicks();   // millis
    immutable BLINK_MS = 500;              // blink every 0.5 s

    while (true)
    {
        ulong now = SDL_GetTicks();
        if (now - lastBlink > BLINK_MS)
        {
            caretVisible = !caretVisible;
            lastBlink    = now;
        }
        bool tab, quit;
        if (!pollWindowEvents(&win, tab, quit, inputtext, TAB_SPACE_AMOUNT) || quit)
            break;

        /* Clear and draw scene here */
        SDL_SetRenderDrawColor(win.renderer, 20, 20, 20, 255);
        SDL_RenderClear(win.renderer);
        
        SDL_FRect leftBar = { 0,
                              0,
                              LEFT_BAR_WIDTH,
                              cast(float)win.height };
        fillRect(win.renderer, 35, 35, 55, 255, leftBar);

        //-- bottom bar (stretches full width)
        SDL_FRect bottomBar = { 0,
                                cast(float)win.height - BOTTOM_BAR_HEIGHT,
                                cast(float)win.width,
                                BOTTOM_BAR_HEIGHT };
        fillRect(win.renderer, 35, 35, 55, 255, bottomBar);

        SDL_FRect content = {
            LEFT_BAR_WIDTH,                       // start right after the sidebar
            0,
            cast(float)win.width  - LEFT_BAR_WIDTH,
            cast(float)win.height - BOTTOM_BAR_HEIGHT
        };

        SDL_FRect textArea = {
            content.x + MARGIN,
            content.y + MARGIN,                   //   <— now near the *top*, not bottom
            content.w - 2*MARGIN,
            content.h - 2*MARGIN
        };

        if (textTex !is null)
            SDL_DestroyTexture(textTex);

        textTex = renderMultiline(win.renderer,
                          font,
                          inputtext,
                          white,
                          &textRect,
                          cast(int)textArea.x,
                          cast(int)textArea.y,
                          cast(int)textArea.w); 
        
        SDL_FRect textFRect;
        SDL_RectToFRect(&textRect, &textFRect);
        textFRect.x = textArea.x;          // indent from left bar + padding
        textFRect.y = textArea.y;          // sit on the bottom bar’s padding

        // don’t overrun the input zone;
        if (textFRect.w > textArea.w)
            textFRect.w = textArea.w;

        if (textTex !is null)
            SDL_RenderTexture(win.renderer, textTex, null, &textFRect);

        /* ---------- figure out caret position ---------- */

        // split once; reuse for both caret and renderMultiline
        auto lines = inputtext.split('\n');

        auto lastLine = lines.length ? lines[$ - 1] : "";

        /*  w, h  in pixels for that line  */
        int glyphW = 0, glyphH = 0;
        TTF_GetStringSize(font,
                          lastLine.toStringz,
                          cast(size_t) lastLine.length,   // byte length
                          &glyphW,
                          &glyphH);     

        /* Y offset = (#completed lines) * line-skip  */
        int lineSkip = TTF_GetFontLineSkip(font);
        float caretY = textArea.y + (lines.length - 1) * lineSkip;

        /* X offset = left margin + pixel width of that last line */
        float caretX = textArea.x + glyphW;

        /* constrict caret to the textArea width (optional) */
        if (caretX > textArea.x + textArea.w - 1)
            caretX = textArea.x + textArea.w - 1;

        /* build a 2-px-wide caret rect */
        SDL_FRect caret = { caretX, caretY, 10, cast(float)glyphH };

    /* ---------- draw caret if visible ---------- */
        if (caretVisible)
            drawCaret(win.renderer, caret);
            
            SDL_RenderPresent(win.renderer);       /* … draw textures / shapes … */

            presentWindow(&win);

        }

    destroyWindow(&win);
    TTF_CloseFont(font);
}

