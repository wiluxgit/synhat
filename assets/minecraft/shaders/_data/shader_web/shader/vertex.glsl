uniform sampler2D Sampler0;

#define out out highp

// how long to stretch along normal to simulate 90 deg face
#define AS_OUTER (32.0)

#define MASK_TRANSFROM_TYPE (0x0f)
#define TRANSFROM_TYPE_DISPLACEMENT (0)
#define TRANSFROM_TYPE_UV_CROP (1)
#define TRANSFROM_TYPE_UV_OFFSET (2)
#define TRANSFROM_TYPE_POSTFLAG (3)

#define FLAG_DISP_NEGATIVE (1<<4)
#define FLAG_DISP_ASYM_NEGATIVE (1<<5)
#define FLAG_DISP_OPPOSING_SNAP (1<<6)
//#define FLAG_DISP_UNUSED (3<<6)
#define MASK_DISP_OFFSET (0x3f)
#define MASK_DISP_ASYM_OFFSET (0x3f)
#define MASK_DISP_ASYM_TYPE (0xc0)
#define MASK_DISP_ASYM_DIRECTION (0xc0)
#define DISP_ASYM_DIRECTION_TOP (0<<6)
#define DISP_ASYM_DIRECTION_BOT (1<<6)
#define DISP_ASYM_DIRECTION_RIGHT (2<<6)
#define DISP_ASYM_DIRECTION_LEFT (3<<6)
#define DISP_ASYM_TYPE_SIMPLE (0<<6)
#define DISP_ASYM_TYPE_FLIP_OUT (1<<6)
#define DISP_ASYM_TYPE_FLIP_IN (2<<6)
//#define DISP_ASYM_TYPE_UNUSED (3<<6)

#define OVERLAYSCALE (1.125)

int getPerpendicularLength(int faceId, bool isAlex);
void writeUVBounds(int faceId, bool isAlex);
int getMCVertID();
vec4 getTfDataFromID(int faceDataSourceId);
vec4 colorFromInt(int i); //DEBUG

void applyDisplacement(bool isAlex, int vertId, int data0, int data1, int data2);
void applyUVCrop      (bool isAlex, int vertId, int data0, int data1, int data2);
void applyUVOffset    (bool isAlex, int vertId, int data0, int data1, int data2);
void applyPostFlags   (bool isAlex, int vertId, int data0, int data1, int data2);

bool isSecondaryLayer(int vertId);
int getFaceId(int vertId);
int getCornerId(int vertId);
int getDirId(int vertId);
vec3 pixelNormal();

vec3 NewPosition;

//
mat4 ModelViewMat;
mat4 ProjMat;
vec3 Position;
vec3 Normal;
vec2 UV0;

// WX
out vec2 texCoord0;
out vec2 wx_maxUV;
out vec2 wx_minUV;
out vec4 wx_vertexColor;
out float wx_isEdited;

void main() {
    ModelViewMat = viewMatrix;
    ProjMat = projectionMatrix;
    Position = position;
    Normal = normal;
    UV0 = vec2(uv.x, 1.0-uv.y); //ThreeJS reverses the UV coordinates AND the texture by default
    texCoord0 = UV0;

    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    int mcid = getMCVertID();

    float mcidx = float(mcid)/400.0;
    float mcidy = float((mcid/4)%6)/6.0;
	wx_vertexColor = vec4(mcidx,mcidy,0,1);


    wx_isEdited = 0.0;
    NewPosition = Position;

    if (true) { //(gl_VertexID >= 18*8){ //is second layer
        vec4 topRightPixel = texelFetch(Sampler0, ivec2(0, 0), 0)*256.0; //Macs can't texelfetch in vertex shader?
        int header0 = int(topRightPixel.r + 0.1);
        int header1 = int(topRightPixel.g + 0.1);
        int header2 = int(topRightPixel.b + 0.1);

        if (header0 == 0xda && header1 == 0x67) {
            bool isAlex = (header2 == 1);

            int faceId = getFaceId(mcid);
            int cornerId = getCornerId(mcid);

			int fileoffset = faceId + (4*6);
			int dataC = fileoffset % 4;
			int dataX = (fileoffset / 4) % 8;
			int dataY = (fileoffset / (8*4));

			vec4 srcPixel = texelFetch(Sampler0, ivec2(dataX,dataY), 0)*256.0;

			//<DEBUG>
			switch(faceId) {
				case 38: // top hat
					srcPixel = vec4(1,1,1,1); //use data block 1
					break;
			}
			//</DEBUG>


			int faceDataSourceId = int(srcPixel[dataC]+0.1);

			wx_vertexColor = colorFromInt(faceDataSourceId);

			while (faceDataSourceId != 0 && faceDataSourceId != 255) {
				wx_isEdited = 1.0;

				vec4 transformData = getTfDataFromID(faceDataSourceId);

            	int data0 = int(transformData.r+0.1);
        	    int data1 = int(transformData.g+0.1);
    	        int data2 = int(transformData.b+0.1);
	            int data3 = int(transformData.a+0.1);

	            int type = MASK_TRANSFROM_TYPE & data0;

	            switch (type) {
	            	case TRANSFROM_TYPE_DISPLACEMENT:
	            		applyDisplacement(isAlex, mcid, data0, data1, data2);
	            		break;
	            	case TRANSFROM_TYPE_UV_CROP:
	            		applyUVCrop(isAlex, mcid, data0, data1, data2);
	            		break;
	            	case TRANSFROM_TYPE_UV_OFFSET:
	            		applyUVOffset(isAlex, mcid, data0, data1, data2);
	            		break;
	            	case TRANSFROM_TYPE_POSTFLAG:
	            		applyPostFlags(isAlex, mcid, data0, data1, data2);
	            		break;
	            }

	            // read last 8 bits (alpha bits), if not UV_OFFSET (since that consuemes all bytes)
	        	if (type != TRANSFROM_TYPE_UV_OFFSET) {
	        		faceDataSourceId = data3;
	        	} else {
	        		faceDataSourceId = 0;
	        	}
                faceDataSourceId = 0;
			}

			//if (wx_isEdited) {
			//	writeDeaults()
			//}
        }
    }
    gl_Position = ProjMat * ModelViewMat * vec4(NewPosition, 1.0);
    return;
    //normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);
}

void applyDisplacement(bool isAlex, int vertId, int data0, int data1, int data2) {
	bool isNegativeOffset 			 = (data0 & FLAG_DISP_NEGATIVE) != 0;
	bool opposingSnap				 = (data0 & FLAG_DISP_OPPOSING_SNAP) != 0;
	bool asymmetric_isNegativeOffset = (data0 & FLAG_DISP_ASYM_NEGATIVE) != 0;

	float offset					 = float(data1 & MASK_DISP_OFFSET);
	int assymetric_type 			 = data1 & MASK_DISP_ASYM_TYPE;
	float assymetric_offset 		 = float(data2 & MASK_DISP_ASYM_OFFSET);
	int assymetric_direction 		 = data2 & MASK_DISP_ASYM_DIRECTION;

	int faceId = getFaceId(vertId);
	int cornerId = getCornerId(vertId);
	int dirId = getDirId(vertId);
	bool isSecondary = isSecondaryLayer(vertId);
	int perpLenPixels = getPerpendicularLength(faceId, isAlex);

	float directionMod = 1.0;
	if (isNegativeOffset) {
		directionMod = -1.0;
	}
	float asymmetric_directionMod = 1.0;
	if (asymmetric_isNegativeOffset) {
		asymmetric_directionMod = -1.0;
	}
	float pixelSize = 1.0;
	if (isSecondary != opposingSnap) { // isSecondary XOR snapToOpposing
		pixelSize = OVERLAYSCALE;
	}

	bool ignoreSnap = (assymetric_type == DISP_ASYM_TYPE_FLIP_IN); //hacky yes
	if (opposingSnap && !ignoreSnap) {
		float snapDirection = 1.0;
		if (isSecondary) {
			snapDirection = -1.0;
		}
		float layerExtention = snapDirection * (OVERLAYSCALE - 1.0) * float(perpLenPixels) / 2.0;
		NewPosition += pixelNormal() * layerExtention;
	}
	NewPosition += pixelNormal() * offset * pixelSize * directionMod;

	const int[8] corners1 = int[8](0, 2, 0, 1, 2, 0, 3, 2);
	const int[8] corners2 = int[8](1, 3, 3, 2, 3, 1, 1, 0);
	int cornIndex = (assymetric_direction >> 6) | (dirId == 5 ? 1<<3 : 0);
	int corner1 = corners1[cornIndex];
	int corner2 = corners2[cornIndex];

	if (cornerId == corner1 || cornerId == corner2) {
		switch (assymetric_type) {
			case DISP_ASYM_TYPE_SIMPLE:
				NewPosition += pixelNormal() * pixelSize * assymetric_offset * directionMod;
				break;
			case DISP_ASYM_TYPE_FLIP_OUT:
				NewPosition += pixelNormal() * pixelSize * AS_OUTER * directionMod;
				//TODO: uv stuff
				break;
			case DISP_ASYM_TYPE_FLIP_IN:
				// does not work for inner faces
				float backheight = 19.125 * float(perpLenPixels);
				NewPosition -= pixelNormal() * 1.0 * backheight;
				//TODO: uv stuff
				break;
		}
	}
}
void applyUVCrop(bool isAlex, int vertId, int data0, int data1, int data2) {
	return;
}
void applyUVOffset(bool isAlex, int vertId, int data0, int data1, int data2) {
	return;
}
void applyPostFlags(bool isAlex, int vertId, int data0, int data1, int data2) {
	return;
}
vec3 pixelNormal() {
	return Normal * (1.125/16.0);
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


vec4 getTfDataFromID(int faceDataSourceId) {
	int faceDataX = faceDataSourceId % 8;
	int faceDataY = faceDataSourceId / 8 + 3;
	if (faceDataY >= 8) {
		faceDataX += 24;
		faceDataY -= 4;
	}
	return texelFetch(Sampler0, ivec2(faceDataX,faceDataY), 0)*256.0;
}
vec4 colorFromInt(int i) {
	if (i<0) {
		return vec4(0.2,0.2,0.2,1);
	}

	switch (i%8) {
		case 0: return vec4(1,0,0,1);
		case 1: return vec4(0,1,0,1);
		case 2: return vec4(0,0,1,1);
		case 3: return vec4(1,1,0,1);
		case 4: return vec4(0,1,1,1);
		case 5: return vec4(1,0,1,1);
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

int faceIDLookup(int dirid, int uvu, int uvv);
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
    int faceid = faceIDLookup(dirid, uvu, uvv);
	return faceid*4 + corner;
}

int faceIDLookup(int dirid, int uvu, int uvv) {
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