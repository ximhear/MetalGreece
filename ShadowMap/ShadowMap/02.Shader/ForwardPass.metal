#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float3 color    [[attribute(2)]];
};

struct SceneUniforms {
    float4x4 lightViewProjMatrix;
    float4x4 cameraProjMatrix;
    float4x4 cameraViewProjMatrix;
    float3   lightPos;
};

struct ModelUniforms {
    float4x4 modelMatrix;
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
    out.normal = normalize((model.modelMatrix * float4(in.normal,0.0)).xyz);

    out.position = scene.cameraViewProjMatrix * worldPos;

    float4 lightPos = scene.lightViewProjMatrix * worldPos;
    out.shadowCoord = (lightPos.xyz / lightPos.w) * float3(0.5, 0.5, 1) * float3(1, -1, 1) + float3(0.5, 0.5, 0.0);
    out.color = in.color;
    return out;
}

fragment float4 main_fragment(VertexOut in [[stage_in]],
                              depth2d<float> shadowMap [[texture(0)]],
                              sampler shadowSampler [[sampler(0)]],
                              constant SceneUniforms &scene [[buffer(2)]])
{
    // shadowMap.sample_compare: 1.0 -> lit, 0.0 -> in shadow
    float shadow = shadowMap.sample(shadowSampler, in.shadowCoord.xy);
//    float shadow = shadowMap.sample_compare(shadowSampler, in.shadowCoord.xy, in.shadowCoord.z);
    if (shadow < in.shadowCoord.z) {
        shadow = 0.0;
    } else {
        shadow = 1.0;
    }
    float visibility = (shadow > 0.5) ? 1.0 : 0.1;

    return float4(in.color.x * visibility, in.color.y * visibility, in.color.z * visibility, 1);
}
