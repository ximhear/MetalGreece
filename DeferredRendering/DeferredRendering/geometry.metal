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
    float3 normal   [[attribute(1)]];
    float2 uv       [[attribute(2)]];
    float3 color       [[attribute(3)]];
};

struct Uniforms {
    float4x4 modelViewProj; // Left-handed MVP matrix will be passed
    float4x4 modelMatrix; // Left-handed MVP matrix will be passed
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float2 uv;
    float3 color;
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
    
    out.normal = (u.modelMatrix * float4(vertices[vid].normal, 1)).xyz; // Normal is passed as-is
    out.uv = vertices[vid].uv;         // UV coordinates are passed as-is
    out.color = vertices[vid].color;
    
    return out;
}

fragment GBufferOut geometry_fragment(VertexOut in [[stage_in]]) {
    GBufferOut out;

    // Apply a fixed albedo color (pink)
//    out.albedo = float4(1.0, 0.0, 0.0, 1.0);
    out.albedo = float4(in.color, 1);

    // Transform normal to the 0-1 range for MRT output
    float3 N = normalize(in.normal);
    out.normal = float4(N * 0.5 + 0.5, 1.0);

    return out;
}
