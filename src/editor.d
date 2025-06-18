module editor;

import bindbc.sdl;
import bindbc.opengl;
import defines;
import std.stdio : writeln;
import std.string;
import std.conv : to;

//TODO => move to opengl specifics
GLuint createShaderProgram(string vertSource, string fragSource)
{
    GLuint vert = glCreateShader(GL_VERTEX_SHADER);
    GLuint frag = glCreateShader(GL_FRAGMENT_SHADER);

    const(GLchar)* vertSrcPtr = toStringz(vertSource);
    const(GLchar)* fragSrcPtr = toStringz(fragSource);

    glShaderSource(vert, 1, &vertSrcPtr, null);
    glCompileShader(vert);
    checkCompileStatus(vert, "VERTEX");

    glShaderSource(frag, 1, &fragSrcPtr, null);
    glCompileShader(frag);
    checkCompileStatus(frag, "FRAGMENT");

    GLuint program = glCreateProgram();
    glAttachShader(program, vert);
    glAttachShader(program, frag);
    glLinkProgram(program);

    // Check link status
    GLint linked = GL_FALSE;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (linked == GL_FALSE) {
        char[1024] buffer;
        GLsizei length;
        glGetProgramInfoLog(program, buffer.length, &length, buffer.ptr);
        writeln("SHADER LINK ERROR:\n", buffer[0 .. length].fromStringz);
        assert(0, "Shader link failed");
    }

    // Clean up shaders after linking
    glDetachShader(program, vert);
    glDetachShader(program, frag);
    glDeleteShader(vert);
    glDeleteShader(frag);

    return program;
}

private void checkCompileStatus(GLuint shader, string stage)
{
    GLint compiled = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (compiled == GL_FALSE) {
        char[1024] buffer;
        GLsizei length;
        glGetShaderInfoLog(shader, buffer.length, &length, buffer.ptr);
        writeln(stage, " SHADER COMPILE ERROR:\n", buffer[0 .. length].fromStringz);
        assert(0, stage ~ " shader failed to compile");
    }
}

struct Mgui {
    alias Id = size_t;

    bool active;
    bool hot;
    Id owner;

    vec2 mouse_position;

    GLuint shader;
    GLuint uiVAO;
    GLuint uiVBO;
    GLint uProjLoc, uColorLoc;


    void guiInitRenderer(int winW, int winH) {
        enum string vertSrc = q{
            #version 330 core
            layout(location = 0) in vec2 aPos;
            uniform mat4 uProjection;
            void main() {
                gl_Position = uProjection * vec4(aPos, 0.0, 1.0);
            }
        };

        enum string fragSrc = q{
            #version 330 core
            out vec4 FragColor;
            uniform vec3 uColor;
            void main() {
                FragColor = vec4(uColor, 1.0);
            }
        };

        shader = createShaderProgram(vertSrc, fragSrc);
        uProjLoc = glGetUniformLocation(shader, "uProjection");
        uColorLoc = glGetUniformLocation(shader, "uColor");

        float l = 0, r = cast(float)winW;
        float t = 0, b = cast(float)winH;
        float[16] ortho = [
            2/(r-l), 0,       0, 0,
            0,      2/(t-b),  0, 0,
            0,      0,       -1, 0,
           -(r+l)/(r-l), -(t+b)/(t-b), 0, 1
        ];
        glUseProgram(shader);
        glUniformMatrix4fv(uProjLoc, 1, GL_FALSE, ortho.ptr);

        // single dynamic VBO (8 floats = 4 verts)
        glGenVertexArrays(1, &uiVAO);
        glGenBuffers(1, &uiVBO);
        glBindVertexArray(uiVAO);
        glBindBuffer(GL_ARRAY_BUFFER, uiVBO);
        glBufferData(GL_ARRAY_BUFFER, 8 * float.sizeof, null, GL_STREAM_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE,
                              2 * float.sizeof, cast(void*)0);
        glBindVertexArray(0);
    }
    
    void begin() {
        hot = false;
        active = false;
        
        float mx, my;
        SDL_GetMouseState(&mx, &my);
        mouse_position = vec2(cast(float)mx, cast(float)my);
        
        int winW, winH;
        SDL_GetWindowSize(SDL_GL_GetCurrentWindow(), &winW, &winH);
glViewport(0, 0, winW, winH);

        float l = 0, r = cast(float)winW;
        float t = 0, b = cast(float)winH;

        float[16] ortho = [
            2/(r-l), 0,       0, 0,
            0,      2/(t-b),  0, 0,
            0,      0,       -1, 0,
            -(r+l)/(r-l), -(t+b)/(t-b), 0, 1
        ];
        
        glUseProgram(shader);
        glUniformMatrix4fv(uProjLoc, 1, GL_FALSE, ortho.ptr);
        glBindVertexArray(uiVAO);
    }

    void end() {
        if ((SDL_GetMouseState(null, null) & SDL_BUTTON_MASK(SDL_BUTTON_LEFT)) == 0) {
            owner = Id.init; 
        }
    }

    bool gui_button(Id id, float x, float y, int w, int h) {
        bool inside = mouse_position.x >= x && mouse_position.x <= x + w &&
                      mouse_position.y >= y && mouse_position.y <= y + h;

        bool leftDown = (SDL_GetMouseState(null, null) & SDL_BUTTON_MASK(SDL_BUTTON_LEFT)) != 0;

        if (inside) {
            hot = true;
        }

        if (inside && leftDown && owner == Id.init) {
            owner = id;
        }

        bool clicked = false;
        if (owner == id && !leftDown) {
            clicked = inside;
            owner = Id.init;
        }

        draw_rect(x, y, w, h, inside || owner == id);

        return clicked;
    }

    void draw_rect(float x, float y, float w, float h, bool highlight)
    {
        vec3 col = highlight ? vec3(0.8f,0.3f,0.3f) : vec3(0.4f,0.4f,0.5f);
        glUniform3f(uColorLoc, col.x, col.y, col.z);

        float[8] verts = [
            x,     y,         // top-left
            x + w, y,         // top-right
            x + w, y + h,     // bottom-right
            x,     y + h      // bottom-left
        ];

        glBufferSubData(GL_ARRAY_BUFFER, 0, verts.sizeof, verts.ptr);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    }

};



