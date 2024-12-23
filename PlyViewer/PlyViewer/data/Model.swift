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


class Model {
    
    var vertices: [Vertex] = []
    var indices: [UInt32] = []
    var faces: [Face] = []
    
    func loadFromJson() {
        // Load model from json
        // stanfordDragonData.json
        // { triangles: [[UInt32, UInt32, UInt32]], vertices: [[Float, Float, Float]] }
        do {
            let jsonURL = Bundle.main.url(forResource: "stanfordDragonData", withExtension: "json")!
            GZLogFunc(jsonURL)
            let jsonData = try Data(contentsOf: jsonURL)
            let meshData = try JSONDecoder().decode(MeshData.self, from: jsonData)
            GZLogFunc(meshData.triangles.first)
            GZLogFunc(meshData.triangles.last)
            GZLogFunc(meshData.vertices.first)
            GZLogFunc(meshData.vertices.last)
            GZLogFunc(meshData.triangles.count)
            GZLogFunc(meshData.vertices.count)
            GZLogFunc()
            
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
            
            for (index, vertex) in meshData.vertices.enumerated() {
                vertices.append(Vertex(position: SIMD3<Float>(vertex[0], vertex[1], vertex[2]), color: colors[index % colors.count]))
            }
            for (index, triangle) in meshData.triangles.enumerated() {
                let v0 = SIMD3<Float>(meshData.vertices[Int(triangle[0])])
                let v1 = SIMD3<Float>(meshData.vertices[Int(triangle[2])])
                let v2 = SIMD3<Float>(meshData.vertices[Int(triangle[1])])
                let vec1 = v1 - v0
                let vec2 = v2 - v0
                let normal: SIMD3<Float> = simd_normalize(simd_cross(vec1, vec2))
                faces.append(Face(normal: normal, color: colors[index % colors.count]))
            }
            indices = meshData.triangles.flatMap { [$0[0], $0[2], $0[1]] }
            GZLogFunc(vertices.count)
            GZLogFunc(indices.count)
            GZLogFunc()
        } catch {
            GZLogFunc(error)
            GZLogFunc()
            indices = []
            vertices = []
        }

    }
    
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
