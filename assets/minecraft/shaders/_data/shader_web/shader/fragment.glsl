uniform sampler2D Sampler0;

in vec2 texCoord0;
in highp vec2 wx_maxUV;
in highp vec2 wx_minUV;
in highp vec4 wx_vertexColor;
in highp float wx_isEdited;

out vec4 fragColor;

void main() {
    vec4 color = texture2D(Sampler0, texCoord0);

    //if (1==0) {
    if (wx_isEdited != 0.0) {
        fragColor = wx_vertexColor;
    } else {
        if (color.a < 0.1) {
            discard;
        }
        fragColor = color;
    }
}