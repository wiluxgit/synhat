#define in in highp
#define out out highp

uniform sampler2D Sampler0;

in vec2 texCoord0;
in vec2 wx_clipMin;
in vec2 wx_clipMax;
in vec2 wx_clipOffset;
in vec4 wx_vertexColor;
in float wx_isEdited;

out vec4 fragColor;

void main() {

    if (wx_isEdited != 0.0) {
        vec4 color = texture2D(Sampler0, texCoord0);

        if (color.a < 0.1) {
            fragColor = wx_vertexColor;
        } else {
            fragColor = (wx_vertexColor + color) / 2.0;
        }
    } else {
        vec4 color = texture2D(Sampler0, texCoord0);
        if (color.a < 0.1) {
            discard;
        }
        fragColor = color;
    }
}