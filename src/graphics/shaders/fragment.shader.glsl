#version 450 core

in vec2 UV;
in vec3 Normal;
in vec3 Tangent;
in vec3 FragPos;
out vec4 FragColor;

uniform sampler2D textureDiffuse;
uniform sampler2D textureNormal;
uniform sampler2D textureRoughness;

uniform bool useTexture;
uniform bool useNormalMap;
uniform bool useRoughnessMap;

uniform vec4 defaultColor;

// Material properties
uniform vec3 materialSpecular;
uniform float roughness;

// Lighting uniforms
uniform vec3 lightPos;
uniform vec3 viewPos;

void main() {
    // Base color
    vec3 color = useTexture ? texture(textureDiffuse, UV).rgb : defaultColor.rgb;

    // Normal mapping
    vec3 normal = normalize(Normal);
    if (useNormalMap) {
        vec3 normalMap = texture(textureNormal, UV).rgb;
        normalMap = normalize(normalMap * 2.0 - 1.0);

        vec3 T = normalize(Tangent);
        vec3 N = normalize(Normal);
        T = normalize(T - dot(T, N) * N);
        vec3 B = cross(N, T);
        mat3 TBN = mat3(T, B, N);

        normal = normalize(TBN * normalMap);
    }

    // Roughness sampling
    float finalRoughness = roughness;
    if (useRoughnessMap) {
        finalRoughness = 1.0 - texture(textureRoughness, UV).r; // Invert roughness map (roughness is not glossiness)
    }

    // Convert roughness to specular power (0-1 roughness to 32-2 exponent)
    float specularPower = mix(32.0, 2.0, finalRoughness);

    // Lighting calculations
    vec3 lightDir = normalize(lightPos - FragPos);

    // Diffuse
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = diff * color;

    // Specular
    vec3 viewDir = normalize(viewPos - FragPos);
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), specularPower);
    vec3 specular = spec * materialSpecular;

    // Combine results
    vec3 finalColor = (diffuse + specular);
    FragColor = vec4(finalColor, 1.0);
}