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
