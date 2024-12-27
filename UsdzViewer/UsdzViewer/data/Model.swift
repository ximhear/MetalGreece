//
//  Model.swift
//  ShadowMap
//
//  Created by gzonelee on 12/21/24.
//

import Foundation
import simd

struct Vertex {
    let position: SIMD3<Float>
    let color: SIMD3<Float>
}

struct MeshData: Codable {
    let triangles: [[UInt32]]
    let vertices: [[Float]]
}

struct Face {
    let normal: SIMD3<Float>
    let color: SIMD3<Float>
}

/*
 // 삼각형과 평면 정점 데이터 (position + normal)
 let vertices: [Float] = [
     // 삼각형
     // pos          normal   color
     0, 0.5, -1,       0, 1, 0,  1, 0, 0,
     1, 0.5, 1,       0, 1, 0,  1, 0, 0,
     -1, 0.5, 1,       0, 1, 0,  1, 0, 0,

     // 평면 (사각형)
     // pos          normal        color
     -2, -0.5, -2,     0, 1, 0,    0, 1, 0,
     2, -0.5, -2,      0, 1, 0,    0, 1, 0,
     -2, -0.5, 2,      0, 1, 0,    0, 1, 0,
     2, -0.5, 2,       0, 1, 0,    0, 1, 0,
 ]
 let indices: [UInt32] = [
     // 삼각형
     0, 1, 2,

     // 평면 (두 개의 삼각형)
     3, 4, 5,
     5, 4, 6
 ]
 */


struct Model: Sendable, Hashable {
    
    let fileName: String
    let vertices: [Vertex]
    let indices: [UInt32]
    let faces: [Face]
    
    func printInfo() {
        if vertices.isEmpty == false {
            let threeValues = [vertices[0].position.x, vertices[0].position.y, vertices[0].position.z]
            let initialValue = [threeValues, threeValues]
            let range = vertices.reduce(initialValue) { partialResult, vertex in
                return [
                    [
                        min(partialResult[0][0], vertex.position.x),
                        min(partialResult[0][1], vertex.position.y),
                        min(partialResult[0][2], vertex.position.z)
                    ],
                    [
                        max(partialResult[1][0], vertex.position.x),
                        max(partialResult[1][1], vertex.position.y),
                        max(partialResult[1][2], vertex.position.z)
                    ]
                ]
            }
            GZLogFunc("x : \(range[0][0]), \(range[1][0])")
            GZLogFunc("y : \(range[0][1]), \(range[1][1])")
            GZLogFunc("z : \(range[0][2]), \(range[1][2])")
        }
        else {
            GZLogFunc("No vertex")
        }

    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(fileName)
    }
    
    static func == (lhs: Model, rhs: Model) -> Bool {
        return lhs.fileName == rhs.fileName
    }
}

extension Model: CustomStringConvertible {
    var description: String {
        return "Model(fileName: \(fileName), vertices: \(vertices.count), indices: \(indices.count), faces: \(faces.count))"
    }
}

class ColorUtil {
    let colors: [SIMD3<Float>] = [
        SIMD3<Float>(1.0, 0.0, 0.0), // Red
        SIMD3<Float>(0.0, 1.0, 0.0), // Green
        SIMD3<Float>(0.0, 0.0, 1.0), // Blue
        SIMD3<Float>(1.0, 1.0, 0.0), // Yellow
        SIMD3<Float>(1.0, 0.0, 1.0), // Magenta
        SIMD3<Float>(0.0, 1.0, 1.0), // Cyan
        SIMD3<Float>(0.5, 0.5, 0.5), // Gray
        SIMD3<Float>(1.0, 0.5, 0.0), // Orange
        SIMD3<Float>(0.5, 0.0, 1.0), // Purple
        SIMD3<Float>(0.0, 0.5, 0.5), // Teal
        SIMD3<Float>(0.5, 1.0, 0.5), // Light Green
        SIMD3<Float>(1.0, 0.8, 0.6), // Peach
        SIMD3<Float>(0.6, 0.4, 0.2), // Brown
        SIMD3<Float>(0.8, 0.8, 0.8), // Light Gray
        SIMD3<Float>(0.2, 0.2, 0.2), // Dark Gray
        SIMD3<Float>(0.8, 0.0, 0.0), // Dark Red
        SIMD3<Float>(0.0, 0.8, 0.0), // Dark Green
        SIMD3<Float>(0.0, 0.0, 0.8), // Dark Blue
        SIMD3<Float>(0.8, 0.8, 0.0), // Dark Yellow
        SIMD3<Float>(0.0, 0.8, 0.8)  // Dark Cyan
    ]
    
    func getColor(index: Int) -> SIMD3<Float> {
        return colors[index % colors.count]
    }
}
