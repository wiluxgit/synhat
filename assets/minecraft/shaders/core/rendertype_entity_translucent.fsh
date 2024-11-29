#version 330
#ifdef BONE_TEXTURE // ThreeJS
#define in in highp
#define out out highp
#else
#extension GL_EXT_gpu_shader4 : enable
#moj_import <fog.glsl>
#moj_import <light.glsl>
#endif

// Vanilla uniform
uniform sampler2D Sampler0;
uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

// Vanilla input
in float vertexDistance;
in vec4 vertexColor;
in vec4 lightMapColor;
in vec4 overlayColor;
in vec2 texCoord0;
in vec4 normal;

// wx input
// in vec2 texCoord0;
in vec4 wx_vertexColor;
in float wx_isEdited;
in vec2 wx_clipMin;
in vec2 wx_clipMax;

// Vanilla output
out vec4 fragColor;

// Directional Lighting Hack
#ifdef BONE_TEXTURE // ThreeJS
vec4 getDirectionalColor() {
    return vec4(1,1,1,0);
}
#else // Minecraft
in vec3 wx_passLight0_Direction;
in vec3 wx_passLight1_Direction;
in vec3 wx_passModelViewPos;
in vec4 wx_passVertexColor;
in vec3 wx_invMatrix0;
in vec3 wx_invMatrix1;
in vec3 wx_invMatrix2;
vec4 getDirectionalColor(){
    vec3 hackProjectedNormal = normalize(cross(dFdx(wx_passModelViewPos), dFdy(wx_passModelViewPos)));
    hackProjectedNormal.z *= -1;
    
    mat3 wx_invMatrix = mat3(wx_invMatrix0, wx_invMatrix1, wx_invMatrix2);
    vec3 normalInVertexShaderWorld = normalize(wx_invMatrix * hackProjectedNormal);
    return minecraft_mix_light(wx_passLight0_Direction, wx_passLight1_Direction, normalInVertexShaderWorld, wx_passVertexColor);
}
#endif

void main() {

    if (wx_isEdited != 0.0) {
        vec4 color = texture2D(Sampler0, texCoord0);
        vec4 discardColor = wx_vertexColor;

        float checker = float(int(floor(texCoord0.x * 128.0) + floor(texCoord0.y * 128.0)) % 2);
        float checkerSmall = float(int(floor(texCoord0.x * 256.0) + floor(texCoord0.y * 256.0)) % 2);

        if (checker == 0.0) {
            discardColor.xyz *= 0.5;
        }

        if (texCoord0.x < wx_clipMin.x || texCoord0.x > wx_clipMax.x) {
            //discard;
            fragColor = vec4(0.5, 0.5, 0.5, 1.0) - vec4(checkerSmall, checkerSmall, checkerSmall, 0) / 3.0 ;
            //return;
        }
        if (texCoord0.y < wx_clipMin.y || texCoord0.y > wx_clipMax.y) {
            //discard;
            fragColor = vec4(0.66, 0.66, 0.66, 1.0) - vec4(checkerSmall, checkerSmall, checkerSmall, 0) / 3.0;
            //return;
        }

        if (color.a < 0.1) {
            //discard;
            fragColor = discardColor;
        } else {
            fragColor = color;
            //fragColor = (discardColor + color) / 2.0;
        }
        fragColor = discardColor;
    } else {
        vec4 color = texture2D(Sampler0, texCoord0);
        if (color.a < 0.1) {
            discard;
        }

        vec4 vxColor = getDirectionalColor();
        color *= vxColor * ColorModulator;
        color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
        color *= lightMapColor;

        fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
    }
}