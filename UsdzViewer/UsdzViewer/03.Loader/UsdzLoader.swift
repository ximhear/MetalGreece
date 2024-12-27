//
//  UsdzLoader.swift
//  UsdzViewer
//
//  Created by gzonelee on 12/27/24.
//

import Foundation
import MetalKit
import ModelIO

class UsdzLoader {
    
    func load(from fileName: String) -> Model? {
       
        return nil
    }
    
    func loadUSDZAsset(named filename: String, device: MTLDevice) -> [MTKMesh]? {
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

