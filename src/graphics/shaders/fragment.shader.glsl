#version 450 core

in vec2 UV;
out vec4 FragColor;

uniform sampler2D textureDiffuse;
uniform bool useTexture;
uniform vec4 defaultColor;

void main() {
    if (useTexture) {
        FragColor = texture(textureDiffuse, UV);
    } else {
        FragColor = defaultColor;
    }
}