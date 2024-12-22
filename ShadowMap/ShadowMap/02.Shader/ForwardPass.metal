#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
//    float3 normal   [[attribute(1)]];
    float3 color    [[attribute(1)]];
};

struct Face {
    float3 normal;
    float3 color;
};

struct SceneUniforms {
    float4x4 lightViewProjMatrix;
    float4x4 cameraProjMatrix;
    float4x4 cameraViewProjMatrix;
    float3   lightPos;
};

struct ModelUniforms {
    float4x4 modelMatrix;
    float3x3 normalMatrix;
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPos;
    float3 normal;
    float3 shadowCoord;
    float3 color;
};

vertex VertexOut main_vertex(VertexIn in [[stage_in]],
                             constant SceneUniforms &scene [[buffer(0)]],
                             constant ModelUniforms &model [[buffer(1)]])
{
    VertexOut out;
    float4 worldPos = model.modelMatrix * float4(in.position, 1.0);
    out.worldPos = worldPos.xyz;
//    out.normal = normalize((model.modelMatrix * float4(in.normal,0.0)).xyz);

    out.position = scene.cameraViewProjMatrix * worldPos;
    out.color = in.color;

    float4 lightPos = scene.lightViewProjMatrix * worldPos;
    out.shadowCoord = (lightPos.xyz / lightPos.w) * float3(0.5, 0.5, 1) * float3(1, -1, 1) + float3(0.5, 0.5, 0.0);
//    out.color = in.color;
    return out;
}

fragment float4 main_fragment(VertexOut in [[stage_in]],
                              depth2d<float> shadowMap [[texture(0)]],
                              sampler shadowSampler [[sampler(0)]],
                              constant SceneUniforms &scene [[buffer(0)]],
                              constant ModelUniforms &model [[buffer(1)]],
                              constant Face *faces [[buffer(2)]],
                              uint primID [[primitive_id]])
{
    // normal to color
//    float3 normal = model.normalMatrix * faces[primID].normal;
//    float3 normalColor = (normal + 1.0) * 0.5;
//    return float4(normalColor, 1);
    
    // face color
//    return float4(faces[primID].color, 1);
    
    // vertex color
//    return float4(in.color, 1);
    
    // shadowMap.sample_compare: 1.0 -> lit, 0.0 -> in shadow
    float3 color = faces[primID].color;
    
    float shadow = shadowMap.sample(shadowSampler, in.shadowCoord.xy);
    if (shadow + 0.0001 < in.shadowCoord.z) {
        shadow = 0.0;
    } else {
        shadow = 1.0;
    }
    float visibility = (shadow > 0.5) ? 1.0 : 0.6;
    
//    float shadow = shadowMap.sample_compare(shadowSampler, in.shadowCoord.xy, in.shadowCoord.z);
//    float visibility = mix(0.6, 1.0, shadow); // 부드러운 그림자
    
    float3 baseColor = color * visibility; // 기본 색상 * 가시성
    float3 shadowColor = float3(0.0, 0.0, 0.0) * (1.0 - visibility); // 그림자 색상
    float3 finalColor = baseColor + shadowColor; // 결합된 색상
    return float4(finalColor, 1.0);

//    return float4(color.x * visibility, color.y * visibility, color.z * visibility, 1);
}
