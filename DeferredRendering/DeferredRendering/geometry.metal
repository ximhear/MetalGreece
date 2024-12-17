//
//  geometry.metal
//  DeferredRendering
//
//  Created by gzonelee on 12/14/24.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
};

// Face 구조체: CPU 측에서 구성하여 buffer에 담아둠
struct Face {
    float3 normal;
    float3 color;
};

struct Uniforms {
    float4x4 modelViewProj; // Left-handed MVP matrix will be passed
    float4x4 modelMatrix; // Left-handed MVP matrix will be passed
};

struct VertexOut {
    float4 position [[position]];
};

struct GBufferOut {
    float4 albedo [[color(0)]];
    float4 normal [[color(1)]];
};

vertex VertexOut geometry_vertex(uint vid [[vertex_id]],
                                 const device VertexIn *vertices [[buffer(0)]],
                                 constant Uniforms &u [[buffer(1)]]) {
    VertexOut out;
    
    // Use the left-handed MVP matrix
    float3 pos = vertices[vid].position;
    out.position = u.modelViewProj * float4(pos, 1.0);
    
    return out;
}

fragment GBufferOut geometry_fragment(VertexOut in [[stage_in]],
                                      constant Uniforms &u [[buffer(1)]],
                                      constant Face *faces [[buffer(2)]],
                                      uint primID [[primitive_id]]) {
    GBufferOut out;

    // 현재 처리중인 픽셀이 속한 Face 데이터 획득
    Face f = faces[primID];
    out.albedo = float4(f.color, 1.0);

    // Transform normal to the 0-1 range for MRT output
    float3 normal = (u.modelMatrix * float4(f.normal, 1)).xyz; // Normal is passed as-is
    float3 N = normalize(normal);
    out.normal = float4(N * 0.5 + 0.5, 1.0);

    return out;
}
