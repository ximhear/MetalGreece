//
//  Renderer.swift
//  DeferredRendering
//
//  Created by gzonelee on 12/14/24.
//

import MetalKit
import simd

struct Vertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var uv: SIMD2<Float>
    var color: SIMD3<Float>
}
class Renderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!

    var geometryPipelineState: MTLRenderPipelineState!
    var lightingPipelineState: MTLRenderPipelineState!

    var albedoTexture: MTLTexture!
    var normalTexture: MTLTexture!
    var depthTexture: MTLTexture!

    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var quadVertexBuffer: MTLBuffer!
    var rotation: Float = 0

    struct Uniforms {
        var modelViewProj: simd_float4x4
        var modelMatrix: simd_float4x4
    }
    var uniformBuffer: MTLBuffer!
    var uniformBuffer1: MTLBuffer!

    override init() {
        super.init()
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device.makeCommandQueue()

        buildResources()
        buildPipelines()
    }

    func buildResources() {

        let phi: Float = (1.0 + sqrt(5.0)) / 2.0 // 황금비

        // 12개의 꼭짓점 정의 (Left-handed 좌표계에 맞게 Z축 값 반전)
        let vertices: [Vertex] = [
            Vertex(position: [-1,  phi,  0], normal: [-1,  phi,  0], uv: [0, 0], color: [1, 0, 0]),
            Vertex(position: [ 1,  phi,  0], normal: [ 1,  phi,  0], uv: [1, 0], color: [1, 0, 0]),
            Vertex(position: [-1, -phi,  0], normal: [-1, -phi,  0], uv: [0, 1], color: [1, 0, 0]),
            Vertex(position: [ 1, -phi,  0], normal: [ 1, -phi,  0], uv: [1, 1], color: [1, 0, 0]),
            
            Vertex(position: [ 0, -1, -phi], normal: [ 0, -1, -phi], uv: [0, 0], color: [0, 1, 0]),
            Vertex(position: [ 0,  1, -phi], normal: [ 0,  1, -phi], uv: [1, 0], color: [0, 1, 0]),
            Vertex(position: [ 0, -1,  phi], normal: [ 0, -1,  phi], uv: [0, 1], color: [0, 1, 0]),
            Vertex(position: [ 0,  1,  phi], normal: [ 0,  1,  phi], uv: [1, 1], color: [0, 1, 0]),
            
            Vertex(position: [ phi,  0,  1], normal: [ phi,  0,  1], uv: [0, 0], color: [0, 0, 1]),
            Vertex(position: [ phi,  0, -1], normal: [ phi,  0, -1], uv: [1, 0], color: [0, 0, 1]),
            Vertex(position: [-phi,  0,  1], normal: [-phi,  0,  1], uv: [0, 1], color: [0, 0, 1]),
            Vertex(position: [-phi,  0, -1], normal: [-phi,  0, -1], uv: [1, 1], color: [0, 0, 1]),
        ]

        // 20개의 삼각형 면 정의 (CW: 시계 방향)
        let indices: [UInt16] = [
            0, 5, 11,
            0, 1, 5,
            0, 7, 1,
            0, 10, 7,
            0, 11, 10,
            
            1, 9, 5,
            5, 4, 11,
            11, 2, 10,
            10, 6, 7,
            7, 8, 1,
            
            3, 4, 9,
            3, 2, 4,
            3, 6, 2,
            3, 8, 6,
            3, 9, 8,
            
            4, 5, 9,
            2, 11, 4,
            6, 10, 2,
            8, 7, 6,
            9, 1, 8,
        ]



        // 이로써 front face는 z = -0.5에 위치하고, 카메라(0,0,-3)에서 바라볼 때 CCW로 보여지고, cullMode = .back 사용할 경우 올바른 전면 렌더링이 이뤄집니다.

        // cullMode = .back 사용
        // 이 상태로 Left-Handed 좌표계에서 +Z를 바라보는 카메라 기준 front face는 CCW.


        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: MemoryLayout<Vertex>.size * vertices.count,
                                         options: [])
        indexBuffer = device.makeBuffer(bytes: indices,
                                        length: MemoryLayout<UInt16>.size * indices.count,
                                        options: [])

        let quadVertices: [Float] = [
            -0.5, -0.5, 0.0,
             0.5, -0.5, 0.0,
             0.5,  0.5, 0.0,
             
             -0.5, -0.5, 0.0,
             0.5,  0.5, 0.0,
            -0.5,  0.5, 0.0
        ]
        quadVertexBuffer = device.makeBuffer(bytes: quadVertices,
                                             length: MemoryLayout<Float>.size * quadVertices.count,
                                             options: [])
        GZLogFunc(MemoryLayout<Float>.size * quadVertices.count)

        let fovY: Float = radians_from_degrees(60.0)
        let aspect: Float = 1.0
        let near: Float = 0.1
        let far: Float = 100.0

        let projectionMatrix = leftHandedPerspectiveFOV(fovY: fovY, aspect: aspect, near: near, far: far)
        let viewMatrix = float4x4Translation([0, 0, 6])//lookAtLH(eye: [0, 0, -1], target: [0, 0, 0], up: [0, 1, 0])
        let modelMatrix = matrix_identity_float4x4

        let mvpMatrix = projectionMatrix * viewMatrix * modelMatrix

        var uni = Uniforms(modelViewProj: mvpMatrix, modelMatrix: modelMatrix)
        uniformBuffer = device.makeBuffer(bytes: &uni, length: MemoryLayout<Uniforms>.size, options: [])
        
//        let orthoMatrix = orthographicMatrixLH(left: -1,
//                                               right: 1,
//                                               bottom: -1,
//                                               top: 1,
//                                               near: -1,
//                                               far: 1)
        let orthoMatrix = orthographicMatrix(left: -1, right: 1, bottom: -1, top: 1, nearZ: -1, farZ: 1)
        var uni1 = Uniforms(modelViewProj: orthoMatrix * float4x4Translation([0, 0, 0.1]), modelMatrix: matrix_identity_float4x4)
        uniformBuffer1 = device.makeBuffer(bytes: &uni1, length: MemoryLayout<Uniforms>.size, options: [])
    }

    func buildPipelines() {
        guard let library = try? device.makeDefaultLibrary(bundle: .main) else {
            fatalError("Failed to load Metal library.")
        }

        // Define the vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3 // Position
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        vertexDescriptor.attributes[1].format = .float3 // Normal
        vertexDescriptor.attributes[1].offset = 16
        vertexDescriptor.attributes[1].bufferIndex = 0

        vertexDescriptor.attributes[2].format = .float2 // UV
        vertexDescriptor.attributes[2].offset = 32
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        vertexDescriptor.attributes[3].format = .float3 // Color
        vertexDescriptor.attributes[3].offset = 48
        vertexDescriptor.attributes[3].bufferIndex = 0

        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        // Geometry pipeline
        let geoDesc = MTLRenderPipelineDescriptor()
        geoDesc.vertexFunction = library.makeFunction(name: "geometry_vertex")
        geoDesc.fragmentFunction = library.makeFunction(name: "geometry_fragment")
        geoDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        geoDesc.colorAttachments[1].pixelFormat = .rgba16Float
        geoDesc.depthAttachmentPixelFormat = .depth32Float
        geoDesc.vertexDescriptor = vertexDescriptor // Attach the vertex descriptor
        geometryPipelineState = try! device.makeRenderPipelineState(descriptor: geoDesc)

        let vertexDescriptor1 = MTLVertexDescriptor()
        vertexDescriptor1.attributes[0].format = .float3
        vertexDescriptor1.attributes[0].offset = 0
        vertexDescriptor1.attributes[0].bufferIndex = 0

        vertexDescriptor1.layouts[0].stride = 12
        vertexDescriptor1.layouts[0].stepFunction = .perVertex
        // Lighting pipeline
        let lightDesc = MTLRenderPipelineDescriptor()
        lightDesc.vertexFunction = library.makeFunction(name: "lighting_vertex")
        lightDesc.fragmentFunction = library.makeFunction(name: "lighting_fragment")
        lightDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        lightDesc.vertexDescriptor = vertexDescriptor1 // Attach the vertex descriptor
        lightingPipelineState = try! device.makeRenderPipelineState(descriptor: lightDesc)
    }

    
    var projectionMatrix: float4x4 = matrix_identity_float4x4
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        GZLogFunc()
        let width = Int(size.width)
        let height = Int(size.height)

        // Recreate albedo texture
        let albedoDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        albedoDescriptor.usage = [.renderTarget, .shaderRead]
        albedoDescriptor.sampleCount = 1
        albedoTexture = device.makeTexture(descriptor: albedoDescriptor)

        // Recreate normal texture
        let normalDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        normalDescriptor.usage = [.renderTarget, .shaderRead]
        normalDescriptor.sampleCount = 1
        normalTexture = device.makeTexture(descriptor: normalDescriptor)

        // Recreate depth texture
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        depthDescriptor.storageMode = .private
        depthDescriptor.usage = [.renderTarget]
        depthDescriptor.sampleCount = 1
        depthTexture = device.makeTexture(descriptor: depthDescriptor)

        // Update projection matrix with new aspect ratio
        let aspect = Float(size.width / size.height)
        let fovY: Float = radians_from_degrees(60.0)
        let near: Float = 0.1
        let far: Float = 100.0

        projectionMatrix = leftHandedPerspectiveFOV(fovY: fovY, aspect: aspect, near: near, far: far)
//        let viewMatrix = lookAtLH(eye: [0, 0, -3], target: [0, 0, 0], up: [0, 1, 0])
        
        let orthoMatrix = orthographicMatrixLH(left: -1,
                                               right: 1,
                                               bottom: -1,
                                               top: 1,
                                               near: -1,
                                               far: 1)
        var uni1 = Uniforms(modelViewProj: orthoMatrix * float4x4Translation([0, 0, 1]), modelMatrix: matrix_identity_float4x4)
        uniformBuffer1 = device.makeBuffer(bytes: &uni1, length: MemoryLayout<Uniforms>.size, options: [])
    }

    func draw(in view: MTKView) {
        rotation += 0.01
        let viewMatrix = float4x4Translation([0, 0, 10])//lookAtLH(eye: [0, 0, -1], target: [0, 0, 0], up: [0, 1, 0])
        let modelMatrix = rotateX(rotation) * rotateY(rotation)
        let mvpMatrix = projectionMatrix * viewMatrix * modelMatrix

        var uni = Uniforms(modelViewProj: mvpMatrix, modelMatrix: modelMatrix)
        uniformBuffer = device.makeBuffer(bytes: &uni, length: MemoryLayout<Uniforms>.size, options: [])

        let orthoMatrix = orthographicMatrix(left: -1, right: 1, bottom: -1, top: 1, nearZ: -1, farZ: 1)
        var uni1 = Uniforms(modelViewProj: orthoMatrix * float4x4Translation([0, 0, 0.1]), modelMatrix: matrix_identity_float4x4)
        uniformBuffer1 = device.makeBuffer(bytes: &uni1, length: MemoryLayout<Uniforms>.size, options: [])
        
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let geoPassDesc = MTLRenderPassDescriptor()
//        geoPassDesc.colorAttachments[0].texture = drawable.texture
        geoPassDesc.colorAttachments[0].texture = albedoTexture
        geoPassDesc.colorAttachments[0].loadAction = .clear
        geoPassDesc.colorAttachments[0].storeAction = .store
        geoPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1)

        geoPassDesc.colorAttachments[1].texture = normalTexture
        geoPassDesc.colorAttachments[1].loadAction = .clear
        geoPassDesc.colorAttachments[1].storeAction = .store
        geoPassDesc.colorAttachments[1].clearColor = MTLClearColorMake(0, 0, 0, 1)

        geoPassDesc.depthAttachment.texture = depthTexture
        geoPassDesc.depthAttachment.loadAction = .clear
        geoPassDesc.depthAttachment.storeAction = .store
        geoPassDesc.depthAttachment.clearDepth = 1.0

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: geoPassDesc) {
            encoder.setRenderPipelineState(geometryPipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            encoder.setFrontFacing(.counterClockwise)
            encoder.setCullMode(.back)

            encoder.drawIndexedPrimitives(type: .triangle,
                                          indexCount: 36,
                                          indexType: .uint16,
                                          indexBuffer: indexBuffer,
                                          indexBufferOffset: 0)
            encoder.endEncoding()
        }

        let lightPassDesc = MTLRenderPassDescriptor()
        lightPassDesc.colorAttachments[0].texture = drawable.texture
        lightPassDesc.colorAttachments[0].loadAction = .clear
        lightPassDesc.colorAttachments[0].storeAction = .store
        lightPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.1, 0.1, 1.0, 1)

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: lightPassDesc) {
            encoder.setRenderPipelineState(lightingPipelineState)
            encoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(uniformBuffer1, offset: 0, index: 1)
            encoder.setFragmentTexture(albedoTexture, index: 0)
            encoder.setFragmentTexture(normalTexture, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return degrees * (.pi / 180.0)
}

func leftHandedPerspectiveFOV(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let yScale = 1 / tanf(fovY * 0.5)
    let xScale = yScale / aspect
    let zRange = far - near

    return float4x4([
        SIMD4<Float>(xScale, 0,      0,               0),
        SIMD4<Float>(0,      yScale, 0,               0),
        SIMD4<Float>(0,      0,      far/zRange,     1),
        SIMD4<Float>(0,      0,     -(near*far)/zRange, 0)
    ])
}

func lookAtLH(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let zAxis = normalize(target - eye)
    let xAxis = normalize(cross(up, zAxis))
    let yAxis = cross(zAxis, xAxis)

    return simd_float4x4(rows: [
        SIMD4(xAxis.x, yAxis.x, zAxis.x, 0),
        SIMD4(xAxis.y, yAxis.y, zAxis.y, 0),
        SIMD4(xAxis.z, yAxis.z, zAxis.z, 0),
        SIMD4(-dot(xAxis, eye), -dot(yAxis, eye), -dot(zAxis, eye), 1)
    ])
}

func float4x4Translation(_ translation: SIMD3<Float>) -> simd_float4x4 {
    var matrix = matrix_identity_float4x4
    matrix.columns.3.x = translation.x
    matrix.columns.3.y = translation.y
    matrix.columns.3.z = translation.z
    return matrix
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


func orthographicMatrix(left: Float, right: Float,
                        bottom: Float, top: Float,
                        nearZ: Float, farZ: Float) -> simd_float4x4 {
    let rl = right - left
    let tb = top - bottom
    let fn = farZ - nearZ
    
    // 정사영 행렬:
    // [ 2/(r-l)      0           0          -(r+l)/(r-l) ]
    // [     0     2/(t-b)        0          -(t+b)/(t-b) ]
    // [     0         0        1/(f-n)       -n/(f-n)    ]
    // [     0         0           0               1       ]
    
    return simd_float4x4(columns: (
        simd_float4( 2.0 / rl,        0.0,             0.0,              0.0),
        simd_float4(      0.0,   2.0 / tb,             0.0,              0.0),
        simd_float4(      0.0,        0.0,        1.0 / fn,              0.0),
        simd_float4(-(right + left) / rl, -(top + bottom) / tb, -nearZ / fn, 1.0)
    ))
}

func rotateY(_ angle: Float) -> float4x4 {
    let c = cos(angle)
    let s = sin(angle)
    return float4x4([
        SIMD4<Float>( c, 0, -s, 0),
        SIMD4<Float>( 0, 1,  0, 0),
        SIMD4<Float>( s, 0,  c, 0),
        SIMD4<Float>( 0, 0,  0, 1)
    ])
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
