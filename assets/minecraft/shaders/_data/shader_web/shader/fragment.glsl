uniform sampler2D Sampler0;
varying vec2 texCoord0;

void main() {
    vec4 color = texture2D(Sampler0, texCoord0);
    if (color.a < 0.1) {
        discard;
    }
    gl_FragColor = color; //vec4(0.18, 0.54, 0.34, 1.0);
}