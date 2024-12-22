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
}

class Renderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var shadowRenderPipeline: MTLRenderPipelineState!
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
        modelMatrix: float4x4(translation: [0,0,0])
    )

    var sceneUniformBuffer: MTLBuffer!
    var modelUniformBuffer: MTLBuffer!
    var rotation: Float = 0
    
    var model = Model()


    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var faceBuffer: MTLBuffer!
    let depthWidth: Int = 1024 * 2

    init?(mtkView: MTKView) {
        guard let dev = mtkView.device else { return nil }
        device = dev
        guard let cq = device.makeCommandQueue() else { return nil }
        commandQueue = cq

        model.loadFromJson()
        
        vertexBuffer = device.makeBuffer(bytes: model.vertices,
                                         length: model.vertices.count * MemoryLayout<Vertex>.stride,
                                         options: [])
        indexBuffer = device.makeBuffer(bytes: model.indices,
                                        length: model.indices.count * MemoryLayout<UInt16>.size,
                                        options: [])
        faceBuffer = device.makeBuffer(bytes: model.faces,
                                       length: model.faces.count * MemoryLayout<Face>.size,
                                        options: [])

        GZLogFunc(MemoryLayout<SceneUniforms>.size)
        GZLogFunc(MemoryLayout<SceneUniforms>.stride)
        GZLogFunc(MemoryLayout<float4x4>.stride)
        GZLogFunc(MemoryLayout<Vertex>.stride)
        GZLogFunc()
        
        sceneUniformBuffer = device.makeBuffer(length: MemoryLayout<SceneUniforms>.size, options: [])
        modelUniformBuffer = device.makeBuffer(length: MemoryLayout<ModelUniforms>.size, options: [])

        setupMatrices(viewSize: mtkView.drawableSize)

        // 쉐도우 맵용 깊이 텍스처
        let shadowMapDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float,
                                                                     width: depthWidth,
                                                                     height: depthWidth,
                                                                     mipmapped: false)
        shadowMapDesc.storageMode = .private
//        shadowMapDesc.storageMode = .shared
        shadowMapDesc.usage = [.renderTarget, .shaderRead]
        shadowDepthTexture = device.makeTexture(descriptor: shadowMapDesc)

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

        // Shadow Pipeline (depth-only)
        let shadowPSODesc = MTLRenderPipelineDescriptor()
        shadowPSODesc.vertexFunction = library.makeFunction(name: "shadow_vertex")
        shadowPSODesc.fragmentFunction = nil
        shadowPSODesc.vertexDescriptor = vertexDescriptor
        shadowPSODesc.depthAttachmentPixelFormat = .depth32Float

        do {
            shadowRenderPipeline = try device.makeRenderPipelineState(descriptor: shadowPSODesc)
        } catch {
            print("Failed to create shadowRenderPipeline: \(error)")
            return nil
        }

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

    func setupMatrices(viewSize: CGSize) {
        let aspect = Float(viewSize.width/viewSize.height)
        // LH Perspective for camera
        sceneUniforms.cameraProjMatrix = perspectiveMatrixLH(aspect: aspect, fovY: Float.pi / 6, nearZ: 0.1, farZ: 1000)

        // LH Orthographic for light (빛의 관점)
        sceneUniforms.lightViewProjMatrix =
//        perspectiveMatrixLH(aspect: aspect, fovY: Float.pi / 6, nearZ: 0.1, farZ: 1000) *
        orthographicMatrixLH(left: -5, right: 5, bottom: -5, top: 5, near: -20, far: 20) *
        float4x4(translation: [0, 0, 8]) * rotateX(-Float.pi / 2) // 빛을 삼각형 위에 배치
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
        
        sceneUniforms.cameraViewProjMatrix = sceneUniforms.cameraProjMatrix * float4x4(translation: [0, -50, 330]) * rotateY(rotation)

        memcpy(sceneUniformBuffer.contents(), &sceneUniforms, MemoryLayout<SceneUniforms>.size)
        memcpy(modelUniformBuffer.contents(), &modelUniforms, MemoryLayout<ModelUniforms>.size)

        // Shadow Pass (light POV)
        let shadowPassDesc = MTLRenderPassDescriptor()
        shadowPassDesc.depthAttachment.texture = shadowDepthTexture
        shadowPassDesc.depthAttachment.loadAction = .clear
        shadowPassDesc.depthAttachment.storeAction = .store
        shadowPassDesc.depthAttachment.clearDepth = 1.0

        if let shadowEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: shadowPassDesc) {
            shadowEncoder.setRenderPipelineState(shadowRenderPipeline)
            shadowEncoder.setDepthStencilState(depthStencilState)
            shadowEncoder.setVertexBuffer(sceneUniformBuffer, offset: 0, index: 0)
            shadowEncoder.setVertexBuffer(modelUniformBuffer, offset: 0, index: 1)
            shadowEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 2)
            shadowEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: model.indices.count,
                                                indexType: .uint16,
                                                indexBuffer: indexBuffer,
                                                indexBufferOffset: 0)
            shadowEncoder.endEncoding()
        }

        rpd.depthAttachment.clearDepth = 1.0
        if let mainEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) {
            mainEncoder.setRenderPipelineState(mainRenderPipeline)
            mainEncoder.setDepthStencilState(depthStencilState)
            mainEncoder.setVertexBuffer(sceneUniformBuffer, offset: 0, index: 0)
            mainEncoder.setVertexBuffer(modelUniformBuffer, offset: 0, index: 1)
            mainEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 2)
            mainEncoder.setFragmentBuffer(sceneUniformBuffer, offset: 0, index: 0)
            mainEncoder.setFragmentBuffer(modelUniformBuffer, offset: 0, index: 1)
            mainEncoder.setFragmentBuffer(faceBuffer, offset: 0, index: 2)
            mainEncoder.setFrontFacing(.counterClockwise)
            mainEncoder.setCullMode(.back)

            let samplerDesc = MTLSamplerDescriptor()
            samplerDesc.minFilter = .linear
            samplerDesc.magFilter = .linear
            samplerDesc.compareFunction = .less
            guard let shadowSampler = device.makeSamplerState(descriptor: samplerDesc) else { return }

            mainEncoder.setFragmentTexture(shadowDepthTexture, index: 0)
            mainEncoder.setFragmentSamplerState(shadowSampler, index: 0)

            mainEncoder.drawIndexedPrimitives(type: .triangle,
                                              indexCount: model.indices.count,
                                              indexType: .uint16,
                                              indexBuffer: indexBuffer,
                                              indexBufferOffset: 0)
            mainEncoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
