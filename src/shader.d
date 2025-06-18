module shader;

import bindbc.opengl;
import std.string;
import std.stdio : writeln;

struct Shader {
    GLuint p_id;

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

        p_id = glCreateProgram();
        glAttachShader(p_id, vert);
        glAttachShader(p_id, frag);
        glLinkProgram(p_id);

        // Check link status
        GLint linked = GL_FALSE;
        glGetProgramiv(p_id, GL_LINK_STATUS, &linked);
        if (linked == GL_FALSE) {
            char[1024] buffer;
            GLsizei length;
            glGetProgramInfoLog(p_id, buffer.length, &length, buffer.ptr);
            writeln("SHADER LINK ERROR:\n", buffer[0 .. length].fromStringz);
            assert(0, "Shader link failed");
        }

        // Clean up shaders after linking
        glDetachShader(p_id, vert);
        glDetachShader(p_id, frag);
        glDeleteShader(vert);
        glDeleteShader(frag);

        return p_id;
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
};
