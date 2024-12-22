//
//  FlatBottom.swift
//  ShadowMap
//
//  Created by gzonelee on 12/22/24.
//

import Foundation
import simd
import MetalKit

struct Flat3DRange {
    let minX: Float
    let maxX: Float
    let y: Float
    let minZ: Float
    let maxZ: Float
}

class FlatBottom {
    
    var vertices: [Vertex] = []
    var indices: [UInt16] = []
    var faces: [Face] = []
    
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var faceBuffer: MTLBuffer!


    init(device: MTLDevice, range: Flat3DRange, color: SIMD3<Float>) {
        vertices = [
            Vertex(position: [range.minX, range.y, range.minZ], color: color),
            Vertex(position: [range.maxX, range.y, range.minZ], color: color),
            Vertex(position: [range.minX, range.y, range.maxZ], color: color),
            Vertex(position: [range.maxX, range.y, range.maxZ], color: color),
        ]
        indices = [
            0, 1, 2,
            2, 1, 3
        ]
        
        faces = [
            Face(normal: [0, 1, 0], color: color),
            Face(normal: [0, 1, 0], color: color),
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: vertices.count * MemoryLayout<Vertex>.stride,
                                         options: [])
        indexBuffer = device.makeBuffer(bytes: indices,
                                        length: indices.count * MemoryLayout<UInt16>.size,
                                        options: [])
        faceBuffer = device.makeBuffer(bytes: faces,
                                       length: faces.count * MemoryLayout<Face>.size,
                                        options: [])
    }
}
