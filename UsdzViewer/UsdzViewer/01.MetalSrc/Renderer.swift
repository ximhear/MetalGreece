//
//  Renderer.swift
//  ShadowMap
//
//  Created by gzonelee on 12/12/24.
//

import MetalKit
import simd
import ModelIO

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

@MainActor class Renderer {
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
    
    let mtkMeshes: [MTKMesh]

    var vertexBuffers: [MTLBuffer]
    var indexBuffers: [MTLBuffer]
    var faceBuffers: [MTLBuffer]
    let depthWidth: Int = 1024 * 2
    
    var viewX: Float = 0
    var viewY: Float = 0
    var viewZ: Float = 0
    
    let maxVerticies = 4194303
//    let maxVerticies = 90000
    
    let isCounterClockwise: Bool

    init?(mtkView: MTKView, fileName: String) {
        guard let dev = mtkView.device else { return nil }
        device = dev
        guard let cq = device.makeCommandQueue() else { return nil }
        commandQueue = cq

        guard let mtkMeshes = UsdzLoader().loadUSDZAsset(named: fileName, device: device) else {
            return nil
        }
        self.mtkMeshes = mtkMeshes
        
        if let counterClockwise = Self.isTriangleCounterClockwiseInMTKMesh(mesh: mtkMeshes.first), counterClockwise {
            isCounterClockwise = true
        }
        else {
            isCounterClockwise = false
        }
        GZLogFunc(isCounterClockwise)
        GZLogFunc()
        
        for mtkMesh in mtkMeshes {
            GZLogFunc()
            GZLogFunc(mtkMesh.vertexCount)
            GZLogFunc(mtkMesh.vertexBuffers.first?.length)
            GZLogFunc(mtkMesh.vertexBuffers.count)
            GZLogFunc(mtkMesh.submeshes.count)
            GZLogFunc(mtkMesh.vertexDescriptor)
            for x in mtkMesh.submeshes {
                GZLogFunc(x.indexCount)
            }
            GZLogFunc()
        }
        GZLogFunc()
        
        vertexBuffers = []
        indexBuffers = []
        faceBuffers = []
        

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
        vertexDescriptor.attributes[0].bufferIndex = 0
        // normal
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 1
        // uv
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = 0
        vertexDescriptor.attributes[2].bufferIndex = 2
        
        vertexDescriptor.layouts[0].stride = 12
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        vertexDescriptor.layouts[1].stride = 12
        vertexDescriptor.layouts[1].stepFunction = .perVertex
        
        vertexDescriptor.layouts[2].stride = 8
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

        memcpy(sceneUniformBuffer.contents(), &sceneUniforms, MemoryLayout<SceneUniforms>.size)
        memcpy(modelUniformBuffer.contents(), &modelUniforms, MemoryLayout<ModelUniforms>.size)

        rpd.depthAttachment.clearDepth = 1.0
        if mtkMeshes.count > 0 {
            let samplerDesc = MTLSamplerDescriptor()
            samplerDesc.minFilter = .linear
            samplerDesc.magFilter = .linear
            samplerDesc.compareFunction = .less
            guard let shadowSampler = device.makeSamplerState(descriptor: samplerDesc) else { return }
            
            if let mainEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) {
                mainEncoder.setRenderPipelineState(mainRenderPipeline)
                mainEncoder.setDepthStencilState(depthStencilState)
                mainEncoder.setVertexBuffer(sceneUniformBuffer, offset: 0, index: 3)
                mainEncoder.setVertexBuffer(modelUniformBuffer, offset: 0, index: 4)
                mainEncoder.setFragmentBuffer(sceneUniformBuffer, offset: 0, index: 3)
                mainEncoder.setFragmentBuffer(modelUniformBuffer, offset: 0, index: 4)
                mainEncoder.setFrontFacing(isCounterClockwise ? .counterClockwise : .clockwise)
                mainEncoder.setCullMode(.back)
//                mainEncoder.setTriangleFillMode(.lines)
                
                mainEncoder.setFragmentTexture(shadowDepthTexture, index: 0)
                mainEncoder.setFragmentSamplerState(shadowSampler, index: 0)
                
                for mtkMesh in mtkMeshes {
                    for (index, vertexBuffer) in mtkMesh.vertexBuffers.enumerated() {
                        mainEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: index)
                    }
                    for submesh in mtkMesh.submeshes {
                        mainEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                          indexCount: submesh.indexCount,
                                                          indexType: submesh.indexType,
                                                          indexBuffer: submesh.indexBuffer.buffer,
                                                          indexBufferOffset: submesh.indexBuffer.offset)
                    }
//                    break
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
    
    func isTriangleCounterClockwiseLeftHanded(mesh: MDLMesh) -> Bool {
        // 정점 버퍼 가져오기
        guard let vertexBuffer = mesh.vertexBuffers.first else {
            print("Failed to get vertex buffer.")
            return false
        }

        // 정점 데이터를 Float3 배열로 추출
        let vertexData = vertexBuffer.map().bytes.assumingMemoryBound(to: simd_float3.self)
        let vertexCount = mesh.vertexCount

        // 인덱스 버퍼 가져오기
        guard let submesh = mesh.submeshes?.first as? MDLSubmesh else {
            print("Failed to get index buffer.")
            return false
        }

        let indexBuffer = submesh.indexBuffer
        // 인덱스 데이터를 UInt32 배열로 추출
        GZLogFunc(submesh.indexType)
        GZLogFunc()
        let indexData = indexBuffer.map().bytes.assumingMemoryBound(to: UInt32.self)
        let indexCount = submesh.indexCount

        // 첫 번째 삼각형의 세 정점 추출
        if indexCount < 3 {
            print("Not enough indices for a triangle.")
            return false
        }

        let i0 = indexData[0]
        let i1 = indexData[1]
        let i2 = indexData[2]

        if i0 >= vertexCount || i1 >= vertexCount || i2 >= vertexCount {
            print("Invalid index.")
            return false
        }

        let v0 = vertexData[Int(i0)]
        let v1 = vertexData[Int(i1)]
        let v2 = vertexData[Int(i2)]

        // 삼각형의 두 벡터 계산
        let ab = v1 - v0
        let ac = v2 - v0

        // 법선 벡터 계산
        let normal = cross(ab, ac)

        // 왼손 좌표계: 법선의 z 값으로 반시계 확인
        return normal.z > 0 // true면 counterclockwise, false면 clockwise
    }
    
    
    static func isTriangleCounterClockwiseInMTKMesh(mesh: MTKMesh?, submeshIndex: Int = 0) -> Bool? {
        // Vertex Buffer 가져오기
        guard let mesh, let vertexBuffer = mesh.vertexBuffers.first?.buffer else {
            print("Failed to get vertex buffer.")
            return nil
        }

        // Submesh에서 Index Buffer 가져오기
        guard submeshIndex < mesh.submeshes.count else {
            print("Invalid submesh index.")
            return nil
        }
        let submesh = mesh.submeshes[submeshIndex]
        let indexBuffer = submesh.indexBuffer.buffer
        let indexType = submesh.indexType
        let indexCount = submesh.indexCount

        // Vertex 데이터 읽기
        let vertexPointer = vertexBuffer.contents().assumingMemoryBound(to: simd_float3.self)

        // Index 데이터 읽기
        var index0: Int = 0
        var index1: Int = 0
        var index2: Int = 0
        if indexType == .uint16 {
            let indexPointer = indexBuffer.contents().assumingMemoryBound(to: UInt16.self)
            index0 = Int(indexPointer[0])
            index1 = Int(indexPointer[1])
            index2 = Int(indexPointer[2])
        } else if indexType == .uint32 {
            let indexPointer = indexBuffer.contents().assumingMemoryBound(to: UInt32.self)
            index0 = Int(indexPointer[0])
            index1 = Int(indexPointer[1])
            index2 = Int(indexPointer[2])
        } else {
            print("Unsupported index type.")
            return nil
        }

        // 첫 번째 삼각형의 세 정점 가져오기
        guard indexCount >= 3 else {
            print("Not enough indices for a triangle.")
            return nil
        }

        let i0 = index0
        let i1 = index1
        let i2 = index2

        guard i0 < mesh.vertexCount, i1 < mesh.vertexCount, i2 < mesh.vertexCount else {
            print("Invalid indices in index buffer.")
            return nil
        }

        let v0 = vertexPointer[i0]
        let v1 = vertexPointer[i1]
        let v2 = vertexPointer[i2]

        // 벡터 계산
        let ab = v1 - v0
        let ac = v2 - v0

        // 2D Cross Product 계산
        let crossProduct = cross(ab, ac)

        // 방향 확인 (반시계: true, 시계: false)
        return crossProduct.z > 0
    }
}
