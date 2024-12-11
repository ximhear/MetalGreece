#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
};

struct SceneUniforms {
    float4x4 lightViewProjMatrix;
    float4x4 cameraViewProjMatrix; // not used here
    float3   lightPos;
};

struct ModelUniforms {
    float4x4 modelMatrix;
};

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut shadow_vertex(VertexIn in [[stage_in]],
                               constant SceneUniforms &scene [[buffer(0)]],
                               constant ModelUniforms &model [[buffer(1)]])
{
    VertexOut out;
    float4 worldPos = model.modelMatrix * float4(in.position, 1.0);
    out.position = scene.lightViewProjMatrix * worldPos;
    return out;
}
// fragment 없음 (depth-only)
