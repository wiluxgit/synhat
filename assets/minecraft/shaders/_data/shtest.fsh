//#version 150

//#moj_import <fog.glsl>
//#moj_import <light.glsl>

uniform sampler2D Sampler0;

//uniform vec4 ColorModulator;
//uniform float FogStart;
//uniform float FogEnd;
//uniform vec4 FogColor;
//uniform vec3 Light0_Direction;
//uniform vec3 Light1_Direction;

//uniform mat4 ModelViewMat;
//uniform mat4 ProjMat;

in highp float vertexDistance;
in highp vec4 vertexColor;
in highp vec4 lightMapColor;
in highp vec4 overlayColor;
in highp vec2 texCoord0;
in highp vec4 normal;

in highp vec3 wx_passLight0_Direction;
in highp vec3 wx_passLight1_Direction;
in highp vec3 wx_passModelViewPos;
in highp vec4 wx_passVertexColor;
in highp vec3 wx_invMatrix0;
in highp vec3 wx_invMatrix1;
in highp vec3 wx_invMatrix2;

in highp vec2 wx_scalingOrigin;
in highp vec2 wx_scaling;
in highp vec2 wx_maxUV;
in highp vec2 wx_minUV;
in highp vec2 wx_UVDisplacement;
in highp float wx_isEdited;

out highp vec4 outColor;

#define MAX 1 

void main() {
    highp vec4 color = texture(Sampler0, texCoord0);
    
    if(wx_isEdited != 0.0){
        
        highp vec2 diff = texCoord0-wx_scalingOrigin;
        highp vec2 newTexCoord = (texCoord0 - diff) + (diff * wx_scaling);
        
        //float isIn1 = 0;
        if(newTexCoord.y < wx_minUV.y || newTexCoord.y > wx_maxUV.y) discard;
        if(newTexCoord.x < wx_minUV.x || newTexCoord.x > wx_maxUV.x) discard;

        newTexCoord += wx_UVDisplacement;
        
        color = texture(Sampler0, newTexCoord);
        if (color.a < 0.1) {
            discard;
        }
		outColor = color;
    } else {

        if (color.a < 0.1) {
            discard;
        }
		outColor = color;
        //fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);

        //vec3 fcs = vec3(inverse(ModelViewMat * ProjMat) * normal) - passNormal;
        //vec3 fcs = (ModelViewMat * ProjMat * vec4(passNormal,0) - normal).xyz;
        //fragColor = vec4(-normal.xyz,1);
        //fragColor = vec4(max(0.0, dot(Light0_Direction, passNormal.xyz)),0,0,1);
    }
}
