#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 uv    [[attribute(2)]];
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
    float2 uv;
};

vertex VertexOut main_vertex(VertexIn in [[stage_in]],
                             constant SceneUniforms &scene [[buffer(3)]],
                             constant ModelUniforms &model [[buffer(4)]])
{
    VertexOut out;
    float4 worldPos = model.modelMatrix * float4(in.position, 1.0);
    out.worldPos = worldPos.xyz;
//    out.normal = normalize((model.modelMatrix * float4(in.normal,0.0)).xyz);

    out.position = scene.cameraViewProjMatrix * worldPos;
    out.uv = in.uv;
    out.normal = in.normal;

    float4 lightPos = scene.lightViewProjMatrix * worldPos;
    out.shadowCoord = (lightPos.xyz / lightPos.w) * float3(0.5, 0.5, 1) * float3(1, -1, 1) + float3(0.5, 0.5, 0.0);
//    out.color = in.color;
    return out;
}

fragment float4 main_fragment(VertexOut in [[stage_in]],
                              depth2d<float> shadowMap [[texture(0)]],
                              sampler shadowSampler [[sampler(0)]],
                              constant SceneUniforms &scene [[buffer(3)]],
                              constant ModelUniforms &model [[buffer(4)]],
                              constant Face *faces [[buffer(2)]],
                              uint primID [[primitive_id]])
{
//    return float4(0, 1, 0, 1);
    // normal to color
    float3 normal = model.normalMatrix * in.normal;
    float3 normalColor = (normal + 1.0) * 0.5;
//    return float4(normalColor.x, normalColor.y, 1 - normalColor.z, 1);
    return float4(normalColor, 1);
}
