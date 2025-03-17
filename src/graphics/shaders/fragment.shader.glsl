#version 450 core

in vec2 UV;
in vec3 Normal;
in vec3 Tangent;
in vec3 FragPos;
out vec4 FragColor;

uniform sampler2D textureDiffuse;
uniform sampler2D textureNormal;
uniform sampler2D textureRoughness;
uniform sampler2D textureMetallic;

uniform bool useTexture;
uniform bool useNormalMap;
uniform bool useRoughnessMap;
uniform bool useMetallicMap;

uniform vec4 defaultColor;

// Material properties
uniform vec3 materialSpecular;
uniform float roughness;
uniform float metallic;

// Lighting uniforms
uniform vec3 lightPos;
uniform vec3 viewPos;

// PBR Constants
const float PI = 3.14159265359;
const vec3 dielectricSpecular = vec3(0.04);

void main() {
    // Base color
    vec3 albedo = useTexture ? texture(textureDiffuse, UV).rgb : defaultColor.rgb;
    albedo = pow(albedo, vec3(2.2)); // Gamma correction

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

    // Material properties
    float finalRoughness = roughness;
    float finalMetallic = metallic;

    if (useRoughnessMap)
    finalRoughness = texture(textureRoughness, UV).r;

    if (useMetallicMap)
    finalMetallic = texture(textureMetallic, UV).r;

    // Metallic workflow
    vec3 diffuseColor = albedo * (1.0 - finalMetallic);
    vec3 specularColor = mix(dielectricSpecular, albedo, finalMetallic);

    // Lighting calculations
    vec3 lightDir = normalize(lightPos - FragPos);
    vec3 viewDir = normalize(viewPos - FragPos);

    // Diffuse
    float NdotL = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = NdotL * diffuseColor;

    // Specular (Simplified Cook-Torrance)
    vec3 halfwayDir = normalize(lightDir + viewDir);
    float NdotH = max(dot(normal, halfwayDir), 0.0);
    float NdotV = max(dot(normal, viewDir), 0.0);

    // Roughness-based terms
    float roughnessSq = finalRoughness * finalRoughness;
    float denom = (NdotH * roughnessSq - NdotH) * NdotH + 1.0;
    float specularTerm = roughnessSq / (PI * denom * denom);

    vec3 specular = specularTerm * specularColor;

    // Combine results with energy conservation
    vec3 finalColor = (diffuse + specular) * NdotL;
    FragColor = vec4(pow(finalColor, vec3(1.0/2.2)), 1.0); // Gamma correction
}