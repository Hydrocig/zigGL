#version 450 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aUV;
layout (location = 2) in vec3 aNormal;
layout (location = 3) in vec3 aTangent;

out vec2 UV;
out vec3 Normal;
out vec3 Tangent;
out vec3 FragPos;

uniform mat4 MVP;
uniform mat4 Model;

void main() {
    gl_Position = MVP * vec4(aPos, 1.0);
    UV = aUV;
    FragPos = vec3(Model * vec4(aPos, 1.0));
    Normal = mat3(transpose(inverse(Model))) * aNormal;
    Tangent = mat3(transpose(inverse(Model))) * aTangent;
}