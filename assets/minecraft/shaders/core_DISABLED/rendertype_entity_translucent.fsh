#version 150

#moj_import <fog.glsl>
#moj_import <light.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;
uniform vec3 Light0_Direction;
uniform vec3 Light1_Direction;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

in float vertexDistance;
in vec4 vertexColor;
in vec4 lightMapColor;
in vec4 overlayColor;
in vec2 texCoord0;
in vec4 normal;

in vec3 wx_passLight0_Direction;
in vec3 wx_passLight1_Direction;
in vec3 wx_passModelViewPos;
in vec4 wx_passVertexColor;
in vec3 wx_invMatrix0;
in vec3 wx_invMatrix1;
in vec3 wx_invMatrix2;

in vec2 wx_scalingOrigin;
in vec2 wx_scaling;
in vec2 wx_maxUV;
in vec2 wx_minUV;
in vec2 wx_UVDisplacement;
in float wx_isEdited;

out vec4 fragColor;

#define MAX 1 

vec4 getDirectionalColor(){
    vec3 hackProjectedNormal = normalize(cross(dFdx(wx_passModelViewPos), dFdy(wx_passModelViewPos)));
    hackProjectedNormal.z *= -1;
    
    mat3 wx_invMatrix = mat3(wx_invMatrix0, wx_invMatrix1, wx_invMatrix2);
    vec3 normalInVertexShaderWorld = normalize(wx_invMatrix * hackProjectedNormal);
    return minecraft_mix_light(wx_passLight0_Direction, wx_passLight1_Direction, normalInVertexShaderWorld, wx_passVertexColor);
}
void main() {
    vec4 color = texture(Sampler0, texCoord0);
    
    if(wx_isEdited != 0){
        /*
        // TESTING TO FIX LIGHTING
        //`nnormal` is the badly calculated `normal`m 
        //nnormal of skewed face == normal of unskwed face
        vec3 nnormal = normalize(cross(dFdx(passMPos), dFdy(passMPos)));
        nnormal.z*=-1;

        //    normal = ProjMat * ModelViewMat * vec4(Normal, 0.0)
        //=>? Normal = inv(ProjMat * ModelViewMat)*normal
        vec3 nNormal = passInvTrans * nnormal;
        nNormal = normalize(nNormal.xyz);
        nNormal.z*=-1;

        vec4 vxColor = minecraft_mix_light(Light0_Direction, Light1_Direction, nnormal, passColor);
        */
        
        vec2 diff = texCoord0-wx_scalingOrigin;
        vec2 newTexCoord = (texCoord0 - diff) + (diff * wx_scaling);
        
        //float isIn1 = 0;
        if(newTexCoord.y < wx_minUV.y || newTexCoord.y > wx_maxUV.y) discard;
        if(newTexCoord.x < wx_minUV.x || newTexCoord.x > wx_maxUV.x) discard;

        newTexCoord += wx_UVDisplacement;
        
        color = texture(Sampler0, newTexCoord);
        if (color.a < 0.1) {
            discard;
        }
        
        vec4 vxColor = getDirectionalColor();

        color *= vxColor * ColorModulator;
        color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
        color *= lightMapColor;

        fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
        
        //fragColor = vec4(mod(newTexCoord.x*8,1), mod(newTexCoord.y*8,1), isIn1, 1);
        //fragColor = vec4(mod(newTexCoord.x*8,1), mod(newTexCoord.y*8,1), mod(newTexCoord.y*2,1), 1);
        //float modx = dot(Light0_Direction, nnormal);
        //fragColor = vec4(max(0.0, modx),0,0,1);
        //fragColor = overlayColor;
    } else {

        if (color.a < 0.1) {
            discard;
        }

        color *= vertexColor * ColorModulator;
        color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
        color *= lightMapColor;

        fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);

        //vec3 fcs = vec3(inverse(ModelViewMat * ProjMat) * normal) - passNormal;
        //vec3 fcs = (ModelViewMat * ProjMat * vec4(passNormal,0) - normal).xyz;
        //fragColor = vec4(-normal.xyz,1);
        //fragColor = vec4(max(0.0, dot(Light0_Direction, passNormal.xyz)),0,0,1);
    }
}
