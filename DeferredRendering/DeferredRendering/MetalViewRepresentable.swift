//
//  MetalViewRepresentable.swift
//  DeferredRendering
//
//  Created by gzonelee on 12/14/24.
//

import Foundation
import SwiftUI
import MetalKit

struct MetalViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.delegate = context.coordinator
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        // Handle view size changes, etc.
    }

    func makeCoordinator() -> Renderer {
        return Renderer()
    }
}
