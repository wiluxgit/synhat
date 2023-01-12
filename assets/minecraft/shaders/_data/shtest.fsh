/*#version 330

in vec4 p_color;
in vec2 p_uv;

uniform sampler2D Sampler0;
out vec4 outColor;

void main() {
   	outColor = texture(Sampler0, p_uv);
   	if (outColor.a < 0.1) {
		discard;
	}
}*/

#version 330

uniform sampler2D Sampler0;

in highp float vertexDistance;
in highp vec4 vertexColor;
in highp vec4 lightMapColor;
in highp vec4 overlayColor;
in highp vec2 texCoord0;
in highp vec4 normal;

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
    //color = vertexColor;
	
    if(wx_isEdited != 0){
        
        highp vec2 diff = texCoord0-wx_scalingOrigin;
        highp vec2 newTexCoord = (texCoord0 - diff) + (diff * wx_scaling);
        
        //float isIn1 = 0;
        //if(newTexCoord.y < wx_minUV.y || newTexCoord.y > wx_maxUV.y) discard;
        //if(newTexCoord.x < wx_minUV.x || newTexCoord.x > wx_maxUV.x) discard;

        newTexCoord += wx_UVDisplacement;
        
        color = texture(Sampler0, newTexCoord);
        //color = vec4(normalize(normal.xyz)/2+vec3(0.5,0.5,0.5), 1);
        color = vertexColor;
        if (color.a < 0.1) {
            discard;
        }
		outColor = color;
    } else {

        if (color.a < 0.1) {
            discard;
        }
		outColor = color;
    }
}
