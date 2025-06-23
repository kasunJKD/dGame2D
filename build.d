#!rdmd

import std.stdio;
import std.file;
import std.path;
import std.process;
import std.string;

enum sourceDir = "src";
enum exeName = "game.exe";
enum string sdlSourceDll = "vendors\\sdl3\\bin\\SDL3.dll";
enum string bindbcSdlDir   = "vendors/bindbc-sdl/source";
enum string bindbcCommonDir= "vendors/bindbc-common/source";
enum string bindbcLoaderDir= "vendors/bindbc-loader/source";
enum string bindbcOpenGLDir= "vendors/bindbc-opengl/source";
enum string bindbcFreeTypeDir= "vendors/bindbc-freetype/source";

/* string[] compileImGuiObjs() */
/* { */
/*     string[] objs; */
/*     foreach (file; imguiCpps) */
/*     { */
/*         string fullPath = cimguiDir ~ "/imgui/" ~ file; */
/*         string objFile = "build/debug/" ~ file.replace(".cpp", ".obj"); */
/*         objs ~= objFile; */
/**/
/*         if (!exists(objFile)) */
/*         { */
/*             writeln(">> Compiling ImGui: ", file); */
/*             auto res = executeShell("clang++ -m64 -std=c++17 -Ivendors/cimgui/imgui -c " ~ fullPath ~ " -o " ~ objFile); */
/*             if (res.status != 0) */
/*             { */
/*                 writeln("‼ Failed to compile ", file); */
/*                 write(res.output); */
/*             } */
/*         } */
/*     } */
/*     return objs; */
/* } */

void main(string[] args)
{
    string mode = (args.length > 1) ? args[1].toLower() : "debug";
    if (mode != "debug" && mode != "release")
    {
        writeln("Usage: ", args[0], " [debug|release]");
        return;
    }

    auto outputDir = buildPath("build", mode);
    auto outputBin = buildPath(outputDir, exeName);

    if (!outputDir.exists)
    {
        writeln(">> Creating directory `", outputDir, "` …");
        mkdirRecurse(outputDir);
    }

    // Collect D sources
    string[] sources;
    foreach (dir; [sourceDir, bindbcSdlDir, bindbcCommonDir, bindbcLoaderDir, bindbcOpenGLDir])
    {
        foreach (entry; dirEntries(dir, "*.d", SpanMode.depth))
            sources ~= entry.name;
    }

    if (sources.empty)
    {
        writeln("‼ No `.d` files found.");
        return;
    }

    string[] compileCmd = [
        "dmd",
        "-m64",
        "-version=SDL_3_2_4",
        "-version=GL_46",
        "-version=FT_2_13",
        "-version=Debug",
        "-version=SDL_TTF_3_2",
        mode == "debug" ? "-g" : "-release",
        "-I" ~ sourceDir,
        "-I" ~ bindbcSdlDir,
        "-I" ~ bindbcCommonDir,
        "-I" ~ bindbcLoaderDir,
        "-I" ~ bindbcOpenGLDir,
        "-I" ~ bindbcFreeTypeDir,
        "-L/LIBPATH:vendors/sdl3/lib",
        "-LSDL3.lib",
        "-L/LIBPATH:vendors/bindbc-freetype/freetype",
        "-Lfreetype.lib"
    ];

    if (mode == "release")
        compileCmd ~= ["-O", "-inline"];

    compileCmd ~= ["-of" ~ outputBin];
    compileCmd ~= sources;

    writeln(">> Compiling in ", mode.toUpper(), " mode → `", outputBin, "` …");
    auto compRes = execute(compileCmd);

    if (compRes.status != 0)
    {
        writeln("‼ Compilation failed (exit code ", compRes.status, "):");
        write(compRes.output);
        return;
    }

    writeln("✔ Compilation succeeded.");

    if (exists(sdlSourceDll))
    {
        auto destDll = buildPath(outputDir, "SDL3.dll");
        writeln(">> Copying SDL3.dll → `", destDll, "` …");
        try
        {
            copy(sdlSourceDll, destDll);
            writeln("✔ SDL3.dll copied.");
        }
        catch (Exception e)
        {
            writeln("‼ Failed to copy SDL3.dll: ", e.msg);
        }
    }
    else
    {
        writeln("‼ SDL3.dll not found at `", sdlSourceDll, "`.");
    }

    writeln(">> Running `", outputBin, "` …");
    try
    {
        auto runRes = execute([outputBin]);
        writeln("--- Program output (stdout+stderr) ---");
        write(runRes.output); 
        stdout.flush();
        writeln("--- End program output ---");
        if (runRes.status != 0)
            writeln("‼ Program exited with code ", runRes.status);
    }
    catch (ProcessException e)
    {
        writeln("‼ Failed to run `", outputBin, "`: ", e.msg);
    }
}
