//
//  Math.swift
//  ShadowMap
//
//  Created by gzonelee on 12/12/24.
//

import simd

func perspectiveMatrixLH(aspect: Float, fovY: Float, nearZ: Float, farZ: Float) -> float4x4 {
    let yScale = 1 / tanf(fovY * 0.5)
    let xScale = yScale / aspect
    let zRange = farZ - nearZ

    return float4x4([
        SIMD4<Float>(xScale, 0,      0,               0),
        SIMD4<Float>(0,      yScale, 0,               0),
        SIMD4<Float>(0,      0,      farZ/zRange,     1),
        SIMD4<Float>(0,      0,     -(nearZ*farZ)/zRange, 0)
    ])
}

func orthographicMatrixLH(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> float4x4 {
    float4x4([
        SIMD4<Float>(2/(right-left),0,0,0),
        SIMD4<Float>(0,2/(top-bottom),0,0),
        SIMD4<Float>(0,0,1/(far-near),0),
        SIMD4<Float>(-(right+left)/(right-left),
                     -(top+bottom)/(top-bottom),
                     -near/(far-near),1)
    ])
}

func lookAtLH(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
    let f = simd_normalize(center - eye)
    let s = simd_normalize(simd_cross(up, f))
    let u = simd_cross(f, s)

    let M = float4x4([
        SIMD4<Float>( s.x,   u.x,   f.x, 0),
        SIMD4<Float>( s.y,   u.y,   f.y, 0),
        SIMD4<Float>( s.z,   u.z,   f.z, 0),
        SIMD4<Float>(-simd_dot(s, eye), -simd_dot(u, eye), -simd_dot(f, eye), 1)
    ])
    return M
}

func rotateX(_ angle: Float) -> float4x4 {
    let c = cos(angle)
    let s = sin(angle)
    return float4x4([
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, c, s, 0),
        SIMD4<Float>(0, -s, c, 0),
        SIMD4<Float>(0, 0, 0, 1)
    ])
}

func rotateY(_ angle: Float) -> float4x4 {
    let c = cos(angle)
    let s = sin(angle)
    return float4x4([
        SIMD4<Float>(c, 0, -s, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(s, 0, c, 0),
        SIMD4<Float>(0, 0, 0, 1)
    ])
}

extension float4x4 {
    init(_ columns: [SIMD4<Float>]) {
        self.init()
        self.columns = (columns[0], columns[1], columns[2], columns[3])
    }

    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        self.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
    }
}

