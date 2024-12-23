//
//  PlyParser.swift
//  PlyViewer
//
//  Created by gzonelee on 12/23/24.
//

import Foundation
import simd

struct PlyVertex {
    var x: Float
    var y: Float
    var z: Float
}

struct PlyFace {
    var vertexIndices: [Int]
}

struct PlyModel {
    var vertices: [PlyVertex] = []
    var faces: [PlyFace] = []
}

enum PlyParseError: Error {
    case invalidHeader
    case unsupportedFormat
    case invalidData
}

class PlyParser {
    let colors = ColorUtil()
    
    func load(from plyName: String) -> Model {
        let plyURL = Bundle.main.url(forResource: plyName, withExtension: "ply")!
        GZLogFunc(plyURL)
        let model = Model()
        do {
            let plyModel = try parse(from: plyURL)
            GZLogFunc(model.vertices.count)
            GZLogFunc(model.faces.count)
            
            let vertices: [Vertex] = plyModel.vertices.enumerated().map { index, vertex in
                let position = SIMD3<Float>(vertex.x, vertex.y, vertex.z)
                let color = colors.getColor(index: index)
                return Vertex(position: position, color: color)
            }
            let indices: [UInt32] = plyModel.faces.map{ $0.vertexIndices }.flatMap { [UInt32($0[0]), UInt32($0[2]), UInt32($0[1])] }
            
            let faces: [Face] = plyModel.faces.enumerated().map { index, face in
                let v0 = vertices[face.vertexIndices[0]].position
                let v1 = vertices[face.vertexIndices[2]].position
                let v2 = vertices[face.vertexIndices[1]].position
                let vec1 = v1 - v0
                let vec2 = v2 - v0
                let normal: SIMD3<Float> = simd_normalize(simd_cross(vec1, vec2))
                return Face(normal: normal, color: colors.getColor(index: index))
            }
            model.vertices = vertices
            model.indices = indices
            model.faces = faces
        }
        catch {
            GZLogFunc(error)
        }
        return model
    }
    
    func loadLarge(from plyName: String) -> Model {
        let plyURL = Bundle.main.url(forResource: plyName, withExtension: "ply")!
        GZLogFunc(plyURL)
        let model = Model()
        do {
            let plyModel = try parseLargeFile(from: plyURL)
            GZLogFunc(plyModel.vertices.count)
            GZLogFunc(plyModel.faces.count)
            
            let vertices: [Vertex] = plyModel.vertices.enumerated().map { index, vertex in
                let position = SIMD3<Float>(vertex.x, vertex.y, vertex.z)
                let color = colors.getColor(index: index)
                return Vertex(position: position, color: color)
            }
            let indices: [UInt32] = plyModel.faces.map{ $0.vertexIndices }.flatMap { [UInt32($0[0]), UInt32($0[2]), UInt32($0[1])] }
            
            let faces: [Face] = plyModel.faces.enumerated().map { index, face in
                let v0 = vertices[face.vertexIndices[0]].position
                let v1 = vertices[face.vertexIndices[2]].position
                let v2 = vertices[face.vertexIndices[1]].position
                let vec1 = v1 - v0
                let vec2 = v2 - v0
                let normal: SIMD3<Float> = simd_normalize(simd_cross(vec1, vec2))
                return Face(normal: normal, color: colors.getColor(index: index))
            }
            model.vertices = vertices
            model.indices = indices
            model.faces = faces
        }
        catch {
            GZLogFunc(error)
        }
        return model
    }

    func parse(from url: URL) throws -> PlyModel {
        let content = try String(contentsOf: url, encoding: .utf8)
        var lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        // Parse header
        guard lines.first == "ply" else {
            throw PlyParseError.invalidHeader
        }

        var isAscii = false
        var vertexCount = 0
        var faceCount = 0
        var headerParsed = false
        var model = PlyModel()

        lines.removeFirst()

        while let line = lines.first, line != "end_header" {
            lines.removeFirst()
            if line.hasPrefix("format ascii") {
                isAscii = true
            } else if line.hasPrefix("element vertex") {
                vertexCount = Int(line.components(separatedBy: " ")[2]) ?? 0
            } else if line.hasPrefix("element face") {
                faceCount = Int(line.components(separatedBy: " ")[2]) ?? 0
            } else if line.hasPrefix("format binary") {
                throw PlyParseError.unsupportedFormat
            }
        }

        if lines.first == "end_header" {
            lines.removeFirst()
            headerParsed = true
        }

        guard headerParsed, isAscii else {
            throw PlyParseError.invalidHeader
        }

        // Parse vertices
        for _ in 0..<vertexCount {
            guard let line = lines.first else {
                throw PlyParseError.invalidData
            }
            lines.removeFirst()
            let components = line.split(separator: " ").compactMap { Float($0) }
            guard components.count >= 3 else {
                throw PlyParseError.invalidData
            }
            model.vertices.append(PlyVertex(x: components[0], y: components[1], z: components[2]))
        }

        // Parse faces
        for _ in 0..<faceCount {
            guard let line = lines.first else {
                throw PlyParseError.invalidData
            }
            lines.removeFirst()
            let components = line.split(separator: " ").compactMap { Int($0) }
            guard components.count > 1 else {
                throw PlyParseError.invalidData
            }
            let vertexIndices = Array(components[1...])
            model.faces.append(PlyFace(vertexIndices: vertexIndices))
        }

        return model
    }
    
    func parseLargeFile(from url: URL) throws -> PlyModel {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { fileHandle.closeFile() }
        
        guard let header = fileHandle.readLine(), header == "ply" else {
            throw PlyParseError.invalidHeader
        }
        
        var isAscii = false
        var vertexCount = 0
        var faceCount = 0
        var headerParsed = false
        var model = PlyModel()
        
        while let line = fileHandle.readLine() {
            if line == "end_header" {
                headerParsed = true
                break
            } else if line.hasPrefix("format ascii") {
                isAscii = true
            } else if line.hasPrefix("element vertex") {
                vertexCount = Int(line.components(separatedBy: " ")[2]) ?? 0
            } else if line.hasPrefix("element face") {
                faceCount = Int(line.components(separatedBy: " ")[2]) ?? 0
            } else if line.hasPrefix("format binary") {
                throw PlyParseError.unsupportedFormat
            }
        }
        
        guard headerParsed, isAscii else {
            throw PlyParseError.invalidHeader
        }
        
        // Parse vertices
        for _ in 0..<vertexCount {
            guard let line = fileHandle.readLine() else {
                throw PlyParseError.invalidData
            }
            let components = line.split(separator: " ").compactMap { Float($0) }
            guard components.count >= 3 else {
                throw PlyParseError.invalidData
            }
            model.vertices.append(PlyVertex(x: components[0], y: components[1], z: components[2]))
        }
        
        // Parse faces
        for _ in 0..<faceCount {
            guard let line = fileHandle.readLine() else {
                throw PlyParseError.invalidData
            }
            let components = line.split(separator: " ").compactMap { Int($0) }
            guard components.count > 1 else {
                throw PlyParseError.invalidData
            }
            let vertexIndices = Array(components[1...])
            model.faces.append(PlyFace(vertexIndices: vertexIndices))
        }
        
        return model
    }
}

extension FileHandle {
    func readLine() -> String? {
        var lineData = Data()
        while let char = try? self.read(upToCount: 1), let byte = char.first {
            if byte == 10 { // Newline character
                break
            }
            lineData.append(byte)
        }
        return String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
