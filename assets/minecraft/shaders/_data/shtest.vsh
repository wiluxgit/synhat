/*#version 330

uniform mat4 ProjMat;
uniform mat4 ModelViewMat;

layout (location = 0) in vec3 Position;
layout (location = 1) in vec3 Normal;
layout (location = 2) in vec2 uv;

out vec4 p_color;
out vec2 p_uv;

void main() {
   p_color = vec4(abs(Normal), 1.0);
   p_uv = uv;
   gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);
}*/


#version 330

//#moj_import <light.glsl>

layout (location = 0) in vec3 Position;
layout (location = 1) in vec3 Normal;
layout (location = 2) in vec2 UV0;

uniform sampler2D Sampler0;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

out highp float vertexDistance;
out highp vec4 vertexColor;
out highp vec4 lightMapColor;
out highp vec4 overlayColor;
out highp vec2 texCoord0;
out highp vec4 normal;

out highp vec2 wx_scalingOrigin;
out highp vec2 wx_scaling;
out highp vec2 wx_maxUV;
out highp vec2 wx_minUV;
out highp vec2 wx_UVDisplacement;
out highp float wx_isEdited;

#define AS_OUTER (32.0)   // how long to stretch along normal to simulate 90 deg face

#define TRANSFORM_NONE (0<<4)
#define TRANSFORM_OUTER (1<<4)
#define TRANSFORM_OUTER_REVERSED (2<<4)
#define TRANSFORM_INNER_REVERSED (3<<4)
#define SCALEDIR_X_PLUS (0<<6)
#define SCALEDIR_X_MINUS (1<<6)
#define SCALEDIR_Y_PLUS (2<<6)
#define SCALEDIR_Y_MINUS (3<<6)
#define F_ENABLED (0x80)

int getPerpendicularLength(int faceId, bool isAlex);
void writeUVBounds(int faceId, bool isAlex);

void main() {
    vertexDistance = length((ModelViewMat * vec4(Position, 1.0)).xyz);
    vertexColor = vec4(1,1,0,1);
    if (gl_VertexID == 10) {
    	vertexColor = vec4(1,0,1,1);
    }
    
    texCoord0 = UV0;
    normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);  

    wx_isEdited = 0.0;

    if (true) { //(gl_VertexID >= 18*8){ //is second layer
        vec4 topRightPixel = texelFetch(Sampler0, ivec2(0, 0), 0)*256.0; //Macs can't texelfetch in vertex shader?
        int header0 = int(topRightPixel.r + 0.1);
        int header1 = int(topRightPixel.g + 0.1);
        int header2 = int(topRightPixel.b + 0.1);

        if (true){ //(header0 == 0xda && header1 == 0x67){ 
            bool isAlex = (header2 == 1);

            int faceId = gl_VertexID / 4;
            int cornerId = gl_VertexID % 4;

            vec3 newPos = Position;
            vec4 pxData = texelFetch(Sampler0, ivec2((faceId-8)%8, (faceId-8)/8), 0)*256.0;
            int data0 = int(pxData.r+0.1);
            int data1 = int(pxData.g+0.1);
            int data2 = int(pxData.b+0.1); 
            
            //<debug>
            switch(faceId) {    
            //case 36: data0 = (1<<0) | (1<<3) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_X_PLUS; break; // Left hat
            //case 37: data0 = (1<<1) | (1<<2) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_X_MINUS; break; // Right hat
            //case 38: data0 = (1<<0) | (1<<1) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_Y_MINUS; break; // Top hat 
            //case 39: data0 = (1<<2) | (1<<3) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_Y_MINUS; break; // Bottom hat 
            
            //case 54: data0 = (1<<0) | (1<<3) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_X_PLUS; break; // Left L-Shirt
            //case 55: data0 = (1<<1) | (1<<2) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_X_MINUS; break; // Right L-Shirt
            //case 56: data0 = (1<<0) | (1<<1) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_Y_MINUS; break; // Top L-Shirt 
            //case 57: data0 = (1<<2) | (1<<3) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_Y_MINUS; break; // Bottom L-Shirt 

            //case 42: data0 = (1<<0) | (1<<3) | TRANSFORM_OUTER | F_ENABLED; data1 = SCALEDIR_X_PLUS; break; // Left L-Pant
            //case 43: data0 = (1<<1) | (1<<2) | TRANSFORM_OUTER | F_ENABLED; data1 = SCALEDIR_X_MINUS; break; // Right L-Pant
            //case 44: data0 = (1<<0) | (1<<1) | TRANSFORM_OUTER | F_ENABLED; data1 = SCALEDIR_Y_MINUS; break; // Top L-Pant 
            //case 45: data0 = (1<<2) | (1<<3) | TRANSFORM_OUTER | F_ENABLED; data1 = SCALEDIR_Y_MINUS; break; // Bottom L-Pant 

            //case 67: data0 = (1<<0) | (1<<3) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_X_PLUS; break;  //Right jacket
            //case 66: data0 = (1<<1) | (1<<2) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_X_MINUS; break;  //Left jacket
            //case 69: data0 = (1<<0) | (1<<1) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_Y_PLUS; break;  //Bottom jacket
            //case 71: data0 = (1<<2) | (1<<3) | TRANSFORM_INNER_REVERSED | F_ENABLED; data1 = SCALEDIR_Y_PLUS; break;  //Back jacket
            }
            //</debug>

            if((data0 & F_ENABLED) != 0){
                wx_isEdited = 1.0; 

                writeUVBounds(faceId, isAlex);
                
                int cornerBits = data0 & 0xf;
                int transformType = data0 & 0x70;
                int uvX = data1 & 0x3F;
                int uvY = data2 & 0x3F;
                int strechDirection = data1 & 0xC0;

                switch(strechDirection){
                    case SCALEDIR_X_PLUS: 
                        wx_scalingOrigin = vec2(wx_minUV.x, (wx_maxUV.y+wx_minUV.y)/2.0);
                        break;
                    case SCALEDIR_X_MINUS: 
                        wx_scalingOrigin = vec2(wx_maxUV.x, (wx_maxUV.y+wx_minUV.y)/2.0);
                        break;
                    case SCALEDIR_Y_PLUS: 
                        wx_scalingOrigin = vec2((wx_maxUV.x+wx_minUV.x)/2.0, wx_minUV.y);
                        break;
                    case SCALEDIR_Y_MINUS: 
                        wx_scalingOrigin = vec2((wx_maxUV.x+wx_minUV.x)/2.0, wx_maxUV.y);
                        break;
                }

                bool isSelectedCorner = ((1<<cornerId) & cornerBits) != 0;
                vec2 size = wx_maxUV-wx_minUV; //Could be used to generalize wx_scaling i think

                if(float(uvX)/64.0 + wx_minUV.x >= 1.0) uvX -= 64; // Seeings as UV frag cut is capped inside 0..1 this 
                if(float(uvY)/64.0 + wx_minUV.y >= 1.0) uvY -= 64; //  is needed for wrapping offsets
                wx_UVDisplacement = vec2(uvX,uvY) / 64.0;

                switch(transformType) {                    
                    case TRANSFORM_OUTER:
                        if(isSelectedCorner) 
                            newPos += Normal*AS_OUTER;
                        switch(strechDirection) {
                            case SCALEDIR_X_PLUS: 
                            case SCALEDIR_X_MINUS: 
                                wx_scaling = vec2(AS_OUTER/(size.x*4.0), 1);
                                break;
                            case SCALEDIR_Y_PLUS: 
                            case SCALEDIR_Y_MINUS: 
                                wx_scaling = vec2(1, AS_OUTER/(size.y*4.0));
                                break;
                            }
                        break;
                    case TRANSFORM_OUTER_REVERSED:
                        float perpLen1 = float(getPerpendicularLength(faceId, isAlex));

                        newPos -= Normal*(perpLen1/16.0);
                        if(isSelectedCorner) 
                            newPos -= Normal*AS_OUTER;
                        switch(strechDirection) {
                            case SCALEDIR_X_PLUS: 
                            case SCALEDIR_X_MINUS: 
                                wx_scaling = vec2(AS_OUTER/(size.x*4.0), 1);
                                break;
                            case SCALEDIR_Y_PLUS: 
                            case SCALEDIR_Y_MINUS: 
                                wx_scaling = vec2(1, AS_OUTER/(size.y*4.0));
                                break;
                            }
                        break;

                    case TRANSFORM_INNER_REVERSED: // kinda broken for most faces
                        float perpLen2 = float(getPerpendicularLength(faceId, isAlex));

                        if(isSelectedCorner) 
                            newPos -= Normal*perpLen2;
                        switch(strechDirection) {
                            case SCALEDIR_X_PLUS: 
                                wx_scaling = vec2(perpLen2/(size.x*4.0), 1.12);
                                wx_minUV += vec2(perpLen2, 0)/64.0;
                                wx_maxUV += vec2(perpLen2, 0)/64.0;
                                wx_UVDisplacement += vec2(perpLen2, 0)/64.0; 
                                break;
                            case SCALEDIR_X_MINUS: 
                                wx_scaling = vec2(perpLen2/(size.x*4.0), 1.12);
                                wx_minUV -= vec2(perpLen2, 0)/64.0;
                                wx_maxUV -= vec2(perpLen2, 0)/64.0;
                                wx_UVDisplacement += vec2(perpLen2, 0)/64.0; 
                                break;
                            case SCALEDIR_Y_PLUS: 
                                wx_scaling = vec2(1.12, perpLen2/(size.y*4.0));                                
                                wx_minUV += vec2(0, perpLen2)/64.0; 
                                wx_maxUV += vec2(0, perpLen2)/64.0;
                                wx_UVDisplacement += vec2(0, perpLen2)/64.0; 
                                break;
                            case SCALEDIR_Y_MINUS: 
                                wx_scaling = vec2(1.12, perpLen2/(size.y*4.0));                                
                                wx_minUV -= vec2(0, perpLen2)/64.0; 
                                wx_maxUV -= vec2(0, perpLen2)/64.0;
                                wx_UVDisplacement += vec2(0, perpLen2)/64.0; 
                                break;
                            }
                        break;
                }

                gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);
                return;
            }
        }        
    }   
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);
    return;
}

// retuns the length (in pixels) to the back face for a given face
int getPerpendicularLength(int faceId, bool isAlex) {
    int facetype = faceId/6;
    int faceAxis = faceId%6;
    int perpendicularLength;
    switch(facetype) {
        case 6: //Head
            return 8;
        case 7: // L-Pant
        case 8: // R-Pant
            if(faceAxis == 2 || faceAxis == 3){ // Top/Bot
                return 12;
            } else {
                return 4;
            }
        case 9: // R-Arm
        case 10: // L-Arm
            if(faceAxis == 2 || faceAxis == 3){ // Top/Bot
                return 12;
            } else {
                return isAlex ? 3 : 4; // Account for Alex models
            }
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

// Can be optimized
void writeUVBounds(int faceId, bool isAlex){
    switch(faceId){
    // ======== Hat ========
    case 36: //Left Hat
        wx_minUV = vec2(48, 8)/64.0;
        wx_maxUV = vec2(56, 16)/64.0;
        return;
    case 37: //Right Hat
        wx_minUV = vec2(32, 8)/64.0;
        wx_maxUV = vec2(40, 16)/64.0;
        return;
    case 38: //Top Hat
        wx_minUV = vec2(40, 0)/64.0;
        wx_maxUV = vec2(48, 8)/64.0;
        return;
    case 39: //Bottom Hat
        wx_minUV = vec2(48, 0)/64.0;
        wx_maxUV = vec2(56, 8)/64.0;
        return;
    case 40: //Front Hat
        wx_minUV = vec2(40, 8)/64.0;
        wx_maxUV = vec2(48, 16)/64.0;
        return;
    case 41: //Back Hat
        wx_minUV = vec2(56, 8)/64.0;
        wx_maxUV = vec2(64, 16)/64.0;
        return;

    // ======== L-pant ========
    case 42: //Left L-Pant
        wx_minUV = vec2(8, 52)/64.0;
        wx_maxUV = vec2(12, 64)/64.0;
        return;
    case 43: //Right L-Pant
        wx_minUV = vec2(0, 52)/64.0;
        wx_maxUV = vec2(4, 64)/64.0;
        return;
    case 44: //Top L-Pant
        wx_minUV = vec2(4, 48)/64.0;
        wx_maxUV = vec2(8, 52)/64.0;
        return;
    case 45: //Bottom L-Pant
        wx_minUV = vec2(8, 48)/64.0;
        wx_maxUV = vec2(12, 52)/64.0;
        return;
    case 46: //Front L-Pant
        wx_minUV = vec2(4, 52)/64.0;
        wx_maxUV = vec2(8, 64)/64.0;
        return;
    case 47: //Back L-Pant
        wx_minUV = vec2(12, 52)/64.0;
        wx_maxUV = vec2(16, 64)/64.0;
        return;

    // ======== R-Pant ========
    case 48: //Left R-Pant
        wx_minUV = vec2(8, 36)/64.0;
        wx_maxUV = vec2(12, 48)/64.0;
        return;
    case 49: //Right R-Pant
        wx_minUV = vec2(0, 36)/64.0;
        wx_maxUV = vec2(4, 48)/64.0;
        return;
    case 50: //Top R-Pant
        wx_minUV = vec2(4, 32)/64.0;
        wx_maxUV = vec2(8, 36)/64.0;
        return;
    case 51: //Bottom R-Pant
        wx_minUV = vec2(8, 32)/64.0;
        wx_maxUV = vec2(12, 36)/64.0;
        return;
    case 52: //Front R-Pant
        wx_minUV = vec2(4, 36)/64.0;
        wx_maxUV = vec2(8, 48)/64.0;
        return;
    case 53: //Back R-Pant
        wx_minUV = vec2(12, 36)/64.0;
        wx_maxUV = vec2(16, 48)/64.0;
        return;

    // ======== L-Shirt ========
    case 54: //Left L-Shirt
        if(isAlex){
            wx_minUV = vec2(8+48-1, 52)/64.0;
            wx_maxUV = vec2(12+48-1, 64)/64.0;  
        } else {
            wx_minUV = vec2(8+48, 52)/64.0;
            wx_maxUV = vec2(12+48, 64)/64.0;  
        }
        return;
    case 55: //Right L-Shirt
        wx_minUV = vec2(0+48, 52)/64.0;
        wx_maxUV = vec2(4+48, 64)/64.0;
        return;
    case 56: //Top L-Shirt
        if(isAlex){
            wx_minUV = vec2(4+48, 48)/64.0;
            wx_maxUV = vec2(8+48-1, 52)/64.0;
        } else {
            wx_minUV = vec2(4+48, 48)/64.0;
            wx_maxUV = vec2(8+48, 52)/64.0;
        }
        return;
    case 57: //Bottom L-Shirt
        if(isAlex){
            wx_minUV = vec2(8+48-1, 48)/64.0;
            wx_maxUV = vec2(12+48-2, 52)/64.0;
        } else {
            wx_minUV = vec2(8+48, 48)/64.0;
            wx_maxUV = vec2(12+48, 52)/64.0;
        }
        return;
    case 58: //Front L-Shirt
        if(isAlex){
            wx_minUV = vec2(4+48, 52)/64.0;
            wx_maxUV = vec2(8+48-1, 64)/64.0;
        } else {
            wx_minUV = vec2(4+48, 52)/64.0;
            wx_maxUV = vec2(8+48, 64)/64.0;
        }
        return;
    case 59: //Back L-Shirt
        if(isAlex){
            wx_minUV = vec2(12+48-1, 52)/64.0;
            wx_maxUV = vec2(16+48-2, 64)/64.0;
        } else {
            wx_minUV = vec2(12+48, 52)/64.0;
            wx_maxUV = vec2(16+48, 64)/64.0;
        }
        return;

    // ======== R-Shirt ========
    case 60: //Left R-Shirt
        if(isAlex){
            wx_minUV = vec2(48-1, 36)/64.0;
            wx_maxUV = vec2(52-1, 48)/64.0;
        } else {
            wx_minUV = vec2(48, 36)/64.0;
            wx_maxUV = vec2(52, 48)/64.0;
        }
        return;
    case 61: //Right R-Shirt
        wx_minUV = vec2(40, 36)/64.0;
        wx_maxUV = vec2(44, 48)/64.0;
        return;
    case 62: //Top R-Shirt
        if(isAlex){
            wx_minUV = vec2(44, 32)/64.0;
            wx_maxUV = vec2(48-1, 36)/64.0;
        } else {
            wx_minUV = vec2(44, 32)/64.0;
            wx_maxUV = vec2(48, 36)/64.0;
        }
        return;
    case 63: //Bottom R-Shirt
        if(isAlex){
            wx_minUV = vec2(48-1, 32)/64.0;
            wx_maxUV = vec2(52-2, 36)/64.0;
        } else {
            wx_minUV = vec2(48, 32)/64.0;
            wx_maxUV = vec2(52, 36)/64.0;
        }
        return;
    case 64: //Front R-Shirt
        if(isAlex){
            wx_minUV = vec2(44, 36)/64.0;
            wx_minUV = vec2(48-1, 48)/64.0;
        } else {
            wx_minUV = vec2(44, 36)/64.0;
            wx_minUV = vec2(48, 48)/64.0;
        }
        return;
    case 65: //Back R-Shirt
        if(isAlex){
            wx_minUV = vec2(52-1, 36)/64.0;
            wx_maxUV = vec2(56-2, 48)/64.0;
        } else {
            wx_minUV = vec2(52, 36)/64.0;
            wx_maxUV = vec2(56, 48)/64.0;
        }
        return;

    // ======== Shirt ========
    case 66: //Left Shirt
        wx_minUV = vec2(28, 36)/64.0;
        wx_maxUV = vec2(32, 48)/64.0;
        return;
    case 67: //Right Shirt
        wx_minUV = vec2(16, 36)/64.0;
        wx_maxUV = vec2(20, 48)/64.0;
        return;
    case 68: //Top Shirt
        wx_minUV = vec2(20, 32)/64.0;
        wx_maxUV = vec2(28, 36)/64.0;
        return;
    case 69: //Bottom Shirt
        wx_minUV = vec2(28, 32)/64.0;
        wx_maxUV = vec2(36, 36)/64.0;
        return;
    case 70: //Front Shirt
        wx_minUV = vec2(20, 36)/64.0;
        wx_maxUV = vec2(28, 48)/64.0;
        return;
    case 71: //Back Shirt
        wx_minUV = vec2(32, 36)/64.0;
        wx_maxUV = vec2(40, 48)/64.0;
        return;
    }
}