//
//  Renderer.swift
//  ShadowMap
//
//  Created by gzonelee on 12/12/24.
//

import MetalKit
import simd

struct SceneUniforms {
    var lightViewProjMatrix: float4x4
    var cameraProjMatrix: float4x4
    var cameraViewProjMatrix: float4x4
    var lightPos: SIMD3<Float>
}


struct ModelUniforms {
    var modelMatrix: float4x4
    var normalMatrix: float3x3
}

class Renderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var mainRenderPipeline: MTLRenderPipelineState!
    var depthStencilState: MTLDepthStencilState!
    var shadowDepthTexture: MTLTexture!

    var sceneUniforms = SceneUniforms(
        lightViewProjMatrix: matrix_identity_float4x4,
        cameraProjMatrix: matrix_identity_float4x4,
        cameraViewProjMatrix: matrix_identity_float4x4,
        lightPos: [0,3,0] // 빛을 삼각형 위에 배치
    )
    var modelUniforms = ModelUniforms(
        modelMatrix: float4x4(translation: [0,0,0]),
        normalMatrix: float3x3(1)
    )

    var sceneUniformBuffer: MTLBuffer!
    var modelUniformBuffer: MTLBuffer!
    var rotation: Float = 0
    
    let model: Model

    var vertexBuffers: [MTLBuffer]
    var indexBuffers: [MTLBuffer]
    var faceBuffers: [MTLBuffer]
    let depthWidth: Int = 1024 * 2
    
    var viewX: Float = 0
    var viewY: Float = 0
    var viewZ: Float = 0
    
    let maxVerticies = 4194303
//    let maxVerticies = 90000

    init?(mtkView: MTKView, model: Model) {
        guard let dev = mtkView.device else { return nil }
        device = dev
        guard let cq = device.makeCommandQueue() else { return nil }
        commandQueue = cq

//        model = plyParser.loadLarge(from: fileName)
        self.model = model
        GZLogFunc(model.vertices.count)
        GZLogFunc(model.faces.count)
        GZLogFunc(model.indices.count)
        model.printInfo()
        GZLogFunc()
        
        let count = (model.vertices.count + maxVerticies - 1) / maxVerticies
        
        vertexBuffers = []
        indexBuffers = []
        faceBuffers = []
        for i in 0..<count {
            let start = i * maxVerticies
            var end = start + maxVerticies
            if i == count - 1 {
                end = model.vertices.count
            }
            let vertexSlice = model.vertices[start..<end] // 필요한 구간 Slice
            let indexSlice = model.indices[start..<end] // 필요한 구간 Slice
            let faceSlice = model.faces[start/3..<end/3] // 필요한 구간 Slice
            var vertexBuffer: MTLBuffer?
            var indexBuffer: MTLBuffer?
            var faceBuffer: MTLBuffer?
            vertexSlice.withUnsafeBytes { rawBuffer in
                vertexBuffer = device.makeBuffer(bytes: rawBuffer.baseAddress!,
                                                  length: rawBuffer.count,
                                                  options: [])
            }
            let indices = indexSlice.map { $0 - UInt32(start) }
            indices.withUnsafeBytes { rawBuffer in
                GZLogFunc(rawBuffer.count)
                indexBuffer = device.makeBuffer(bytes: rawBuffer.baseAddress!,
                                                  length: rawBuffer.count,
                                                  options: [])
            }
            faceSlice.withUnsafeBytes { rawBuffer in
                faceBuffer = device.makeBuffer(bytes: rawBuffer.baseAddress!,
                                                  length: rawBuffer.count,
                                                  options: [])
            }
            if let vertexBuffer, let indexBuffer, let faceBuffer {
                vertexBuffers.append(vertexBuffer)
                indexBuffers.append(indexBuffer)
                faceBuffers.append(faceBuffer)
            }
        }
        

        GZLogFunc(MemoryLayout<SceneUniforms>.size)
        GZLogFunc(MemoryLayout<SceneUniforms>.stride)
        GZLogFunc(MemoryLayout<float4x4>.stride)
        GZLogFunc(MemoryLayout<Vertex>.stride)
        GZLogFunc()
        
        sceneUniformBuffer = device.makeBuffer(length: MemoryLayout<SceneUniforms>.size, options: [])
        modelUniformBuffer = device.makeBuffer(length: MemoryLayout<ModelUniforms>.size, options: [])

        setupMatrices(viewSize: mtkView.drawableSize)

        // Depth Stencil
        let depthStencilDesc = MTLDepthStencilDescriptor()
        depthStencilDesc.depthCompareFunction = .less
        depthStencilDesc.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDesc)

        guard let library = device.makeDefaultLibrary() else { return nil }

        // Vertex Descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        // position
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 2
        // normal
//        vertexDescriptor.attributes[1].format = .float3
//        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 3
//        vertexDescriptor.attributes[1].bufferIndex = 2
        // color
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = 16
        vertexDescriptor.attributes[1].bufferIndex = 2
        vertexDescriptor.layouts[2].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[2].stepFunction = .perVertex

        // Main Pipeline (with shadow map)
        let mainPSODesc = MTLRenderPipelineDescriptor()
        mainPSODesc.vertexFunction = library.makeFunction(name: "main_vertex")
        mainPSODesc.fragmentFunction = library.makeFunction(name: "main_fragment")
        mainPSODesc.vertexDescriptor = vertexDescriptor
        mainPSODesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        mainPSODesc.depthAttachmentPixelFormat = .depth32Float

        do {
            mainRenderPipeline = try device.makeRenderPipelineState(descriptor: mainPSODesc)
        } catch {
            print("Failed to create mainRenderPipeline: \(error)")
            return nil
        }
    }
    
    deinit {
        GZLogFunc()
    }

    func setupMatrices(viewSize: CGSize) {
        let aspect = Float(viewSize.width/viewSize.height)
        // LH Perspective for camera
        sceneUniforms.cameraProjMatrix = perspectiveMatrixLH(aspect: aspect, fovY: Float.pi / 6, nearZ: 0.1, farZ: 1000)

        // LH Orthographic for light (빛의 관점)
        sceneUniforms.lightViewProjMatrix = orthographicMatrixLH(left: -1, right: 1, bottom: -1, top: 1, near: -1, far: 20) * float4x4(translation: [0, 0, 1]) * rotateX(-Float.pi / 2) // 빛을 삼각형 위에 배치
    }

    func resize(size: CGSize) {
        setupMatrices(viewSize: size)
    }

    func draw(in view: MTKView) {
        rotation += 0.01
//        rotation = Float.pi / 2.0
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor else { return }
        
        modelUniforms.modelMatrix = rotateX(-0 / 180.0 * Float.pi) * float4x4(translation: [0, 0, 0]) * rotateY(rotation)
        modelUniforms.normalMatrix = calculateNormalMatrix(from: modelUniforms.modelMatrix)
        sceneUniforms.cameraViewProjMatrix = sceneUniforms.cameraProjMatrix * float4x4(translation: [viewX, viewY, viewZ])
//        sceneUniforms.cameraViewProjMatrix = orthographicMatrixLH(left: -100, right: 100, bottom: -100, top: 100, near: -1100, far: 1500) * float4x4(translation: [0, 0, 120]) * rotateX(-Float.pi / 2)

        memcpy(sceneUniformBuffer.contents(), &sceneUniforms, MemoryLayout<SceneUniforms>.size)
        memcpy(modelUniformBuffer.contents(), &modelUniforms, MemoryLayout<ModelUniforms>.size)

        rpd.depthAttachment.clearDepth = 1.0
        if vertexBuffers.count > 0 {
            let samplerDesc = MTLSamplerDescriptor()
            samplerDesc.minFilter = .linear
            samplerDesc.magFilter = .linear
            samplerDesc.compareFunction = .less
            guard let shadowSampler = device.makeSamplerState(descriptor: samplerDesc) else { return }
            
            if let mainEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) {
                mainEncoder.setRenderPipelineState(mainRenderPipeline)
                mainEncoder.setDepthStencilState(depthStencilState)
                mainEncoder.setVertexBuffer(sceneUniformBuffer, offset: 0, index: 0)
                mainEncoder.setVertexBuffer(modelUniformBuffer, offset: 0, index: 1)
                mainEncoder.setFragmentBuffer(sceneUniformBuffer, offset: 0, index: 0)
                mainEncoder.setFragmentBuffer(modelUniformBuffer, offset: 0, index: 1)
                mainEncoder.setFrontFacing(.counterClockwise)
                mainEncoder.setCullMode(.back)
                
                mainEncoder.setFragmentTexture(shadowDepthTexture, index: 0)
                mainEncoder.setFragmentSamplerState(shadowSampler, index: 0)
                
                for x in 0..<vertexBuffers.count {
                    let vertexBuffer = vertexBuffers[x]
                    let indexBuffer = indexBuffers[x]
                    let faceBuffer = faceBuffers[x]
                    let indexCount: Int
                    indexCount = indexBuffer.length / MemoryLayout<UInt32>.size
                    mainEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 2)
                    mainEncoder.setFragmentBuffer(faceBuffer, offset: 0, index: 2)
                    mainEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: indexCount)
//                    mainEncoder.drawIndexedPrimitives(type: .triangle,
//                                                      indexCount: indexCount,
//                                                      indexType: .uint32,
//                                                      indexBuffer: indexBuffer,
//                                                      indexBufferOffset: 0)
                }
                mainEncoder.endEncoding()
            }
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func calculateNormalMatrix(from modelMatrix: simd_float4x4) -> simd_float3x3 {
        // 4x4 모델 행렬의 상위 3x3 부분 추출
        let upperLeft3x3 = simd_float3x3(
            simd_float3(modelMatrix.columns.0.x, modelMatrix.columns.0.y, modelMatrix.columns.0.z),
            simd_float3(modelMatrix.columns.1.x, modelMatrix.columns.1.y, modelMatrix.columns.1.z),
            simd_float3(modelMatrix.columns.2.x, modelMatrix.columns.2.y, modelMatrix.columns.2.z)
        )
        
        // 역행렬 계산
        let inverse3x3 = upperLeft3x3.inverse
        
        // 역행렬의 전치 행렬 계산
        let normalMatrix = inverse3x3.transpose
        
        return normalMatrix
    }
}
