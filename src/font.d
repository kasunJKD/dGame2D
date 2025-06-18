module font;

import bindbc.opengl;
import bindbc.freetype;
import defines;
import std.exception;
import shader;
import std.conv;
import std.string;

//ability to add or define fonts and load -> fontManager.init()
//use it straight ui_draw_text("asd", pos, rotation)
//use manual memory or gc
//keep track of fonts -> font manager
struct Character {
    GLuint texture;
    ivec2 size;
    ivec2 bearing;
    uint advance;
};

struct Font {
    string name;
    FT_Face face;
    int pixelSize;
    Character[128] atlas;
    bool ready;
};

private struct GLTextPipeline {
    Shader shader;
    GLuint vao;
    GLuint vbo;

    GLint uniformTex;
    GLint uniformColor;
    GLint uniformMVP;
};

struct FontManager {
    private:
        FT_Library ft;
        Font[string] fonts;
        GLTextPipeline pipe;
        enum vsSrc = q{
                #version 460 core
                layout(location = 0) in vec2 inPos;
                layout(location = 1) in vec2 inUV;
                layout(location = 0) out vec2 fragUV;
                uniform mat4 uMVP;
                void main() {
                    fragUV = inUV;
                    //gl_Position = uMVP * vec4(inPos, 0.0, 1.0);
                    gl_Position = vec4(inPos * 0.005 - 1.0, 0.0, 1.0);
                }
            };
        enum fsSrc = q{
            #version 460 core
            layout(location = 0) in vec2 fragUV;
            layout(location = 0) out vec4 outColor;
            uniform sampler2D uTex;
            uniform vec3 uColor;
            void main() {
                float alpha = texture(uTex, fragUV).r;
                outColor = vec4(uColor, alpha);
            }
        };
    public:
        void init() {
            enforce(FT_Init_FreeType(&ft) == 0, "Failed to init FreeType");
            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

            compileShaders();
            setupBuffers();
        }
        
        void shutdown() {
            foreach(ref f; fonts.byValue) {
                unloadFont(f.name);
            }
            if(ft !is null) FT_Done_FreeType(ft);
        }
        void compileShaders() {
            pipe.shader.createShaderProgram(vsSrc, fsSrc);
            glUseProgram(pipe.shader.p_id);
            pipe.uniformTex   = glGetUniformLocation(pipe.shader.p_id, "uTex".ptr);
            pipe.uniformColor = glGetUniformLocation(pipe.shader.p_id, "uColor".ptr);
            pipe.uniformMVP   = glGetUniformLocation(pipe.shader.p_id, "uMVP".ptr);
        }

        void setupBuffers() {
            glGenVertexArrays(1, &pipe.vao);
            glGenBuffers(1, &pipe.vbo);
            glBindVertexArray(pipe.vao);
            glBindBuffer(GL_ARRAY_BUFFER, pipe.vbo);
            glEnableVertexAttribArray(0);
            glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * GLfloat.sizeof, cast(void*) 0);
            glEnableVertexAttribArray(1);
            glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * GLfloat.sizeof, cast(void*) (2 * GLfloat.sizeof));
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            glBindVertexArray(0);
        }
        string loadFont(string alias_, string path, int pixelHeight) {
            enforce(alias_.length, "Alias cannot be empty");
            enforce(!(alias_ in fonts), "Font " ~ alias_ ~ " already loaded");

            FT_Face face;
            auto err = FT_New_Face(ft, toStringz(path), 0, &face);
            enforce(err == FT_Err_Ok, () => format!"Failed to load font '%s' (FT error %s)"(path, err));

            auto errSize = FT_Set_Pixel_Sizes(face, 0, cast(uint) pixelHeight);
            enforce(errSize == FT_Err_Ok,
                () => format!"FT_Set_Pixel_Sizes failed (%s) for '%s'"(errSize, path));

            Font f;
            f.name      = alias_;
            f.face      = face;
            f.pixelSize = pixelHeight;
            f.ready     = true;

            // Ensure 1‑byte packing for GL_RED upload
            glPixelStorei(GLenum(0x0CF5), 1); // GL_UNPACK_ALIGNMENT

            foreach(i; 0 .. 128) {
                FT_Load_Char(face, to!uint(i), FT_LOAD_RENDER | FT_LOAD_FORCE_AUTOHINT);
                auto slot = face.glyph;
                GLuint tex;
                glGenTextures(1, &tex);
                glBindTexture(GL_TEXTURE_2D, tex);
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RED,
                             slot.bitmap.width, slot.bitmap.rows, 0,
                             GL_RED, GL_UNSIGNED_BYTE, slot.bitmap.buffer);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
                Character ch;
                ch.texture  = tex;
                ch.size.x   = slot.bitmap.width;
                ch.size.y   = slot.bitmap.rows;
                ch.bearing.x = slot.bitmap_left;   // <- corrected field
                ch.bearing.y = slot.bitmap_top;    // <- corrected field
                ch.advance   = cast(uint) slot.advance.x;
                f.atlas[i] = ch;
            }
            fonts[alias_] = f;
            return alias_;
        }
        
        void unloadFont(string alias_) {
            if(alias_ !in fonts) return;
            auto f = fonts[alias_];
            foreach(ref g; f.atlas) if(g.texture) glDeleteTextures(1, &g.texture);
            if(f.face !is null) FT_Done_Face(f.face);
            fonts.remove(alias_);
        }
        
        
        void drawText(string alias_, const(char)[] text, vec2 pos, float rotation,
                      vec3 colour = vec3(1,1,1), mat4 mvp = mat4.identity) {
            auto pf = alias_ in fonts;
            if(pf is null || !(*pf).ready) return;
            auto ref font = *pf;

            glUseProgram(pipe.shader.p_id);
            glUniform3f(pipe.uniformColor, colour.x, colour.y, colour.z);
            glUniform1i(pipe.uniformTex, 0);
            
            glUniformMatrix4fv(pipe.uniformMVP, 1, GL_TRUE, mvp.ptr);
        
            glActiveTexture(GL_TEXTURE0);
            glBindVertexArray(pipe.vao);

            float x = pos.x;
            foreach(dchar c; text) {
                if(c >= 128) continue;
                auto g = font.atlas[c];

                float xpos = x + g.bearing.x;
                float ypos = pos.y - (g.size.y - g.bearing.y);
                float w = g.size.x;
                float h = g.size.y;

                GLfloat[24] verts = [
                    xpos,     ypos + h, 0, 0,
                    xpos,     ypos,     0, 1,
                    xpos + w, ypos,     1, 1,
                    xpos,     ypos + h, 0, 0,
                    xpos + w, ypos,     1, 1,
                    xpos + w, ypos + h, 1, 0,
                ];

                glBindTexture(GL_TEXTURE_2D, g.texture);
                glBindBuffer(GL_ARRAY_BUFFER, pipe.vbo);
                glBufferData(GL_ARRAY_BUFFER, verts.sizeof, verts.ptr, GL_DYNAMIC_DRAW);

                // Ensure both attribs (pos + UV) are live
                glEnableVertexAttribArray(0);
                glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * GLfloat.sizeof, cast(void*)0);
                glEnableVertexAttribArray(1);
                glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * GLfloat.sizeof, cast(void*)(2 * GLfloat.sizeof));

                glDrawArrays(GL_TRIANGLES, 0, 6);
                x += (g.advance >> 6);
            }

            glBindVertexArray(0);
            glBindTexture(GL_TEXTURE_2D, 0);
        }
};

FontManager fontManager;

void ui_draw_text(string text, vec2 pos, float rotation = 0.0f,
                  vec3 colour = vec3(1.0,1.0,1.0), string font = "default") {
    // Build orthographic MVP on every call for simplicity.  Cache in real code.
    mat4 orthoMVP = mat4.ortho(0, /*screenW*/ 800, /*screenH*/ 600, 0, -1, 1);
    fontManager.drawText(font, text, pos, rotation, colour, orthoMVP);
}
