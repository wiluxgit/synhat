#version 330

#ifdef BROWSER // ThreeJS
#define in in highp
#define out out highp
#else // Minecraft
#extension GL_EXT_gpu_shader4 : enable
#moj_import <light.glsl>
#moj_import <fog.glsl>
#endif

//=================================================================================
// Macros
//=================================================================================

// how long to stretch along normal to simulate 90 deg face
#define AS_FLIP (128.0)


// How much bigger the second layer is
#define OVERLAYSCALE (1.125)
#define PIXELFACTOR (1.125/16.0)

// FACE_OPERATION_ENTRY
#define MASK_FACE_OPERATION_ENTRY_TRANFORM_ARGUMENT_INDEX (63) // 0b00111111
#define MASK_TRANFORM_TYPE (192) // 0b11000000
#define TRANFORM_TYPE_DISPLACEMENT (0<<6)
#define TRANFORM_TYPE_UV_CROP (1<<6)
#define TRANFORM_TYPE_UV_OFFSET (2<<6)
#define TRANFORM_TYPE_SPECIAL (3<<6)

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
int getMCVertID();
int getFaceId(int vertId);
int getCornerId(int vertId);
int getDirId(int vertId);
int getFaceOperationEntry(int faceId);
vec4 getFaceOperationPixel(int faceId);
vec4 getTransformArguments(int activeTransformIndex);

// hard coded face properties
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
#ifdef BROWSER // ThreeJS
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

#ifdef BROWSER // ThreeJS
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

#ifdef BROWSER
    // ThreeJS fix to convert all names to the same as minecraft
    ModelViewMat = viewMatrix;
    ProjMat = projectionMatrix;
    Position = position;
    Normal = normal;
    UV0 = vec2(uv.x, 1.0-uv.y); // ThreeJS reverses the UV coordinates AND the texture by default
#endif
    int vertId = getMCVertID();

    //<DEBUG>
    float vertIdx = float(vertId)/400.0;
    float vertIdy = float((vertId/4)%6)/6.0;
    wx_vertexColor = vec4(vertIdx, vertIdy, 0, 1);
    wx_vertexColor = colorFromInt(getFaceId(vertId));
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

    if (false) { //(gl_VertexID >= 18*8){ //is second layer

        // Get header pixel
        vec4 topRightPixel = texelFetch(Sampler0, ivec2(0, 0), 0)*256.0;
        int headerR = int(topRightPixel.r + 0.1);
        int headerG = int(topRightPixel.g + 0.1);
        int headerB = int(topRightPixel.b + 0.1);

        if (headerR == 0xda && headerG == 0x67) {
            bool isAlex = (headerB == 1);

            int faceId = getFaceId(vertId);
            int cornerId = getCornerId(vertId);

            int nextFaceOperationEntry = getFaceOperationEntry(faceId);

            if (nextFaceOperationEntry != 0) {
                initVanillaUV(faceId, isAlex);
                NewFaceCenter = vanillaCenterUV;

                while (true) {
                    int activeTransformIndex = nextFaceOperationEntry & MASK_FACE_OPERATION_ENTRY_TRANFORM_ARGUMENT_INDEX;
                    int activeTransformType = nextFaceOperationEntry & MASK_TRANFORM_TYPE;

                    if (activeTransformIndex == 0 || activeTransformIndex > 44) {
                        break;
                    }

                    wx_isEdited = 1.0;

                    vec4 transformData = getTransformArguments(activeTransformIndex);
                    //wx_vertexColor = transformData / 256.0;

                    int dataR = int(transformData.r+0.1);
                    int dataG = int(transformData.g+0.1);
                    int dataB = int(transformData.b+0.1);
                    nextFaceOperationEntry = int(transformData.a+0.1);

                    switch (activeTransformType) {
                        case TRANFORM_TYPE_DISPLACEMENT:
                            applyDisplacement(isAlex, vertId, dataR, dataG, dataB);
                            break;
                        case TRANFORM_TYPE_UV_CROP:
                            applyUVCrop(isAlex, vertId, dataR, dataG, dataB);
                            break;
                        case TRANFORM_TYPE_UV_OFFSET:
                            applyUVOffset(isAlex, vertId, dataR, dataG, dataB);
                            break;
                        case TRANFORM_TYPE_SPECIAL:
                            applyPostFlags(isAlex, vertId, dataR, dataG, dataB);
                            break;
                    }
                }
            }

            // UV crop shenanigans
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

#ifdef BROWSER // ThreeJS
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
        wx_vertexColor = colorFromInt(asymEdge);
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
    wx_vertexColor = colorFromInt(cornerId);
    return;
}
void applyPostFlags(bool isAlex, int vertId, int dataR, int dataG, int dataB) {
    return;
}
vec3 pixelNormal() {
    return Normal * PIXELFACTOR;
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
vec4 getFaceOperationPixel(int faceId) {
    int F_index = faceId / 4;
    int temp = 2 + F_index;
    int x = temp % 8;
    int y = temp / 8;

    return texelFetch(Sampler0, ivec2(x, y), 0)*256.0;
}
int getFaceOperationEntry(int faceId) {
    vec4 rgba = getFaceOperationPixel(faceId);

    switch (faceId % 4) {
        case 0: return int(rgba.r+0.1);
        case 1: return int(rgba.g+0.1);
        case 2: return int(rgba.b+0.1);
        case 3: return int(rgba.a+0.1);
    }
}
vec4 getTransformArguments(int activeTransformIndex) {
    int temp = (8*2+4) + activeTransformIndex;
    int x = temp % 8;
    int y = temp / 8;
    return texelFetch(Sampler0, ivec2(x, y), 0)*256.0;
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
        case 0: return vec4(1,0,0,1); // R
        case 1: return vec4(0,1,0,1); // G
        case 2: return vec4(0,0,1,1); // B
        case 3: return vec4(1,1,0,1); // YELLOW
        case 4: return vec4(0,1,1,1); // CYAN
        case 5: return vec4(1,0,1,1); // MAGENTA
        case 6: return vec4(1,1,1,1);
        case 7: return vec4(0,0,0,1);
    }
}

// retuns the length (in pixels) to the back face for a given face
int getPerpendicularLength(int faceId, bool isAlex) {
    int facetype = faceId/6;
    int faceAxis = faceId%6;
    int perpendicularLength;
    switch(facetype) {
        case 0:
        case 6: //Head
            return 8;
        case 1:
        case 2:
        case 7: // L-Pant
        case 8: // R-Pant
            if(faceAxis == 2 || faceAxis == 3){ // Top/Bot
                return 12;
            } else {
                return 4;
            }
        case 3:
        case 4:
        case 9: // R-Arm
        case 10: // L-Arm
            if(faceAxis == 2 || faceAxis == 3){ // Top/Bot
                return 12;
            } else {
                return isAlex ? 3 : 4; // Account for Alex models
            }
        case 5:
        case 11:
            if(faceAxis == 0 || faceAxis == 1) { // Left/Right
                return 8;
            } else if(faceAxis == 2 || faceAxis == 3) {// Top/Bot
                return 12;
            } else { // Front/Back
                return 4;
            }
    }
}

// ---------------------------------------------------------------------------------
// getMCVertID():
//  Returns the The vertex id is unique number for each vertex, all players have identical order
//  For ThreeJS all polygons are drawn independantly
// ---------------------------------------------------------------------------------
#ifndef BROWSER // Minecraft
int getMCVertID() {
    return gl_VertexID;
}
#else // ThreeJS
int faceIdLookup(int dirid, int uvu, int uvv);
int getMCVertID() {
    int dirid;
    int corner;

    switch(gl_VertexID % 6){
    case 0:
    case 3:
        corner = 0;
        break;
    case 2:
    case 4:
        corner = 2;
        break;
    case 1:
        corner = 1;
        break;
    case 5:
        corner = 3;
        break;
    }

    if (Normal.x > 0.1 && Normal.y == 0.0 && Normal.z == 0.0) {
        dirid = 0;
    } else if (Normal.x < -0.1 && Normal.y == 0.0 && Normal.z == 0.0) {
        dirid = 1;
    } else if (Normal.x == 0.0 && Normal.y > 0.1 && Normal.z == 0.0) {
        dirid = 2;
    } else if (Normal.x == 0.0 && Normal.y < -0.1 && Normal.z == 0.0) {
        dirid = 3;
    } else if (Normal.x == 0.0 && Normal.y == 0.0 && Normal.z > 0.1) {
        dirid = 4;
    } else if (Normal.x == 0.0 && Normal.y == 0.0 && Normal.z < -0.1) {
        dirid = 5;
    }

    int uvu = int(UV0.x*64.0 + 0.1);
    int uvv = int(UV0.y*64.0 + 0.1);
    int faceId = faceIdLookup(dirid, uvu, uvv);
    return faceId*4 + corner;
}

int faceIdLookup(int dirid, int uvu, int uvv) {
    switch(dirid){
    case 0:
        if ((uvu == 24) && (uvv == 8)) return 0;
        if ((uvu == 16) && (uvv == 8)) return 0;
        if ((uvu == 16) && (uvv == 16)) return 0;
        if ((uvu == 24) && (uvv == 16)) return 0;
        if ((uvu == 32) && (uvv == 20)) return 6;
        if ((uvu == 28) && (uvv == 20)) return 6;
        if ((uvu == 28) && (uvv == 32)) return 6;
        if ((uvu == 32) && (uvv == 32)) return 6;
        if ((uvu == 44) && (uvv == 52)) return 12;
        if ((uvu == 40) && (uvv == 52)) return 12;
        if ((uvu == 40) && (uvv == 64)) return 12;
        if ((uvu == 44) && (uvv == 64)) return 12;
        if ((uvu == 52) && (uvv == 20)) return 18;
        if ((uvu == 48) && (uvv == 20)) return 18;
        if ((uvu == 48) && (uvv == 32)) return 18;
        if ((uvu == 52) && (uvv == 32)) return 18;
        if ((uvu == 28) && (uvv == 52)) return 24;
        if ((uvu == 24) && (uvv == 52)) return 24;
        if ((uvu == 24) && (uvv == 64)) return 24;
        if ((uvu == 28) && (uvv == 64)) return 24;
        if ((uvu == 12) && (uvv == 20)) return 30;
        if ((uvu == 8) && (uvv == 20)) return 30;
        if ((uvu == 8) && (uvv == 32)) return 30;
        if ((uvu == 12) && (uvv == 32)) return 30;
        if ((uvu == 56) && (uvv == 8)) return 36;
        if ((uvu == 48) && (uvv == 8)) return 36;
        if ((uvu == 48) && (uvv == 16)) return 36;
        if ((uvu == 56) && (uvv == 16)) return 36;
        if ((uvu == 12) && (uvv == 36)) return 42;
        if ((uvu == 8) && (uvv == 36)) return 42;
        if ((uvu == 8) && (uvv == 48)) return 42;
        if ((uvu == 12) && (uvv == 48)) return 42;
        if ((uvu == 12) && (uvv == 52)) return 48;
        if ((uvu == 8) && (uvv == 52)) return 48;
        if ((uvu == 8) && (uvv == 64)) return 48;
        if ((uvu == 12) && (uvv == 64)) return 48;
        if ((uvu == 60) && (uvv == 52)) return 54;
        if ((uvu == 56) && (uvv == 52)) return 54;
        if ((uvu == 56) && (uvv == 64)) return 54;
        if ((uvu == 60) && (uvv == 64)) return 54;
        if ((uvu == 52) && (uvv == 36)) return 60;
        if ((uvu == 48) && (uvv == 36)) return 60;
        if ((uvu == 48) && (uvv == 48)) return 60;
        if ((uvu == 52) && (uvv == 48)) return 60;
        if ((uvu == 32) && (uvv == 36)) return 66;
        if ((uvu == 28) && (uvv == 36)) return 66;
        if ((uvu == 28) && (uvv == 48)) return 66;
        if ((uvu == 32) && (uvv == 48)) return 66;
        return -1;
    case 1:
        if ((uvu == 8) && (uvv == 8)) return 1;
        if ((uvu == 0) && (uvv == 8)) return 1;
        if ((uvu == 0) && (uvv == 16)) return 1;
        if ((uvu == 8) && (uvv == 16)) return 1;
        if ((uvu == 20) && (uvv == 20)) return 7;
        if ((uvu == 16) && (uvv == 20)) return 7;
        if ((uvu == 16) && (uvv == 32)) return 7;
        if ((uvu == 20) && (uvv == 32)) return 7;
        if ((uvu == 36) && (uvv == 52)) return 13;
        if ((uvu == 32) && (uvv == 52)) return 13;
        if ((uvu == 32) && (uvv == 64)) return 13;
        if ((uvu == 36) && (uvv == 64)) return 13;
        if ((uvu == 44) && (uvv == 20)) return 19;
        if ((uvu == 40) && (uvv == 20)) return 19;
        if ((uvu == 40) && (uvv == 32)) return 19;
        if ((uvu == 44) && (uvv == 32)) return 19;
        if ((uvu == 20) && (uvv == 52)) return 25;
        if ((uvu == 16) && (uvv == 52)) return 25;
        if ((uvu == 16) && (uvv == 64)) return 25;
        if ((uvu == 20) && (uvv == 64)) return 25;
        if ((uvu == 4) && (uvv == 20)) return 31;
        if ((uvu == 0) && (uvv == 20)) return 31;
        if ((uvu == 0) && (uvv == 32)) return 31;
        if ((uvu == 4) && (uvv == 32)) return 31;
        if ((uvu == 40) && (uvv == 8)) return 37;
        if ((uvu == 32) && (uvv == 8)) return 37;
        if ((uvu == 32) && (uvv == 16)) return 37;
        if ((uvu == 40) && (uvv == 16)) return 37;
        if ((uvu == 4) && (uvv == 36)) return 43;
        if ((uvu == 0) && (uvv == 36)) return 43;
        if ((uvu == 0) && (uvv == 48)) return 43;
        if ((uvu == 4) && (uvv == 48)) return 43;
        if ((uvu == 4) && (uvv == 52)) return 49;
        if ((uvu == 0) && (uvv == 52)) return 49;
        if ((uvu == 0) && (uvv == 64)) return 49;
        if ((uvu == 4) && (uvv == 64)) return 49;
        if ((uvu == 52) && (uvv == 52)) return 55;
        if ((uvu == 48) && (uvv == 52)) return 55;
        if ((uvu == 48) && (uvv == 64)) return 55;
        if ((uvu == 52) && (uvv == 64)) return 55;
        if ((uvu == 44) && (uvv == 36)) return 61;
        if ((uvu == 40) && (uvv == 36)) return 61;
        if ((uvu == 40) && (uvv == 48)) return 61;
        if ((uvu == 44) && (uvv == 48)) return 61;
        if ((uvu == 20) && (uvv == 36)) return 67;
        if ((uvu == 16) && (uvv == 36)) return 67;
        if ((uvu == 16) && (uvv == 48)) return 67;
        if ((uvu == 20) && (uvv == 48)) return 67;
        return -1;
    case 2:
        if ((uvu == 16) && (uvv == 0)) return 2;
        if ((uvu == 8) && (uvv == 0)) return 2;
        if ((uvu == 8) && (uvv == 8)) return 2;
        if ((uvu == 16) && (uvv == 8)) return 2;
        if ((uvu == 28) && (uvv == 16)) return 8;
        if ((uvu == 20) && (uvv == 16)) return 8;
        if ((uvu == 20) && (uvv == 20)) return 8;
        if ((uvu == 28) && (uvv == 20)) return 8;
        if ((uvu == 40) && (uvv == 48)) return 14;
        if ((uvu == 36) && (uvv == 48)) return 14;
        if ((uvu == 36) && (uvv == 52)) return 14;
        if ((uvu == 40) && (uvv == 52)) return 14;
        if ((uvu == 48) && (uvv == 16)) return 20;
        if ((uvu == 44) && (uvv == 16)) return 20;
        if ((uvu == 44) && (uvv == 20)) return 20;
        if ((uvu == 48) && (uvv == 20)) return 20;
        if ((uvu == 24) && (uvv == 48)) return 26;
        if ((uvu == 20) && (uvv == 48)) return 26;
        if ((uvu == 20) && (uvv == 52)) return 26;
        if ((uvu == 24) && (uvv == 52)) return 26;
        if ((uvu == 8) && (uvv == 16)) return 32;
        if ((uvu == 4) && (uvv == 16)) return 32;
        if ((uvu == 4) && (uvv == 20)) return 32;
        if ((uvu == 8) && (uvv == 20)) return 32;
        if ((uvu == 48) && (uvv == 0)) return 38;
        if ((uvu == 40) && (uvv == 0)) return 38;
        if ((uvu == 40) && (uvv == 8)) return 38;
        if ((uvu == 48) && (uvv == 8)) return 38;
        if ((uvu == 8) && (uvv == 32)) return 44;
        if ((uvu == 4) && (uvv == 32)) return 44;
        if ((uvu == 4) && (uvv == 36)) return 44;
        if ((uvu == 8) && (uvv == 36)) return 44;
        if ((uvu == 8) && (uvv == 48)) return 50;
        if ((uvu == 4) && (uvv == 48)) return 50;
        if ((uvu == 4) && (uvv == 52)) return 50;
        if ((uvu == 8) && (uvv == 52)) return 50;
        if ((uvu == 56) && (uvv == 48)) return 56;
        if ((uvu == 52) && (uvv == 48)) return 56;
        if ((uvu == 52) && (uvv == 52)) return 56;
        if ((uvu == 56) && (uvv == 52)) return 56;
        if ((uvu == 48) && (uvv == 32)) return 62;
        if ((uvu == 44) && (uvv == 32)) return 62;
        if ((uvu == 44) && (uvv == 36)) return 62;
        if ((uvu == 48) && (uvv == 36)) return 62;
        if ((uvu == 28) && (uvv == 32)) return 68;
        if ((uvu == 20) && (uvv == 32)) return 68;
        if ((uvu == 20) && (uvv == 36)) return 68;
        if ((uvu == 28) && (uvv == 36)) return 68;
        return -1;
    case 3:
        if ((uvu == 24) && (uvv == 8)) return 3;
        if ((uvu == 16) && (uvv == 8)) return 3;
        if ((uvu == 16) && (uvv == 0)) return 3;
        if ((uvu == 24) && (uvv == 0)) return 3;
        if ((uvu == 32) && (uvv == 20)) return 9;
        if ((uvu == 28) && (uvv == 20)) return 9;
        if ((uvu == 28) && (uvv == 16)) return 9;
        if ((uvu == 36) && (uvv == 16)) return 9;
        if ((uvu == 44) && (uvv == 52)) return 15;
        if ((uvu == 40) && (uvv == 52)) return 15;
        if ((uvu == 40) && (uvv == 48)) return 15;
        if ((uvu == 44) && (uvv == 48)) return 15;
        if ((uvu == 52) && (uvv == 20)) return 21;
        if ((uvu == 48) && (uvv == 20)) return 21;
        if ((uvu == 48) && (uvv == 16)) return 21;
        if ((uvu == 52) && (uvv == 16)) return 21;
        if ((uvu == 28) && (uvv == 52)) return 27;
        if ((uvu == 24) && (uvv == 52)) return 27;
        if ((uvu == 24) && (uvv == 48)) return 27;
        if ((uvu == 28) && (uvv == 48)) return 27;
        if ((uvu == 12) && (uvv == 20)) return 33;
        if ((uvu == 8) && (uvv == 20)) return 33;
        if ((uvu == 8) && (uvv == 16)) return 33;
        if ((uvu == 12) && (uvv == 16)) return 33;
        if ((uvu == 56) && (uvv == 8)) return 39;
        if ((uvu == 48) && (uvv == 8)) return 39;
        if ((uvu == 48) && (uvv == 0)) return 39;
        if ((uvu == 56) && (uvv == 0)) return 39;
        if ((uvu == 12) && (uvv == 36)) return 45;
        if ((uvu == 8) && (uvv == 36)) return 45;
        if ((uvu == 8) && (uvv == 32)) return 45;
        if ((uvu == 12) && (uvv == 32)) return 45;
        if ((uvu == 12) && (uvv == 52)) return 51;
        if ((uvu == 8) && (uvv == 52)) return 51;
        if ((uvu == 8) && (uvv == 48)) return 51;
        if ((uvu == 12) && (uvv == 48)) return 51;
        if ((uvu == 60) && (uvv == 52)) return 57;
        if ((uvu == 56) && (uvv == 52)) return 57;
        if ((uvu == 56) && (uvv == 48)) return 57;
        if ((uvu == 60) && (uvv == 48)) return 57;
        if ((uvu == 52) && (uvv == 36)) return 63;
        if ((uvu == 48) && (uvv == 36)) return 63;
        if ((uvu == 48) && (uvv == 32)) return 63;
        if ((uvu == 52) && (uvv == 32)) return 63;
        if ((uvu == 32) && (uvv == 36)) return 69;
        if ((uvu == 28) && (uvv == 36)) return 69;
        if ((uvu == 28) && (uvv == 32)) return 69;
        if ((uvu == 36) && (uvv == 32)) return 69;
        return -1;
    case 4:
        if ((uvu == 16) && (uvv == 8)) return 4;
        if ((uvu == 8) && (uvv == 8)) return 4;
        if ((uvu == 8) && (uvv == 16)) return 4;
        if ((uvu == 16) && (uvv == 16)) return 4;
        if ((uvu == 28) && (uvv == 20)) return 10;
        if ((uvu == 20) && (uvv == 20)) return 10;
        if ((uvu == 20) && (uvv == 32)) return 10;
        if ((uvu == 28) && (uvv == 32)) return 10;
        if ((uvu == 40) && (uvv == 52)) return 16;
        if ((uvu == 36) && (uvv == 52)) return 16;
        if ((uvu == 36) && (uvv == 64)) return 16;
        if ((uvu == 40) && (uvv == 64)) return 16;
        if ((uvu == 48) && (uvv == 20)) return 22;
        if ((uvu == 44) && (uvv == 20)) return 22;
        if ((uvu == 44) && (uvv == 32)) return 22;
        if ((uvu == 48) && (uvv == 32)) return 22;
        if ((uvu == 24) && (uvv == 52)) return 28;
        if ((uvu == 20) && (uvv == 52)) return 28;
        if ((uvu == 20) && (uvv == 64)) return 28;
        if ((uvu == 24) && (uvv == 64)) return 28;
        if ((uvu == 8) && (uvv == 20)) return 34;
        if ((uvu == 4) && (uvv == 20)) return 34;
        if ((uvu == 4) && (uvv == 32)) return 34;
        if ((uvu == 8) && (uvv == 32)) return 34;
        if ((uvu == 48) && (uvv == 8)) return 40;
        if ((uvu == 40) && (uvv == 8)) return 40;
        if ((uvu == 40) && (uvv == 16)) return 40;
        if ((uvu == 48) && (uvv == 16)) return 40;
        if ((uvu == 8) && (uvv == 36)) return 46;
        if ((uvu == 4) && (uvv == 36)) return 46;
        if ((uvu == 4) && (uvv == 48)) return 46;
        if ((uvu == 8) && (uvv == 48)) return 46;
        if ((uvu == 8) && (uvv == 52)) return 52;
        if ((uvu == 4) && (uvv == 52)) return 52;
        if ((uvu == 4) && (uvv == 64)) return 52;
        if ((uvu == 8) && (uvv == 64)) return 52;
        if ((uvu == 56) && (uvv == 52)) return 58;
        if ((uvu == 52) && (uvv == 52)) return 58;
        if ((uvu == 52) && (uvv == 64)) return 58;
        if ((uvu == 56) && (uvv == 64)) return 58;
        if ((uvu == 48) && (uvv == 36)) return 64;
        if ((uvu == 44) && (uvv == 36)) return 64;
        if ((uvu == 44) && (uvv == 48)) return 64;
        if ((uvu == 48) && (uvv == 48)) return 64;
        if ((uvu == 28) && (uvv == 36)) return 70;
        if ((uvu == 20) && (uvv == 36)) return 70;
        if ((uvu == 20) && (uvv == 48)) return 70;
        if ((uvu == 28) && (uvv == 48)) return 70;
        return -1;
    case 5:
        if ((uvu == 32) && (uvv == 8)) return 5;
        if ((uvu == 24) && (uvv == 8)) return 5;
        if ((uvu == 24) && (uvv == 16)) return 5;
        if ((uvu == 32) && (uvv == 16)) return 5;
        if ((uvu == 40) && (uvv == 20)) return 11;
        if ((uvu == 32) && (uvv == 20)) return 11;
        if ((uvu == 32) && (uvv == 32)) return 11;
        if ((uvu == 40) && (uvv == 32)) return 11;
        if ((uvu == 48) && (uvv == 52)) return 17;
        if ((uvu == 44) && (uvv == 52)) return 17;
        if ((uvu == 44) && (uvv == 64)) return 17;
        if ((uvu == 48) && (uvv == 64)) return 17;
        if ((uvu == 56) && (uvv == 20)) return 23;
        if ((uvu == 52) && (uvv == 20)) return 23;
        if ((uvu == 52) && (uvv == 32)) return 23;
        if ((uvu == 56) && (uvv == 32)) return 23;
        if ((uvu == 32) && (uvv == 52)) return 29;
        if ((uvu == 28) && (uvv == 52)) return 29;
        if ((uvu == 28) && (uvv == 64)) return 29;
        if ((uvu == 32) && (uvv == 64)) return 29;
        if ((uvu == 16) && (uvv == 20)) return 35;
        if ((uvu == 12) && (uvv == 20)) return 35;
        if ((uvu == 12) && (uvv == 32)) return 35;
        if ((uvu == 16) && (uvv == 32)) return 35;
        if ((uvu == 64) && (uvv == 8)) return 41;
        if ((uvu == 56) && (uvv == 8)) return 41;
        if ((uvu == 56) && (uvv == 16)) return 41;
        if ((uvu == 64) && (uvv == 16)) return 41;
        if ((uvu == 16) && (uvv == 36)) return 47;
        if ((uvu == 12) && (uvv == 36)) return 47;
        if ((uvu == 12) && (uvv == 48)) return 47;
        if ((uvu == 16) && (uvv == 48)) return 47;
        if ((uvu == 16) && (uvv == 52)) return 53;
        if ((uvu == 12) && (uvv == 52)) return 53;
        if ((uvu == 12) && (uvv == 64)) return 53;
        if ((uvu == 16) && (uvv == 64)) return 53;
        if ((uvu == 64) && (uvv == 52)) return 59;
        if ((uvu == 60) && (uvv == 52)) return 59;
        if ((uvu == 60) && (uvv == 64)) return 59;
        if ((uvu == 64) && (uvv == 64)) return 59;
        if ((uvu == 56) && (uvv == 36)) return 65;
        if ((uvu == 52) && (uvv == 36)) return 65;
        if ((uvu == 52) && (uvv == 48)) return 65;
        if ((uvu == 56) && (uvv == 48)) return 65;
        if ((uvu == 40) && (uvv == 36)) return 71;
        if ((uvu == 32) && (uvv == 36)) return 71;
        if ((uvu == 32) && (uvv == 48)) return 71;
        if ((uvu == 40) && (uvv == 48)) return 71;
        return -1;
    }
    return -1;
}
#endif

void initVanillaUV(int faceId, bool isAlex){
    initVanillaUV2(faceId, isAlex);
    vanillaCenterUV = (vanillaMinUV + vanillaMaxUV) / 2.0;
}
// Can be optimized
void initVanillaUV2(int faceId, bool isAlex){
    switch(faceId) {
    // +---------------------+
    // |    PRIMARY LAYER    |
    // +---------------------+
    // ======== Head ========
        case 0: //Left Head
            vanillaMinUV = vec2(48-32, 8)/64.0;
            vanillaMaxUV = vec2(56-32, 16)/64.0;
            return;
        case 1: //Right Head
            vanillaMinUV = vec2(32-32, 8)/64.0;
            vanillaMaxUV = vec2(40-32, 16)/64.0;
            return;
        case 2: //Top Head
            vanillaMinUV = vec2(40-32, 0)/64.0;
            vanillaMaxUV = vec2(48-32, 8)/64.0;
            return;
        case 3: //Bottom Head
            vanillaMinUV = vec2(48-32, 0)/64.0;
            vanillaMaxUV = vec2(56-32, 8)/64.0;
            return;
        case 4: //Front Head
            vanillaMinUV = vec2(40-32, 8)/64.0;
            vanillaMaxUV = vec2(48-32, 16)/64.0;
            return;
        case 5: //Back Head
            vanillaMinUV = vec2(56-32, 8)/64.0;
            vanillaMaxUV = vec2(64-32, 16)/64.0;
            return;

        // ======== Body ========
        case 6: //Left Body
            vanillaMinUV = vec2(28, 36-16)/64.0;
            vanillaMaxUV = vec2(32, 48-16)/64.0;
            return;
        case 7: //Right Body
            vanillaMinUV = vec2(16, 36-16)/64.0;
            vanillaMaxUV = vec2(20, 48-16)/64.0;
            return;
        case 8: //Front Body
            vanillaMinUV = vec2(20, 36-16)/64.0;
            vanillaMaxUV = vec2(28, 48-16)/64.0;
            return;
        case 9: //Back Body
            vanillaMinUV = vec2(32, 36-16)/64.0;
            vanillaMaxUV = vec2(40, 48-16)/64.0;
            return;
        case 10: //Top Body
            vanillaMinUV = vec2(20, 32-16)/64.0;
            vanillaMaxUV = vec2(28, 36-16)/64.0;
            return;
        case 11: //Bottom Body
            vanillaMinUV = vec2(28, 32-16)/64.0;
            vanillaMaxUV = vec2(36, 36-16)/64.0;
            return;

        // ======== R-Arm ========
        case 12: //Left R-Arm
            if(isAlex){
                vanillaMinUV = vec2(48-1, 36-16)/64.0;
                vanillaMaxUV = vec2(52-1, 48-16)/64.0;
            } else {
                vanillaMinUV = vec2(48, 36-16)/64.0;
                vanillaMaxUV = vec2(52, 48-16)/64.0;
            }
            return;
        case 13: //Right R-Arm
            vanillaMinUV = vec2(40, 36-16)/64.0;
            vanillaMaxUV = vec2(44, 48-16)/64.0;
            return;
        case 14: //Top R-Arm
            if(isAlex){
                vanillaMinUV = vec2(44, 32-16)/64.0;
                vanillaMaxUV = vec2(48-1, 36-16)/64.0;
            } else {
                vanillaMinUV = vec2(44, 32-16)/64.0;
                vanillaMaxUV = vec2(48, 36-16)/64.0;
            }
            return;
        case 15: //Bottom R-Arm
            if(isAlex){
                vanillaMinUV = vec2(48-1, 32-16)/64.0;
                vanillaMaxUV = vec2(52-2, 36-16)/64.0;
            } else {
                vanillaMinUV = vec2(48, 32-16)/64.0;
                vanillaMaxUV = vec2(52, 36-16)/64.0;
            }
            return;
        case 16: //Front R-Arm
            if(isAlex){
                vanillaMinUV = vec2(44, 36-16)/64.0;
                vanillaMinUV = vec2(48-1, 48-16)/64.0;
            } else {
                vanillaMinUV = vec2(44, 36-16)/64.0;
                vanillaMinUV = vec2(48, 48-16)/64.0;
            }
            return;
        case 17: //Back R-Arm
            if(isAlex){
                vanillaMinUV = vec2(52-1, 36-16)/64.0;
                vanillaMaxUV = vec2(56-2, 48-16)/64.0;
            } else {
                vanillaMinUV = vec2(52, 36-16)/64.0;
                vanillaMaxUV = vec2(56, 48-16)/64.0;
            }
            return;

        // ======== L-Arm ========
        case 18: //Left L-Arm
            if(isAlex){
                vanillaMinUV = vec2(8+48-1-16, 52)/64.0;
                vanillaMaxUV = vec2(12+48-1-16, 64)/64.0;
            } else {
                vanillaMinUV = vec2(8+48-16, 52)/64.0;
                vanillaMaxUV = vec2(12+48-16, 64)/64.0;
            }
            return;
        case 19: //Right L-Arm
            vanillaMinUV = vec2(0+48-16, 52)/64.0;
            vanillaMaxUV = vec2(4+48-16, 64)/64.0;
            return;
        case 20: //Top L-Arm
            if(isAlex){
                vanillaMinUV = vec2(4+48-16, 48)/64.0;
                vanillaMaxUV = vec2(8+48-1-16, 52)/64.0;
            } else {
                vanillaMinUV = vec2(4+48-16, 48)/64.0;
                vanillaMaxUV = vec2(8+48-16, 52)/64.0;
            }
            return;
        case 21: //Bottom L-Arm
            if(isAlex){
                vanillaMinUV = vec2(8+48-1-16, 48)/64.0;
                vanillaMaxUV = vec2(12+48-2-16, 52)/64.0;
            } else {
                vanillaMinUV = vec2(8+48-16, 48)/64.0;
                vanillaMaxUV = vec2(12+48-16, 52)/64.0;
            }
            return;
        case 22: //Front L-Arm
            if(isAlex){
                vanillaMinUV = vec2(4+48-16, 52)/64.0;
                vanillaMaxUV = vec2(8+48-1-16, 64)/64.0;
            } else {
                vanillaMinUV = vec2(4+48-16, 52)/64.0;
                vanillaMaxUV = vec2(8+48-16, 64)/64.0;
            }
            return;
        case 23: //Back L-Arm
            if(isAlex){
                vanillaMinUV = vec2(12+48-1-16, 52)/64.0;
                vanillaMaxUV = vec2(16+48-2-16, 64)/64.0;
            } else {
                vanillaMinUV = vec2(12+48-16, 52)/64.0;
                vanillaMaxUV = vec2(16+48-16, 64)/64.0;
            }
            return;

        // ======== R-Leg ========
        case 24: //Left R-Leg
            vanillaMinUV = vec2(8, 36-16)/64.0;
            vanillaMaxUV = vec2(12, 48-16)/64.0;
            return;
        case 25: //Right R-Leg
            vanillaMinUV = vec2(0, 36-16)/64.0;
            vanillaMaxUV = vec2(4, 48-16)/64.0;
            return;
        case 26: //Top R-Leg
            vanillaMinUV = vec2(4, 32-16)/64.0;
            vanillaMaxUV = vec2(8, 36-16)/64.0;
            return;
        case 27: //Bottom R-Leg
            vanillaMinUV = vec2(8, 32-16)/64.0;
            vanillaMaxUV = vec2(12, 36-16)/64.0;
            return;
        case 28: //Front R-Leg
            vanillaMinUV = vec2(4, 36-16)/64.0;
            vanillaMaxUV = vec2(8, 48-16)/64.0;
            return;
        case 29: //Back R-Leg
            vanillaMinUV = vec2(12, 36-16)/64.0;
            vanillaMaxUV = vec2(16, 48-16)/64.0;
            return;

        // ======== L-Leg ========
        case 30: //Left L-Leg
            vanillaMinUV = vec2(8+16, 52)/64.0;
            vanillaMaxUV = vec2(12+16, 64)/64.0;
            return;
        case 31: //Right L-Leg
            vanillaMinUV = vec2(0+16, 52)/64.0;
            vanillaMaxUV = vec2(4+16, 64)/64.0;
            return;
        case 32: //Top L-Leg
            vanillaMinUV = vec2(4+16, 48)/64.0;
            vanillaMaxUV = vec2(8+16, 52)/64.0;
            return;
        case 33: //Bottom L-Leg
            vanillaMinUV = vec2(8+16, 48)/64.0;
            vanillaMaxUV = vec2(12+16, 52)/64.0;
            return;
        case 34: //Front L-Leg
            vanillaMinUV = vec2(4+16, 52)/64.0;
            vanillaMaxUV = vec2(8+16, 64)/64.0;
            return;
        case 35: //Back L-Leg
            vanillaMinUV = vec2(12+16, 52)/64.0;
            vanillaMaxUV = vec2(16+16, 64)/64.0;
            return;

    // +---------------------+
    // |   SECONDARY LAYER   |
    // +---------------------+
        // ======== Hat ========
        case 36: //Left Hat
            vanillaMinUV = vec2(48, 8)/64.0;
            vanillaMaxUV = vec2(56, 16)/64.0;
            return;
        case 37: //Right Hat
            vanillaMinUV = vec2(32, 8)/64.0;
            vanillaMaxUV = vec2(40, 16)/64.0;
            return;
        case 38: //Top Hat
            vanillaMinUV = vec2(40, 0)/64.0;
            vanillaMaxUV = vec2(48, 8)/64.0;
            return;
        case 39: //Bottom Hat
            vanillaMinUV = vec2(48, 0)/64.0;
            vanillaMaxUV = vec2(56, 8)/64.0;
            return;
        case 40: //Front Hat
            vanillaMinUV = vec2(40, 8)/64.0;
            vanillaMaxUV = vec2(48, 16)/64.0;
            return;
        case 41: //Back Hat
            vanillaMinUV = vec2(56, 8)/64.0;
            vanillaMaxUV = vec2(64, 16)/64.0;
            return;

        // ======== L-pant ========
        case 42: //Left L-Pant
            vanillaMinUV = vec2(8, 52)/64.0;
            vanillaMaxUV = vec2(12, 64)/64.0;
            return;
        case 43: //Right L-Pant
            vanillaMinUV = vec2(0, 52)/64.0;
            vanillaMaxUV = vec2(4, 64)/64.0;
            return;
        case 44: //Top L-Pant
            vanillaMinUV = vec2(4, 48)/64.0;
            vanillaMaxUV = vec2(8, 52)/64.0;
            return;
        case 45: //Bottom L-Pant
            vanillaMinUV = vec2(8, 48)/64.0;
            vanillaMaxUV = vec2(12, 52)/64.0;
            return;
        case 46: //Front L-Pant
            vanillaMinUV = vec2(4, 52)/64.0;
            vanillaMaxUV = vec2(8, 64)/64.0;
            return;
        case 47: //Back L-Pant
            vanillaMinUV = vec2(12, 52)/64.0;
            vanillaMaxUV = vec2(16, 64)/64.0;
            return;

        // ======== R-Pant ========
        case 48: //Left R-Pant
            vanillaMinUV = vec2(8, 36)/64.0;
            vanillaMaxUV = vec2(12, 48)/64.0;
            return;
        case 49: //Right R-Pant
            vanillaMinUV = vec2(0, 36)/64.0;
            vanillaMaxUV = vec2(4, 48)/64.0;
            return;
        case 50: //Top R-Pant
            vanillaMinUV = vec2(4, 32)/64.0;
            vanillaMaxUV = vec2(8, 36)/64.0;
            return;
        case 51: //Bottom R-Pant
            vanillaMinUV = vec2(8, 32)/64.0;
            vanillaMaxUV = vec2(12, 36)/64.0;
            return;
        case 52: //Front R-Pant
            vanillaMinUV = vec2(4, 36)/64.0;
            vanillaMaxUV = vec2(8, 48)/64.0;
            return;
        case 53: //Back R-Pant
            vanillaMinUV = vec2(12, 36)/64.0;
            vanillaMaxUV = vec2(16, 48)/64.0;
            return;

        // ======== L-Shirt ========
        case 54: //Left L-Shirt
            if(isAlex){
                vanillaMinUV = vec2(8+48-1, 52)/64.0;
                vanillaMaxUV = vec2(12+48-1, 64)/64.0;
            } else {
                vanillaMinUV = vec2(8+48, 52)/64.0;
                vanillaMaxUV = vec2(12+48, 64)/64.0;
            }
            return;
        case 55: //Right L-Shirt
            vanillaMinUV = vec2(0+48, 52)/64.0;
            vanillaMaxUV = vec2(4+48, 64)/64.0;
            return;
        case 56: //Top L-Shirt
            if(isAlex){
                vanillaMinUV = vec2(4+48, 48)/64.0;
                vanillaMaxUV = vec2(8+48-1, 52)/64.0;
            } else {
                vanillaMinUV = vec2(4+48, 48)/64.0;
                vanillaMaxUV = vec2(8+48, 52)/64.0;
            }
            return;
        case 57: //Bottom L-Shirt
            if(isAlex){
                vanillaMinUV = vec2(8+48-1, 48)/64.0;
                vanillaMaxUV = vec2(12+48-2, 52)/64.0;
            } else {
                vanillaMinUV = vec2(8+48, 48)/64.0;
                vanillaMaxUV = vec2(12+48, 52)/64.0;
            }
            return;
        case 58: //Front L-Shirt
            if(isAlex){
                vanillaMinUV = vec2(4+48, 52)/64.0;
                vanillaMaxUV = vec2(8+48-1, 64)/64.0;
            } else {
                vanillaMinUV = vec2(4+48, 52)/64.0;
                vanillaMaxUV = vec2(8+48, 64)/64.0;
            }
            return;
        case 59: //Back L-Shirt
            if(isAlex){
                vanillaMinUV = vec2(12+48-1, 52)/64.0;
                vanillaMaxUV = vec2(16+48-2, 64)/64.0;
            } else {
                vanillaMinUV = vec2(12+48, 52)/64.0;
                vanillaMaxUV = vec2(16+48, 64)/64.0;
            }
            return;

        // ======== R-Shirt ========
        case 60: //Left R-Shirt
            if(isAlex){
                vanillaMinUV = vec2(48-1, 36)/64.0;
                vanillaMaxUV = vec2(52-1, 48)/64.0;
            } else {
                vanillaMinUV = vec2(48, 36)/64.0;
                vanillaMaxUV = vec2(52, 48)/64.0;
            }
            return;
        case 61: //Right R-Shirt
            vanillaMinUV = vec2(40, 36)/64.0;
            vanillaMaxUV = vec2(44, 48)/64.0;
            return;
        case 62: //Top R-Shirt
            if(isAlex){
                vanillaMinUV = vec2(44, 32)/64.0;
                vanillaMaxUV = vec2(48-1, 36)/64.0;
            } else {
                vanillaMinUV = vec2(44, 32)/64.0;
                vanillaMaxUV = vec2(48, 36)/64.0;
            }
            return;
        case 63: //Bottom R-Shirt
            if(isAlex){
                vanillaMinUV = vec2(48-1, 32)/64.0;
                vanillaMaxUV = vec2(52-2, 36)/64.0;
            } else {
                vanillaMinUV = vec2(48, 32)/64.0;
                vanillaMaxUV = vec2(52, 36)/64.0;
            }
            return;
        case 64: //Front R-Shirt
            if(isAlex){
                vanillaMinUV = vec2(44, 36)/64.0;
                vanillaMinUV = vec2(48-1, 48)/64.0;
            } else {
                vanillaMinUV = vec2(44, 36)/64.0;
                vanillaMinUV = vec2(48, 48)/64.0;
            }
            return;
        case 65: //Back R-Shirt
            if(isAlex){
                vanillaMinUV = vec2(52-1, 36)/64.0;
                vanillaMaxUV = vec2(56-2, 48)/64.0;
            } else {
                vanillaMinUV = vec2(52, 36)/64.0;
                vanillaMaxUV = vec2(56, 48)/64.0;
            }
            return;

        // ======== Shirt ========
        // NOTE THE DIFFERENT ORDER
        case 66: //Left Shirt
            vanillaMinUV = vec2(28, 36)/64.0;
            vanillaMaxUV = vec2(32, 48)/64.0;
            return;
        case 67: //Right Shirt
            vanillaMinUV = vec2(16, 36)/64.0;
            vanillaMaxUV = vec2(20, 48)/64.0;
            return;
        case 68: //Top Shirt
            vanillaMinUV = vec2(20, 32)/64.0;
            vanillaMaxUV = vec2(28, 36)/64.0;
            return;
        case 69: //Bottom Shirt
            vanillaMinUV = vec2(28, 32)/64.0;
            vanillaMaxUV = vec2(36, 36)/64.0;
            return;
        case 70: //Front Shirt
            vanillaMinUV = vec2(20, 36)/64.0;
            vanillaMaxUV = vec2(28, 48)/64.0;
            return;
        case 71: //Back Shirt
            vanillaMinUV = vec2(32, 36)/64.0;
            vanillaMaxUV = vec2(40, 48)/64.0;
            return;
    }
}