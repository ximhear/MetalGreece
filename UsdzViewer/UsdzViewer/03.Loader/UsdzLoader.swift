//
//  UsdzLoader.swift
//  UsdzViewer
//
//  Created by gzonelee on 12/27/24.
//

import Foundation
import MetalKit
import ModelIO
import ZIPFoundation

struct UsdzMeshData {
    let mtkMeshes: [MTKMesh]
    let meshTextures: [[MTLTexture?]]
}

class UsdzLoader {
    
    /// MDLAsset → MTKMesh 로드 (일반 예시)
    func loadUSDZAsset(named filename: String, device: MTLDevice) -> [MTKMesh]? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "usdz") else {
            print("Failed to find \(filename).usdz in bundle.")
            return nil
        }
        
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: nil, bufferAllocator: allocator)
        
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
    
    /// USDZ 파일을 로드하고 MTKMesh 배열을 반환하는 함수
    /// - Parameters:
    ///   - filename: 로드할 USDZ 파일 이름 (확장자 제외)
    ///   - device: Metal 디바이스
    /// - Returns: 로드된 MTKMesh 배열 또는 nil
    func loadUSDZ(named filename: String, device: MTLDevice) -> UsdzMeshData? {
        
        // 1. 번들에서 .usdz 파일 찾기
        guard let sourceURL = Bundle.main.url(forResource: filename, withExtension: "usdz") else {
            GZLogFunc("번들 내에서 \(filename).usdz 파일을 찾을 수 없습니다.")
            return nil
        }
        
        let fileManager = FileManager.default
        
        // 2. Documents/usdz 폴더 경로 설정
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            GZLogFunc("Documents 디렉토리에 접근할 수 없습니다.")
            return nil
        }
        let usdzFolderURL = documentsDirectory.appendingPathComponent("usdz")
        
        // 3. 기존 usdz 폴더가 있다면 삭제
        if fileManager.fileExists(atPath: usdzFolderURL.path) {
            do {
                try fileManager.removeItem(at: usdzFolderURL)
                GZLogFunc("기존 usdz 폴더가 삭제되었습니다.")
            } catch {
                GZLogFunc("기존 usdz 폴더 삭제 실패: \(error)")
                return nil
            }
        }
        
        // 4. 새 usdz 폴더 생성
        do {
            try fileManager.createDirectory(at: usdzFolderURL, withIntermediateDirectories: true, attributes: nil)
            GZLogFunc("usdz 폴더가 생성되었습니다: \(usdzFolderURL.path)")
        } catch {
            GZLogFunc("usdz 디렉토리 생성 실패: \(error)")
            return nil
        }
        
        // 5. 번들에서 .usdz 파일을 Documents/usdz 폴더로 복사
        let destinationURL = usdzFolderURL.appendingPathComponent("\(filename).usdz")
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            GZLogFunc("\(filename).usdz 파일이 \(destinationURL.path)으로 복사되었습니다.")
        } catch {
            GZLogFunc("usdz 파일 복사 실패: \(error)")
            return nil
        }
        
        // 6. ZIPFoundation을 이용하여 .usdz 파일 압축 해제
        do {
            try unzipUSDZUsingZIPFoundation(sourceURL: destinationURL, destinationURL: usdzFolderURL)
            GZLogFunc("\(filename).usdz 파일이 성공적으로 압축 해제되었습니다.")
        } catch {
            GZLogFunc("usdz 파일 압축 해제 실패: \(error)")
            return nil
        }
        
        // 7. 압축 해제된 폴더에서 .usdc 또는 .usda 파일 찾기
        guard let usdcURL = findFirstFile(withExtensions: ["usdc", "usda"], in: usdzFolderURL) else {
            GZLogFunc("압축 해제된 usdz 폴더 내에서 .usdc 또는 .usda 파일을 찾을 수 없습니다.")
            return nil
        }
        GZLogFunc("찾은 파일: \(usdcURL.lastPathComponent)")
        
        // 8. MDLAsset 생성
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: usdcURL, vertexDescriptor: nil, bufferAllocator: allocator)
        
        // 9. MDLMesh 추출
        guard let mdlMeshes = asset.childObjects(of: MDLMesh.self) as? [MDLMesh] else {
            GZLogFunc("Asset 내에서 MDLMesh를 찾을 수 없습니다.")
            return nil
        }
        
        // 10. MTKMesh 변환 및 텍스처 로드
        var mtkMeshes: [MTKMesh] = []
        var meshTextures: [[MTLTexture?]] = []
        for mdlMesh in mdlMeshes {
            // 서브메시를 돌면서 baseColor 텍스처 로드
            if let submeshes = mdlMesh.submeshes {
                var textures: [MTLTexture?] = []
                for submesh in submeshes {
                    guard let mdlSubmesh = submesh as? MDLSubmesh,
                          let material = mdlSubmesh.material else { continue }
                    
                    var meshTexture: MTLTexture?
                    // baseColor 프로퍼티 확인
                    if let baseColorProperty = material.property(with: .baseColor) {
                        // 1. baseColor가 텍스처인 경우
                        if baseColorProperty.type == .texture,
                           let mdlTexture = baseColorProperty.textureSamplerValue?.texture {
                            
                            // MDLTexture를 MTLTexture로 변환
                            if let mtlTexture = convertMDLTextureToMTLTexture(mdlTexture: mdlTexture, device: device) {
                                meshTexture = mtlTexture
                            } else {
                                GZLogFunc("MDLTexture를 MTLTexture로 변환하지 못했습니다.")
                            }
                        }
                        // 2. baseColor가 문자열(파일 경로)인 경우
                        else if baseColorProperty.type == .string,
                                let textureFilename = baseColorProperty.stringValue {
                            GZLogFunc(textureFilename)
                            
                            let textureFileURL = URL(fileURLWithPath: textureFilename)
                            
                            do {
                                let mtlTexture = try MTKTextureLoader(device: device).newTexture(URL: textureFileURL, options: nil)
                                meshTexture = mtlTexture
                            } catch {
                                GZLogFunc("텍스처 파일 로드 실패: \(textureFilename), 에러: \(error)")
                            }
                        }
                    }
                    textures.append(meshTexture)
                }
                meshTextures.append(textures)
            }
            
            // MDLMesh를 MTKMesh로 변환
            do {
                let mtkMesh = try createMTKMeshWithSelectedAttributes(from: mdlMesh, device: device)
//                let mtkMesh = try MTKMesh(mesh: mdlMesh, device: device)
                mtkMeshes.append(mtkMesh)
            } catch {
                GZLogFunc("MDLMesh를 MTKMesh로 변환하는 중 에러 발생: \(error)")
            }
        }
        
        return UsdzMeshData(mtkMeshes: mtkMeshes, meshTextures: meshTextures)
    }
    
    /// ZIPFoundation을 이용한 .usdz 파일 압축 해제 함수
    /// - Parameters:
    ///   - sourceURL: 압축 해제할 .usdz 파일의 URL
    ///   - destinationURL: 압축을 해제할 폴더의 URL
    /// - Throws: 압축 해제 과정에서 발생한 에러
    private func unzipUSDZUsingZIPFoundation(sourceURL: URL, destinationURL: URL) throws {
        
        let fileManager = FileManager()
        do {
            let archive = try Archive(url: sourceURL, accessMode: .read)
            for entry in archive {
                let entryPath = entry.path
                let entryDestinationURL = destinationURL.appendingPathComponent(entryPath)
                
                // 디렉토리인 경우 생성
                if entryPath.hasSuffix("/") {
                    try fileManager.createDirectory(at: entryDestinationURL, withIntermediateDirectories: true, attributes: nil)
                    continue
                }
                
                // 상위 디렉토리 생성
                try fileManager.createDirectory(at: entryDestinationURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                
                // 파일 추출
                _ = try archive.extract(entry, to: entryDestinationURL)
                print("Extracted \(entryPath) to \(entryDestinationURL.path)")
            }
        } catch {
            GZLogFunc(error)
        }
    }
    
    /// 지정된 폴더 내에서 특정 확장자를 가진 첫 번째 파일을 찾는 함수
    /// - Parameters:
    ///   - exts: 찾고자 하는 파일 확장자 배열 (예: ["usdc", "usda"])
    ///   - folder: 검색할 폴더의 URL
    /// - Returns: 첫 번째로 발견된 파일의 URL 또는 nil
    private func findFirstFile(withExtensions exts: [String], in folder: URL) -> URL? {
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            for ext in exts {
                if let file = files.first(where: { $0.pathExtension.lowercased() == ext.lowercased() }) {
                    return file
                }
            }
        } catch {
            print("Error listing contents of folder: \(error)")
        }
        return nil
    }
    
    func convertMDLTextureToMTLTexture(mdlTexture: MDLTexture, device: MTLDevice) -> MTLTexture? {
        // 텍스처 설명 가져오기
        
        let textureLoader = MTKTextureLoader(device: device)
        do {
            return try textureLoader.newTexture(texture: mdlTexture, options: [.SRGB: true, .generateMipmaps: true])
        }
        catch {
            GZLogFunc(error)
            return nil
        }
    }
    
    func createMTKMeshWithSelectedAttributes(from mdlMesh: MDLMesh, device: MTLDevice) throws -> MTKMesh {
        // 사용하려는 속성의 이름을 정의
        let selectedAttributes: [String] = [
            MDLVertexAttributePosition,  // 위치 정보
            MDLVertexAttributeNormal,    // 노멀 정보
            MDLVertexAttributeTextureCoordinate // 텍스처 좌표
        ]
        
        // 새 버텍스 속성 배열 생성
        let newVertexDescriptor = MDLVertexDescriptor()
        
        for (index, attributeName) in selectedAttributes.enumerated() {
            if let originalAttribute = mdlMesh.vertexDescriptor.attributeNamed(attributeName) {
                // 선택된 속성을 새 버텍스 디스크립터에 복사
                let attribute = mdlMesh.vertexDescriptor.layouts[index] as! MDLVertexBufferLayout
                newVertexDescriptor.attributes[index] = originalAttribute
//                GZLogFunc(attribute)
                newVertexDescriptor.layouts[index] = MDLVertexBufferLayout(stride: attribute.stride)
            } else {
                GZLogFunc("Attribute \(attributeName) not found in the original MDLMesh.")
            }
        }
        
        // 레이아웃 구성 (stride 계산 필요)
        
        // MDLMesh에 새 버텍스 디스크립터 적용
        mdlMesh.vertexDescriptor = newVertexDescriptor
        
        // 선택된 속성을 반영한 MTKMesh 생성
        let mtkMesh = try MTKMesh(mesh: mdlMesh, device: device)
        
        return mtkMesh
    }
}
