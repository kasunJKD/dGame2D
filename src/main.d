import bindbc.loader;  
import bindbc.sdl;
import bindbc.opengl;
import std.stdio : writeln;
import window;
import editor;

version (Debug)
{
    enum bool isDebugBuild = true;
}
else
{
    enum bool isDebugBuild = false;
}

enum Mode { Editor, Game }

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

    Window win = createWindow("My SDL3 Window", 800, 600);

    GLSupport retVal = loadOpenGL();
    
    Mode mode;
    static if (isDebugBuild)
    {
        mode = Mode.Editor;
        writeln("** DEBUG BUILD **: Starting in Editor mode. Press Tab to toggle.");
        //initEditor(&es);
    }
    else
    {
        mode = Mode.Game;
        writeln("** RELEASE BUILD **: Starting in Game mode (no editor).");
    }

    bool running = true;
    bool quit, keytab;
    while (running) {
        keytab = quit = false;
        if (!pollWindowEvents(&win, keytab, quit))
        {
            running = false;
            break;
        }

        if (quit)
        {
            running = false;
            break;
        }

        static if (isDebugBuild)
        {
            if (keyTab)
            {
                if (currentMode == Mode.Editor)
                {
                    writeln("Switching to Game mode...");
                    currentMode = Mode.Game;
                }
                else
                {
                    writeln("Switching to Editor mode...");
                    currentMode = Mode.Editor;
                }
            }
        }

        /* auto now = Clock.currTime; */
        /* auto dt  = (now - lastTime).seconds; // float seconds */
        /* lastTime = now; */

        glClearColor(1.0f, 0.1f, 0.12f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        static if (isDebugBuild)
        {
            if (currentMode == Mode.Editor)
            {
                //updateAndRenderEditor(&es, &win, mouseX, mouseY, mouseDown, mouseUp, keyS);
            }
            else
            {
                //updateAndRenderGame(&gs, cast(float)dt);
            }
        }
        else
        {
            //updateAndRenderGame(&gs, cast(float)dt);
        }

        presentWindow(&win);
    }
    
    // Clean up
    destroyWindow(&win);
}
