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

#define MINECRAFT_LIGHT_POWER   (0.6)
#define MINECRAFT_AMBIENT_LIGHT (0.4)
highp vec4 minecraft_mix_light(highp vec3 lightDir0, highp vec3 lightDir1, highp vec3 normal, highp vec4 color) {
    lightDir0 = normalize(lightDir0);
    lightDir1 = normalize(lightDir1);
    highp float light0 = max(0.0, dot(lightDir0, normal));
    highp float light1 = max(0.0, dot(lightDir1, normal));
    highp float lightAccum = min(1.0, (light0 + light1) * MINECRAFT_LIGHT_POWER + MINECRAFT_AMBIENT_LIGHT);
    return vec4(color.rgb * lightAccum, color.a);
}
highp vec4 linear_fog(highp vec4 inColor, highp float vertexDistance, highp float fogStart, highp float fogEnd, highp vec4 fogColor) {
    if (vertexDistance <= fogStart) {
        return inColor;
    }

    highp float fogValue = vertexDistance < fogEnd ? smoothstep(fogStart, fogEnd, vertexDistance) : 1.0;
    return vec4(mix(inColor.rgb, fogColor.rgb, fogValue * fogColor.a), inColor.a);
}

highp vec4 getDirectionalColor(){
    highp vec3 hackProjectedNormal = normalize(cross(dFdx(wx_passModelViewPos), dFdy(wx_passModelViewPos)));
    hackProjectedNormal.z *= -1.0;
    
    highp mat3 wx_invMatrix = mat3(wx_invMatrix0, wx_invMatrix1, wx_invMatrix2);
    highp vec3 normalInVertexShaderWorld = normalize(wx_invMatrix * hackProjectedNormal);
    return minecraft_mix_light(wx_passLight0_Direction, wx_passLight1_Direction, normalInVertexShaderWorld, wx_passVertexColor);
}
void main() {
    highp vec4 color = texture(Sampler0, texCoord0);
    
    if(wx_isEdited != 0.0){
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
        
        highp vec4 vxColor = getDirectionalColor();

        color *= vxColor ;//* ColorModulator;
        color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
        color *= lightMapColor;

		outColor = color;
        //fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
        
        //fragColor = vec4(mod(newTexCoord.x*8,1), mod(newTexCoord.y*8,1), isIn1, 1);
        //fragColor = vec4(mod(newTexCoord.x*8,1), mod(newTexCoord.y*8,1), mod(newTexCoord.y*2,1), 1);
        //float modx = dot(Light0_Direction, nnormal);
        //fragColor = vec4(max(0.0, modx),0,0,1);
        //fragColor = overlayColor;
    } else {

        if (color.a < 0.1) {
            discard;
        }

        color *= vertexColor; //* ColorModulator;
        color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
        color *= lightMapColor;

		outColor = color;
        //fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);

        //vec3 fcs = vec3(inverse(ModelViewMat * ProjMat) * normal) - passNormal;
        //vec3 fcs = (ModelViewMat * ProjMat * vec4(passNormal,0) - normal).xyz;
        //fragColor = vec4(-normal.xyz,1);
        //fragColor = vec4(max(0.0, dot(Light0_Direction, passNormal.xyz)),0,0,1);
    }
}
