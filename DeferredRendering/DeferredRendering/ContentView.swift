//
//  ContentView.swift
//  DeferredRendering
//
//  Created by gzonelee on 12/14/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MetalViewRepresentable()
            .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    ContentView()
}
