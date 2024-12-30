//
//  UsdzLoader.swift
//  WhatIsMDL
//
//  Created by gzonelee on 12/30/24.
//

import Foundation
import MetalKit
import ModelIO

class UsdzLoader {
    
    func loadUSDZAsset(named filename: String) -> [MTKMesh]? {
        let device: MTLDevice = MTLCreateSystemDefaultDevice()!
        // 파일 경로 가져오기
        guard let url = Bundle.main.url(forResource: filename, withExtension: "usdz") else {
            print("Failed to find \(filename).usdz in bundle.")
            return nil
        }

        // MetalKit 버퍼 할당자 생성
        let allocator = MTKMeshBufferAllocator(device: device)

        // MDLAsset 생성 시 MTKMeshBufferAllocator 사용
        let asset = MDLAsset(url: url, vertexDescriptor: nil, bufferAllocator: allocator)

        GZLogFunc(asset.childObjects(of: MDLMesh.self).count)
        GZLogFunc()
        guard let mdlMeshes = asset.childObjects(of: MDLMesh.self) as? [MDLMesh] else {
            return nil
        }
        
        GZLogFunc("=====")
        for mdlMesh in mdlMeshes {
            let submeshes = mdlMesh.submeshes as? [MDLSubmesh] ?? []
            GZLogFunc(submeshes.count)
            for submesh in submeshes {
                // 서브메시마다 MDLMaterial 확인 가능
                guard let material = submesh.material else { continue }
                // 예: baseColor(기본 색상) 프로퍼티 가져오기
                let baseColorProp = material.property(with: .baseColor)
                GZLogFunc(baseColorProp)
                if baseColorProp?.type == .string {
                    GZLogFunc("string")
                    GZLogFunc(baseColorProp?.stringValue)
                }
                else if baseColorProp?.type == .URL {
                    GZLogFunc("URL")
                    GZLogFunc(baseColorProp?.urlValue)
                }
                else if baseColorProp?.type == .texture {
                    GZLogFunc("texture")
                    GZLogFunc(baseColorProp?.textureSamplerValue)
                }
                else if baseColorProp?.type == .color {
                    GZLogFunc("color")
                    GZLogFunc(baseColorProp?.color)
                }
                else if baseColorProp?.type == .float {
                    GZLogFunc("float")
                    GZLogFunc(baseColorProp?.floatValue)
                }
                else if baseColorProp?.type == .float2 {
                    GZLogFunc("float2")
                    GZLogFunc(baseColorProp?.float2Value)
                }
                else if baseColorProp?.type == .float3 {
                    GZLogFunc("float3")
                    GZLogFunc(baseColorProp?.float3Value)
                }
                else if baseColorProp?.type == .float4 {
                    GZLogFunc("float4")
                    GZLogFunc(baseColorProp?.float4Value)
                }
                else if baseColorProp?.type == .matrix44 {
                    GZLogFunc("matrix44")
                    GZLogFunc(baseColorProp?.matrix4x4)
                }
                else if baseColorProp?.type == .buffer {
                    GZLogFunc("buffer")
                }
                if let baseColorProp = material.property(with: .baseColor),
                   baseColorProp.type == .texture,
                   let textureSampler = baseColorProp.textureSamplerValue,
                   let mdlTexture = textureSampler.texture {
                    
                    // mdlTexture는 MDLTexture 프로토콜을 따르는 객체
                    // MDLImageTexture일 수도 있고, 메모리에 직접 올라가있는 텍스처일 수도 있습니다.
                    
//                    if let imageTexture = mdlTexture as? MDLImageTexture {
//                        // 실제 이미지 데이터를 사용할 수 있음
//                        let cgImage = imageTexture.imageFromTexture()
//                        // 예) UIImage 생성 등
//                        // let uiImage = UIImage(cgImage: cgImage)
//                        
//                        // 텍스처가 파일 경로로만 연결되어 있을 수도 있습니다.
//                        //  - imageTexture.name
//                        //  - imageTexture.url
//                    }

                    // 또는, 텍스처 자체가 파일 URL만 들고 있는 경우라면
                    // textureSampler.texture?.name
                    // textureSampler.texture?.url
                    // 등을 확인할 수 있습니다.
                }
                // 예: normal 프로퍼티 가져오기
                let normalProp = material.property(with: .tangentSpaceNormal)
                GZLogFunc(normalProp)
                
            }
        }
        var mtkMeshes: [MTKMesh] = []
        for mdlMesh in mdlMeshes {
            do {
                let mtkMesh = try MTKMesh(mesh: mdlMesh, device: device)
                mtkMeshes.append(mtkMesh)
            } catch {
                print("Error converting MDLMesh to MTKMesh: \(error)")
            }
        }
        return mtkMeshes
    }
}

