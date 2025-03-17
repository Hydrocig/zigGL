#version 450 core

in vec2 UV;
in vec3 Normal;
in vec3 Tangent;
in vec3 FragPos;
out vec4 FragColor;

uniform sampler2D textureDiffuse;
uniform sampler2D textureNormal;
uniform bool useTexture;
uniform bool useNormalMap;
uniform vec4 defaultColor;
uniform vec3 lightPos;
uniform vec3 viewPos;

void main() {
    vec3 color = useTexture ? texture(textureDiffuse, UV).rgb : defaultColor.rgb;

    // Normal mapping
    vec3 normal = normalize(Normal);
    if (useNormalMap) {
        // Extract normal from map
        vec3 normalMap = texture(textureNormal, UV).rgb;
        normalMap = normalize(normalMap * 2.0 - 1.0);

        // Create TBN matrix
        vec3 T = normalize(Tangent);
        vec3 N = normalize(Normal);
        T = normalize(T - dot(T, N) * N);
        vec3 B = cross(N, T);
        mat3 TBN = mat3(T, B, N);

        normal = normalize(TBN * normalMap);
    }

    // Simple lighting
    vec3 lightDir = normalize(lightPos - FragPos);
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = diff * vec3(1.0);

    vec3 viewDir = normalize(viewPos - FragPos);
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.5), 32.0);
    vec3 specular = spec * vec3(0.5);

    FragColor = vec4((diffuse + specular) * color, 1.0);
}