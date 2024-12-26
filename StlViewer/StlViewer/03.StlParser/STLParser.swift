//
//  STLParser.swift
//  StlViewer
//
//  Created by gzonelee on 12/24/24.
//

import Foundation
import simd

actor STLParser {
    enum STLFormat {
        case ascii
        case binary
    }

    struct STLResult {
        var vertices: [SIMD3<Float>]
        var normals: [SIMD3<Float>]
    }

    enum STLParserError: Error, LocalizedError {
        case nilSelf
        case fileNotFound
        case invalidFormat
        case parsingError(String)

        var errorDescription: String? {
            switch self {
            case .nilSelf:
                return "nil Self"
            case .fileNotFound:
                return "파일을 찾을 수 없습니다."
            case .invalidFormat:
                return "유효하지 않은 STL 파일 형식입니다."
            case .parsingError(let message):
                return "파싱 에러: \(message)"
            }
        }
    }

    init() {
    }

    /// STL 파일 포맷을 감지합니다.
    func detectFormat(data: Data) -> STLFormat {
        if data.count >= 5, let prefix = String(data: data.subdata(in: 0..<5), encoding: .utf8), prefix.lowercased() == "solid" {
            return .ascii
        }
        return .binary
    }

    /// ASCII STL 파일을 파싱합니다.
    func parseASCII(data: Data) throws -> STLResult {
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        let normalRegex = try NSRegularExpression(pattern: #"facet normal\s+([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)"#)
        let vertexRegex = try NSRegularExpression(pattern: #"vertex\s+([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)"#)

        var currentIndex = data.startIndex
        while currentIndex < data.endIndex {
            // 라인 찾기
            if let lineEndIndex = data[currentIndex...].firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = data[currentIndex..<lineEndIndex]

                // 필요한 경우에만 String으로 변환
                if let lineString = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespaces),
                   let firstChar = lineString.first, (firstChar == "f" || firstChar == "v") { // 'f' (facet) 또는 'v' (vertex)로 시작하는 라인만 처리

                    // 정규 표현식 매칭
                    if let match = normalRegex.firstMatch(in: lineString, range: NSRange(location: 0, length: lineString.utf16.count)) {
                        let components = (1...3).compactMap {
                            Range(match.range(at: $0), in: lineString).flatMap { Float(lineString[$0]) }
                        }
                        if components.count == 3 {
                            normals.append(SIMD3(components))
                        } else {
                            throw STLParserError.parsingError("Invalid normal vector at line: \(lineString)")
                        }
                    } else if let match = vertexRegex.firstMatch(in: lineString, range: NSRange(location: 0, length: lineString.utf16.count)) {
                        let components = (1...3).compactMap {
                            Range(match.range(at: $0), in: lineString).flatMap { Float(lineString[$0]) }
                        }
                        if components.count == 3 {
                            vertices.append(SIMD3(components))
                        } else {
                            throw STLParserError.parsingError("Invalid vertex at line: \(lineString)")
                        }
                    }
                }

                currentIndex = data.index(after: lineEndIndex)
            } else {
                // 마지막 라인 처리
                if currentIndex < data.endIndex {
                    let lineData = data[currentIndex...]
                    if let lineString = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespaces),
                       let firstChar = lineString.first, (firstChar == "f" || firstChar == "v") {

                        // 정규 표현식 매칭 (위와 동일)
                        if let match = normalRegex.firstMatch(in: lineString, range: NSRange(location: 0, length: lineString.utf16.count)) {
                            let components = (1...3).compactMap {
                                Range(match.range(at: $0), in: lineString).flatMap { Float(lineString[$0]) }
                            }
                            if components.count == 3 {
                                normals.append(SIMD3(components))
                            } else {
                                throw STLParserError.parsingError("Invalid normal vector at line: \(lineString)")
                            }
                        } else if let match = vertexRegex.firstMatch(in: lineString, range: NSRange(location: 0, length: lineString.utf16.count)) {
                            let components = (1...3).compactMap {
                                Range(match.range(at: $0), in: lineString).flatMap { Float(lineString[$0]) }
                            }
                            if components.count == 3 {
                                vertices.append(SIMD3(components))
                            } else {
                                throw STLParserError.parsingError("Invalid vertex at line: \(lineString)")
                            }
                        }
                    }
                }
                break
            }
        }

        return STLResult(vertices: vertices, normals: normals)
    }

    /// 바이너리 STL 파일을 파싱합니다.
    func parseBinary(data: Data) throws -> STLResult {
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        
        let triangleCountOffset = 80
        guard data.count >= triangleCountOffset + 4 else {
            throw STLParserError.invalidFormat
        }
        
        // 삼각형 개수를 읽습니다.
        let triangleCount = data.subdata(in: triangleCountOffset..<(triangleCountOffset + 4)).withUnsafeBytes {
            $0.load(as: UInt32.self)
        }
        
        let triangleDataSize = 50
        let vertexDataOffset = triangleCountOffset + 4
        GZLogFunc(triangleCount)
        
        for i in 0..<triangleCount {
            let start = vertexDataOffset + Int(i) * triangleDataSize
            guard data.count >= start + triangleDataSize else {
                throw STLParserError.invalidFormat
            }
            let triangleData = data.subdata(in: start..<(start + triangleDataSize))
            
            // 메모리를 안전하게 읽습니다.
            triangleData.withUnsafeBytes { buffer in
                let pointer = buffer.baseAddress!
                
                // 법선 벡터 읽기
                let normal = pointer.advanced(by: 0).assumingMemoryBound(to: Float.self)
                normals.append(SIMD3(normal[0], normal[1], normal[2]))
                
                // 정점 읽기
                for j in 0..<3 {
                    let vertexOffset = 12 + j * 12
                    let vertex = pointer.advanced(by: vertexOffset).assumingMemoryBound(to: Float.self)
                    vertices.append(SIMD3(vertex[0], vertex[1], vertex[2]))
                }
            }
        }
        
        return STLResult(vertices: vertices, normals: normals)
    }

    func load(from stlName: String) async throws -> Model? {
        guard let stlURL = Bundle.main.url(forResource: stlName, withExtension: "stl") else {
            GZLogFunc("Failed to get URL for \(stlName).stl")
            return nil
        }
        
        let colorUtil = ColorUtil()
        let result = try await parse(from: stlURL)
      
        var vertices: [Vertex] = []
        var faces: [Face] = []
        for index in 0..<Int(result.vertices.count / 3) {
            let v0 = result.vertices[index * 3 + 0]
            let v1 = result.vertices[index * 3 + 2]
            let v2 = result.vertices[index * 3 + 1]
            vertices.append(Vertex(position: v0, color: colorUtil.getColor(index: index * 3)))
            vertices.append(Vertex(position: v1, color: colorUtil.getColor(index: index * 3 + 1)))
            vertices.append(Vertex(position: v2, color: colorUtil.getColor(index: index * 3 + 2)))
            
            let vec0 = v1 - v0
            let vec1 = v2 - v0
            
            let normal: SIMD3<Float> = simd_normalize(simd_cross(vec0, vec1))
            faces.append(Face(normal: normal, color: colorUtil.getColor(index: index)))
        }
        let indices = vertices.enumerated().map { index, _ in UInt32(index) }
        let model = Model(fileName: stlName, vertices: vertices, indices: indices, faces: faces)
        GZLogFunc(model.vertices.count)
        GZLogFunc(model.indices.count)
        GZLogFunc(model.faces.count)
        GZLogFunc()
        return model
    }
    
    /// STL 파일을 로드합니다.
    func parse(from stlURL: URL) async throws -> STLResult {
        guard let data = try? Data(contentsOf: stlURL) else {
            throw STLParserError.fileNotFound
        }
        let format = self.detectFormat(data: data)
        
        let result: STLResult
        if format == .ascii {
            result = try self.parseASCII(data: data)
        }
        else {
            result = try self.parseBinary(data: data)
        }
        return result
    }
}
