//
//  lighting.metal
//  DeferredRendering
//
//  Created by gzonelee on 12/14/24.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
};
struct VertexOut {
    float4 position [[position]];
    float4 position1;
};

struct Uniforms {
    float4x4 modelViewProj; // Left-handed MVP matrix will be passed
};

vertex VertexOut lighting_vertex(VertexIn in [[stage_in]],
                                 constant Uniforms &u [[buffer(1)]]) {
    VertexOut out;
//    out.position = u.modelViewProj * float4(in.position, 1);
    out.position = float4(in.position, 1);
    out.position1 = out.position ;
    return out;
}

fragment float4 lighting_fragment(VertexOut in [[stage_in]],
                                  texture2d<float> albedoTex [[texture(0)]],
                                  texture2d<float> normalTex [[texture(1)]]) {
    constexpr sampler sampler1(
                               s_address::clamp_to_zero,
                               t_address::clamp_to_zero,
                               mag_filter::linear,
                               min_filter::linear
                               );
    // Convert screen coordinates (-1 to 1) to UV coordinates (0 to 1)
    
    float2 uv = in.position1.xy;
    uv = (uv * 0.5) + 0.5;
    
    // Sample albedo and normal textures
    float4 albedo = albedoTex.sample(sampler1, uv);
    float4 normal = normalTex.sample(sampler1, uv);

    // Reconstruct the normal in the -1 to 1 range
    float3 N = normalize((normal.xyz * 2.0) - 1.0);

    // Simple directional light
    float3 lightDir = normalize(float3(0.0, 0.0, 1.0)); // Light direction
    float NdotL = max(dot(N, -lightDir), 0.0);            // Diffuse term
//
    float3 litColor = albedo.rgb * NdotL; // Multiply light intensity by albedo
//    return float4(uv.x, uv.y, 0, 1.0);         // Output the final lit color
//    return float4(albedo.rgb, 1.0);         // Output the final lit color
    return float4(litColor, 1.0);         // Output the final lit color
}
