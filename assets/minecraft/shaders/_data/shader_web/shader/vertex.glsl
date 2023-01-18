uniform sampler2D Sampler0;
varying vec2 texCoord0;

void main() {
    gl_Position = projectionMatrix * viewMatrix * vec4(position, 1.0);
    texCoord0 = uv;
    //normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);
}