#define in in highp
#define out out highp

uniform sampler2D Sampler0;

in vec2 texCoord0;
in vec4 wx_vertexColor;
in float wx_isEdited;
in vec2 wx_clipMin;
in vec2 wx_clipMax;

out vec4 fragColor;

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
            discard;
            fragColor = vec4(0.5, 0.5, 0.5, 1.0) - vec4(checkerSmall, checkerSmall, checkerSmall, 0) / 3.0 ;
            return;
        }
        if (texCoord0.y < wx_clipMin.y || texCoord0.y > wx_clipMax.y) {
            discard;
            fragColor = vec4(0.66, 0.66, 0.66, 1.0) - vec4(checkerSmall, checkerSmall, checkerSmall, 0) / 3.0;
            return;
        }

        if (color.a < 0.1) {
            discard;
            fragColor = discardColor;
        } else {
            fragColor = color;
            //fragColor = (discardColor + color) / 2.0;
        }
    } else {
        vec4 color = texture2D(Sampler0, texCoord0);
        if (color.a < 0.1) {
            discard;
        }
        fragColor = color;
    }
}