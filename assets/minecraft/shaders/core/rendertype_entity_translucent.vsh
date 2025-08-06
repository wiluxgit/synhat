#version 330

#ifdef GL_ES // ThreeJS
#define in in highp
#define out out highp
#else // Minecraft

#moj_import <fog.glsl>
#moj_import <light.glsl>

#endif

//=================================================================================
// Macros
//=================================================================================

// how long to stretch along normal to simulate 90 deg face
#define AS_FLIP (128.0)


// How much bigger the second layer is
#define OVERLAYSCALE (1.125)

// How big a pixel is in relation to a Normal (in wordspace?)
#ifdef GL_ES
#define PIXELFACTOR 0.5 / 16.0
#else // Minecraft
#define PIXELFACTOR (0.942/16.0)
#endif

// FACE_OPERATION_ENTRY
#define TRANFORM_TYPE_DISPLACEMENT 0
#define TRANFORM_TYPE_UV_CROP 1
#define TRANFORM_TYPE_UV_OFFSET 2
#define TRANFORM_TYPE_SPECIAL 3

// TRANFORM_TYPE_DISPLACEMENT
#define MASK_TTD_globalDisplacement (63) // 0b00111111
#define FLAG_TTD_snap (64)  // 0b01000000
#define FLAG_TTD_sign (128) // 0b10000000
#define MASK_TTD_asymDisplacement (63) // 0b00111111
#define MASK_TTD_asymSpecialMode (63) // 0b00111111
#define FLAG_TTD_asymSpec (64)  // 0b01000000
#define FLAG_TTD_asymSign (128) // 0b10000000
#define MASK_TTD_asymEdge (3) // 0b00000011
#define ASYM_EDGE_top (0)
#define ASYM_EDGE_bot (1)
#define ASYM_EDGE_left (2)
#define ASYM_EDGE_right (3)
#define ASYM_SPECIAL_MODE_flipOuter (0)
#define ASYM_SPECIAL_MODE_flipInner (1)

// TRANSFROM_TYPE_UV_CROP
#define FLAG_TUC_SNAP_X (1<<0)
#define FLAG_TUC_SNAP_Y (1<<1)
#define FLAG_TUC_MIRROR_X (1<<2)
#define FLAG_TUC_MIRROR_Y (1<<3)

// Util
#define FLAG_DIR_RIGHT (1)
#define FLAG_DIR_BOT (2)
#define MASK_DIR (3)
#define DIR_TOPLEFT (0)
#define DIR_TOPRIGHT (1)
#define DIR_BOTLEFT (2)
#define DIR_BOTRIGHT (3)

//=================================================================================
// Helper Functios
//=================================================================================
// Data Reading
int getVertId();
int getFaceId(int vertId);
int getCornerId(int vertId);
int getDirId(int vertId);
int lookupTransformIndex(int faceId);
ivec3 lookupTransformBytes(int transformIndex);

// Hard coded face properties
int getPerpendicularLength(int faceId, bool isAlex);
bool isSecondaryLayer(int vertId);
void initVanillaUV(int faceId, bool isAlex);
void initVanillaUV2(int faceId, bool isAlex);
vec2 vanillaMinUV;
vec2 vanillaMaxUV;
vec2 vanillaCenterUV;

// bit data helpers
int extractCombineBits6and7(int r, int g, int b);

//DEBUG
vec4 colorFromInt(int i);

void applyDisplacement(bool isAlex, int vertId, int dataR, int dataG, int dataB);
void applyUVCrop      (bool isAlex, int vertId, int dataR, int dataG, int dataB);
void applyUVOffset    (bool isAlex, int vertId, int dataR, int dataG, int dataB);
void applyPostFlags   (bool isAlex, int vertId, int dataR, int dataG, int dataB);

vec3 pixelNormal();
float pixelNormalLength();

//=================================================================================
// INPUTS
//=================================================================================
#ifdef GL_ES // ThreeJS
mat4 ModelViewMat;
mat4 ProjMat;
vec3 Position;
vec3 Normal;
vec2 UV0;
uniform sampler2D Sampler0;
#else // Minecraft
in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV1;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler0;
uniform sampler2D Sampler1;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform mat3 IViewRotMat;
uniform int FogShape;

uniform vec3 Light0_Direction;
uniform vec3 Light1_Direction;
#endif

//=================================================================================
// OUTPUTS
//=================================================================================

// Vanilla
out float vertexDistance;
out vec4 vertexColor;
out vec4 lightMapColor;
out vec4 overlayColor;
out vec2 texCoord0;

// extmodel custom outputs
out vec4 wx_vertexColor;
out float wx_isEdited;
out vec2 wx_clipMin;
out vec2 wx_clipMax;

#ifdef GL_ES // ThreeJS
#else // Minecraft
out vec3 wx_passLight0_Direction;
out vec3 wx_passLight1_Direction;
out vec3 wx_passModelViewPos;
out vec4 wx_passVertexColor;
out vec3 wx_invMatrix0;
out vec3 wx_invMatrix1;
out vec3 wx_invMatrix2;
out vec4 normal;
#endif

//=================================================================================
// GLOBAL TEMP DATA
//=================================================================================
vec3 NewPosition;
vec2 NewFaceCenter;
vec2 NewUV;
vec2 ClipScroll;
vec2 ClipScale;
float CropEdgeTop;
float CropEdgeBot;
float CropEdgeLeft;
float CropEdgeRight;
bool SnapX;
bool SnapY;
bool MirrorX;
bool MirrorY;

void main() {

#ifdef GL_ES
    // ThreeJS fix to convert all names to the same as minecraft
    ModelViewMat = viewMatrix;
    ProjMat = projectionMatrix;
    Position = position;
    Normal = normal;
    UV0 = vec2(uv.x, 1.0-uv.y); // ThreeJS reverses the UV coordinates AND the texture by default
#endif
    int vertId = getVertId();

    //<DEBUG>
    //float vertIdx = float(vertId)/400.0;
    //float vertIdy = float((vertId/4)%6)/6.0;
    //wx_vertexColor = vec4(vertIdx, vertIdy, 0, 1);
    wx_vertexColor = colorFromInt(vertId);
    //wx_vertexColor = vec4(Normal, 1.0);
    //</DEBUG>

    wx_isEdited = 0.0;
    NewUV = UV0;
    NewPosition = Position;
    ClipScroll = vec2(0.0, 0.0);
    ClipScale = vec2(1.0, 1.0);
    SnapX = false;
    SnapY = false;
    MirrorX = false;
    MirrorY = false;
    CropEdgeTop = 0.0;
    CropEdgeBot = 0.0;
    CropEdgeLeft = 0.0;
    CropEdgeRight = 0.0;

    if (true) { //(gl_VertexID >= 18*8){ //is second layer

        // Get header pixel
        vec4 topRightPixel = texelFetch(Sampler0, ivec2(0, 0), 0)*256.0;
        int headerR = int(topRightPixel.r + 0.1);
        int headerG = int(topRightPixel.g + 0.1);
        int headerB = int(topRightPixel.b + 0.1);

        if (headerR == 0xda && headerG == 0x67) {
            bool isAlex = (headerB == 1);

            int faceId = getFaceId(vertId);
            int cornerId = getCornerId(vertId);
            initVanillaUV(faceId, isAlex);
            NewFaceCenter = vanillaCenterUV;

            int nextTfIndex = lookupTransformIndex(faceId);

            int emergencyStop = 0;
            while (nextTfIndex != 255) {
                // TODO document this
                if(++emergencyStop >= 10) {
                    break; // This is needed in order to prevent the render from crashing
                }

                wx_isEdited = 1.0;

                // HEADER
                ivec3 tfHeader = lookupTransformBytes(nextTfIndex);
                int T_next = tfHeader.x;
                int T_size = tfHeader.y;
                int T_type = tfHeader.z;

                // DATA
                ivec3 tfData = lookupTransformBytes(nextTfIndex+1);
                switch (T_type) {
                    case TRANFORM_TYPE_DISPLACEMENT:
                        applyDisplacement(isAlex, vertId, tfData.x, tfData.y, tfData.z);
                        break;
                    case TRANFORM_TYPE_UV_CROP:
                        applyUVCrop(isAlex, vertId, tfData.x, tfData.y, tfData.z);
                        break;
                    case TRANFORM_TYPE_UV_OFFSET:
                        applyUVOffset(isAlex, vertId, tfData.x, tfData.y, tfData.z);
                        break;
                    case TRANFORM_TYPE_SPECIAL:
                        applyPostFlags(isAlex, vertId, tfData.x, tfData.y, tfData.z);
                        break;
                    default:
                        break;
                }

                // Iterate to next in linked list
                nextTfIndex = T_next;
            }

            // UV crop shenanigans postproccessing
            if (wx_isEdited == 1.0) {
                vec2 center2cornerVec = NewUV - NewFaceCenter;
                vec2 opposing = NewFaceCenter - center2cornerVec;

                int direction = 0;
                if (center2cornerVec.x >= 0.0) direction |= FLAG_DIR_RIGHT;
                if (center2cornerVec.y >= 0.0) direction |= FLAG_DIR_BOT;

                switch (direction) {
                    case DIR_TOPLEFT:
                        wx_clipMin = vec2(NewUV.x, NewUV.y);
                        wx_clipMax = vec2(opposing.x, opposing.y);
                        break;
                    case DIR_TOPRIGHT:
                        wx_clipMin = vec2(opposing.x, NewUV.y);
                        wx_clipMax = vec2(NewUV.x, opposing.y);
                        break;
                    case DIR_BOTLEFT:
                        wx_clipMin = vec2(NewUV.x, opposing.y);
                        wx_clipMax = vec2(opposing.x, NewUV.y);
                        break;
                    case DIR_BOTRIGHT:
                        wx_clipMin = vec2(opposing.x, opposing.y);
                        wx_clipMax = vec2(NewUV.x, NewUV.y);
                        break;
                }

                wx_clipMin += vec2(CropEdgeLeft, CropEdgeTop) / 64.0;
                wx_clipMax -= vec2(CropEdgeRight, CropEdgeBot) / 64.0;

                if (SnapX) {
                    ClipScale.x *= OVERLAYSCALE;
                }
                if (SnapY) {
                    ClipScale.y *= OVERLAYSCALE;
                }

                NewUV = NewFaceCenter + (center2cornerVec * ClipScale) + ClipScroll;
            }
        }
    }

#ifdef GL_ES // ThreeJS
#else // Minecraft
    // Directional Lighting Hack
    mat3 invMatrix = inverse(mat3(ProjMat)) * inverse(mat3(ModelViewMat));
    wx_passLight0_Direction = Light0_Direction;
    wx_passLight1_Direction = Light1_Direction;
    wx_passModelViewPos = (ModelViewMat * vec4(NewPosition, 1.0)).xyz;
    wx_passVertexColor = Color;
    wx_invMatrix0 = invMatrix[0];
    wx_invMatrix1 = invMatrix[1];
    wx_invMatrix2 = invMatrix[2];

    // Vanilla entity.vsh
    vertexDistance = fog_distance(Position, FogShape); // TODO, Use NewPosition instead?
    vertexColor = minecraft_mix_light(Light0_Direction, Light1_Direction, Normal, Color);
    lightMapColor = texelFetch(Sampler2, UV2 / 16, 0);
    overlayColor = texelFetch(Sampler1, UV1, 0);
    texCoord0 = UV0;
    normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);
#endif
    texCoord0 = NewUV;
    gl_Position = ProjMat * ModelViewMat * vec4(NewPosition, 1.0);
    return;
}

void applyDisplacement(bool isAlex, int vertId, int dataR, int dataG, int dataB) {
    bool isNegativeOffset 		= (dataR & FLAG_TTD_sign) != 0;
    bool isSnap				    = (dataR & FLAG_TTD_snap) != 0;
    bool isAsymNegativeOffset   = (dataG & FLAG_TTD_asymSign) != 0;
    bool isAsymSpecial          = (dataG & FLAG_TTD_asymSpec) != 0;

    float offset				= float(dataR & MASK_TTD_globalDisplacement);
    int asymEdge 		        = dataB & MASK_TTD_asymEdge;

    int faceId                  = getFaceId(vertId);
    int cornerId                = getCornerId(vertId);
    int dirId                   = getDirId(vertId);
    bool isSecondary            = isSecondaryLayer(vertId);
    float perpLenPixels         = float(getPerpendicularLength(faceId, isAlex));
    int asymSpecialMode         = dataG & MASK_TTD_asymSpecialMode;

    float directionMod = 1.0;
    if (isNegativeOffset) {
        directionMod = -1.0;
    }
    float asymmetricDirectionMod = 1.0;
    if (isAsymNegativeOffset) {
        asymmetricDirectionMod = -1.0;
    }
    float pixelSize = 1.0;
    if (isSecondary != isSnap) { // isSecondary XOR snapToOpposing
        pixelSize = OVERLAYSCALE;
    }

    float distanceToOtherLayer = (OVERLAYSCALE - 1.0) * perpLenPixels / 2.0;
    if (isSnap) {
        float snapDirection = 1.0;
        if (isSecondary) {
            snapDirection = -1.0;
        }
        float layerExtention = snapDirection * distanceToOtherLayer;
        NewPosition += pixelNormal() * layerExtention;
    }
    NewPosition += pixelNormal() * offset * (0.5 * pixelSize) * directionMod;

    const int[8] corners1 = int[8](0, 2, 0, 1, 2, 0, 3, 2);
    const int[8] corners2 = int[8](1, 3, 3, 2, 3, 1, 1, 0);
    // If bottom face the corner indexes needs twisting
    int cornIndex = asymEdge | (dirId == 5 ? 4 : 0);
    int corner1 = corners1[cornIndex];
    int corner2 = corners2[cornIndex];

    // check that at least one of the edge corners is the active vertex
    // otherwise it should not be moved
    float asymDelta;
    if (cornerId == corner1 || cornerId == corner2) {
        if (!isAsymSpecial) {
            float asymDisplacement = float(dataG & MASK_TTD_asymDisplacement);
            asymDelta = (0.5 * pixelSize) * asymDisplacement * asymmetricDirectionMod;

        } else {
            switch(asymSpecialMode) {
                case ASYM_SPECIAL_MODE_flipOuter:
                    asymDelta = 1.0 * pixelSize * AS_FLIP;
                    break;
                case ASYM_SPECIAL_MODE_flipInner:
                    float backheight = 19.125 * perpLenPixels;
                    asymDelta = -1.0 * backheight;
                    break;
            }
        }
    }
    NewPosition += pixelNormal() * asymDelta;

    // Automatic Clipping
    if (isAsymSpecial) {
        float asymDeltaAbs = abs(asymDelta);
        float scale = 1.0;
        float scroll = 0.0;

        bool isXaxis = asymEdge == ASYM_EDGE_left || asymEdge == ASYM_EDGE_right;
        float scrollMod = (asymEdge == ASYM_EDGE_bot || asymEdge == ASYM_EDGE_left) ? 1.0 : -1.0;

        // If bottom face flip axis
        if (dirId == 3) {
            scrollMod *= -1.0;
        }

        switch(asymSpecialMode) {
            case ASYM_SPECIAL_MODE_flipOuter:
                scale = asymDeltaAbs * pixelNormalLength() * (0.5 / PIXELFACTOR);
                scroll = 0.5 * scrollMod * perpLenPixels / 64.0;
                break;
            case ASYM_SPECIAL_MODE_flipInner:
                float correctSnap = (perpLenPixels + 2.0 * distanceToOtherLayer) / (perpLenPixels + distanceToOtherLayer);
                scale = correctSnap * asymDeltaAbs * pixelNormalLength() * (0.5 / PIXELFACTOR);
                scroll = 1.5 * scrollMod * perpLenPixels / 64.0;
                break;
            default:
                return; // ERROR
        }
        if (isXaxis) {
            ClipScale.x *= scale;
            ClipScroll.x -= scroll;
        } else {
            ClipScale.y *= scale;
            ClipScroll.y -= scroll;
        }
        //wx_vertexColor = colorFromInt(asymEdge);
    }
}
void applyUVCrop(bool isAlex, int vertId, int dataR, int dataG, int dataB) {
    CropEdgeTop += float(dataR & 15); // 0b00001111
    CropEdgeBot += float(dataR >> 4);
    CropEdgeLeft += float(dataG & 15); // 0b00001111
    CropEdgeRight += float(dataG >> 4);
    SnapX = (dataB & FLAG_TUC_SNAP_X) != 0;
    SnapY = (dataB & FLAG_TUC_SNAP_Y) != 0;
    MirrorX = (dataB & FLAG_TUC_MIRROR_X) != 0;
    MirrorY = (dataB & FLAG_TUC_MIRROR_Y) != 0;
    return;
}
void applyUVOffset(bool isAlex, int vertId, int dataR, int dataG, int dataB) {
    int xmax = dataR & 63; // 0b00111111
    int xmin = dataG & 63;
    int ymax = dataB & 63;
    int ymin = extractCombineBits6and7(dataR, dataG, dataB);

    int faceId = getFaceId(vertId);
    int cornerId = getCornerId(vertId);

    switch(cornerId) {
        case 0:
            NewUV += vec2(float(xmax), float(ymin)) / 64.0;
            break;
        case 1:
            NewUV += vec2(float(xmin), float(ymin)) / 64.0;
            break;
        case 2:
            NewUV += vec2(float(xmin), float(ymax)) / 64.0;
            break;
        case 3:
            NewUV += vec2(float(xmax), float(ymax)) / 64.0;
            break;
    }

    NewFaceCenter += (vec2(float(xmax+xmin), float(ymax+ymin)) / 64.0) / 2.0;

    // Debug
    //wx_vertexColor = colorFromInt(cornerId);
    return;
}
void applyPostFlags(bool isAlex, int vertId, int dataR, int dataG, int dataB) {
    return;
}
vec3 pixelNormal() {
    return normalize(Normal) * PIXELFACTOR; // Normalization is needed for sodium?
}
float pixelNormalLength() {
    return length(pixelNormal());
}


bool isSecondaryLayer(int vertId) {
    return vertId >= 36*4;
}
int getFaceId(int vertId) {
    return (vertId / 4);
}
int getDirId(int vertId) {
    return (vertId / 4) % 6;
}
int getCornerId(int vertId) {
    return vertId % 4;
}

//---------------------------------------------------------------------------------
// lookupTransformIndex()
//  returns the Transfom Index for a specific faceId
//---------------------------------------------------------------------------------
int lookupTransformIndex(int faceId) {
    int rgbaIndex = faceId % 3;
    int pixelIndex = faceId / 3;
    int x = (pixelIndex + 8) % 8;
    int y = (pixelIndex + 8) / 8;
    vec4 pixelData = texelFetch(Sampler0, ivec2(x, y), 0) * 255.0;

    switch (rgbaIndex) {
        case 0: return int(round(pixelData.r));
        case 1: return int(round(pixelData.g));
        case 2: return int(round(pixelData.b));
        default: return 0; // unreachable but WEB GL complains if not defined
    }
}
//---------------------------------------------------------------------------------
// lookupTransformBytes()
//  returns the RGB value as an ivec3 given a transformIndex
//---------------------------------------------------------------------------------
ivec3 lookupTransformBytes(int transformIndex) {
    int temp = 32 + transformIndex;
    int x = temp % 8;
    int y = temp / 8;
    if (y >= 8) {
        x += 24;
        y -= 8;
    }
    vec4 pixelData = texelFetch(Sampler0, ivec2(x, y), 0) * 255.0;
    return ivec3(
        round(pixelData.r),
        round(pixelData.g),
        round(pixelData.b)
    );
}

// bit data helpers
int extractCombineBits6and7(int r, int g, int b) {
    int mask = 192; // 0b11000000;
    return ((r & mask) >> 2) | ((g & mask) >> 4) | ((b & mask) >> 6);
}

// Debug
vec4 colorFromInt(int i) {
    if (i<0) {
        return vec4(0.2,0.2,0.2,1);
    }

    switch (i%8) {
        case 0: return vec4(1,0,0,1); // RED
        case 1: return vec4(0,1,0,1); // GREEN
        case 2: return vec4(0,0,1,1); // BBLUE
        case 3: return vec4(1,1,0,1); // YELLOW
        case 4: return vec4(0,1,1,1); // CYAN
        case 5: return vec4(1,0,1,1); // MAGENTA
        case 6: return vec4(1,1,1,1); // WHITE
        case 7: return vec4(0,0,0,1); // BLACK
    }
}


//---------------------------------------------------------------------------------
// getPerpendicularLength()
//  retuns the length (in pixels) to the back face for a given face
//---------------------------------------------------------------------------------
int getPerpendicularLength(int faceId, bool isAlex) {
    #define BODY_PART_HEAD    0
    #define BODY_PART_BODY    1
    #define BODY_PART_ARM_R   2
    #define BODY_PART_ARM_L   3
    #define BODY_PART_LEG_R   4
    #define BODY_PART_LEG_L   5
    #define BODY_PART_HAT     6
    #define BODY_PART_PANT_L  7
    #define BODY_PART_PANT_R  8
    #define BODY_PART_SLEVE_L 9
    #define BODY_PART_SLEVE_R 10
    #define BODY_PART_JACKET  11
    #define FACE_AXIS_TOP    0
    #define FACE_AXIS_BOTTOM 1
    #define FACE_AXIS_RIGHT  2
    #define FACE_AXIS_FRONT  3
    #define FACE_AXIS_LEFT   4
    #define FACE_AXIS_BACK   5

    int bodyPart = faceId / 6;
    int faceAxis = faceId % 6;
    switch(bodyPart) {
        case BODY_PART_HEAD:
        case BODY_PART_HAT:
            return 8;
        case BODY_PART_BODY:
        case BODY_PART_JACKET:
            switch(faceAxis) {
                case FACE_AXIS_TOP:
                case FACE_AXIS_BOTTOM:
                    return 12;
                case FACE_AXIS_LEFT:
                case FACE_AXIS_RIGHT:
                    return 8;
                case FACE_AXIS_FRONT:
                case FACE_AXIS_BACK:
                    return 4;
            }
        case BODY_PART_LEG_R:
        case BODY_PART_LEG_L:
        case BODY_PART_PANT_R:
        case BODY_PART_PANT_L:
            switch(faceAxis) {
                case FACE_AXIS_TOP:
                case FACE_AXIS_BOTTOM:
                    return 12;
                case FACE_AXIS_LEFT:
                case FACE_AXIS_RIGHT:
                case FACE_AXIS_FRONT:
                case FACE_AXIS_BACK:
                    return 4;
            }
        case BODY_PART_ARM_R:
        case BODY_PART_ARM_L:
        case BODY_PART_SLEVE_R:
        case BODY_PART_SLEVE_L:
            switch(faceAxis) {
                case FACE_AXIS_TOP:
                case FACE_AXIS_BOTTOM:
                    return 12;
                case FACE_AXIS_LEFT:
                case FACE_AXIS_RIGHT:
                    return isAlex ? 3 : 4;
                case FACE_AXIS_FRONT:
                case FACE_AXIS_BACK:
                    return 4;
            }
    }
}

//---------------------------------------------------------------------------------
// getVertId()
//  Returns the The vertex id is unique number for each vertex, all players have identical order
//  The THREE_vertexID must be implemented to be the same order as minecraft
//---------------------------------------------------------------------------------
#ifdef GL_ES // ThreeJS
attribute int THREE_vertexID;
int getVertId() {
    return THREE_vertexID;
}
#else // Minecraft
int getVertId() {
    return gl_VertexID;
}
#endif

//---------------------------------------------------------------------------------
// initVanillaUV()
//  initializes the follow globals
//    vanillaCenterUV
//    vanillaMinUV
//    vanillaMaxUV
//---------------------------------------------------------------------------------
void initVanillaUV(int faceId, bool isAlex){
    initVanillaUV2(faceId, isAlex);
    vanillaCenterUV = (vanillaMinUV + vanillaMaxUV) / 2.0;
}
// Can be optimized
void initVanillaUV2(int faceId, bool isAlex){
    #define FACEID_HEAD_TOP       0
    #define FACEID_HEAD_BOTTOM    1
    #define FACEID_HEAD_RIGHT     2
    #define FACEID_HEAD_FRONT     3
    #define FACEID_HEAD_LEFT      4
    #define FACEID_HEAD_BACK      5
    #define FACEID_BODY_TOP       6
    #define FACEID_BODY_BOTTOM    7
    #define FACEID_BODY_RIGHT     8
    #define FACEID_BODY_FRONT     9
    #define FACEID_BODY_LEFT      10
    #define FACEID_BODY_BACK      11
    #define FACEID_ARM_R_TOP      12
    #define FACEID_ARM_R_BOTTOM   13
    #define FACEID_ARM_R_RIGHT    14
    #define FACEID_ARM_R_FRONT    15
    #define FACEID_ARM_R_LEFT     16
    #define FACEID_ARM_R_BACK     17
    #define FACEID_ARM_L_TOP      18
    #define FACEID_ARM_L_BOTTOM   19
    #define FACEID_ARM_L_RIGHT    20
    #define FACEID_ARM_L_FRONT    21
    #define FACEID_ARM_L_LEFT     22
    #define FACEID_ARM_L_BACK     23
    #define FACEID_LEG_R_TOP      24
    #define FACEID_LEG_R_BOTTOM   25
    #define FACEID_LEG_R_RIGHT    26
    #define FACEID_LEG_R_FRONT    27
    #define FACEID_LEG_R_LEFT     28
    #define FACEID_LEG_R_BACK     29
    #define FACEID_LEG_L_TOP      30
    #define FACEID_LEG_L_BOTTOM   31
    #define FACEID_LEG_L_RIGHT    32
    #define FACEID_LEG_L_FRONT    33
    #define FACEID_LEG_L_LEFT     34
    #define FACEID_LEG_L_BACK     35
    #define FACEID_HAT_TOP        36
    #define FACEID_HAT_BOTTOM     37
    #define FACEID_HAT_RIGHT      38
    #define FACEID_HAT_FRONT      39
    #define FACEID_HAT_LEFT       40
    #define FACEID_HAT_BACK       41
    #define FACEID_PANT_L_TOP     42
    #define FACEID_PANT_L_BOTTOM  43
    #define FACEID_PANT_L_RIGHT   44
    #define FACEID_PANT_L_FRONT   45
    #define FACEID_PANT_L_LEFT    46
    #define FACEID_PANT_L_BACK    47
    #define FACEID_PANT_R_TOP     48
    #define FACEID_PANT_R_BOTTOM  49
    #define FACEID_PANT_R_RIGHT   50
    #define FACEID_PANT_R_FRONT   51
    #define FACEID_PANT_R_LEFT    52
    #define FACEID_PANT_R_BACK    53
    #define FACEID_SLEVE_L_TOP    54
    #define FACEID_SLEVE_L_BOTTOM 55
    #define FACEID_SLEVE_L_RIGHT  56
    #define FACEID_SLEVE_L_FRONT  57
    #define FACEID_SLEVE_L_LEFT   58
    #define FACEID_SLEVE_L_BACK   59
    #define FACEID_SLEVE_R_TOP    60
    #define FACEID_SLEVE_R_BOTTOM 61
    #define FACEID_SLEVE_R_RIGHT  62
    #define FACEID_SLEVE_R_FRONT  63
    #define FACEID_SLEVE_R_LEFT   64
    #define FACEID_SLEVE_R_BACK   65
    #define FACEID_JACKET_TOP      66
    #define FACEID_JACKET_BOTTOM   67
    #define FACEID_JACKET_RIGHT    68
    #define FACEID_JACKET_FRONT    69
    #define FACEID_JACKET_LEFT     70
    #define FACEID_JACKET_BACK     71
    switch(faceId) {
    // ======== Head ========
        case FACEID_HEAD_LEFT:
            vanillaMinUV = vec2(48-32, 8)/64.0;
            vanillaMaxUV = vec2(56-32, 16)/64.0;
            return;
        case FACEID_HEAD_RIGHT:
            vanillaMinUV = vec2(32-32, 8)/64.0;
            vanillaMaxUV = vec2(40-32, 16)/64.0;
            return;
        case FACEID_HEAD_TOP:
            vanillaMinUV = vec2(40-32, 0)/64.0;
            vanillaMaxUV = vec2(48-32, 8)/64.0;
            return;
        case FACEID_HEAD_BOTTOM:
            vanillaMinUV = vec2(48-32, 0)/64.0;
            vanillaMaxUV = vec2(56-32, 8)/64.0;
            return;
        case FACEID_HEAD_FRONT:
            vanillaMinUV = vec2(40-32, 8)/64.0;
            vanillaMaxUV = vec2(48-32, 16)/64.0;
            return;
        case FACEID_HEAD_BACK:
            vanillaMinUV = vec2(56-32, 8)/64.0;
            vanillaMaxUV = vec2(64-32, 16)/64.0;
            return;

        // ======== Body ========
        case FACEID_BODY_LEFT:
            vanillaMinUV = vec2(28, 36-16)/64.0;
            vanillaMaxUV = vec2(32, 48-16)/64.0;
            return;
        case FACEID_BODY_RIGHT:
            vanillaMinUV = vec2(16, 36-16)/64.0;
            vanillaMaxUV = vec2(20, 48-16)/64.0;
            return;
        case FACEID_BODY_FRONT:
            vanillaMinUV = vec2(20, 36-16)/64.0;
            vanillaMaxUV = vec2(28, 48-16)/64.0;
            return;
        case FACEID_BODY_BACK:
            vanillaMinUV = vec2(32, 36-16)/64.0;
            vanillaMaxUV = vec2(40, 48-16)/64.0;
            return;
        case FACEID_BODY_TOP:
            vanillaMinUV = vec2(20, 32-16)/64.0;
            vanillaMaxUV = vec2(28, 36-16)/64.0;
            return;
        case FACEID_BODY_BOTTOM:
            vanillaMinUV = vec2(28, 32-16)/64.0;
            vanillaMaxUV = vec2(36, 36-16)/64.0;
            return;

        // ======== R-Arm ========
        case FACEID_ARM_R_LEFT:
            if(isAlex){
                vanillaMinUV = vec2(48-1, 36-16)/64.0;
                vanillaMaxUV = vec2(52-1, 48-16)/64.0;
            } else {
                vanillaMinUV = vec2(48, 36-16)/64.0;
                vanillaMaxUV = vec2(52, 48-16)/64.0;
            }
            return;
        case FACEID_ARM_R_RIGHT:
            vanillaMinUV = vec2(40, 36-16)/64.0;
            vanillaMaxUV = vec2(44, 48-16)/64.0;
            return;
        case FACEID_ARM_R_TOP:
            if(isAlex){
                vanillaMinUV = vec2(44, 32-16)/64.0;
                vanillaMaxUV = vec2(48-1, 36-16)/64.0;
            } else {
                vanillaMinUV = vec2(44, 32-16)/64.0;
                vanillaMaxUV = vec2(48, 36-16)/64.0;
            }
            return;
        case FACEID_ARM_R_BOTTOM:
            if(isAlex){
                vanillaMinUV = vec2(48-1, 32-16)/64.0;
                vanillaMaxUV = vec2(52-2, 36-16)/64.0;
            } else {
                vanillaMinUV = vec2(48, 32-16)/64.0;
                vanillaMaxUV = vec2(52, 36-16)/64.0;
            }
            return;
        case FACEID_ARM_R_FRONT:
            if(isAlex){
                vanillaMinUV = vec2(44, 36-16)/64.0;
                vanillaMinUV = vec2(48-1, 48-16)/64.0;
            } else {
                vanillaMinUV = vec2(44, 36-16)/64.0;
                vanillaMinUV = vec2(48, 48-16)/64.0;
            }
            return;
        case FACEID_ARM_R_BACK:
            if(isAlex){
                vanillaMinUV = vec2(52-1, 36-16)/64.0;
                vanillaMaxUV = vec2(56-2, 48-16)/64.0;
            } else {
                vanillaMinUV = vec2(52, 36-16)/64.0;
                vanillaMaxUV = vec2(56, 48-16)/64.0;
            }
            return;

        // ======== L-Arm ========
        case FACEID_ARM_L_LEFT:
            if(isAlex){
                vanillaMinUV = vec2(8+48-1-16, 52)/64.0;
                vanillaMaxUV = vec2(12+48-1-16, 64)/64.0;
            } else {
                vanillaMinUV = vec2(8+48-16, 52)/64.0;
                vanillaMaxUV = vec2(12+48-16, 64)/64.0;
            }
            return;
        case FACEID_ARM_L_RIGHT:
            vanillaMinUV = vec2(0+48-16, 52)/64.0;
            vanillaMaxUV = vec2(4+48-16, 64)/64.0;
            return;
        case FACEID_ARM_L_TOP:
            if(isAlex){
                vanillaMinUV = vec2(4+48-16, 48)/64.0;
                vanillaMaxUV = vec2(8+48-1-16, 52)/64.0;
            } else {
                vanillaMinUV = vec2(4+48-16, 48)/64.0;
                vanillaMaxUV = vec2(8+48-16, 52)/64.0;
            }
            return;
        case FACEID_ARM_L_BOTTOM:
            if(isAlex){
                vanillaMinUV = vec2(8+48-1-16, 48)/64.0;
                vanillaMaxUV = vec2(12+48-2-16, 52)/64.0;
            } else {
                vanillaMinUV = vec2(8+48-16, 48)/64.0;
                vanillaMaxUV = vec2(12+48-16, 52)/64.0;
            }
            return;
        case FACEID_ARM_L_FRONT:
            if(isAlex){
                vanillaMinUV = vec2(4+48-16, 52)/64.0;
                vanillaMaxUV = vec2(8+48-1-16, 64)/64.0;
            } else {
                vanillaMinUV = vec2(4+48-16, 52)/64.0;
                vanillaMaxUV = vec2(8+48-16, 64)/64.0;
            }
            return;
        case FACEID_ARM_L_BACK:
            if(isAlex){
                vanillaMinUV = vec2(12+48-1-16, 52)/64.0;
                vanillaMaxUV = vec2(16+48-2-16, 64)/64.0;
            } else {
                vanillaMinUV = vec2(12+48-16, 52)/64.0;
                vanillaMaxUV = vec2(16+48-16, 64)/64.0;
            }
            return;

        // ======== LEG_R ========
        case FACEID_LEG_R_LEFT:
            vanillaMinUV = vec2(8, 36-16)/64.0;
            vanillaMaxUV = vec2(12, 48-16)/64.0;
            return;
        case FACEID_LEG_R_RIGHT:
            vanillaMinUV = vec2(0, 36-16)/64.0;
            vanillaMaxUV = vec2(4, 48-16)/64.0;
            return;
        case FACEID_LEG_R_TOP:
            vanillaMinUV = vec2(4, 32-16)/64.0;
            vanillaMaxUV = vec2(8, 36-16)/64.0;
            return;
        case FACEID_LEG_R_BOTTOM:
            vanillaMinUV = vec2(8, 32-16)/64.0;
            vanillaMaxUV = vec2(12, 36-16)/64.0;
            return;
        case FACEID_LEG_R_FRONT:
            vanillaMinUV = vec2(4, 36-16)/64.0;
            vanillaMaxUV = vec2(8, 48-16)/64.0;
            return;
        case FACEID_LEG_R_BACK:
            vanillaMinUV = vec2(12, 36-16)/64.0;
            vanillaMaxUV = vec2(16, 48-16)/64.0;
            return;

        // ======== LEG_L ========
        case FACEID_LEG_L_LEFT:
            vanillaMinUV = vec2(8+16, 52)/64.0;
            vanillaMaxUV = vec2(12+16, 64)/64.0;
            return;
        case FACEID_LEG_L_RIGHT:
            vanillaMinUV = vec2(0+16, 52)/64.0;
            vanillaMaxUV = vec2(4+16, 64)/64.0;
            return;
        case FACEID_LEG_L_TOP:
            vanillaMinUV = vec2(4+16, 48)/64.0;
            vanillaMaxUV = vec2(8+16, 52)/64.0;
            return;
        case FACEID_LEG_L_BOTTOM:
            vanillaMinUV = vec2(8+16, 48)/64.0;
            vanillaMaxUV = vec2(12+16, 52)/64.0;
            return;
        case FACEID_LEG_L_FRONT:
            vanillaMinUV = vec2(4+16, 52)/64.0;
            vanillaMaxUV = vec2(8+16, 64)/64.0;
            return;
        case FACEID_LEG_L_BACK:
            vanillaMinUV = vec2(12+16, 52)/64.0;
            vanillaMaxUV = vec2(16+16, 64)/64.0;
            return;

        // ======== Hat ========
        case FACEID_HAT_LEFT:
            vanillaMinUV = vec2(48, 8)/64.0;
            vanillaMaxUV = vec2(56, 16)/64.0;
            return;
        case FACEID_HAT_RIGHT:
            vanillaMinUV = vec2(32, 8)/64.0;
            vanillaMaxUV = vec2(40, 16)/64.0;
            return;
        case FACEID_HAT_TOP:
            vanillaMinUV = vec2(40, 0)/64.0;
            vanillaMaxUV = vec2(48, 8)/64.0;
            return;
        case FACEID_HAT_BOTTOM:
            vanillaMinUV = vec2(48, 0)/64.0;
            vanillaMaxUV = vec2(56, 8)/64.0;
            return;
        case FACEID_HAT_FRONT:
            vanillaMinUV = vec2(40, 8)/64.0;
            vanillaMaxUV = vec2(48, 16)/64.0;
            return;
        case FACEID_HAT_BACK:
            vanillaMinUV = vec2(56, 8)/64.0;
            vanillaMaxUV = vec2(64, 16)/64.0;
            return;

        // ======== L-pant ========
        case FACEID_PANT_L_LEFT:
            vanillaMinUV = vec2(8, 52)/64.0;
            vanillaMaxUV = vec2(12, 64)/64.0;
            return;
        case FACEID_PANT_L_RIGHT:
            vanillaMinUV = vec2(0, 52)/64.0;
            vanillaMaxUV = vec2(4, 64)/64.0;
            return;
        case FACEID_PANT_L_TOP:
            vanillaMinUV = vec2(4, 48)/64.0;
            vanillaMaxUV = vec2(8, 52)/64.0;
            return;
        case FACEID_PANT_L_BOTTOM:
            vanillaMinUV = vec2(8, 48)/64.0;
            vanillaMaxUV = vec2(12, 52)/64.0;
            return;
        case FACEID_PANT_L_FRONT:
            vanillaMinUV = vec2(4, 52)/64.0;
            vanillaMaxUV = vec2(8, 64)/64.0;
            return;
        case FACEID_PANT_L_BACK:
            vanillaMinUV = vec2(12, 52)/64.0;
            vanillaMaxUV = vec2(16, 64)/64.0;
            return;

        // ======== R-Pant ========
        case FACEID_PANT_R_LEFT:
            vanillaMinUV = vec2(8, 36)/64.0;
            vanillaMaxUV = vec2(12, 48)/64.0;
            return;
        case FACEID_PANT_R_RIGHT:
            vanillaMinUV = vec2(0, 36)/64.0;
            vanillaMaxUV = vec2(4, 48)/64.0;
            return;
        case FACEID_PANT_R_TOP:
            vanillaMinUV = vec2(4, 32)/64.0;
            vanillaMaxUV = vec2(8, 36)/64.0;
            return;
        case FACEID_PANT_R_BOTTOM:
            vanillaMinUV = vec2(8, 32)/64.0;
            vanillaMaxUV = vec2(12, 36)/64.0;
            return;
        case FACEID_PANT_R_FRONT:
            vanillaMinUV = vec2(4, 36)/64.0;
            vanillaMaxUV = vec2(8, 48)/64.0;
            return;
        case FACEID_PANT_R_BACK:
            vanillaMinUV = vec2(12, 36)/64.0;
            vanillaMaxUV = vec2(16, 48)/64.0;
            return;

        // ======== L-Shirt ========
        case FACEID_SLEVE_L_LEFT:
            if(isAlex){
                vanillaMinUV = vec2(8+48-1, 52)/64.0;
                vanillaMaxUV = vec2(12+48-1, 64)/64.0;
            } else {
                vanillaMinUV = vec2(8+48, 52)/64.0;
                vanillaMaxUV = vec2(12+48, 64)/64.0;
            }
            return;
        case FACEID_SLEVE_L_RIGHT:
            vanillaMinUV = vec2(0+48, 52)/64.0;
            vanillaMaxUV = vec2(4+48, 64)/64.0;
            return;
        case FACEID_SLEVE_L_TOP:
            if(isAlex){
                vanillaMinUV = vec2(4+48, 48)/64.0;
                vanillaMaxUV = vec2(8+48-1, 52)/64.0;
            } else {
                vanillaMinUV = vec2(4+48, 48)/64.0;
                vanillaMaxUV = vec2(8+48, 52)/64.0;
            }
            return;
        case FACEID_SLEVE_L_BOTTOM:
            if(isAlex){
                vanillaMinUV = vec2(8+48-1, 48)/64.0;
                vanillaMaxUV = vec2(12+48-2, 52)/64.0;
            } else {
                vanillaMinUV = vec2(8+48, 48)/64.0;
                vanillaMaxUV = vec2(12+48, 52)/64.0;
            }
            return;
        case FACEID_SLEVE_L_FRONT:
            if(isAlex){
                vanillaMinUV = vec2(4+48, 52)/64.0;
                vanillaMaxUV = vec2(8+48-1, 64)/64.0;
            } else {
                vanillaMinUV = vec2(4+48, 52)/64.0;
                vanillaMaxUV = vec2(8+48, 64)/64.0;
            }
            return;
        case FACEID_SLEVE_L_BACK:
            if(isAlex){
                vanillaMinUV = vec2(12+48-1, 52)/64.0;
                vanillaMaxUV = vec2(16+48-2, 64)/64.0;
            } else {
                vanillaMinUV = vec2(12+48, 52)/64.0;
                vanillaMaxUV = vec2(16+48, 64)/64.0;
            }
            return;

        // ======== R-Shirt ========
        case FACEID_SLEVE_R_LEFT:
            if(isAlex){
                vanillaMinUV = vec2(48-1, 36)/64.0;
                vanillaMaxUV = vec2(52-1, 48)/64.0;
            } else {
                vanillaMinUV = vec2(48, 36)/64.0;
                vanillaMaxUV = vec2(52, 48)/64.0;
            }
            return;
        case FACEID_SLEVE_R_RIGHT:
            vanillaMinUV = vec2(40, 36)/64.0;
            vanillaMaxUV = vec2(44, 48)/64.0;
            return;
        case FACEID_SLEVE_R_TOP:
            if(isAlex){
                vanillaMinUV = vec2(44, 32)/64.0;
                vanillaMaxUV = vec2(48-1, 36)/64.0;
            } else {
                vanillaMinUV = vec2(44, 32)/64.0;
                vanillaMaxUV = vec2(48, 36)/64.0;
            }
            return;
        case FACEID_SLEVE_R_BOTTOM:
            if(isAlex){
                vanillaMinUV = vec2(48-1, 32)/64.0;
                vanillaMaxUV = vec2(52-2, 36)/64.0;
            } else {
                vanillaMinUV = vec2(48, 32)/64.0;
                vanillaMaxUV = vec2(52, 36)/64.0;
            }
            return;
        case FACEID_SLEVE_R_FRONT:
            if(isAlex){
                vanillaMinUV = vec2(44, 36)/64.0;
                vanillaMinUV = vec2(48-1, 48)/64.0;
            } else {
                vanillaMinUV = vec2(44, 36)/64.0;
                vanillaMinUV = vec2(48, 48)/64.0;
            }
            return;
        case FACEID_SLEVE_R_BACK:
            if(isAlex){
                vanillaMinUV = vec2(52-1, 36)/64.0;
                vanillaMaxUV = vec2(56-2, 48)/64.0;
            } else {
                vanillaMinUV = vec2(52, 36)/64.0;
                vanillaMaxUV = vec2(56, 48)/64.0;
            }
            return;

        // ======== JACKET ========
        case FACEID_JACKET_LEFT:
            vanillaMinUV = vec2(28, 36)/64.0;
            vanillaMaxUV = vec2(32, 48)/64.0;
            return;
        case FACEID_JACKET_RIGHT:
            vanillaMinUV = vec2(16, 36)/64.0;
            vanillaMaxUV = vec2(20, 48)/64.0;
            return;
        case FACEID_JACKET_TOP:
            vanillaMinUV = vec2(20, 32)/64.0;
            vanillaMaxUV = vec2(28, 36)/64.0;
            return;
        case FACEID_JACKET_BOTTOM:
            vanillaMinUV = vec2(28, 32)/64.0;
            vanillaMaxUV = vec2(36, 36)/64.0;
            return;
        case FACEID_JACKET_FRONT:
            vanillaMinUV = vec2(20, 36)/64.0;
            vanillaMaxUV = vec2(28, 48)/64.0;
            return;
        case FACEID_JACKET_BACK:
            vanillaMinUV = vec2(32, 36)/64.0;
            vanillaMaxUV = vec2(40, 48)/64.0;
            return;
    }
}