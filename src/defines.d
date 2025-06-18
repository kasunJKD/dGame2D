module defines;

//keep everything in one define file might change later
/**
    --------------------
    Math related stuff
    -------------------
*/

struct vec2 {
    float x;
    float y;
};

struct vec3 {
    float x;
    float y;
    float z;
};

struct ivec2 {
    int x;
    int y;
};

struct ivec3 {
    int x;
    int y;
    int z;
};

struct mat4 {
    float[16] data; // column-major: index = col * 4 + row

    static mat4 identity() {
        mat4 m;
        foreach (i; 0 .. 4)
            m.data[i * 5] = 1.0f; // 0,5,10,15
        return m;
    }

    float opIndex(size_t col, size_t row) const {
        return data[col * 4 + row];
    }

    ref float opIndex(size_t col, size_t row) {
        return data[col * 4 + row];
    }

    const(float)* ptr() const {
        return &data[0];
    }

    static mat4 ortho(float left, float right, float bottom, float top, float nearZ, float farZ) {
        mat4 m = mat4.identity();
        m[0, 0] = 2.0f / (right - left);
        m[1, 1] = 2.0f / (top - bottom);
        m[2, 2] = -2.0f / (farZ - nearZ);
        m[3, 0] = - (right + left) / (right - left);
        m[3, 1] = - (top + bottom) / (top - bottom);
        m[3, 2] = - (farZ + nearZ) / (farZ - nearZ);
        return m;
    }
}


/**
    --------------------
    Entity related stuff
    -------------------
*/

//base
struct Entity {
    size_t id;
    vec3 position;
};

struct Animated
{
    Entity* _entPtr;
    size_t  _version;

    // A helper property that returns a `ref Entity`, not a copy:
    @property ref Entity getEntity() @trusted
    {
        return *(_entPtr);
    }

    // Make Animated forward‐member lookups into the referenced Entity:
    alias getEntity this;
}
