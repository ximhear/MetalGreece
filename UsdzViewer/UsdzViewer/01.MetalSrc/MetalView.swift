//
//  MetalView.swift
//  ShadowMap
//
//  Created by gzonelee on 12/12/24.
//

import SwiftUI
import MetalKit
import ModelIO

struct MetalView: UIViewRepresentable {
    let fileName: String
    let x: Float
    let y: Float
    let z: Float
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero)
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColorMake(0.8,0.8,0.9,1.0)
        context.coordinator.renderer = Renderer(mtkView: mtkView, fileName: fileName)
        mtkView.delegate = context.coordinator
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer.viewX = x
        context.coordinator.renderer.viewY = y
        context.coordinator.renderer.viewZ = z
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: Renderer!

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.resize(size: size)
        }

        func draw(in view: MTKView) {
            renderer.draw(in: view)
        }
    }
}


