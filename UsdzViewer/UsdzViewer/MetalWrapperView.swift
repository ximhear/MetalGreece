//
//  MetalWrapperView.swift
//  StlViewer
//
//  Created by gzonelee on 12/26/24.
//

import SwiftUI
import ModelIO

struct MetalWrapperView: View {
    let fileName: String?
    @State var stepValue: Float = 10
    @State var translationX: Float = 0
    @State var translationY: Float = 0
    @State var translationZ: Float = 100
    var body: some View {
        VStack {
            if let fileName {
                MetalView(fileName: fileName, x: translationX, y: translationY, z: translationZ)
                    .edgesIgnoringSafeArea(.all)
            }
            else {
                ZStack {
                    Color.red
                }
            }
            VStack {
                HStack {
                    Text("Step Value")
                    TextField("Step Value", value: $stepValue , formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("X")
                    Text("\(translationX)")
                    Stepper("", value: $translationX, step: stepValue) { stepValue in
                        GZLogFunc(stepValue)
                    }
                }
                HStack {
                    Text("Y")
                    Text("\(translationY)")
                    Stepper("", value: $translationY, step: stepValue) { stepValue in
                        GZLogFunc(stepValue)
                        
                    }
                }
                HStack {
                    Text("Z")
                    Text("\(translationZ)")
                    Stepper("", value: $translationZ, step: stepValue) { stepValue in
                        GZLogFunc(stepValue)
                        
                    }
                }
            }
                
            .padding()
        }
    }
}

#Preview {
    MetalWrapperView(fileName: nil)
}
